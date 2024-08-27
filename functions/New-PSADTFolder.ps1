function New-PSADTFolder {
    <#
    .SYNOPSIS
        Downloads specified (hopefully latest) version of Powershell App Deployment Toolkit and creates directory structure for application deployment.

    .DESCRIPTION
        Creates basic directory structure for PSADT deployment after downloading specified PSADT.zip folder from Github.

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>

    $PSADT_DOWNLOAD_URL = "https://github.com/PSAppDeployToolkit/PSAppDeployToolkit/releases/download/3.10.2/PSAppDeployToolkit_3.10.2.zip"
    ## Downloads the PSADT Toolkit and extracts it
    ## Renames Toolkit folder to the given Application Name.

    $ApplicationName = Read-Host "Enter the name of the application"
    $DeploymentFolder_Destination = Read-Host "Enter destination for PSADT folder (press enter for default: $env:USERPROFILE\$APPLICATIONNAME)"
    if ($DeploymentFolder_Destination -eq '') {
        $DeploymentFolder_Destination = "$env:USERPROFILE\$APPLICATIONNAME"
    }

    ## create destination directory if not exist
    if (-not (Test-Path $DeploymentFolder_Destination -PathType Container -Erroraction SilentlyContinue)) {
        New-Item -Path $DeploymentFolder_Destination -ItemType Directory | out-null
    }

    ## Download the PSADT .zip folder (current latest):
    Invoke-WebRequest "$PSADT_DOWNLOAD_URL" -Outfile "$env:USERPROFILE\PSADT.zip"

    Expand-Archive -Path "$env:USERPROFILE\PSADT.zip" -DestinationPath "$env:USERPROFILE\PSADT"

    ## Get the toolkit folder:
    $toolkit_folder = Get-ChildItem -Path "$env:USERPROFILE\PSADT" -Filter "Toolkit" -Directory | Select -Exp FullName

    Copy-Item -Path "$toolkit_folder\*" -Destination "$DeploymentFolder_Destination\"

    ## Delete everything not needed:
    REmove-Item -Path "$env:USERPROFILE\PSADT*" -Recurse -Force -ErrorAction SilentlyContinue

    ## Rename the Deploy-Application.ps1 file
    Rename-Item -Path "$DeploymentFolder_Destination\Deploy-Application.ps1" -NewName "Deploy-$ApplicationName.ps1"
}