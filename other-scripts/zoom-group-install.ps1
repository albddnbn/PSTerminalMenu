$targets = Get-Content targets.txt
$productNames = @("*zoom*")
$UninstallKeys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
                    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
Invoke-Command -Computername $targets -Scriptblock {
	$results = foreach ($key in (Get-ChildItem $Using:UninstallKeys) ) {

	foreach ($product in $Using:productNames) {
		if ($key.GetValue("DisplayName") -like "$product") {
			[pscustomobject]@{
				# KeyName = $key.Name.split('\')[-1];
				DisplayName = $key.GetValue("DisplayName");
				# UninstallString = $key.GetValue("UninstallString");
				# Publisher = $key.GetValue("Publisher");
				Displayversion = $key.GetValue("DisplayVersion");
			}
		}
	}
}
	if ($null -eq $results) {
		# write-host "Installing ZOOM on: $env:COMPUTERNAME" -foregroundcolor Green
		Invoke-WebRequest -Uri "https://zoom.us/client/latest/ZoomInstallerFull.msi?archType=x64" -OutFile "C:\Users\Public\ZoomInstallerFull.msi"
		# run msi installer and save exit code to #$Result variable
		$result = (Start-Process MsiExec.exe -ArgumentList "/i C:\Users\Public\ZoomInstallerFull.msi ZSSOHost='dtcc.edu' /qn /L*V $env:WINDIR\Temp\Zoom-Install.log" -wait -Passthru).ExitCode
		if ($result -eq 0) {
			"Installed - $env:COMPUTERNAME - $result"
		} else {
			"CHECK - $env:COMPUTERNAME"
		}

	} else {
		if ($results.DisplayVersion -ne "5.14.15287") {
			# write-host "INSTALLing ZOOM ON: $env:COMPUTERNAME" -foregroundcolor green
			Invoke-WebRequest -Uri "https://zoom.us/client/latest/ZoomInstallerFull.msi?archType=x64" -OutFile "C:\Users\Public\ZoomInstallerFull.msi"
			# run msi installer and save exit code to #$Result variable
			$result = (Start-Process MsiExec.exe -ArgumentList "/i C:\Users\Public\ZoomInstallerFull.msi ZSSOHost='dtcc.edu' /qn /L*V $env:WINDIR\Temp\Zoom-Install.log" -wait -Passthru).ExitCode
			if ($result -eq 0) {
			"Updated - $env:COMPUTERNAME - $result"
			} else {
				"CHECK $env:COMPUTERNAME"

	} else {
		"$env:COMPUTERNAME has latest ZOOM version"
	}		
}
}















function get-zoom {
Invoke-WebRequest -Uri "https://zoom.us/client/latest/ZoomInstallerFull.msi?archType=x64" -OutFile "C:\Users\Public\ZoomInstallerFull.msi"

$result = (Start-Process MsiExec.exe -ArgumentList "/i C:\Users\Public\ZoomInstallerFull.msi ZSSOHost='dtcc.edu' /qn /L*V $env:WINDIR\Temp\Zoom-Install.log" -wait -Passthru).ExitCode
if ($result -eq 0) {
	return 0
} else {
	return 1
}
}