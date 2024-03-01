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
        $APPS_TO_INSTALL = [system.collections.arraylist]::new(
            {
                Name = "Chrome"
                Installer = "https://dl.google.com/chrome/install/GoogleChromeStandaloneEnterprise64.msi"
                ThemeFile = ""
                Arguments = "/quiet /norestart"
            },
            {
                Name = "Notepad++"
                Installer = ""
                ThemeFile = "dracula.xml"
                Arguments = ""
            },
            {
                Name = "VSCode"
                Installer = "https://go.microsoft.com/fwlink/?LinkID=852157"
                ThemeFile = "dracula.json"
                Arguments = "/silent"
            }
        )
        


        $APPX_PACKAGES_TO_INSTALL = @(
            "Microsoft.WindowsTerminal"
        )

        $REG_FILES_TO_IMPORT = @(
            "EnableExpandedContextMenu.reg",
            "CopyAsPath.reg"
        )
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
        }
    }

    END {

        Read-Host "Press enter to continue."
    }

}
