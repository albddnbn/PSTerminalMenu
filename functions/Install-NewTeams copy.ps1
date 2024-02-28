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
            ValueFromPipeline = $true
        )]
        $TargetComputer
    )
    BEGIN {
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            if (($TargetComputer -is [System.Collections.IEnumerable]) -and ($TargetComputer -isnot [string])) {
                $null
                ## If it's a string - check for commas, try to get-content, then try to ping.
            }
            elseif ($TargetComputer -is [string]) {
                if ($TargetComputer -in @('', '127.0.0.1')) {
                    $TargetComputer = @('127.0.0.1')
                }
                elseif ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                elseif (Test-Path $Targetcomputer -erroraction SilentlyContinue) {
                    $TargetComputer = Get-Content $TargetComputer
                }
                else {
                    $test_ping = Test-Connection -ComputerName $TargetComputer -count 1 -Quiet
                    if ($test_ping) {
                        $TargetComputer = @($TargetComputer)
                    }
                    else {
                        $TargetComputerInput = $TargetComputerInput + "x"
                        $TargetComputerInput = Get-ADComputer -Filter * | Where-Object { $_.DNSHostname -match "^$TargetComputerInput*" } | Select -Exp DNShostname
                        $TargetComputerInput = $TargetComputerInput | Sort-Object   
                    }
                }
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        $reply = Read-Host "Install of Teams will stop any running teams processes on target machines - skip computers that have users logged in? [y/n]"
        # get newteams folder from irregular applications
        $NewTeamsFolder = Get-ChildItem -Path "$env:PSMENU_DIR\deploy\irregular" -Filter 'NewTeams' -Directory -ErrorAction SilentlyContinue
        if (-not $NewTeamsFolder) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: NewTeams folder not found in $env:PSMENU_DIR\deploy\irregular" -foregroundcolor red
            return
        }
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($NewTeamsFolder.fullname), copying the new teams installation script to $($TargetComputer -join ', ')"
        $skipped_computers = [system.collections.arraylist]::new()
        ForEach ($single_computer in $TargetComputer) {
            if (-not (Test-Path \\$single_computer\c$)) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is inaccessible, skipping." -foregroundcolor yellow
                $skipped_computers.add($single_computer) | out-null
                continue
            }

            Remove-Item -Path "\\$single_computer\c$\temp\NewTeams" -Recurse -Force -ErrorAction SilentlyContinue

            Copy-Item "$($NewTeamsFolder.fullname)" -Destination "\\$single_computer\c$\temp" -Recurse -Force -ErrorAction SilentlyContinue

            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Copied NewTeams folder to \\$single_computer\c$\temp"

        }
        $NewTeamsFolder = Get-ChildItem -Path "$env:PSMENU_DIR\deploy\irregular" -Filter 'NewTeams' -Directory -ErrorAction SilentlyContinue


        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning installation/provisioning of 'New Teams' on $($TargetComputer -join ', ')"
    }
    ## Remove teams classic and install/provision new teams client on machines.
    PROCESS {
        ## Create PSSession on on target machine
        $single_target_session = New-PSSession $TargetComputer
        ## Copy the New Teams folder to target, using the session
        try {
            Copy-Item -Path "$($NewTeamsFolder.fullname)" -Destination 'C:\temp' -ToSession $single_target_session -Recurse -Force
        }
        catch {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Error copying NewTeams folder to $TargetComputer" -foregroundcolor red
            continue
        }



        Invoke-Command -ComputerName $Targetcomputer -scriptblock {

            $check_for_user = $using:reply
            if ($check_for_user.ToLower() -eq 'y') {
                $user_logged_in = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
                if ($user_logged_in) {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] " -NoNewline
                    Write-Host "[$env:COMPUTERNAME] :: Found $user_logged_in logged in, skipping installation of Teams." -foregroundcolor yellow
                    continue
                }
            }
            $installteamsscript = get-childitem -path 'C:\temp\newteams' -filter "install-msteams.ps1" -file -erroraction SilentlyContinue
            if (-not $installteamsscript) {
                Write-Host "No install-msteams.ps1 on $env:computername" -foregroundcolor red
                continue
            }
        
            &"$($installteamsscript.fullname)" -logfile C:\temp\newteams\newteamslog2.txt -forceinstall -setrunonce
        }
    }
    END {

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Installation of Teams complete on $($TargetComputer -join ', ')" -foregroundcolor green
        Read-Host "Press enter to continue."
    }

}