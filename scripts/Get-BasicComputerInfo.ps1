# get some basic details about the computer
$manufacturer = get-ciminstance -class win32_computersystem | select -exp manufacturer
$model = get-ciminstance -class win32_computersystem | select -exp model
$biosversion = get-ciminstance -class win32_bios | select -exp smbiosbiosversion
$bioreleasedate = get-ciminstance -class win32_bios | select -exp releasedate
$winbuild = get-ciminstance -class win32_operatingsystem | select -exp buildnumber

$totalram = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum / 1gb
$totalram = [string]$totalram + " GB"

# current_user
$current_user = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username

$obj = [PSCustomObject]@{
    Manufacturer    = $manufacturer
    Model           = $model
    CurrentUser     = $current_user
    WindowsBuild    = $winbuild
    BiosVersion     = $biosversion
    BiosReleaseDate = $bioreleasedate
    TotalRAM        = $totalram
}
return $obj