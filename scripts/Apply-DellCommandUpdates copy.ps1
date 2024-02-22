Function Apply-DellCommandUpdates {
    <#
    .SYNOPSIS
        Looks for dcu-cli.exe in Program Files (x86) and executes it with /applyupdates switch.
        This will not reboot the computer automatically (/applyupdates -reboot=disable). /applyupdates -reboot=enable switch is needed to do that.

    .DESCRIPTION
        More detailed description on what the function does.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 's-c136-02' or 's-c136-02.dtcc.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: s-a227- will create a list of all hostnames that start with 
        s-a227-, in other words the Stanton Open Computer Lab student computers.

    .PARAMETER WeeklyUpdates
        'y' will use this command: &"$($dellcommandexe.fullname)" /configure -scheduleWeekly=Sun,02:00
        to set weekly updates on Sundays at 2am.
        'n' will not set weekly update times, leaving update schedule as default (every 3 days).

    .PARAMETER OutputFile
        'n' or 'no' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and CreateOutputFile input.
        Ex: CreateOutputfile = 'A220', output file(s) will be in $env:PSMENU_DIR\reports\AssetInfo - A220\


    .EXAMPLE
        An example of one way of running the function.

    .EXAMPLE
        You can include as many examples as necessary to reflect different ways of running the function, different parameters, etc.

    .NOTES
        Executing like this: Start-Process "$($dellcommandexe.fullname)" -argumentlist $params doesn't show output.
        Trying $result = (Start-process file -argumentlist $params -wait -passthru).exitcode -> this still rebooted s-c136-03

    #>
    param(
        $TargetComputer,
        $WeeklyUpdates
        # [string]$Outputfile
    )
    # dot source utility functions
    ForEach ($utility_function in (Get-ChildItem -Path "$env:MENU_UTILS" -Filter '*.ps1' -File)) {
        . $utility_function.fullname
    }
    $outputfile = 'n'
    # set REPORT_TITLE for output, and set thedate variable
    $REPORT_TITLE = "Apply-DCUpdates" # reports outputting to $env:PSMENU_DIR\reports\$thedate\Sample-Function\
    $thedate = Get-Date -Format 'yyyy-MM-dd'


    # Filter TargetComputer input to create hostname list:
    $TargetComputer = Get-TargetComputers -TargetComputerInput $TargetComputer

    # create an output filepath, not including file extension that can be used to create .csv / .xlsx report files at end of function
    if ($outputfile -eq '') {
        # create default filename
        $outputfile = Get-OutputFileString -Titlestring $REPORT_TITLE -rootdirectory $env:PSMENU_DIR -foldertitle $REPORT_TITLE -reportoutput

    }
    elseif ($Outputfile.ToLower() -notin @('n', 'no')) {
        # if outputfile isn't blank and isn't n/no - use it for creation of output filepath
        $outputfile = Get-OutputFileString -Titlestring $outputfile -rootdirectory $env:PSMENU_DIR -foldertitle $REPORT_TITLE -reportoutput
    }
    # if it speeds things up / makes sense - you can ping targets first to filter out offline hosts.
    # this section is important for functions that do things like install software or run bios updates - you want to have a record of the computers that are skipped over.
    $max_hosts = 30
    if ($TargetComputer.count -lt $max_hosts) {
        $TargetComputer = Get-LiveHosts -TargetComputerInput $Targetcomputer
    }

    if ($WeeklyUpdates.ToLower() -eq 'y') {
        $WeeklyUpdates = $true
    }
    else {
        $WeeklyUpdates = $false
    }

    ## CHECK FOR DELL COMMAND | UPDATE on Target computers and ask user if they want to install or skip these machines.
    #
    $check_for_dellupdate_app = {
        $result = Test-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{74D42EE8-F48D-4DC2-9635-41A324EEACCF}" -ErrorAction SilentlyContinue
        if ($null -eq $result) {
            $result = $false
        }
        else {
            $result = $true
        }
        $obj = [pscustomobject]@{
            DCUInstalled = $result
        } 
        return $obj
    }

    $check_computers = Invoke-Command -ComputerName $TargetComputer -ScriptBlock $check_for_dellupdate_app

    $no_command_update = $check_computers | where-object { $_.DCUInstalled -eq $false }
    if ($no_command_update) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No Dell Command Update found on: $($no_command_update -join ', ')" -ForegroundColor Red

        $reply = Read-Host "Install Dell Command | Update software on these computers? (y/n)"

        if ($reply.ToLower() -eq 'y') {
            $DeploymentFolder = Get-ChildItem -Path "$env:PSMENU_DIR\deploy\applications" -Filter "DellCommandUpdate" -Directory -ErrorAction SilentlyContinue
            $execute_psadtinstall_ps1 = Get-ChildItem -Path "$env:LOCAL_SCRIPTS" -Filter 'Execute-PSADTInstall.ps1' -File -ErrorAction SilentlyContinue
            if ((-not $DeploymentFolder) -or (-not $execute_psadtinstall_ps1)) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: DellCommandUpdate folder not found in $env:PSMENU_DIR\deploy\applications, skipping DCU install /  application of updates on these computers." -Foregroundcolor Red
            
                $TargetComputer = $targetComputer | where-object { $_ -notin $($no_command_update | select -exp pscomputername) }
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($DeploymentFolder.fullname) and $($execute_psadtinstall_ps1.fullname), copying to computers and executing."
                if ($no_command_update -eq '127.0.0.1') {
                    # can run locally using deployment folder in menu:
                    Set-Location "$($DeploymentFolder.FullName)"
                    Powershell.exe -Executionpolicy bypass "./Deploy-$($deploymentfolder.name).ps1" -Deploymenttype 'install' -deploymode 'silent'

                    Set-Location "$env:PSMENU_DIR"
     
                }
                else {
                    $skip_pcs = Read-Host "Skip computers that have users logged in? (y/n)"
                    if ($skip_pcs.ToLower() -ne 'n') {
                        $skip_pcs = 'y'
                    }
                    # clear previous folders:
                    ForEach ($single_computer in $($no_command_update | Select -exp PSComputerName)) {
                        Write-Host "Removing any previous deployment folders for the app, and copying new folder over."
                        Remove-Item "\\$single_computer\C$\temp\$($deploymentfolder.name)" -recurse -force -erroraction SilentlyContinue
                        Copy-Item "$($DeploymentFolder.fullname)" -Destination "\\$single_computer\C$\temp\$($DeploymentFolder.Name)" -recurse -Force     
                    }
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Finished copying deployment folders to remote computers, executing install scripts now..."
                    ## Actual installation / running the script from ./menu/files
                    Invoke-Command -ComputerName $($no_command_update | Select -exp pscomputername) -FilePath "$($execute_psadtinstall_ps1.fullname)" -ArgumentList "DellCommandUpdate", $skip_pcs
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Finished installing Dell Command | Update on $($no_command_update.pscomputername) -join ', '). A good addition to this function would be to add something that checks for software on computers afterwards."
                }  
            } 
        }
        else {
            # remove machines that don't have DCU from TargetComputer
            $TargetComputer = $targetComputer | where-object { $_ -notin $($no_command_update | select -exp pscomputername) }

        }
    }
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Computer list after DCU software check: $($Targetcomputer -join ', ')."
    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning function on $($TargetComputer -join ', ')"

    # look for Dell Command Update encrypted BIOS pw file:
    $encrypted_bios_file = Get-ChildItem -Path "$env:SUPPORTFILES_DIR" -Filter "StantonEncryptedBios.txt" -File -ErrorAction SilentlyContinue
    if (-not $encrypted_bios_file) {
        $encrypted_bios_file = Read-Host "Couldn't find StantonEncryptedBIOS.txt, enter absolute path to file"
    }
    # Read-Host "TESTING: This is encryted_bios_file variable 'name': $($encrypted_bios_file.name). Press enter to continue"

    # # take insecure user input of encryption key string
    # $keystring = Read-Host "Enter encryption key string" -AsSecureString
    
    ForEach ($single_computer in $TargetComputer) {
        Copy-Item "$($encrypted_bios_file.fullname)" "\\$single_computer\c$\temp\biosfile.txt" -Force
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Copied $($encrypted_bios_file.fullname) to \\$single_computer\c$\temp\biosfile.txt"
    }

    $results = Invoke-Command -ComputerName $Targetcomputer -scriptblock {

        $LoggedInUser = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username

        $obj = [pscustomobject]@{
            DCUInstalled   = $false
            UpdatesStarted = ""
            # DCUExitCode    = ""
            Username       = $LoggedInUser
        }

        $apply_updates_process_started = $false
        # find Dell Command Update executable
        $dellcommandexe = Get-ChildItem -Path "${env:ProgramFiles(x86)}" -Filter "dcu-cli.exe" -File -Recurse # -ErrorAction SilentlyContinue
        
        $bioskeyfile = Get-ChildItem -Path "C:\temp" -Filter 'biosfile.txt' -File -ErrorAction SilentlyContinue
        # stop running on this computer if its not there ()
        if ((-not $dellcommandexe) -or (-not $bioskeyfile)) {
            # $obj.DCUInstalled = $false
            Write-Host "[$env:COMPUTERNAME] :: Dell Command Update not installed, or couldn't find BIOS encryption file." -Foregroundcolor Red
            $obj
            continue
        }

        if ($obj.LoggedInUser) {
            Write-Host "[$env:COMPUTERNAME] :: Found $($obj.LoggedInUser), skipping application of updates." -Foregroundcolor Yellow
        }
        else {
            Write-Host "[$env:COMPUTERNAME] :: Found $($dellcommandexe.fullname), executing with the /applyupdates -reboot=enable parameters." -ForegroundColor Yellow
            # NOTE: abuddenb - Haven't been able to get the -reboot=disable switch to work yet.
            # Start-Process $($dellcommandexe.fullname) -argumentlist "/applyUpdates -encryptedPasswordFile=$($bioskeyfile.fullname) -encryptionKey=""$($keystring)"" -reboot=enable"
            &$($dellcommandexe.fullname) /applyUpdates -encryptedPasswordFile=$($bioskeyfile.fullname) -encryptionKey='Slurmsz790' -reboot=enable

            $apply_updates_process_started = $true
        }
        # return results of a command or any other type of object, so it will be addded to the $results list
        $userloggedin
        $obj = [pscustomobject]@{
            UpdatesStarted = $apply_updates_process_started
            UserLoggedIn   = $userloggedin
        }
        $obj
    } | Select * -ExcludeProperty RunSpaceId, PSShowComputerName # filters out some properties that don't seem necessary for these functions

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting results to $outputfile .csv / .xlsx."
    if ($outputfile.tolower() -ne 'n') {
        Output-Reports -Filepath $outputfile -Content $results -ReportTitle $REPORT_TITLE -CSVFile $true -XLSXFile $true
    }
    else {
        if ($results.count -le 2) {
            $results | Format-List
        }
        else {
            $results | Out-Gridview
        }
    
    }
    
    # open the folder - output-reports will already auto open the .xlsx if it was created
    Invoke-Item -Path "$env:PSMENU_DIR\reports\$thedate\$REPORT_TITLE"

}