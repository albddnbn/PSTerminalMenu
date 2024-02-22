<#
.SYNOPSIS
    WARNING: Script will force close the 'Teams' process if not told to skip occupied computers.
    Performs a 'purge' of Microsoft Teams Classic, and the Teams Machine-Wide Installer from local computer in preparation for installation of the 'new' Teams (work or school) client.
    Attempts to uninstall the user installations of Teams Classic for any user logged in (if not skipping computer), then attempts to remove the Teams Machine-Wide Installer.
    Script will delete any remaining Teams folders for user or computer, and delete corresponding registry keys.

.NOTES
    Info on new Teams upgrade: https://learn.microsoft.com/en-us/microsoftteams/new-teams-bulk-install-client
    PSADT Silent install of Microsoft Teams Classic (contains uninstall section used as source): https://silentinstallhq.com/microsoft-teams-install-and-uninstall-powershell/
    Info on Teams install/uninstall/cleanup: https://lazyadmin.nl/powershell/microsoft-teams-uninstall-reinstall-and-cleanup-guide-scripts/
#>
param(
    $skip_occupied_computers
)
$check_for_user = $skip_occupied_computers
if ($check_for_user.ToLower() -eq 'y') {
    $user_logged_in = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
    if ($user_logged_in) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] " -NoNewline
        Write-Host "[$env:COMPUTERNAME] :: Found $user_logged_in logged in, skipping removal of Teams Classic." -foregroundcolor yellow
        return
    }
}

Write-Host ""
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Beginning removal of Teams classic." -foregroundcolor yellow

# install nuget / foce
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | out-null
# install psadt / force
Install-Module PSADT -Force | out-null

# kill teams processes:
Get-PRocess -Name 'Teams' -erroraction silentlycontinue | Stop-Process -Force

$user_folders = Get-ChildItem -Path "C:\Users" -Directory

# uninstall user profile teams isntalations
ForEach ($single_user_folder in $user_folders) {

    $username = $single_user_folder.name
    # get teams update.exe
    $update_exe = Get-ChildItem -Path "$($single_user_folder.fullname)\AppData\Local\Microsoft\Teams\" -Filter "Update.exe" -File -Recurse -ErrorAction SilentlyContinue
    if ($update_exe) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Found $($update_exe.fullname), attempting to uninstall Teams for $($single_user_folder.name)."
        Execute-ProcessAsUser -username $username -Path "$($update_exe.fullname)" -Parameters "--uninstall -s" -Wait
        Start-Sleep -Seconds 5
        Update-Desktop
    }

    # remove local app data teams folder
    if (Test-Path  "$($single_user_folder.fullname)\AppData\Local\Microsoft\Teams\" -erroraction silentlycontinue) {
        Remove-item -path  "$($single_user_folder.fullname)\AppData\Local\Microsoft\Teams\" -recurse -force
    }
    # remove any start menu links to old teams for the user:
    Remove-Item -path "$($single_user_folder.fullname)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\*Teams*.lnk" -Force -ErrorAction SilentlyContinue

    # remove any desktop shortcuts for teams:
    Remove-Item -path "$($single_user_folder.fullname)\Desktop\*Teams*.lnk" -Force -Erroraction SilentlyContinue

    Update-desktop
}

Write-host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Finished user uninstallations/deletions, attempting Teams Machine-Wide uninstall and ignoring error exit codes." -Foregroundcolor Yellow

Remove-MSIApplications -Name 'Teams Machine-Wide Installer' -ContinueOnError $true

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Finished Teams Machine-Wide uninstall, deleting Teams registry keys in HKCU and HKLM."

Remove-RegistryKey -Key 'HKCU:\SOFTWARE\Microsoft\Teams\' -Recurse
Remove-RegistryKey -Key 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{731F6BAA-A986-45A4-8936-7C3AAAAA760B}' -Recurse
Remove-RegistryKey -Key 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Teams' -Recurse


Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Deleting any existing 'Teams Installer' Folder in C:\Program Files (x86)."

Remove-Item -Path 'C:\Program Files (x86)\Teams Installer' -Recurse -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 3

Update-Desktop