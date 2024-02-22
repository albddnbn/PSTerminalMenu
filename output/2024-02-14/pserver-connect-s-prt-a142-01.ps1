$printername = '\\s-ps-02\s-prt-a142-01'
try {
    (New-Object -comobject wscript.network).addwindowsprinterconnection($printername)
    (New-Object -comobject wscript.network).setdefaultprinter($printername)
    Write-Host "Mapped $printername successfully." -Foregroundcolor Green
} catch {
    Write-Host "Failed to map printer: $printername, please let Tech Support know." -Foregroundcolor Red
}
Start-Sleep -Seconds 5
