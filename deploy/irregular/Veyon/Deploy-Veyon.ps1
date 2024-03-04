<#
.SYNOPSIS
    This script performs the installation or uninstallation of Veyon.
    # LICENSE #
    PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
    Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
    This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
    You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
    The script is provided as a template to perform an install or uninstall of an application(s).
    The script either performs an "Install" deployment type or an "Uninstall" deployment type.
    The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
    The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
    The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
    Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
    Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
    Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
    Disables logging to file for the script. Default is: $false.
.EXAMPLE
    PowerShell.exe .\Deploy-Veyon.ps1 -DeploymentType "Install" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-Veyon.ps1 -DeploymentType "Install" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-Veyon.ps1 -DeploymentType "Install" -DeployMode "Interactive"
.EXAMPLE
    PowerShell.exe .\Deploy-Veyon.ps1 -DeploymentType "Uninstall" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-Veyon.ps1 -DeploymentType "Uninstall" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-Veyon.ps1 -DeploymentType "Uninstall" -DeployMode "Interactive"
.NOTES
    Toolkit Exit Code Ranges:
    60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
    69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
    70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
    http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [string]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [string]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false,
    # [Parameter(Mandatory = $false)]
    # [string]$InstallationType = 'Student'
    [Parameter(Mandatory = $false)]
    [switch]$MasterPC
)

