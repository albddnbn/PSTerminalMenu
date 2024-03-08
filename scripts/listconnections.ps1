while ($true) {
	
	$processids = Get-Process -Name 'Sketchup' -ErrorAction SilentlyContinue | Select -Exp ID
	if ($processids) {
		ForEach($single_process in $processids) {
			try {
				Get-NetTCPConnection -OwningProcess $single_process
			} catch {
				Write-Host "nothing right now"
			}
		}
	}
	Start-Sleep -Seconds 1
}