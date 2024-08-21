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

    .PARAMETER DoNotDisturbUsers
        'y' will skip any computers that are occupied by a user.
        'n' will attempt to remove Teams Classic from all computers, including those with users logged in.

    .EXAMPLE
        Remove Microsoft Teams Classic from all computers that have hostnames starting with 't-computer-'
        Remove-TeamsClassic -TargetComputer 't-computer-' -DoNotDisturbUsers 'y'

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
        [String[]]$TargetComputer,
        [Parameter(
            Mandatory = $true,
            Position = 1
        
        )]
        [string]$DoNotDisturbUsers
    )
    ## 1. Handling of TargetComputer input
    ## 2. ask to skip occupied computers
    ## 3. find the Purge-TeamsClassic.ps1 file.
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

        ## 2. Ask to skip occupied computers
        # $DoNotDisturbUsers = Read-Host "Removal of Teams Classic will stop any running teams processes on target machines - skip computers that have users logged in? [y/n]"
    
        try {
            $DoNotDisturbUsers = $DoNotDisturbUsers.ToLower()
            if ($DoNotDisturbUsers -eq 'y') {
                Write-Host "Skipping occupied computers - acknowledged."
            }
            else {
                Write-Host "Shutting down Teams and removing Teams Classic, even on occupied computers - acknowledged."
            }
    
        }
        catch {
            Write-Host "Wasn't able to convert $DoNotDisturbUsers to lowercase, assuming 'y'."
            $DoNotDisturbUsers = 'y'
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
        ForEach ($single_computer in $TargetComputer) {

            if ($single_computer) {

                ## test with ping first:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    Invoke-Command -ComputerName $single_computer -FilePath "$($teamsclassic_scrubber_ps1.fullname)" -ArgumentList $DoNotDisturbUsers
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Teams Classic removal attempt on $single_computer completed."
                }
            }
        }
    }

    ## Function completion msg
    END {

        ## create file to announce completion, for when function is run as background job
        if (-not $env:PSMENU_DIR) {
            $env:PSMENU_DIR = pwd
        }
        ## create simple output path to reports directory
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        $DIRECTORY_NAME = 'TeamsRemoval'
        $OUTPUT_FILENAME = 'TeamsRemoval'
        if (-not (Test-Path "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME" -ErrorAction SilentlyContinue)) {
            New-Item -Path "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME" -ItemType Directory -Force | Out-Null
        }
        
        $counter = 0
        do {
            $output_filepath = "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME\$OUTPUT_FILENAME-$counter.txt"
        } until (-not (Test-Path $output_filepath -ErrorAction SilentlyContinue))



        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Finished removing Microsoft Teams 'Classic' from these computers." | Out-File -FilePath $output_filepath -Append
        $TargetComputer | Out-File -FilePath $output_filepath -Append
        # Read-Host "Press enter to continue."
    }
}