function Get-LiveHosts {
    <#
    .SYNOPSIS
        Takes a list of hostnames as input, and returns list of live hosts (hosts that are reponsive on the network).
        The script gauges a 'live' host as 'live' if it responds to one ping.
        This filters out offline/unresponsive hosts so any use of Invoke-Command won't waste time with those computers.

    .NOTES
        Author :    abuddenb
        Date   :    1-14-2024
    #>
    param(
        $TargetComputerInput
    )

    $responsive_hosts = [system.collections.arraylist]::new()
    ForEach ($single_host in $TargetComputerInput) {
        if (($single_host -ne '') -and ($single_host -ne $null)) {
            $connection_result = Test-Connection $single_host -Count 1 -Quiet
            if ($connection_result) {
                $responsive_hosts.add($single_host) | Out-Null
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewLine
                Write-Host "$single_host" -NoNewLine -Foregroundcolor Green
                Write-Host " is online."
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewLine
                Write-Host "$single_host" -NoNewLine -Foregroundcolor Red
                Write-Host " did not respond to one ping."
            }
        }
    }

    Start-Sleep -seconds 2

    Clear-Host

    $unresponsive_hosts = $TargetComputerInput | Where-Object { $_ -notin $responsive_hosts }
    Write-Host ""
    Write-Host "LIVE hosts determined: " -nonewline
    Write-Host "$($responsive_hosts -join ', ')" -Foregroundcolor Green

    Write-Host "OFFLINE hosts: " -NoNewline
    Write-Host "$($unresponsive_hosts -join ', ')" -Foregroundcolor Red

    $TargetComputerInput = $TargetComputerInput | Where-object { $_ -notin $unresponsive_hosts }

    return $TargetComputerInput
    

}