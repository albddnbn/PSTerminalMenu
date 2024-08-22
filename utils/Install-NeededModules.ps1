function Install-NeededModules {
    <#
.SYNOPSIS
    This file checks for modules needed to run functions in the menu, and attempts to install them if they're not present.

.DESCRIPTION
    The script will first check for a connection to internet by trying to ping google.com - if this is successful, it knows it can download any needed modules using the Install-Module cmdlet.
    If the connection fails, it will check for the needed modules in the supportfiles directory, and if they're not there, it will check for the InstallModule.ps1 file in the corresponding module's folder in the supportfiles directory, and run it if it exists.
    Each modules Install-Module.ps1 file was adapted from the Install-Module.ps1 file found by default in the ImportExcel module.
    If anyone has a better way of doing this, or has an experience where these methods don't work, please let someone know!

.NOTES
    Additional notes about the file.
#>
    $module_dependencies = @('ps-menu', 'importexcel', 'ps2exe')

    # Check for internet connectivity:
    $TestConnection = Test-Connection google.com -Count 2 -Quiet
    if ($TestConnection) {
        # make sure nuget is available
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable)) {
            Write-Host "Installing NuGet package provider..." -ForegroundColor Yellow
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        }

        # Set-Location "$env:SUPPORTFILES_DIR"
        ForEach ($modulename in $module_dependencies) {
            $module_check = Get-Module -Name $modulename -ListAvailable -erroraction SilentlyContinue
            if ($module_check) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $modulename"
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $modulename not found, attempting to install now..."
                Install-Module $modulename -Force
            }
            ipmo $modulename | out-null

        }
    }
    elseif (-not $TestConnection) {
        ForEach ($modulename in $module_dependencies) {
            $module_check = Get-Module -Name $modulename -ListAvailable
            if (-not $module_check) {
                # get the installmodule.ps1 file:
                $InstallModulePS1File = Get-ChildItem -Path "$env:PSMENU_DIR\supportfiles\$modulename" -Filter "InstallModule.ps1" -File -ErrorAction SilentlyContinue
                if (-not $InstallModulePS1File) {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find InstallModule.ps1 file for $modulename, skipping..."
                    continue
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found InstallModule.ps1 file for $modulename, running now..."
                    &"$($InstallModulePS1File.fullname)"
                }
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $modulename"
                ipmo $modulename | out-null
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Finished importing $modulename"
            }
        }
    }

    #ACTIVEDIRECTORY MODULE should not be necessary.
    # $ad_module_check = Get-Module -Name 'ActiveDirectory' -ListAvailable
    # if ($ad_module_check) {
    #     Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found ActiveDirectory module."
    # }
    # else {
    #     Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ActiveDirectory module unavailable, importing from $env:PSMENU_DIR\supportfiles."
    #     . "$env:PSMENU_DIR\functions\Install-ActiveDirectoryModule.ps1"
    #     Install-ActiveDirectoryModule
    #     # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Finished installing ActiveDirectory module, importing now."
    #     # ipmo ActiveDirectory
    # }
}