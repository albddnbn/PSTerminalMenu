param(
    $computerlist
)

Start-Transcript D:\remotereach.txt

$csvfile = 'D:\remotecomputers.csv'
New-Item -Path $csvfile -Itemtype 'file'

$collections_container = [system.collections.arraylist]::new()
ForEach ($ipaddr in $computerlist) {

    $connect_result = Test-Connection $ipaddr -Count 1 -Quiet
    if ($connect_result) {
        Write-Host "$ipaddr is online" -foregroundcolor green
        $hostname = Resolve-DnsName $ipaddr -ErrorAction SilentlyContinue | Select-Object -ExpandProperty NameHost
        # source: https://serverfault.com/questions/551247/testing-if-enter-pssession-is-successful
        $testSession = New-PSSession -Computer $hostname
        $pssessionstatus = $false
        if (-not($testSession)) {
            Write-Host "$hostname inaccessible!" -Foregroundcolor Red
        }
        else {
            Write-Host "Great! $hostname is accessible!" -Foregroundcolor Green
            $pssessionstatus = $true
            Remove-PSSession $testSession
        }

    }

    $obj = [pscustomobject]@{
        IPaddress       = $ipaddr
        Hostname        = $hostname
        PSSessionStatus = $pssessionstatus
    }
    $obj | Export-Csv -Path $csvfile -Append -NoTypeInformation
    $collections_container.add($obj) | Out-Null
}

$collections_container | Format-Table -AutoSize
$collections_container | export-csv "D:\computers-i-can-reach-collecitons-container-12-7-23.csv" -notypeinformation