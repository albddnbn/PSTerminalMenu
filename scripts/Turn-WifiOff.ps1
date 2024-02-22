param(
    $computerlist
)

Invoke-command -computername $computerlist -scriptblock {
    # check for ethernet connection / status:
    $EthStatus = Get-Netadapter | where-object { $_.Name -eq 'Ethernet' } | select -exp status
    if ($ethstatus -eq 'Up') {
        Write-Host "[$env:COMPUTERNAME] :: Eth is up, turning off Wi-Fi..." -foregroundcolor green
        powershell Set-NetAdapterAdvancedProperty -Name "Wi-Fi" -AllProperties -RegistryKeyword "SoftwareRadioOff" -RegistryValue "1"
    }
    else {
        Write-Host "[$env:COMPUTERNAME] :: Eth is down, leaving Wi-Fi alone..." -foregroundcolor red
    }

}