function Install-BIOSUpdates {
    <#
.SYNOPSIS
    Sends BIOS executables to target Dell computers based on computer model, then executes the executable silently without forcing a reboot.
    The script can send a reboot to unoccupied computers after executing the BIOS executables. If bios executable is run on a computer, but the computer is not rebooted - the bios update WILL take place on next reboot if flash was successful.
    The script can

.DESCRIPTION
    The bios executables are executed WITHOUT a force restart parameter, so this means that you're only flashing the BIOS firmware, and have the opportunity to review the flash logs before sending a reboot to the computer.

.PARAMETER TargetComputer
    Target computer or computers of the function.
    Single hostname, ex: 's-c136-02' or 's-c136-02.dtcc.edu'
    Path to text file containing one hostname per line, ex: 'D:\computers.txt'
    First section of a hostname to generate a list, ex: s-a227- will create a list of all hostnames that start with s-a227-, in other words the Stanton Open Computer Lab student computers.

.PARAMETER Outputfile
    Used in part to create filename of initial bios info output file.

.PARAMETER FlashAll
    If 'y' is input for FlashAll, the script will still flash bios on computers that have a user logged in, instead of skipping the computer altogether.
    Doing so will cause the BIOS update to take place the next time that computer reboots - this could cause a problem if the computer reboots in a few days and encounters an error.

.EXAMPLE
    Install-BIOSUpdates -TargetComputer @('computer1', 'computer2', 'computer3')

.EXAMPLE
    $computers = Get-ADComputer -Filter {DNSHostname -like "s-a227-*"} | Select -Exp DNSHostname
    Install-BIOSUpdates -TargetComputer $computers

.NOTES
    The bios directory in the menu's root has to be updated with latest BIOS files for this to work properly.
#>
    param(
        $TargetComputer,
        $outputfile,
        [String]$FlashAll = 'no'
    )


    $BIOSPWD = ''
    if ($BIOSPWD -eq '') {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Please enter BIOS password for Dell computers."
    }

    # STAGE 1 -- Setup, parameter intake, and initial checks
    $thedate = Get-Date -Format 'yyyy-MM-dd'
    $REPORT_DIRECTORY = 'BIOS'
    # folder for bios executables - created in C:\temp
    $BIOS_DIRECTORY = 'BIOSUPDATE'
    # make sure REPORT_DIRECTORY directory is in reports/thedate
    if (-not (Test-PAth "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY" -erroraction SilentlyContinue)) {
        New-Item -Path "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY" -ItemType 'directory' -Force | Out-Null
    }
    # return new targetcomputer value
    try {
        $TargetComputer = Get-TargetComputers -TargetComputerInput $TargetComputer
    }
    catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow

        if (Test-Path $TargetComputer -erroraction silentlycontinue) {
            Write-Host "$TargetComputer is a file, getting content to create hostname list."
            $TargetComputer = Get-Content $TargetComputer
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer is not a valid hostname or file path." -Foregroundcolor Red
            return
        }
    }     
    
    $TargetComputer = $TargetComputer | where-object { $_ -ne $null }

    # create list of online / offline hosts
    $offline_hosts = @()
    $online_hosts = @()
    ForEach ($single_computer in $TargetComputer) {
        $test_ping = Test-Connection $single_computer -Count 1 -Quiet
        if ($test_ping) {
            $online_hosts += $single_computer
        }
        else {
            $offline_hosts += $single_computer
        }
    }

    $TargetComputer = $online_hosts

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Initiating 'Send BIOS Updates' protocol."

    $get_current_bios_scriptblock = [scriptblock]::Create(
        @'
# get some basic details about the computer
$model = (get-ciminstance -class win32_computersystem).model
$biosversion = (get-ciminstance -class win32_bios).smbiosbiosversion
# current_user
$current_user = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
$obj = [PSCustomObject]@{
    Model           = $model
    CurrentUser     = $current_user
    BiosVersion     = $biosversion
    BiosFile        = ""
}
return $obj
'@
    )
    # }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Getting current BIOS versions for $($TargetComputer -join ', '), and checking for occupation."
    
    if ($Targetcomputer -eq '127.0.0.1') {
        $initial_bios_info = Invoke-Command -Scriptblock $get_current_bios_scriptblock
        # add localhost pscomputername for clarity / continuity purposes
        $initial_bios_info | add-member -membertype NoteProperty -Name 'PSComputerName' -Value '127.0.0.1'
    }
    else {
        $initial_bios_info = Invoke-Command -ComputerName $TargetComputer -Scriptblock $get_current_bios_scriptblock
    }

    ## cycle through $initial_bios_info, and set the biosfile property for each computer model
    ForEach ($single_computer in $initial_bios_info) {
        $computer_name = $single_computer.pscomputername
        $computer_model = $single_computer.model -replace ' Tower', ''
        $bios_directory = Get-ChildItem -Path "$env:PSMENU_DIR\bios" -Filter "$computer_model*" -Directory -ErrorAction SilentlyContinue
        if (-not $bios_directory) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Unable to find bios directory for $computer_model, skipping." -Foregroundcolor Red
            Read-Host "Press enter to continue to next computer."
            continue
        }
        $bios_file = Get-ChildItem -Path "$($bios_directory.fullname)" -Filter "*.exe" -File -ErrorAction SilentlyContinue
        if (-not $bios_file) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Unable to find bios file for $computer_model, skipping." -Foregroundcolor Red
            Read-Host "Press enter to continue to next computer."
            continue
        }
        # deal with multiple bios files (different versions)
        if ($bios_file.count -gt 1) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found multiple bios files for $computer_model, please choose one to copy to $($single_computer.pscomputername)."
            $bios_file_choice = Menu $($ios_file.name)
            $bios_file = $bios_file | Where-Object { $_.name -eq $bios_file_choice }
        }

        $single_computer.BiosFile = $bios_file.name
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($bios_file.name), copying to $($single_computer.pscomputername) after creating C:\temp if necessary..."
    
        # make sure folder is there, and copy bios file over
        if ($computer_name -eq '127.0.0.1') {
            Remove-ITem -Path "C:\temp\$BIOS_DIRECTORY" -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -Path "C:\temp\$BIOS_DIRECTORY" -Itemtype 'Directory' -Force | Out-Null
            Copy-Item "$($bios_file.fullname)" -Destination "C:\temp\$BIOS_DIRECTORY" -Force
        }
        else {
            Remove-Item -Path "\\$computer_name\c$\temp\$BIOS_DIRECTORY" -Recurse -erroraction SilentlyContinue
            New-Item -Path "\\$computer_name\c$\temp\$BIOS_DIRECTORY" -ItemType 'directory' -ErrorAction SilentlyContinue | Out-Null
            Copy-Item "$($bios_file.fullname)" -Destination "\\$computer_name\c$\temp\$BIOS_DIRECTORY" -Force
        }

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$computer_name] :: Copied  $($bios_file.name) to C:\temp\$BIOS_DIRECTORY" -Foregroundcolor Green    
    }

    # skip_occupied = 'y' will not take any action on computers with users logged in
    # skip_occupied = 'n' will still flash bios update to computers, but wont force reboot. BIOS update should take place next scheduled reboot.
    $update_bios_scriptblock = {
        param(
            $TargetDir,
            $skip_occupied
            # $logfilepath
        )
        $obj = [pscustomobject]@{
            BiosFlashed  = $false
            LogFilePath  = ""
            UserLoggedIn = $null
        }


        $check_for_user = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
        # $check_for_user = $check_for_user -replace 'DTCC\', ''
        $obj.UserLoggedIn = $check_for_user
        if (($skip_occupied -eq 'y') -and ($check_for_user)) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: User $check_for_user is logged in, skipping bios update." -Foregroundcolor Red
            return $obj
        }

        $biosexe = Get-Childitem -Path $TargetDir -Filter "*.exe" -File -ErrorAction SilentlyContinue
        if ($biosexe) {
            write-host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] :: Found $($biosexe.fullname) on $env:COMPUTERNAME, executing with /s /l /p parameters..."
            Start-Process "$($biosexe.fullname)" -ArgumentList "/s /l=$TargetDIR\biosupdatelog.txt /p=$using:BIOSPWD" -Wait
            $obj.BiosFlashed = $true
            $obj.LogFilePath = "$TargetDIR\biosupdatelog.txt"
            return $obj
        }
        else {
            Write-Host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] :: ERROR: Unable to find an executable in $TargetDir of $env:COMPUTERNAME!" -Foregroundcolor Red
        }
    }

    ## EXECUTE BIOS UPDATE on local / remote computer(s)
    if ($TargetComputer -eq '127.0.0.1') {
        $bios_update_results = Invoke-Command -Scriptblock $update_bios_scriptblock -ArgumentList "C:\temp\$BIOS_DIRECTORY", $FlashAll
        $bios_update_results | add-member -membertype NoteProperty -Name 'PSComputerName' -Value '127.0.0.1'

    }
    else {
        $bios_update_results = Invoke-Command -ComputerName $TargetComputer -scriptblock $update_bios_scriptblock -ArgumentList "C:\temp\$BIOS_DIRECTORY", $FlashAll
    }


    # log collection, printing results...
    # create logs dir in reports:
    if (-not (Test-Path "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\logs" -erroraction silentlycontinue)) {
        New-Item -Path "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\logs" -ItemType 'directory' -Force | Out-Null
    }

    ForEach ($single_computer in $bios_update_results) {
        $logfile_path = $single_computer.LogFilePath
        
        $computer_name = $single_computer.PSComputerName

        if ($computername -eq '127.0.0.1') {
            Copy-item -path $logfile_path -Destination "$env:PSMENU_DIR\reports\$thedate\$report_directory\logs"
        }
        else {
            $logfile_path = $logfile_path.replace('C:', "\\$computer_name\C$")
            COpy-Item -Path $logfile_path -Destination "$env:PSMENU_DIR\reports\$thedate\$report_directory\logs"
        }

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$computer_name] :: Copied $logfile_path to " -nonewline
        Write-Host "$env:PSMENU_DIR\reports\$thedate\$report_directory\logs" -nonewline -foregroundcolor Yellow
        Write-Host ", deleting C:\temp\$BIOS_DIRECTORY."

        $logfolder = (Get-Item $logfile_path).directoryname
        Remove-Item -Path $logfolder -Recurse -Force -ErrorAction SilentlyContinue

    }

    # give user option to reboot computers:
    $unoccupied_computers = ($bios_update_results | where-object { $null -eq $_.loggedinuser }).pscomputername
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: These computers are unoccupied and can be rebooted now to enact the BIOS update: " -NoNewline
    Write-Host "$($unoccupied_computers -join ', ')" -Foregroundcolor Green
    $reply = Read-Host "Reboot computers that don't have users logged in? [y/n]"
    if ($reply.ToLower() -eq 'y') {
        Restart-Computer -ComputerName $unoccupied_computers
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Rebooted $($unoccupied_computers -join ', ')."
    }
    else {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] " -NoNewline
        Write-Host "[WARNING]" -nonewline -foregroundcolor Yellow
        Write-Host " :: Computers aren't being rebooted - they WILL attempt to update BIOS on next scheduled reboot!"
    }


    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
    Write-Host "BIOS update process complete, please remember to check that devices come back online.`n" -Foregroundcolor Green

    Write-Host "These computers were skipped because they're unresponsive:"
    Write-Host "$($offline_hosts -join ', ')" -foregroundcolor red
    $offline_hosts | Out-File -FilePath "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\skipped_computers.txt"
    Invoke-Item  "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY"

}
