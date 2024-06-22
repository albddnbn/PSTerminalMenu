<# Install Teams - Alex B. 6-19-2023
.SYNOPSIS
    Installs Teams on a remote or local computer.
.DESCRIPTION

.PARAMETER InstallerPath
    The absolute path to the Teams installer msi file. If not provided, the script will attempt to find it in the public folder. If it is not found there, it will attempt to download it from Microsoft's servers. If it is not found there, it will prompt the user for the absolute path.
.PARAMETER Target
    The name of the target computer. If not provided, the script will prompt the user for it.
.EXAMPLE
    Install-Teams -InstallerPath "C:\Users\Public\Teams_windows_x64.msi" -Target "computername"
    Installs Teams on the computer named "computername" using the Teams installer msi file located at "C:\Users\Public\Teams_windows_x64.msi".

#>
Function Install-Teams {
    param(
        [String]$InstallerPath,
        [String]$Target
    )
    # Checking if the InstallerPath was provided, downloading file if not -----------------
    if (!($PSBoundParameters.ContainsKey('InstallerPath')) -or ($InstallerPath -eq "")) {
        # if installer path isn't provided, check the public folder
        $InstallerPath = "C:\Users\Public\Teams_windows_x64.msi"
        if (Test-Path -Path "$env:Public\Teams_windows_x64.msi") {
            $InstallerPath = "$env:Public\Teams_windows_x64.msi"
        }
        elseif (Test-Path -Path "$env:Public\Downloads\Teams_windows_x64.msi") {
            $InstallerPath = "$env:Public\Downloads\Teams_windows_x64.msi"
        }
        else {
            Write-Host "Teams installer not found in public folder. Attempting download."
            Invoke-WebRequest -Uri "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true" -OutFile "$env:Public\Downloads\Teams_windows_x64.msi"
            if (Test-Path -Path "$env:Public\Downloads\Teams_windows_x64.msi") {
                $InstallerPath = "$env:Public\Downloads\Teams_windows_x64.msi"
            }
            else {
                Write-Host "Unable to find or download the Teams installer msi file. Please provider absolute path."
                $InstallerPath = Read-Host "Enter absolute path to Teams installer: "
            }
        }
    }
    # test whatever the path ended up being
    if (!(Test-Path -Path $InstallerPath)) {
        Write-Host "Unable to find Teams installer at $InstallerPath." -ForegroundColor Red
        return
    }
    # ------------------------------------------------------------------------------------

    # Checking if the Target was provided, prompting if not -----------------------------
    if (!($PSBoundParameters.ContainsKey('Target'))) {
        $Target = Read-Host "Enter target: "
    }



    # ------------------------------------------------------------------------------------

    # Actually installing the file -------------------------------------------------------
    # copy to target
    Copy-Item -Path $InstallerPath -Destination "\\$Target\c$\users\public\Teams_windows_x64.msi"
    $EndResult = Invoke-Command -ComputerName $Target -ScriptBlock {
        $result = (Start-Process "msiexec" -ArgumentList "/i $env:Public\Teams_windows_x64.msi ALLUSERS=1 /qn" -Wait -Passthru).ExitCode
        $result
    }

    if ($EndResult -eq 0) {
        Write-Host "Successful installation!" -ForegroundColor Green
    }
    else {
        Write-Host "Possibly unsuccessful installation..." -ForegroundColor Yellow
        Write-Host "Exit code: $EndResult" -ForegroundColor Yellow
    }
    # ------------------------------------------------------------------------------------
}