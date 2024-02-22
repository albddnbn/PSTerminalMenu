function Stop-WifiAdapters {
    <#
    .SYNOPSIS
        Attempts to turn off (and disable if 'y' entered for 'DisableWifiAdapter') Wi-Fi adapter of target device(s).
        Having an active Wi-Fi adapter/connection when the Ethernet adapter is also active can cause issues.

    .DESCRIPTION
        Function needs work - 1/13/2024.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER DisableWifiAdapter
        Optional parameter to disable the Wi-Fi adapter. If not specified, the function will only turn off wifi adapter.
        'y' or 'Y' will disable target Wi-Fi adapters.

    .EXAMPLE
        Stop-WifiAdapters -TargetComputer s-c136-02 -DisableWifiAdapter y
        Turns off and disables Wi-Fi adapter on s-c136-02.

    .EXAMPLE
        Stop-WifiAdapters -TargetComputer t-client- -DisableWifiAdapter n
        Turns off Wi-Fi adapters on computers in room S-A227, without disabling them.

    .NOTES
        abuddenb / 2024
    #>
    param(
        $TargetComputer,
        [string]$DisableWifiAdapter
    )
    BEGIN {
        ## If Targetcomputer is an array or arraylist - it's already been sorted out.
        if (($TargetComputer -is [System.Collections.IEnumerable]) -and (-not($TargetComputer -is [string]))) {
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
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer was not an array, comma-separated list of hostnames, path to hostname text file, or valid single hostname. Exiting." -Foregroundcolor "Red"
                    return
                }
            }
        }
        $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
        # Safety catch to make sure
        if ($null -eq $TargetComputer) {
            # user said to end function:
            return
        }

        $DisableWifiAdapter = $DisableWifiAdapter.ToLower()

        $turnoff_wifi_adapter_scriptblock = {
            param(
                $DisableWifi
            )
            $EthStatus = (Get-Netadapter | where-object { $_.Name -eq 'Ethernet' }).status
            if ($ethstatus -eq 'Up') {
                Write-Host "[$env:COMPUTERNAME] :: Eth is up, turning off Wi-Fi..." -foregroundcolor green
                Set-NetAdapterAdvancedProperty -Name "Wi-Fi" -AllProperties -RegistryKeyword "SoftwareRadioOff" -RegistryValue "1"
                # should these be uncommented?
                if ($DisableWifi -eq 'y') {
                    Disable-NetAdapterPowerManagement -Name "Wi-Fi"
                    Disable-NetAdapter -Name "Wi-Fi" -Force
                }            
            }

            else {
                Write-Host "[$env:COMPUTERNAME] :: Eth is down, leaving Wi-Fi alone..." -foregroundcolor red
            }

        }
    } 
    
    ## Test connection to target machine(s) and then run scriptblock to disable wifi adapter if ethernet adapter is active
    PROCESS {
        Invoke-Command -ComputerName $TargetComputer -Scriptblock $turnoff_wifi_adapter_scriptblock -ArgumentList $DisableWifiAdapter
    }

    ## Pause before continuing back to terminal menu
    END {
        Read-Host "Press enter to continue."
    }
}
