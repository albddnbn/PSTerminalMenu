Function Remove-TeamsClassic {
    <#
    .SYNOPSIS
        Attempts to remove any user installations of Microsoft Teams Classic, and any system installation of 'Teams Machine-Wide Installer'

    .DESCRIPTION
        The Teams Machine-Wide Installer .msi uninstallation WILL return an exit code indicating the product is not currently installed - this is expected.
        The script goes on to remove the Teams Machine-Wide Installer registry key, and then checks for any user installations of Teams Classic.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .EXAMPLE
        Remove-TeamsClassic

    .NOTES
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
        [String[]]$TargetComputer
    )
    ## 1. Handling of TargetComputer input
    ## 2. ask to skip occupied computers
    ## 3. find the Purge-TeamsClassic.ps1 file.
    BEGIN {
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            if (($TargetComputer -is [System.Collections.IEnumerable]) -and ($TargetComputer -isnot [string[]])) {
                $null
                ## If it's a string - check for commas, try to get-content, then try to ping.
            }
            elseif ($TargetComputer -is [string[]]) {
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
                        write-host "getting AD computer"
                        $TargetComputer = $TargetComputer
                        $TargetComputer = Get-ADComputer -Filter * | Where-Object { $_.DNSHostname -match "^$TargetComputer.*" } | Select -Exp DNShostname
                        $TargetComputer = $TargetComputer | Sort-Object 
                        read-host "target $($Targetcomputer -join ', ')" -ForegroundColor cyan  
                    }
                }
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 2. Ask to skip occupied computers
        $do_not_disturb_users = Read-Host "Removal of Teams Classic will stop any running teams processes on target machines - skip computers that have users logged in? [y/n]"
    
        try {
            $do_not_disturb_users = $do_not_disturb_users.ToLower()
            if ($do_not_disturb_users -eq 'y') {
                Write-Host "Skipping occupied computers - acknowledged."
            }
            else {
                Write-Host "Shutting down Teams and removing Teams Classic, even on occupied computers - acknowledged."
            }
    
        }
        catch {
            Write-Host "Wasn't able to convert $do_not_disturb_users to lowercase, assuming 'y'."
            $do_not_disturb_users = 'y'
        }

        ## 3. Find the Purge-TeamsClassic.ps1 file.
        $teamsclassic_scrubber_ps1 = Get-ChildItem -Path "$env:LOCAL_SCRIPTS" -Filter "Purge-TeamsClassic.ps1" -File -ErrorAction SilentlyContinue
        if (-not $teamsclassic_scrubber_ps1) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Purge-TeamsClassic.ps1 not found in $env:PSMENU_DIR\files, ending function." -Foregroundcolor Red
            return
        }

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($teamsclassic_scrubber_ps1.fullname)."
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning removal of Teams Classic on $($TargetComputer -join ', ')"

    }

    ## Use PURGE-TEAMSCLASSIC.PS1 file from LOCALSCRIPTS, on each target computer to remove Teams Classic for all users / system.
    PROCESS {
        if ($TargetComputer) {

            ## test with ping first:
            $pingreply = Test-Connection $TargetComputer -Count 1 -Quiet
            if ($pingreply) {
                Invoke-Command -ComputerName $Targetcomputer -FilePath "$($teamsclassic_scrubber_ps1.fullname)" -ArgumentList $do_not_disturb_users
            }
        }
    }

    ## Function completion msg
    END {
        Write-Host "Finished removing Microsoft Teams 'Classic' from $($Targetcomputer -join ', ')."
        Read-Host "Press enter to continue."
    }
}