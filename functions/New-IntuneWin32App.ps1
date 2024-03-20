function New-IntuneWin32App {
    <#
    .SYNOPSIS
        Creates an .intunewin package file using a PSADT Deployment Folder, given certain conditions.

    .DESCRIPTION
        Uses IntuneWinAppUtil.exe from: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool

    .PARAMETER ScriptFolder
        Path to folder holding source files and/or script.

    .PARAMETER InstallationFile
        Path to the installation executable or script. If your package is installed using a script - target the script. If it's only using an .msi, or .exe - target this.
        This is the file that will be targeted in your 'Installation Line' when creating the Win32 App in Intune.

    .PARAMETER OutputFolder
        Path to the folder where the .intunewin file will be created.

    .EXAMPLE
        Generate-IntuneWin32AppFromPSADT -ScriptFolder "C:\Users\williamwonka\Desktop\PSADT-Deployments\AdobeAcrobatReaderDC-2021.001.20155" -InstallationFile "C:\Users\abuddenb\Desktop\PSADT-Deployments\AdobeAcrobatReaderDC-2021.001.20155\Deploy-Application.ps1" -OutputFolder "C:\Users\abuddenb\Desktop\PSADT-Deployments\AdobeAcrobatReaderDC-2021.001.20155"

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Scriptfolder,
        [Parameter(Mandatory = $true)]
        [string]$InstallationFile,
        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    # get intunewinapputil.exe
    $Intunewinapputil_exe = Get-Childitem -Path "$env:SUPPORTFILES_DIR" -Filter 'IntuneWinAppUtil.exe' -File -Recurse -Erroraction SilentlyContinue
    if (-not $Intunewinapputil_exe) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Unable to find IntuneWinAppUtil.exe in $env:PSMENU_DIR, attempting to download from github..." -ForegroundColor Red
        # download the png from : https://iit.dtcc.edu/wp-content/uploads/2023/07/it-logo.png
        try {
            Invoke-WebRequest -Uri "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.5.zip" -OutFile "$env:PSMENU_DIR\IntuneWinAppUtil.zip"
            Expand-Archive -Path "$env:PSMENU_DIR\IntuneWinAppUtil.zip" -DestinationPath "$env:PSMENU_DIR"
            $Intunewinapputil_exe = Get-Childitem -Path "$env:PSMENU_DIR" -Filter 'IntuneWinAppUtil.exe' -File -Recurse -Erroraction SilentlyContinue
            if (-not $Intunewinapputil_exe) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Unable to find IntuneWinAppUtil.exe in $env:PSMENU_DIR, exiting." -ForegroundColor Red
                exit
            }
        }
        catch {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Unable to find IntuneWinAppUtil.exe from github." -ForegroundColor Red
            Exit
        }
    }
    else {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($Intunewinapputil_exe.fullname) in $env:PSMENU_DIR."
    }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Creating .intunewin package from " -NoNewLine
    Write-Host "$ScriptFolder" -Foregroundcolor Green -NoNewline
    Write-Host ", using " -NoNewLine
    Write-Host "$Installationfile" -NoNewLine -Foregroundcolor Yellow
    Write-Host ", and saving to " -NoNewLine
    Write-Host "$OutputFolder" -Foregroundcolor Cyan -NoNewline
    Write-Host "."

    Start-Process -FilePath "$($Intunewinapputil_exe.fullname)" -ArgumentList "-c ""$ScriptFolder"" -s ""$Installationfile"" -o $OutputFolder -q" -Wait

    Start-Sleep -Seconds 2
    Invoke-Item $OutputFolder

    Write-Host "If the package follows traditional PSADT format, the execution line should be:"
    Write-Host "powershell.exe -ExecutionPolicy Bypass .\$($InstallationFile | Split-Path -Leaf) -DeploymentType 'Install' -DeployMode 'Silent'" -Foregroundcolor Yellow
    # Read-Host "This is an experimental function, press ENTER to continue after screenshotting any error messages, please!"
}