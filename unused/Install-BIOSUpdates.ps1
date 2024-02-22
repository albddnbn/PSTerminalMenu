function Install-BIOSUpdates {
    <#
.SYNOPSIS
    Uses the 'bios' directory to find bios update exe's for a target group of computers, and then copies them to the target computers and executes the executables.

.DESCRIPTION
    The bios executables are executed WITHOUT a force restart parameter, so this means that you're only flashing the BIOS firmware, and have the opportunity to review the flash logs before sending a reboot to the computer.

.PARAMETER TargetComputer
    Target computer or computers of the function.
    Single hostname, ex: 's-c136-02' or 's-c136-02.dtcc.edu'
    Path to text file containing one hostname per line, ex: 'D:\computers.txt'
    First section of a hostname to generate a list, ex: s-a227- will create a list of all hostnames that start with s-a227-, in other words the Stanton Open Computer Lab student computers.

.EXAMPLE
    Install-BIOSUpdates -TargetComputer @('computer1', 'computer2', 'computer3')

.EXAMPLE
    $computers = Get-ADComputer -Filter {DNSHostname -like "s-a227-*"} | Select -Exp DNSHostname
    Install-BIOSUpdates -TargetComputer $computers

.NOTES
    The bios directory in the menu's root has to be updated with latest BIOS files for this to work properly.
#>
    param(
        $TargetComputer
    )
    # STAGE 1 -- Setup, parameter intake, and initial checks
    $REPORT_DIRECTORY = 'BIOS'
    $thedate = Get-Date -Format 'yyyy-MM-dd'

    # UTILITY Functions - Dealing with TargetComputer and OutputFile
    # return new targetcomputer value
    . "$env:PSMENU_DIR\utils\Get-TargetComputers.ps1"
    $TargetComputer = Get-TargetComputers -TargetComputerInput $TargetComputer    $TargetComputer = $TargetComputer | where-object { $_ -ne $null }
    if ($TargetComputer.count -lt 20) {
        . "$env:MENU_UTILS\Get-LiveHosts.ps1"
        $TargetComputer = Get-LiveHosts -TargetComputerInput $TargetComputer
    }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Initiating 'Send BIOS Updates' protocol."

    if (-not (Test-Path "$env:PSMENU_DIR\reports\$thedate")) {
        New-Item -Path "$env:PSMENU_DIR\reports\$thedate" -ItemType Directory
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Created $thedate folder in reports directory."
    }
    # make sure REPORT_DIRECTORY directory is in reports/thedate
    if (-not (Test-Path "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY")) {
        New-Item -Path "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY" -ItemType Directory
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Created $REPORT_DIRECTORY folder in reports/$thedate directory."
    }
    # End of Stage 1 -- Setup, parameter intake, and initial checks
    write-host "$targetcomputer" -foregroundcolor magenta
    # STAGE 2: Get current BIOS versions for Target computers
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning the check for occupied computers..."
    $initial_bios_info = Invoke-Command -ComputerName $TargetComputer -Scriptblock {
        # $user = get-ciminstance -class win32_computersystem | select -exp username
        $user = get-process -name 'explorer' -includeusername -erroraction silentlycontinue | Select -Exp Username
        $modelinfo = Get-Ciminstance -class win32_computersystem | select -exp Model
        $biosversion = get-ciminstance -class win32_bios | select -exp SMBIOSBIOSVersion
        $tpmdetails = get-tpm | select -exp tpmenabled


        $obj = [pscustomobject]@{
            PCModel      = $modelinfo
            BiosVer      = $biosversion
            LoggedInUser = $false
            TPMStatus    = $tpmdetails
            BiosFile     = ""
        }
        if ($user) { 
            $obj.LoggedInUser = $user 
        }
        $obj
    }

    # output initial bios info to .csv file
    $initial_bios_info | Export-Csv -Path "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\initial_bios_info.csv" -NoTypeInformation

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Filtering out computers that have a user logged in..."

    $occupied_computers = $initial_bios_info | Where-Object { $_.LoggedInUser -ne $false }
    $occupied_computernames = $occupied_computers | select -exp pscomputername
    $unoccupied_computers = $initial_bios_info | Where-Object { $_.LoggedInUser -eq $false }
    $unoccupied_computernames = $unoccupied_computers | select -exp pscomputername

    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Occupied computers: " -NoNewline
    # Write-Host "$($occupied_computernames -join ', ')" -Foregroundcolor Yellow
    # Write-Host ""
    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Unoccupied computers: " -NoNewline
    # Write-Host "$($unoccupied_computernames -join ', ')" -ForegroundColor Green

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning the copying of BIOS update executables to Target computers..."
    # get the BIOS files directory
    $bios_files_directory = Get-ChildItem -Path "$env:PSMEnu_DIR" -Filter "bios" -Directory -ErrorAction SilentlyContinue

    # STAGE 3: Get BIOS executable from bios directory based on Target computer's model, and copy it over, prompt user if there are multiple bios executable files for a computer model.
    ForEach ($open_pc in $initial_bios_info) {
        $pcmodel = $open_pc.PCModel
        $hostname = $open_pc.pscomputername
        # replaces the word 'tower' so a modelname like: 'precision 3630 tower' would be 'precision 3630'
        $pcmodel = $pcmodel -replace ' Tower', ''
        # grab the bios ex file from source computer
        $biosfile = Get-ChildItem -Path "$($bios_files_directory.fullname)\$pcmodel" -Filter "*.exe" -File -ErrorAction SilentlyContinue
        # copy over to target pc, generate red text to terminal if bios not found for that model.
        if ($biosfile) {
            if ($biosfile.count -gt 1) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found multiple bios files for $pcmodel, please choose one to copy to $hostname."
                $biosfilechoice = Menu $($Biosfile | select -exp name)
                $biosfile = $biosfile | Where-Object { $_.name -eq $biosfilechoice }
            }
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($biosfile.fullname), copying to $hostname after creating C:\temp if necessary..."
            $testing_for_tempdir = Test-path "\\$hostname\c$\temp" -erroraction silentlycontinue
            if (-not $testing_for_tempdir) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Creating C:\temp on $hostname..." -Foregroundcolor Yellow
                New-Item -Path "\\$hostname\c$\temp" -ItemType 'directory' | Out-Null
            }
            Copy-ITem "$($biosfile.fullname)" -Destination "\\$hostname\c$\temp" -force
            # add a biosfile property that holds path to bios file
            $open_pc.BiosFile = $biosfile | select -exp name
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find bios exe file for $pcmodel"
        }
    }

    # STAGE 4: Execute BIOS update files on all Target Computers, without forcing reboot and with logging.
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Executing bios updates on $($TargetComputer -join ', ')..."
    Invoke-Command -Computername $TargetComputer -Scriptblock {
        $biosfilename = $using:initial_bios_info | where-object { $_.pscomputername -like "$env:COMPUTERNAME*" } | select -exp biosfile
        Read-host "$biosfilename - continue?"
        # gets bios .exe on remote PC, executes and prints log to C:\biosupdatelog.txt
        $biosexe = Get-Childitem -Path 'C:\temp' -Filter "*$biosfilename" -File -ErrorAction SilentlyContinue
        if ($biosexe) {
            Set-Location 'C:\temp'
            write-host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] :: Found $($biosexe.fullname) on $env:COMPUTERNAME, executing with /s /l /p parameters..."
            Start-Process "C:\temp\$biosfilename" -ArgumentList '/s /l=C:\temp\biosupdatelog.txt /p=border9' -Wait
        }
        else {
            Write-Host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] :: ERROR: Unable to find $biosfilename in C:\ of $env:COMPUTERNAME!" -Foregroundcolor Red
        }
    }


    # STAGE 5: Log collection
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Collecting logs..." 
    $bios_flash_logs = [system.collections.arraylist]::new()

    # cycle through unoccupied computers again, gathering the biosupdatelog file
    ForEach ($open_pc in $TargetComputer) {
        # collect log content and pc name, save it into list of objects / output to files on local computer
        $logcontent = Get-Content "\\$open_pc\c$\temp\biosupdatelog.txt"

        $obj = [pscustomobject]@{
            PCName = $open_pc
            Log    = $logcontent
        }

        $bios_flash_logs.Add($obj) | out-null

        $output_filename = "$($obj.PCName)-biosflashlog.txt"
        $output_filepath = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$output_filename"
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Outputting flash log from $($obj.PCName) to $output_filepath..."
    
        $obj.Log | Out-File -FilePath $output_filepath    
    }

    # STAGE 6: Prompt person running script to reboot unoccupied target computers
    $ask_to_send_reboots = Read-Host "Finished collecting logs, send reboots to *unoccupied* computers? (y/n)"
    if ($ask_to_send_reboots.ToLower() -eq 'n') {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exiting script, no reboots sent."
        return
    }
    # 5.5: If they choose yes, script checks PCs again for anyone logged in - if the PC is free, script forces a reboot on the computer.
    elseif ($ask_to_send_reboots.ToLower() -eq 'y') {
        # $reboot_computers = $unoccupied_computernames
        # checks again for logged in users:
        $user_check_results = Invoke-Command -ComputerName $TargetComputer -Scriptblock {
            $user = get-ciminstance -class win32_computersystem | select -exp username

            $obj = [pscustomobject]@{
                LoggedInUser = $false
            }
            if ($user) { $obj.LoggedInUser = $user }
            $obj
        }
        $computers_getting_rebooted = $($user_check_results | Where-Object { $_.LoggedInUser -eq $false } | select -exp pscomputername)
        write-host "Restarting: $($computers_getting_rebooted -join ', ')..."
        $computers_getting_rebooted | Restart-Computer -Force
    }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
    Write-Host "BIOS update process complete, please remember to check that devices come back online." -Foregroundcolor Green
    Write-Host "These computers were skipped because they're unresponsive:"
    Write-Host "$($skipped_computers -join ', ')" -foregroundcolor red
    $skipped_computers | Out-File -FilePath "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\skipped_computers.txt"
    # Explorer.exe "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY"
    Invoke-Item  "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY"

}
