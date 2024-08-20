Function Set-ChromeClearDataOnExit {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer
    )
    ## 1. Handling TargetComputer input if not supplied through pipeline.
    ## 2. Define scriptblock that sets Chrome data deletion registry settings.
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
        ## 2. Scriptblock that runs on each target computer, setting registry values to cause Chrome to auto-delete
        ##    specified categories of browsing data on exit of the application.
        ##    This is useful for 'guest accounts' or 'testing center' computers, that are not likely to have to be 
        ##    reused by the same person.
        $chrome_setting_scriptblock = {
            $testforchromekey = Test-Path -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ClearBrowsingDataOnExitList" -erroraction silentlycontinue
            if (-not $testforchromekey) {
                New-Item -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "ClearBrowsingDataOnExitList" -Force
            }
    
            New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "SyncDisabled" -Value 1 -PropertyType DWord -Force
    
            $chromehash = @{
                "1" = "browsing_history"
                "2" = "download_history"
                "3" = "cookies_and_other_site_data"
                "4" = "cached_images_and_files"
                "5" = "password_signin"
                "6" = "autofill"
                "7" = "site_settings"
                "8" = "hosted_app_data"
            }
            ForEach ($key in $chromehash.keys) {
                New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ClearBrowsingDataOnExitList" -Name $key -Value $chromehash[$key] -PropertyType String -Force
            }
            New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "BackgroundModeEnabled" -Value 0 -PropertyType DWORD -Force
            
            New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "ClearBrowsingDataOnExit" -Value 1 -PropertyType DWORD -Force
        }
    }
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responsive, Collect local asset information from computer
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            if ($single_computer) {

                ## test with ping first:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    Invoke-Command -ComputerName $single_computer -ScriptBlock $chrome_setting_scriptblock
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer didn't respond to one ping, skipping." -ForegroundColor Yellow
                }
            }
        }
    }

    END {
        ## create announcement file for when function is run as background job:
        if (-not $env:PSMENU_DIR) {
            $env:PSMENU_DIR = pwd
        }
        ## create simple output path to reports directory
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        $DIRECTORY_NAME = 'ChromeClearDataOnExit'
        $OUTPUT_FILENAME = 'results'
        if (-not (Test-Path "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME" -ErrorAction SilentlyContinue)) {
            New-Item -Path "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME" -ItemType Directory -Force | Out-Null
        }
        
        $counter = 0
        do {
            $output_filepath = "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME\$OUTPUT_FILENAME-$counter.txt"
        } until (-not (Test-Path $output_filepath -ErrorAction SilentlyContinue))

        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Finished setting Chrome to clear data on exit for computers listed below." | Out-File -FilePath $output_filepath -Append
        $TargetComputer | Out-File -FilePath $output_filepath -Append

        Invoke-Item "$output_filepath"
        
        # Read-Host "Press enter to continue."
    }
}