#Run this file in an admin powershell window to compile .\menu.ps1 into an executable.
Write-Host "Applying values from configuration file..." -ForegroundColor Yellow

# Set SupportFiles environment variable - this directory holds files used by functions - like how the create html report functions uses the iit logo png file.
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Setting `$env:SUPPORTFILES_DIR environment variable to $((Get-Item './supportfiles').FullName)."
$env:SUPPORTFILES_DIR = (Get-Item './supportfiles').FullName

# create hashtable called other_categories from reading the category_functions.json
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Getting values from configuration file..."
$config_file = Get-Content -Path "$env:SUPPORTFILES_DIR\config.json" | ConvertFrom-Json

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Setting `$env:PSMENU_DIR environment variable to $((Get-Item .).FullName)."
# get current directory, save to env var
$env:PSMENU_DIR = (Get-Item .).FullName

# Check if PS2EXE is installed
# PS2EXE powershell module
try {
    ipmo ps2exe
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found the PS2exe module, it's been imported."
}
catch {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Issue importing PS2exe module, attempting to import from $env:SUPPORTFILES_DIR..."
    $PS2EXEDir = Get-ChildItem -Path "$env:SUPPORTFILES_DIR\" -Filter "PS2EXE-MASTER" -Directory -ErrorAction SilentlyContinue
    $PS2exeModuleFile = Get-ChildItem -Path "$($ps2exedir.fullname)" -Filter "*ps2exe.psm1" -File -Recurse -ErrorAction SilentlyContinue
    ipmo "$($PS2exeModuleFile.FullName)" | Out-Null
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: PS2exe module imported from $env:SUPPORTFILES_DIR."
}

# locate menu.ps1
$MenuScript = Get-ChildItem -Path . -Filter "menu.ps1" -File -ErrorAction SilentlyContinue

if ($MenuScript) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Nuget and PS2exe are installed, compiling menu.ps1 into an executable now..."
    # test for existing menu.exe - if its there rename it
    if (Test-Path -Path ".\menu.exe") {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found existing menu.exe, renaming to menu.exe.old"
        Copy-Item './menu.exe' './menu.exe.old' -Force
        Start-Sleep -Seconds 1
        Remove-Item './menu.exe' -Force
    }    
     
    # get the icon file from supportfiles
    $iconfile = Get-ChildItem -Path "./supportfiles" -Filter "ps1avatar.ico" -File -ErrorAction SilentlyContinue    
    if ($iconfile) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($iconfile.FullName), using it as the icon for the executable."
        Invoke-PS2EXE -inputFile "$($Menuscript.fullname)" -outputFile "$env:PSMENU_DIR\menu.exe" -iconFile "$($iconfile.fullname)" -version '2.0.1' -requireAdmin -verbose
    }
    else {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find ps1avatar.ico, using default icon for the executable." -Foregroundcolor Yellow
        Invoke-PS2EXE -inputFile "$($Menuscript.fullname)" -outputFile "$env:PSMENU_DIR\menu.exe" -version '2.0.1' -requireAdmin -verbose
    }
}
else {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find menu.ps1, exiting..." -Foregroundcolor Red
    exit
}

#open folder in fileexplorer
explorer.exe "$env:PSMENU_DIR"