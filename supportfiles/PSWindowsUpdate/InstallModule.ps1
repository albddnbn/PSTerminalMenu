param ($fullPath)
#$fullPath = 'C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate'
if (-not $fullPath) {
    $fullpath = $env:PSModulePath -split ":(?!\\)|;|," |
    Where-Object { $_ -notlike ([System.Environment]::GetFolderPath("UserProfile") + "*") -and $_ -notlike "$pshome*" } |
    Select-Object -First 1
    $fullPath = Join-Path $fullPath -ChildPath "PSWindowsUpdate"
}
Push-location $PSScriptRoot
Robocopy . $fullPath /mir
Pop-Location