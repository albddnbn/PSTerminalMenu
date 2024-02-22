<#
.SYNOPSIS
    Lists computer asset information on local computer including: Bios version, release date, asset tag, computer model, and serial number.
    Called by functions/Get-AssetInformation to retrieve asset information from groups of target computers.S
#>
# computer model (ex: 'precision 3630 tower'), BIOS version, and BIOS release date
$computer_model = get-ciminstance -class win32_computersystem | select -exp model
$biosversion = get-ciminstance -class win32_bios | select -exp smbiosbiosversion
$bioreleasedate = get-ciminstance -class win32_bios | select -exp releasedate
# Asset tag from BIOS (tested with dell computer)
try {
    $command_configure_exe = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Dell\Command Configure\x86_64" -Filter "cctk.exe" -File -ErrorAction Silentlycontinue
    # returns a string like: 'Asset=2001234'
    $asset_tag = &"$($command_configure_exe.fullname)" --asset
    $asset_tag = $asset_tag -replace 'Asset=', ''
}
catch {
    $asset_tag = Get-Ciminstance -class win32_systemenclosure | select -exp smbiosassettag
    # asus motherboard returned 'default string'
    if ($asset_tag.ToLower() -eq 'default string') {
        $asset_tag = 'No asset tag set in BIOS'
    }    
}

$computer_serial_num = get-ciminstance -class win32_bios | select -exp serialnumber

# get monitor info:
$monitors = Get-CimInstance WmiMonitorId -Namespace root\wmi -ComputerName $ComputerName | Select Active, ManufacturerName, UserFriendlyName, SerialNumberID, YearOfManufacture
$monitors | ForEach-Object {
    $_.UserFriendlyName = [System.Text.Encoding]::ASCII.GetString($_.UserFriendlyName)
    $_.SerialNumberID = [System.Text.Encoding]::ASCII.GetString($_.SerialNumberID -notmatch 0)
    $_.ManufacturerName = [System.Text.Encoding]::ASCII.GetString($_.ManufacturerName)
}

$obj = [PSCustomObject]@{
    model               = $computer_model
    biosversion         = $biosversion
    bioreleasedate      = $bioreleasedate
    asset_tag           = $asset_tag
    computer_serial_num = $computer_serial_num
    monitors            = $monitors
    NumMonitors         = $monitors.count
}

return $obj