$PROCESS_NAME = "code"
$TIME_INTERVAL = 1


Write-Host "Found these processes, OK?: "
$PROCESS_NAME
Read-Host "Press enter to continue, CTRL+C to cancel"

# start powershell {
while ($true) {
	
	$processids = Get-Process -Name "$PROCESS_NAME" -ErrorAction SilentlyContinue | Select -Exp ID
	if ($processids) {
		ForEach ($single_process in $processids) {
			try {
				Get-NetTCPConnection -OwningProcess $single_process -ErrorAction SilentlyContinue
			}
			catch {
				Write-Host "nothing right now"
			}
		}
	}
	Start-Sleep -Seconds $TIME_INTERVAL
}
# }