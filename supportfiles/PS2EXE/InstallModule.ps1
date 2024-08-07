param ($fullPath)
#$fullPath = 'C:\Program Files\WindowsPowerShell\Modules\PS2EXE'
if (-not $fullPath) {
    $fullpath = $env:PSModulePath -split ":(?!\\)|;|," |
    Where-Object { $_ -notlike ([System.Environment]::GetFolderPath("UserProfile") + "*") -and $_ -notlike "$pshome*" } |
    Select-Object -First 1
    $fullPath = Join-Path $fullPath -ChildPath "PS2EXE"
}
Push-location $PSScriptRoot
Robocopy . $fullPath /mir
Pop-Location

## Above code was adapted from ImportExcel's InstallModule.ps1 - this didn't always work, so I wrote this as a failsafe
$PSHOME_PATH = "C:\Program Files\WindowsPowerShell\Modules"
$MODULE_NAME = "PS2EXE"


$check_for_path = Test-Path $PSHOME_PATH -ErrorAction SilentlyContinue
if ($check_for_path) {
    Copy-Item "$env:SUPPORTFILES_DIR\$MODULE_NAME" $PSHOME_PATH -Recurse
    Write-Host "Copied $MODULE_NAME to $PSHOME_PATH" -ForegroundColor Green
}

Import-Module $fullPath -Force
Write-Host "Imported $MODULE_NAME module" -ForegroundColor Green