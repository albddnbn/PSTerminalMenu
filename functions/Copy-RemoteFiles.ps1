function Copy-RemoteFiles {
    <#
    .SYNOPSIS
        Recursively grabs target files or folders from remote computer(s) and copies them to specified directory on local computer.

    .DESCRIPTION
        TargetPath specifies the target file(s) or folder(s) to target on remote machines.
        TargetPath can be supplied as a single absolute path, comma-separated list, or array.
        OutputPath specifies the directory to store the retrieved files.
        Creates a subfolder for each target computer to store it's retrieved files.

    .PARAMETER TargetPath
        Path to file(s)/folder(s) to be grabbed from remote machines. Ex: 'C:\users\abuddenb\Desktop\test.txt'

    .PARAMETER OutputPath
        Path to folder to store retrieved files. Ex: 'C:\users\abuddenb\Desktop\grabbed-files'

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .EXAMPLE
        Copy-RemoteFiles -TargetPath "Users\Public\Desktop" -OutputPath "C:\Users\Public\Desktop" -TargetComputer "t-client-"

    .NOTES
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
        [string]$TargetPath,
        [string]$OutputFolder
    )

    ## 1. Handle Targetcomputer input if it's not supplied through pipeline.
    ## 2. Make sure output folder path exists for remote files to be copied to.
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
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

        ## If being run with terminal menu - use full output path
        # if ($env:PSMENU_DIR) {
        #     $OutputFolder = "$env:PSMENU_DIR\output\$thedate\$OutputFolder"
        # }

        ## 2. Make sure the outputpath folder exists (remote files are copied here):

        if (-not(Test-Path "$OutputFolder" -erroraction SilentlyContinue)) {
            New-Item -ItemType Directory -Path "$OutputFolder" -ErrorAction SilentlyContinue | out-null
        }
        
    }

    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. Copy file from pssession on target machine, to local computer.
    ##    Report on success/fail
    ## 4. Remove the pssession.
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            ## 1. no empty Targetcomputer values past this point
            if ($single_computer) {
                ## 2. Make sure machine is responsive on the network
                $target_network_path = $targetpath -replace 'C:', "\\$single_computer\c$"
                if ([system.IO.Directory]::Exists("\\$single_computer\c$")) {
                    if (Test-Path "$target_network_path" -erroraction SilentlyContinue) {

                    
                        $target_session = New-PSSession $single_computer

                        $target_filename = $targetpath | split-path -leaf


                        Copy-Item -Path "$targetpath" -Destination "$OutputFolder\$single_computer-$target_filename" -FromSession $target_session -Recurse
                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Transfer of $targetpath ($single_computer) to $OutputFolder\$single_computer-$target_filename  complete." -foregroundcolor green
                    
                        Remove-PSSession $target_session

                    }
                    else {
                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Failed to copy $targetpath on $single_computer to $OutputFolder on local computer." -foregroundcolor red
                    }
                    ## 4. Bye pssession
                }
            }
        }
    }
    ## Open output folder, pause.
    END {
        if (Test-Path "$OutputFolder" -erroraction SilentlyContinue) {
            Invoke-item "$OutputFolder"
        }
        # read-host "Press enter to continue."
    }
}
