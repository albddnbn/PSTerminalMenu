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
        Stop-WifiAdapters -TargetComputer s-tc136-02 -DisableWifiAdapter y
        Turns off and disables Wi-Fi adapter on single computer/hostname s-tc136-02.

    .EXAMPLE
        Stop-WifiAdapters -TargetComputer t-client- -DisableWifiAdapter n
        Turns off Wi-Fi adapters on computers w/hostnames starting with t-client-, without disabling them.

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
        [string]$DisableWifiAdapter = 'n'
    )
    ## 1. Handling of TargetComputer input
    ## 2. Define Turn off / disable wifi adapter scriptblock that gets run on each target computer
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

                        $TargetComputer = $TargetComputer
                        $TargetComputer = Get-ADComputer -Filter * | Where-Object { $_.DNSHostname -match "^$TargetComputer.*" } | Select -Exp DNShostname
                        $TargetComputer = $TargetComputer | Sort-Object 
  
                    }
                }
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        $DisableWifiAdapter = $DisableWifiAdapter.ToLower()
        ## 2. Turn off / disable wifi adapter scriptblock
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
        ForEach ($single_computer in $TargetComputer) {

            ## empty Targetcomputer values will cause errors to display during test-connection / rest of code
            if ($single_computer) {
                ## Ping test
                $ping_result = Test-Connection $single_computer -count 1 -Quiet
                if ($ping_result) {
                    if ($single_computer -eq '127.0.0.1') {
                        $single_computer = $env:COMPUTERNAME
                    }
        
                    Invoke-Command -ComputerName $single_computer -Scriptblock $turnoff_wifi_adapter_scriptblock -ArgumentList $DisableWifiAdapter
                }
                else {
                    Write-Host "[$env:COMPUTERNAME] :: $single_computer is offline, skipping." -Foregroundcolor Yellow
                }
            }
        }
    }

    ## Pause before continuing back to terminal menu
    END {
        Read-Host "`nPress [ENTER] to continue."
    }
}
