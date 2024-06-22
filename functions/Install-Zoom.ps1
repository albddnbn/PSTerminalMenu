function Install-Zoom {
    <#
    .SYNOPSIS
	Uses a list of ComputerName computer names to install or update Zoom on that group of computers.

    .DESCRIPTION
	Copies the latest Zoom installer .msi over from the local computer to the ComputerName computer(s) and installs or updates Zoom on the ComputerName computer(s).

    .PARAMETER ComputerName
    The ComputerName computer to look for a user on.

    .EXAMPLE
    Update-ZoomGroup -ComputerName "computername"
    - OR - 
    Update-ZoomGroup -ComputerName hosts.txt

    .NOTES
	This script should not need much intervention - it will download the .msi if necessary, try to limit the number of times it grabs the Zoom installer from the web, and it will check that the install was successful and remove the Zoom installer from the remote PC at the end of the script.
	#>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true,
            ParameterSetName = "ComputerName")]
        [string]$ComputerName
    )

    # if computername is a file, get-content, if its a hostname, do nothing
    if (Test-Path $ComputerName) {
        $ComputerNames = Get-Content $ComputerName
    }
    else {
        $ComputerNames = $ComputerName
    }
    # $ComputerNames = Get-Content ComputerNames.txt
    $productNames = @("*zoom*")
    $UninstallKeys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
    # $ErrorActionPreference = "SilentlyContinue"
    # make sure zoom installer is in public folder, if not - download it
    if (!(Test-Path C:\Users\Public\ZoomInstallerFull.msi)) {
        Invoke-WebRequest -Uri "https://zoom.us/client/latest/ZoomInstallerFull.msi?archType=x64" -OutFile "C:\Users\Public\ZoomInstallerFull.msi"
    }
    $ZoomLatestVersion = (Get-ItemProperty -Path C:\Users\Public\ZoomInstallerFull.msi).DisplayVersion
    write-host "Latest Zoom version is $ZoomLatestVersion" -ForegroundColor Green
    $online = @()
    foreach ($ComputerName in $ComputerNames) {
        # $testconnect = Test-Connection $ComputerName
        if (test-connection $ComputerName) {
            $online += $ComputerName

            # copy it over to target computer

            if (Test-Path -Path \\$ComputerName\c$\users\public\ZoomInstallerFull.msi) {
                # CHECK VERSION OF ZOOM ON REMOTE PC
                $ZoomRemoteVersion = (Get-ItemProperty -Path \\$ComputerName\c$\users\public\ZoomInstallerFull.msi).DisplayVersion
                # write-host "Zoom version on $ComputerName is $ZoomRemoteVersion" -ForegroundColor Green
                if ($ZoomRemoteVersion -eq $ZoomLatestVersion) {
                    write-host "Zoom is up to date on $ComputerName" -ForegroundColor Green
                }
                else {
                    write-host "Zoom is out of date on $ComputerName" -ForegroundColor Yellow
                    copy-item C:\Users\Public\ZoomInstallerFull.msi -destination \\$ComputerName\c$\users\public
                    write-host "Copied Zoom msi installer to $ComputerName" -ForegroundColor Green
                }
            }
            copy-item C:\Users\Public\ZoomInstallerFull.msi -destination \\$ComputerName\c$\users\public
            write-host "Copied Zoom msi installer to $ComputerName" -ForegroundColor Green

            # save displayversion of Zoominstallerfull.msi to variable
        }
        else {
            Write-host "$ComputerName unresponsive" -foregroundcolor yellow
        }
    }
    # write-host $online

    Invoke-Command -Computername $online -Scriptblock {
        $results = foreach ($key in (Get-ChildItem $Using:UninstallKeys) ) {
            # CHECKS FOR ZOOM ON REMOTE PC / GETS NAME AND VERSION
            foreach ($product in $Using:productNames) {
                if ($key.GetValue("DisplayName") -like "$product") {
                    [pscustomobject]@{
                        DisplayName    = $key.GetValue("DisplayName");
                        Displayversion = $key.GetValue("DisplayVersion");
                    }
			
                }
            }
        }
        # if zoom isn't detected on remote PC, install it
        if ($null -eq $results) {
            # Zoom isn't installed at all on the PC
            write-host "Installing ZOOM on: $env:COMPUTERNAME" -foregroundcolor Green
            # Invoke-WebRequest -Uri "https://zoom.us/client/latest/ZoomInstallerFull.msi?archType=x64" -OutFile "C:\Users\Public\ZoomInstallerFull.msi"
            # run msi installer and save exit code to #$Result variable
            $result = (Start-Process MsiExec.exe -ArgumentList "/i C:\Users\Public\ZoomInstallerFull.msi ZoomAutoUpdate=true /qn /L*V $env:WINDIR\Temp\Zoom-Install.log" -wait -Passthru).ExitCode
            if ($result -eq 0) {
                Write-Host "Installed Zoom on $env:COMPUTERNAME (error code: $result)" -Foreground Green
            }
            else {
                Write-Host "CHECK - $env:COMPUTERNAME (error code: $result)" -Foreground Red
            }

        }
        else {
            # Zoom is installed, so compare it to the latest version and update if necessary
            # this is where $ZoomLatestVersion comes into play - test to make sure the latest version if on the remote PC
            if ($results.DisplayVersion -ne $ZoomLatestVersion) {
                write-host "INSTALLing ZOOM ON: $env:COMPUTERNAME" -ForegroundColor 
                Green
                # run msi installer and save exit code to #$Result variable
                $result = (Start-Process MsiExec.exe -ArgumentList "/i C:\Users\Public\ZoomInstallerFull.msi /qn /L*V $env:WINDIR\Temp\Zoom-Install.log" -wait -Passthru).ExitCode
                if ($result -eq 0) {
                    "Updated - $env:COMPUTERNAME - $result"
                }
                else {
                    # warn script runner to check the PC or manually install Zoom
                    "CHECK $env:COMPUTERNAME"
                }		
            }
        }

        # lastly, delete the ZoomInstallerFull.msi from the remote PC
        try {
            Remove-Item -Path C:\Users\Public\ZoomInstallerFull.msi -Force
            Write-Host "Removed ZoomInstallerFull.msi from remote Public directory" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to delete ZoomInstallerFull.msi from $env:COMPUTERNAME" -ForegroundColor Yellow
        }
    } 
}