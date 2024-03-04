Function Set-ChromeClearDataOnExit {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        $TargetComputer
    )
    ## 1. Handling TargetComputer input if not supplied through pipeline.
    ## 2. Define scriptblock that sets Chrome data deletion registry settings.
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
        if ($TargetComputer) {

            ## test with ping first:
            $pingreply = Test-Connection $TargetComputer -Count 1 -Quiet
            if ($pingreply) {
                Invoke-Command -ComputerName $Targetcomputer -ScriptBlock $chrome_setting_scriptblock
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Targetcomputer didn't respond to one ping, skipping." -ForegroundColor Yellow
            }
        }
    }

    END {
        Read-Host "Press enter to continue."
    }
}