function Install-ActiveDirectoryModule {
    <#
    .SYNOPSIS
        Installs Powershell Active Directory module without installing RSAT or using DISM.

    .DESCRIPTION
        After installing the Active Directory module on a computer the traditional way, follow the guide in the notes to find the necessary module files.

    .EXAMPLE
        Get-ActiveDirectoryModule

    .NOTES
        Get the .dll file you have to import for AD module:
        https://petertheautomator.com/2020/10/05/use-the-active-directory-powershell-module-without-installing-rsat/

        abuddenb / 02-17-2024
    #>
    $activedirectory_folder = Get-Childitem -path "$env:SUPPORTFILES_DIR" -filter "ActiveDirectory" -Directory -ErrorAction SilentlyContinue
    if (-not $activedirectory_folder) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ActiveDirectory folder not found in $env:SUPPORTFILES_DIR" -foregroundcolor red
        return
    }

    Copy-Item -Path "$($activedirectory_folder.fullname)" -Destination "C:\Program Files\WindowsPowerShell\Modules\" -Recurse -Force -ErrorAction SilentlyContinue

    $Microsoft_AD_Management_DLL = Get-childitem -path "C:\Program Files\WindowsPowerShell\Modules\" -Filter 'Microsoft.ActiveDirectory.Management.dll' -File -Recurse -Erroraction SilentlyContinue
    if (-not $Microsoft_AD_Management_DLL) {
        Write-Host "Unable to find Microsoft.ActiveDirectory.Management.dll in ./ActiveDirectory. Exiting script." -foregroundcolor red
        exit
    }
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($Microsoft_AD_Management_DLL.fullname). Importing ActiveDirectory module."
    Import-Module "$($Microsoft_AD_Management_DLL.fullname)" -Force

}
