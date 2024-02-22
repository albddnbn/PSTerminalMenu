# https://community.spiceworks.com/topic/417345-powershell-script-to-eject-usb-device
$vol = get-wmiobject -Class Win32_Volume | where { $_.Name -eq 'F:\' }  
$vol.DriveLetter = $null  
$vol.Put()  
$vol.Dismount($false, $false)