Function Deploy-PSToolKitApp {
    <#
    .SYNOPSIS
    Copies a PS Toolkit Deployment folder over to a target PC, and runs the installation.

    .DESCRIPTION
    Looks in the ./ps-app-deployments folder, which should have a folder for each PS App Deployment Toolkit App. For Ex: there could be OneDrive, OFfice2021, AdobeReaderDC folders, etc. The folder name needs to correspond to the "Deploy-<FolderName>.ps1" file inside of it.

    .PARAMETER ComputerName
    Target PC

    .EXAMPLE
    Deploy-PSToolKitApp -ComputerName "s-a228-03"

    .NOTES
    Additional notes about the function.
    #>
    # Parameter help description
    param(
        [string[]]$ComputerName,
        [string]$DepType = "Install",
        [string]$DepMode = "Silent"
    )

    if (Get-Module -ListAvailable -Name PS-Menu) {
        Import-Module PS-Menu
    }
    else {
        Write-Host "PS-Menu not found. Installing..."
        Install-Module PS-Menu -Scope CurrentUser -Force
        Import-Module PS-Menu
    }

    $deployment_options = Get-ChildItem -Path "$PSScriptRoot\ps-app-deployments" | ForEach-Object { $_.BaseName }
    $deployment_choice = menu $deployment_options

    $deployment_path = "$PSScriptRoot\ps-app-deployments\$deployment_choice"

    if ($ComputerName -eq "") {
        $ComputerName = Read-Host "Enter the name of the computer to deploy to"
    }

    if (Test-NetConnection $ComputerName -InformationLevel Quiet) {

        # if theres an error - write that access was denied or error
        try {
            # copy the deployment folder to the target PC
            Copy-Item -Path $deployment_path -Destination "\\$ComputerName\c$\temp" -Recurse -Force
            Write-Host ""
            Write-Host "Deployment folder copied to $ComputerName" -ForegroundColor Green
            Write-Host ""
        }
        catch {
            Write-Host ""
            Write-Host "Unable to copy deployment folder to $ComputerName" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
            Write-Host ""
        }


        # run the install script on the target PC
        try {
            Invoke-Command -ComputerName $ComputerName -ScriptBlock -ErrorVariable InvokeError { 
                Powershell.exe -ExecutionPolicy Bypass ".\Deploy-$($using:deployment_choice).ps1" -DeploymentType "$($using:DepType)" -DeployMode "$($using:DepMode)"
            }
            if ($InvokeError) {
                foreach ($error in $InvokeError) {

                    if ($($error.Exception.Message) -notlike "*Failed to Initialize Drives*") {
                        Write-Host ""
                        Write-Host "Diffculty running installation on $ComputerName" -ForegroundColor Red
                        Write-Host "----------------------------------------------------------------------"
                        Write-Host "Error: $_" -ForegroundColor Red
                        Write-Host ""
                    }
                }
            }
            else {
                Write-Host ""
                Write-Host "Install script ran successfully on $ComputerName" -ForegroundColor Green
                Write-Host ""
            }
        }
        catch {
            Write-Host ""
            Write-Host "Unable to run install script on $ComputerName" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
            Write-Host ""
        }
    }
    else {
        Write-Host ""
        Write-Host "$ComputerName is offline x_x" -ForegroundColor Red
        Write-Host ""
    }



}