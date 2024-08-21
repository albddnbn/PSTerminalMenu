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
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

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
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        $WeeklyUpdates
    )
    ## 1. Handling TargetComputer input if not supplied through pipeline.
    ## 2. Create empty results container.
    BEGIN {
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline input for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }

                        $matching_hostnames = (([adsisearcher]"(&(objectCategory=Computer)(name=$computer*))").findall()).properties
                        $matching_hostnames = $matching_hostnames.name
                        $NewTargetComputer += $matching_hostnames
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }
        ## 2. Create results container
        $results = [system.collections.arraylist]::new()
    }
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responsive, check for dell command update executable and apply updates, report on results.
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            ## 1.
            if ($single_computer) {

                ## 2. test with ping:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    ## 3. If machine was responsive, check for dell command update executable and apply updates, report on results.
                    $dcu_apply_result = Invoke-Command -ComputerName $single_computer -scriptblock {

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
            
                    $results.Add($dcu_apply_result) | Out-Null

                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer didn't respond to one ping, skipping." -ForegroundColor Yellow
                }
            }
        }
    }

    ## 1. Output results to gridview and terminal
    END {
        if ($results) {
            $results | Out-GridView - "Dell Command | Update Results"
            $occupied_computers = $($results | where-object { $_.Username } | select-object -expandproperty PSComputerName) -join ', '
            $need_dell_command_update_installed = $($results | where-object { $_.DCUInstalled -eq 'NO' } | select-object -expandproperty PSComputerName) -join ', '
    
            $currently_applying_updates = $($results | where-object { $_.UpdatesStarted -eq "YES" } | select-object -expandproperty PSComputerName) -join ', '
            Write-Host "These computers are occupied: " -nonewline
            Write-Host "$occupied_computers" -Foregroundcolor Yellow
            Write-Host "`n"
            Write-Host "These computers need Dell Command | Update installed: " -nonewline
            Write-Host "$need_dell_command_update_installed" -Foregroundcolor Red
            Write-Host "`n"
            Write-Host "These computers have begun to apply updates and should be rebooting momentarily: " -nonewline
            Write-Host "$currently_applying_updates" -Foregroundcolor Green

        }
        return $results
    }
}