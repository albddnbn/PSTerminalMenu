function Install-SMARTNotebookSoftware {
    <#
    .SYNOPSIS
        Installs SMART Learning Suite software on target computers.
        Info: https://www.smarttech.com/en/education/products/software/smart-notebook

    .DESCRIPTION
        May also be able to use a hostname file eventually.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .EXAMPLE
        Install-SMARTNotebookSoftware -TargetComputer "s-c136-02"

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
    ## 1. Handling TargetComputer input if not supplied through pipeline.
    ## 2. Make sure SMARTNotebook folder is in ./deploy/irregular
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

        ## 2. Get the smartnotebook folder from irregular applications
        $SmartNotebookFolder = Get-ChildItem -path "$env:PSMENU_DIR\deploy\irregular" -Filter 'SMARTNotebook' -Directory -Erroraction SilentlyContinue
        if ($SmartNotebookFolder) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($SmartNotebookFolder.FullName), copying to target computers." -foregroundcolor green
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: SMARTNotebook folder not found in irregular applications, exiting." -foregroundcolor red
            exit
        }

        ## For each target computer - assign installation method - either office or classroom. Classroom installs the smartboard and ink drivers.
        Write-Host "Please choose installation method for target computers:"
        $InstallationTypeReply = Menu @('Office', 'Classroom')

    }
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responsive, find PSADT Folder and install SMARTNotebook software.
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1.
            if ($single_computer) {

                ## 2. test with ping:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    ## 3. Run PSADT installation on target computers.
                    Invoke-Command -ComputerName $single_computer -Scriptblock {
                        $installation_method = $using:InstallationTypeReply
                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME]:: Installation method set to: $installation_method"
                        # unblock files
                        Get-ChildItem -Path "C:\TEMP\SMARTNotebook" -Recurse | Unblock-File
                        # get Deploy-SMARTNotebook.ps1
                        $DeployScript = Get-ChildItem -Path "C:\TEMP\SMARTNotebook" -Filter 'Deploy-SMARTNotebook.ps1' -File -ErrorAction SilentlyContinue
                        if ($DeployScript) {
                            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($DeployScript.FullName), executing." -foregroundcolor green
                            Powershell.exe -ExecutionPolicy Bypass "$($DeployScript.FullName)" -DeploymentType "Install" -DeployMode "Silent" -InstallationType "$installation_method"
                        }
                        else {
                            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Deploy-SMARTNotebook.ps1 not found, exiting." -foregroundcolor red
                            exit
                        }
                    }
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is not responding to ping, skipping." -foregroundcolor red
                }
    
            }
        }
    }

    END {

        ## create file to announce completion for when being run as background job
        if (-not $env:PSMENU_DIR) {
            $env:PSMENU_DIR = pwd
        }
        ## create simple output path to reports directory
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        $DIRECTORY_NAME = 'SMARTNotebook'
        $OUTPUT_FILENAME = 'SMARTInstall'
        if (-not (Test-Path "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME" -ErrorAction SilentlyContinue)) {
            New-Item -Path "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME" -ItemType Directory -Force | Out-Null
        }
        
        $counter = 0
        do {
            $output_filepath = "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME\$OUTPUT_FILENAME-$counter.txt"
        } until (-not (Test-Path $output_filepath -ErrorAction SilentlyContinue))

        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Finished SMART Learning Suite installation(s)." | Out-File -FilePath $output_filepath -Append
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Installation method: $InstallationTypeReply" | Out-File -FilePath $output_filepath -Append
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Target computer(s):" | Out-File -FilePath $output_filepath -Append
        $TargetComputer | Out-File -FilePath $output_filepath -Append
        
        # Read-Host "Press enter to continue."
    }
}