Try {
    ## Set the script execution policy for this process
    Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [string]$appVendor = 'Veyon Solutions'
    [string]$appName = 'Veyon'
    [string]$appVersion = ''
    [string]$appArch = ''
    [string]$appLang = ''
    [string]$appRevision = ''
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = '09/22/2023'
    [string]$appScriptAuthor = 'Jason Bergner'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName = ''
    [string]$installTitle = 'Veyon'

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [int32]$mainExitCode = 0

    ## Variables: Script
    [string]$deployAppScriptFriendlyName = 'Deploy Application'
    [version]$deployAppScriptVersion = [version]'3.8.4'
    [string]$deployAppScriptDate = '26/01/2021'
    [hashtable]$deployAppScriptParameters = $psBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
    [string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
        If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
    }
    Catch {
        If ($mainExitCode -eq 0) { [int32]$mainExitCode = 60008 }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Installation'




        ## Microsoft Intune Win32 App Workaround - Check If Running 32-bit Powershell on 64-bit OS, Restart as 64-bit Process
        If (!([Environment]::Is64BitProcess)) {
            If ([Environment]::Is64BitOperatingSystem) {

                Write-Log -Message "Running 32-bit Powershell on 64-bit OS, Restarting as 64-bit Process..." -Severity 2
                $Arguments = "-NoProfile -ExecutionPolicy ByPass -WindowStyle Hidden -File `"" + $myinvocation.mycommand.definition + "`""
                $Path = (Join-Path $Env:SystemRoot -ChildPath "\sysnative\WindowsPowerShell\v1.0\powershell.exe")

                Start-Process $Path -ArgumentList $Arguments -Wait
                Write-Log -Message "Finished Running x64 version of PowerShell"
                Exit

            }
            Else {
                Write-Log -Message "Running 32-bit Powershell on 32-bit OS"
            }
        }

        ## Show Welcome Message, Close Veyon With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'veyon-cli,veyon-configurator,veyon-wcli,veyon-worker' -CloseAppsCountdown 60

        ## Show Progress Message (With a Message to Indicate the Application is Being Uninstalled)
        Show-InstallationProgress -StatusMessage "Removing Any Existing Version of $installTitle. Please Wait..."

        ## Remove Any Existing Version of Veyon
        $AppList = Get-InstalledApplication -Name 'Veyon'        
        ForEach ($App in $AppList) {
            If ($App.UninstallString) {
                $UninstPath = $($App.UninstallString).Replace('"', '')       
                If (Test-Path -Path $UninstPath) {
                    Write-log -Message "Found $($App.DisplayName) $($App.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                    Execute-Process -Path $UninstPath -Parameters '/S'
                    Start-Sleep -Seconds 10
                }
            }
        }
   
        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Installation'

        # if its a teacher, then create the $env:SystemDrive\Veyon Screenshots folder and give grant users /T /C /Q Users:(OI) (CI) F
        if ($MasterPC) {
            $ScreenshotsFolder = "C:\Veyon Screenshots"
            # if (!(Test-Path -Path $ScreenshotsFolder)) {
            #     New-Item -Path $ScreenshotsFolder -ItemType Directory
            # }
            New-Folder -Path $ScreenshotsFolder
            $AccessToVeyonScreenShots = Get-Acl -Path $ScreenshotsFolder
            $AccessForUsers = New-Object System.Security.AccessControl.FileSystemAccessRule("Users", "FullControl", "Allow")
            # add object and container inheritance
            $AccessToVeyonScreenShots.AddAccessRule($AccessForUsers)

            Get-ChildItem -Path $ScreenshotsFolder -Recurse | Set-ACL -AclObject $AccessToVeyonScreenShots
        }


        If ($ENV:PROCESSOR_ARCHITECTURE -eq 'x86') {
            Write-Log -Message "Detected 32-bit OS Architecture" -Severity 1 -Source $deployAppScriptFriendlyName

            ## Install Veyon 32-bit
            $ExePath32 = Get-ChildItem -Path "$dirFiles" -Include veyon*win32*.exe -File -Recurse -ErrorAction SilentlyContinue
            $Config = Get-ChildItem -Path "$dirFiles" -Include *.json -File -Recurse -ErrorAction SilentlyContinue

            If (($ExePath32.Exists) -and ($Config.Exists)) {
                Write-Log -Message "Found $($ExePath32.FullName) and $($Config.FullName), now attempting to install $installTitle 32-bit."
                Show-InstallationProgress "Installing Veyon 32-bit. This may take some time. Please wait..."
                Execute-Process -Path "$ExePath32" -Parameters "/S /NoMaster /ApplyConfig=""$Config""" -WindowStyle Hidden
                Start-Sleep -Seconds 5
            }

            ElseIf ($ExePath32.Exists) {
                Write-Log -Message "Found $($ExePath32.FullName), now attempting to install $installTitle 32-bit."
                Show-InstallationProgress "Installing Veyon 32-bit. This may take some time. Please wait..."
                Execute-Process -Path "$ExePath32" -Parameters "/S /NoMaster" -WindowStyle Hidden
                Start-Sleep -Seconds 5
            }

        }
        <# 64-bit installation section ---------------------------------------------------------------------- #>
        Else {
            Write-Log -Message "Detected 64-bit OS Architecture" -Severity 1 -Source $deployAppScriptFriendlyName

            ## Install Veyon 64-bit
            $ExePath64 = Get-ChildItem -Path "$dirFiles" -Include veyon*win64*.exe -File -Recurse -ErrorAction SilentlyContinue
            $Config = Get-ChildItem -Path "$dirFiles" -Include *.json -File -Recurse -ErrorAction SilentlyContinue

            If ($ExePath64.Exists) {
                if ($MasterPC) {
                    if ($Config.Exists) { 
                        Write-Log -Message "Found $($ExePath64.FullName) and $($Config.FullName), now attempting to install $installTitle 64-bit."
                        Show-InstallationProgress "Installing Veyon 64-bit MASTER. This may take some time. Please wait..."
                        Execute-Process -Path "$ExePath64" -Parameters "/S /ApplyConfig=""$Config""" -WindowStyle Hidden
                    }
                    else {
                        Write-Log -Message "Found $($ExePath64.FullName), now attempting to install $installTitle 64-bit without config" -Severity 2
                        Show-InstallationProgress "Installing Veyon 64-bit MASTER. This may take some time. Please wait..."
                        Execute-Process -Path "$ExePath64" -Parameters "/S" -WindowStyle Hidden
                    }
                }
                else {
                    Write-Log -Message "Found $($ExePath64.FullName), now attempting to install $installTitle student 64-bit."
                    Show-InstallationProgress "Installing Veyon 64-bit STUDENT. This may take some time. Please wait..."
                    Execute-Process -Path "$ExePath64" -Parameters "/S /NoMaster" -WindowStyle Hidden

                }
                Start-Sleep -Seconds 5
            }
            Else {
                Write-Log -Message "FILE NOT FOUND: $($ExePath64.FullName), $installTitle installation failed." -Severity 3 -Source $deployAppScriptFriendlyName
                Exit-Script -ExitCode 1
            }
        }
       
        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Installation'

        # delete any links to veyon configurator if its student
        if (-not $MasterPC) {
            Write-Log -Message 
            $ConfiguratorLink = Get-ChildItem -Path "$env:PUBLIC\Desktop" -Include "Veyon*.lnk" -File -Recurse -ErrorAction SilentlyContinue
            $StartMenuLinks = Get-ChildItem -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Include "Veyon*.lnk" -File -Recurse -ErrorAction SilentlyContinue
            ForEach ($link in $ConfiguratorLink) {
                Remove-Item -Path "$ConfiguratorLink" -Force -ErrorAction SilentlyContinue
            }
            ForEach ($link in $StartMenuLinks) {
                Remove-Item -Path "$StartMenuLinks" -Force -ErrorAction SilentlyContinue
            }
        }

    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, Close Veyon With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'veyon-cli,veyon-configurator,veyon-wcli,veyon-worker' -CloseAppsCountdown 60

        ## Show Progress Message (With a Message to Indicate the Application is Being Uninstalled)
        Show-InstallationProgress -StatusMessage "Uninstalling the $installTitle Application. Please Wait..."

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Uninstallation'

        ## Uninstall Any Existing Version of Veyon
        $AppList = Get-InstalledApplication -Name 'Veyon'        
        ForEach ($App in $AppList) {
            If ($App.UninstallString) {
                $UninstPath = $($App.UninstallString).Replace('"', '')       
                If (Test-Path -Path $UninstPath) {
                    Write-log -Message "Found $($App.DisplayName) $($App.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                    Execute-Process -Path $UninstPath -Parameters '/S /ClearConfig'
                    Start-Sleep -Seconds 10
                }
            }
        }

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Uninstallation'

        # if $env:SystemDrive\Veyon Screenshots exists, remove it
        $ScreenshotsFolder = "$env:SystemDrive\Veyon Screenshots"
        if (Test-Path -Path $ScreenshotsFolder) {
            # create a Veyon Screenshots Old - DATE folder
            $OldScreenshotsFolder = "$env:SystemDrive\Veyon Screenshots Old - $(Get-Date -Format "MM-dd-yyyy")"
            New-Item -Path $OldScreenshotsFolder -ItemType Directory
            # move the contents of $env:SystemDrive\Veyon Screenshots to $env:SystemDrive\Veyon Screenshots Old - DATE
            Move-Item -Path $ScreenshotsFolder\* -Destination $OldScreenshotsFolder
            
            Remove-Item -Path $ScreenshotsFolder -Force -Recurse
        }


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [string]$installPhase = 'Pre-Repair'

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [string]$installPhase = 'Repair'


        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [string]$installPhase = 'Post-Repair'


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [int32]$mainExitCode = 60001
    [string]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}