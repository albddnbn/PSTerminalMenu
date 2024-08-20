Function Install-NewTeams {
    <#
    .SYNOPSIS
        Installs the 'new' Microsoft Teams (work or school account) client on target computers using the 'network-required' method (only teamsbootstrapper.exe, not .msix).

    .DESCRIPTION
        Doesn't create desktop icon like Teams Classic - users will have to go to Start Menu and search for Teams. They should see a Teams app listed that uses the new icon.
        Sometimes it's hidden toward the bottom of the results in Start Menu search.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .PARAMETER skip_occupied_computers
        This script KILLS ANY RUNNING TEAMS PROCESSES.
        'y' will skip computers that have users logged in, 'n' will not skip them.
        Default is 'y'.

    .EXAMPLE
        Install new teams client and provision for future users - all AD computers with hostnames starting with pc-a227-
        Install-NewTeams -TargetComputer "pc-a227-"

    .NOTES
        The script used for actual installation of the new Teams client was created by:
        Author:     Sassan Fanai
        Date:       2023-11-22
        *need to get a link to script on github to put here*
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$skip_occupied_computers = 'y'
    )
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

        
        # $skip_occupied_computers = Read-Host "Install of Teams will stop any running teams processes on target machines - skip computers that have users logged in? [y/n]"
        # get newteams folder from irregular applications
        $NewTeamsFolder = Get-ChildItem -Path "$env:PSMENU_DIR\deploy\irregular" -Filter 'NewTeams' -Directory -ErrorAction SilentlyContinue
        if (-not $NewTeamsFolder) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: NewTeams folder not found in $env:PSMENU_DIR\deploy\irregular" -foregroundcolor red
            return
        }
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($NewTeamsFolder.fullname) folder."
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning installation/provisioning of 'New Teams' on $($TargetComputer -join ', ')"
    
        ## Create empty collections list for skipped target machines
        $missed_computers = [system.collections.arraylist]::new()
    }
    ## *Remove teams classic and install/provision new teams client on machines*
    ## 1. Check $Targetcomputer for $null / '' values
    ## 2. Send one test ping
    ## 3. Create PSSession on on target machine
    ## 4. Copy the New Teams folder to target, using the session
    ## 5. Execute script - removes Teams classic / installs & provisions new Teams client
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1. Check $single_computer for $null / '' values
            if ($single_computer) {
                ## 2. Send one test ping
                $ping_result = Test-Connection $single_computer -count 1 -Quiet
                if ($ping_result) {
                    if ($single_computer -eq '127.0.0.1') {
                        $single_computer = $env:COMPUTERNAME
                    }
                    ## 3. Create PSSession on on target machine
                    $single_target_session = New-PSSession $single_computer
                    ## 4. Copy the New Teams folder to target, using the session
                    try {
                        Copy-Item -Path "$($NewTeamsFolder.fullname)" -Destination 'C:\temp' -ToSession $single_target_session -Recurse -Force
                    }
                    catch {
                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Error copying NewTeams folder to $single_computer" -foregroundcolor red
                        continue
                    }

                    ## 5. Execute script - removes Teams classic / installs & provisions new Teams client
                    ##    - Skips computer if skip_occupied_computers is 'y' and user is logged in
                    $new_teams_install_result = Invoke-Command -ComputerName $single_computer -scriptblock {

                        $obj = [pscustomobject]@{
                            UserLoggedIn = ''
                            Skipped      = 'no'
                        }
                        $check_for_user = $using:skip_occupied_computers
                        if ($check_for_user.ToLower() -eq 'y') {
                            $user_logged_in = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
                            if ($user_logged_in) {
                                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] " -NoNewline
                                Write-Host "[$env:COMPUTERNAME] :: Found $user_logged_in logged in, skipping installation of Teams." -foregroundcolor yellow
                                $obj.UserLoggedIn = $user_logged_in
                                $obj.Skipped = 'yes'
                                return $obj                            
                            }
                        }
                        $installteamsscript = get-childitem -path 'C:\temp\newteams' -filter "install-msteams.ps1" -file -erroraction SilentlyContinue
                        if (-not $installteamsscript) {
                            Write-Host "No install-msteams.ps1 on $env:computername" -foregroundcolor red
                            $obj.Skipped = 'yes'
                            return $obj
                        }
                        # execute script (NewTeams installation folder can be found in ./deploy/irregular)
                        $install_params = @{
                            logfile      = "C:\WINDOWS\Logs\Software\NewTeamsClient-Install-$(Get-Date -Format 'yyyy-MM-dd').log"
                            forceinstall = $true
                            setrunonce   = $true
                        }
                        ## If the msix file is present - run offline install
                        if (Test-Path -Path 'C:\temp\newteams\Teams_windows_x64.msi') {
                            $install_params['offline'] = $true
                        }
                        &"$($installteamsscript.fullname)" @install_params
                    }

                    ## Check if the computer was skipped
                    if ($new_teams_install_result.Skipped -eq 'yes') {
                        $missed_computers.add($single_computer) | out-null
                        continue
                    }
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is not reachable, skipping." -foregroundcolor red
                    $missed_computers.add($single_computer) | out-null
                    continue
                }
            }
        }
    }
    ## 1. Output the missed computers list to a text file in reports dir / new teams
    ## 2. Function complete - read-host to allow pause for debugging errors/etc
    END {
        if (-not $env:PSMENU_DIR) {
            $env:PSMENU_DIR = pwd
        }
        $DIRECTORY_NAME = 'NewTeams'
        $OUTPUT_FILENAME = 'newteamsresults'
        if (-not (Test-Path "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME" -ErrorAction SilentlyContinue)) {
            New-Item -Path "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME" -ItemType Directory -Force | Out-Null
        }
        
        $counter = 0
        do {
            $output_filepath = "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME\$OUTPUT_FILENAME-$counter.txt"
        } until (-not (Test-Path $output_filepath -ErrorAction SilentlyContinue))

        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: New Teams not installed on these computers." | Out-File -Append -FilePath $output_filepath
        $missed_computers | Out-File -Append -FilePath $output_filepath

        "`n" | Out-File -Append -FilePath $output_filepath

        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Complete list of target computers below." | Out-File -Append -FilePath $output_filepath
        $TargetComputer | Out-File -Append -FilePath $output_filepath

        Invoke-Item $output_filepath
        
        # read-host "Press enter to continue."
    }
}