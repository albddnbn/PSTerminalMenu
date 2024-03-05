##Function will configure different settings that are useful / nice on a computer, including:
# 1. install vs code, notepad++, windows terminal , Set Dracula at night theme
# 2. import enable expanded context menu reg file
# 3. import copy as path in context menu reg file
# 4. install chrome, set as default
Function Configure-Computer {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        $TargetComputer
    )
    BEGIN {
        ## Dracula themes: https://github.com/dracula
        $APPS_TO_INSTALL = [system.collections.array]::new(
            'VSCode',
            'Notepad++',
            'Chrome'
        )

        $REG_FILES_TO_IMPORT = Get-ChildItem -PAth "$env:SUPPORTFILES_DIR\registry" `
            -Include Enable*.reg -File -Erroraction SilentlyContinue

        ## Attempting explicit install of windows terminal in process block for now
    }


    PROCESS {
        ## Create remote session
        $target_session = New-PSSession $TargetComputer

        ## Install software applications
        $APPS_TO_INSTALL | ForEach-Object {
            $DeploymentFolder = Get-ChildItem -Path "$env:PSMENU_DIR\deploy\applications" -Filter "$_" -Directory -ErrorAction SilentlyContinue
            if (-not ($DeploymentFolder)) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find folder for $_ in ./deploy/applications!" -ForegroundColor Yellow
                continue
            }
            try {
                Copy-ITem -Path "$($DeploymentFolder.fullname)" -Destination "C:\temp\" -ToSession $target_session -recurse -force
                
                ## Execute installation script
                Invoke-Command -Session $target_session -ScriptBlock -argumentlist $($Deploymentfolder.name) {
                    param(
                        $installationfolder
                    )
                    $install_script = Get-ChildItem -Path "C:\temp\$installationfolder" -Filter "Deploy-$installationfolder.ps1" -File
                    Powershell.exe -ExecutionPolicy Bypass "$($install_script.fullname)" -Deploymenttype 'Install' -DeployMode 'Silent'                
                }
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't copy folder for $_ to C:\temp on $TargetComputer!" -ForegroundColor Yellow
            }
        }

        ## Apply registry edits:
        $REG_FILES_TO_IMPORT | ForEach-Object {
            try {
                Copy-Item -Path "$($_.fullname)" -Destination "C:\temp\" -ToSession $target_session -Force
                Invoke-Command -Session $target_session -ScriptBlock {
                    param(
                        $regfile
                    )
                    reg import "C:\temp\$regfile"
                    Start-Sleep -Seconds 1
                    Remove-Item "C:\temp\$regfile"
                } -ArgumentList $_.name
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't copy $_ to C:\temp on $TargetComputer!" -ForegroundColor Yellow
            }
        }

        ## Install Windows Terminal:
        $WindowsTerminal_folder = Get-ChildItem -Path "$env:PSMENU_DIR\deploy\irregular" -Filter "WindowsTerminal" -Directory -ErrorAction SilentlyContinue
        if (-not ($WindowsTerminal_folder)) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find WindowsTerminal folder in ./deploy/irregular!" -ForegroundColor Yellow
        }
        else {
            try {
                Copy-Item -Path "$($WindowsTerminal_folder.fullname)" -Destination "C:\temp\" -ToSession $target_session -Recurse -Force
                Invoke-Command -Session $target_session -ScriptBlock {
                    $install_winterminal = Get-ChildItem -Path "C:\temp\WindowsTerminal" -Filter "Deploy-WindowsTerminal.ps1" -File
                    Powershell.exe -ExecutionPolicy Bypass "$($install_winterminal.fullname)" -CloseApps
                }
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Failed trying to install Windows Terminal on $TargetComputer!" -ForegroundColor Yellow
            }
        }

        ## REMOVE THE PS-SESSION
        Remove-PSSession $target_session

    }

    END {

        Read-Host "Press enter to continue."
    }

}