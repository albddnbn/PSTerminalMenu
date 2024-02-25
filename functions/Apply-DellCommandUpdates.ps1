Function Apply-DellCommandUpdates {
    <#
    .SYNOPSIS
        Looks for & executes the dcu-cli.exe on target machine(s) using the '/applyUpdates -reboot=enable' switches.
        Function will automatically pass over currently occupied computers.
        BIOS updates will not be applied unless BIOS password is added to dcu-cli.exe command in some form.

    .DESCRIPTION
        End of function prints 3 lists to terminal:
            1. Computers with users logged in, and were skipped.
            2. Computers without Dell Command | Update installed, and were skipped.
            3. Computers that have begun to apply updates and should be rebooting momentarily.

    .PARAMETER TargetComputer
        Target computer or computers of the function. Single hostname, ex: 's-c136-02' or 's-c136-02.dtcc.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .PARAMETER WeeklyUpdates
        'y'     will use this command: &"$($dellcommandexe.fullname)" /configure -scheduleWeekly=Sun,02:00
                to set weekly updates on Sundays at 2am.           
        'n'     will not set weekly update times, leaving update schedule as default (every 3 days).

    .NOTES
        Executing like this: Start-Process "$($dellcommandexe.fullname)" -argumentlist $params doesn't show output.
        Trying $result = (Start-process file -argumentlist $params -wait -passthru).exitcode -> this still rebooted s-c136-03
                ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        $TargetComputer,
        $WeeklyUpdates
    )
    ## EXECUTE APPLY UPDATES using DCU-CLI.EXE:
    #
    $results = Invoke-Command -ComputerName $Targetcomputer -scriptblock {

        $weeklyupdates_setting = $using:WeeklyUpdates


        $LoggedInUser = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username

        $obj = [pscustomobject]@{
            DCUInstalled   = "NO"
            UpdatesStarted = "NO"
            # DCUExitCode    = ""
            Username       = $LoggedInUser
        }
        if ($obj.UserName) {
            Write-Host "[$env:COMPUTERNAME] :: $LoggedInUser is logged in, skipping computer." -Foregroundcolor Yellow
        }
        # $apply_updates_process_started = $false
        # find Dell Command Update executable
        $dellcommandexe = Get-ChildItem -Path "${env:ProgramFiles(x86)}" -Filter "dcu-cli.exe" -File -Recurse # -ErrorAction SilentlyContinue
        if (-not ($dellcommandexe)) {
            Write-Host "[$env:COMPUTERNAME] :: NO Dell Command | Update found." -Foregroundcolor Red
        }
        else {
            $obj.DCUInstalled = "YES"
        }


        if (($obj.Username) -or (-not $dellcommandexe)) {
            $obj
            break
        }

        Write-Host "[$env:COMPUTERNAME] :: Found $($dellcommandexe.fullname), executing with the /applyupdates -reboot=enable parameters." -ForegroundColor Yellow
        # NOTE: abuddenb - Haven't been able to get the -reboot=disable switch to work yet.
        Write-Host "[$env:COMPUTERNAME] :: Configuring weekly update schedule."
        if ($weeklyupdates_setting.ToLower() -eq 'y') {
            &"$($dellcommandexe.fullname)" /configure -scheduleWeekly='Sun,02:00' -silent
        }
        Write-Host "[$env:COMPUTERNAME] :: Applying updates now." -ForegroundColor Yellow
        &$($dellcommandexe.fullname) /applyUpdates -reboot=enable -silent

        $obj.UpdatesStarted = $true
        
        # return results of a command or any other type of object, so it will be addded to the $results list
        $obj
    } | Select * -ExcludeProperty RunSpaceId, PSShowComputerName # filters out some properties that don't seem necessary for these functions

    $occupied_computers = $($results | where-object { $_.Username } | select-object -expandproperty PSComputerName) -join ', '
    $need_dell_command_update_installed = $($results | where-object { $_.DCUInstalled -eq 'NO' } | select-object -expandproperty PSComputerName) -join ', '
    
    $currently_applying_updates = $($results | where-object { $_.UpdatesStarted -eq "YES" } | select-object -expandproperty PSComputerName) -join ', '
    Write-Host "These computers are occupied: " -nonewline
    Write-Host "$occupied_computers" -Foregroundcolor Yellow
    Write-Host ""
    Write-Host "These computers need Dell Command | Update installed: " -nonewline
    Write-Host "$need_dell_command_update_installed" -Foregroundcolor Red
    Write-Host ""
    Write-Host "These computers have begun to apply updates and should be rebooting momentarily: " -nonewline
    Write-Host "$currently_applying_updates" -Foregroundcolor Green

}