<#
.SYNOPSIS
    Installs an application on the local computer using the PowerShell App Deployment Toolkit.
    Called by functions/Install-AppOnRemotePC to install an application on a group of target computers.

.DESCRIPTION
    Searches for the application folder, by name, in C:\temp.
    Then executes the Deploy-<appname>.ps1 like this: Powershell.exe -ExecutionPolicy Bypass ./Deploy-<appname>.ps1 -DeploymentType "Install" -DeployMode "Silent"

.PARAMETER app_to_install
    Specifies the name of the application to install.
    This is also the name of the PSADT Folder in C:\temp, and the <appname> in Deploy-<appname>.ps1.

.PARAMETER do_not_disturb
    Specifies whether the script will skip the computer if a user is logged in.

.NOTES
    PSADT Documentation : https://psappdeploytoolkit.com/
    PSADT Github        : https://github.com/PSAppDeployToolkit/PSAppDeployToolkit
#>
param(
    $app_to_install,
    $do_not_disturb
)
# Safety net since psadt script silent installs close app-related processes w/o prompting user
$check_for_user = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
if ($check_for_user) {
    if ($($do_not_disturb) -eq 'y') {
        Write-Host "[$env:COMPUTERNAME] :: Skipping, $check_for_user logged in."
        Continue
    }
}

# get the installation script
$Installationscript = Get-ChildItem -Path "C:\temp" -Filter "Deploy-$app_to_install.ps1" -File -Recurse -ErrorAction SilentlyContinue
# unblock files:
Get-ChildItem -Path "C:\temp" -Recurse | Unblock-File
# $AppFolder = Get-ChildItem -Path 'C:\temp' -Filter "$app_to_install" -Directory -Erroraction silentlycontinue
if ($Installationscript) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Found $($Installationscript.Fullname), installing."
    Set-Location "$($Installationscript.DirectoryName)"
    Powershell.exe -ExecutionPolicy Bypass ".\Deploy-$($app_to_install).ps1" -DeploymentType "Install" -DeployMode "Silent"
}
else {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: ERROR - Couldn't find the app deployment script!" -Foregroundcolor Red
}
