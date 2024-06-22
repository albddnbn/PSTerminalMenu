# *************** Functions, One-Liners, etc.   ************************************
function Get-User {
    <#
    .SYNOPSIS
    Writes the username of user on the ComputerName computer, to the terminal.

    .DESCRIPTION
    May also be able to use a hostname file eventually.

    .PARAMETER ComputerName
    The ComputerName computer to look for a user on.

    .EXAMPLE
    Get-User
    - OR - 
    Get-User -ComputerName "computername"

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true,
            ParameterSetName = "ComputerName")]
        [string]$ComputerName
    )
    # if ComputerName argument wasn't supplied in function call - ask script runner to type in a computer name or a txt file path ending in .txt
    if (!($PSBoundParameters.ContainsKey('ComputerName'))) {
        $ComputerName = Read-Host "Enter computer name :"
    }

    # actual command to get user logged into ComputerName PC
    $result = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Username


    # if result is null, no one's logged in rn
    if ($null -eq $result) {
        $result = "No one."
    }
    Write-Host "Current user on " -NoNewline
    Write-Host "$ComputerName : " -ForegroundColor White
    switch ($result) {
        "No one." {
            Write-Host "$result" -ForegroundColor Red
        }
        default {
            Write-Host "$result" -ForegroundColor Green
        }
    }
}

function Get-AssetInfo {
    <#
    .SYNOPSIS
    Gets asset tag and serial number of ComputerName device.

    .DESCRIPTION
    May also be able to use a hostname file eventually.

    .PARAMETER ComputerName
    The ComputerName computer to look for a user on.

    .EXAMPLE
    Get-AssetInfo
    - OR - 
    Get-AssetInfo -ComputerName "computername"

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]

    param (
        [Parameter(Position = 0, Mandatory = $true,
            ParameterSetName = "ComputerName")]
        [string]$ComputerName
    )
    # if ComputerName is null, then the function wasn't called using any parameters (i.e. it's being called by GUI, so grab text in textbox for $ComputerName value):
    if (!($PSBoundParameters.ContainsKey('ComputerName'))) {
        # $ComputerName isn't bound, so use textbox input to assign value
        $ComputerName = Read-Host "Please enter ComputerName: "
    }

    # command to get Asset #
    $assettag = (Get-CimInstance -ComputerName $ComputerName -Class Win32_SystemEnclosure | Select-Object SMBiosAssetTag).SMBiosAssetTag
    $serial = (Get-CimInstance -Class win32_bios).SerialNumber

    Write-Host "Asset info for $ComputerName :"
    Write-Host "---------------------------------"
    Write-Host "Asset tag: " -NoNewLine
    Write-Host $assettag -ForegroundColor Cyan
    Write-Host "SN: " -NoNewLine 
    Write-Host $serial -ForegroundColor Green
}

# NOT written by Alex B., from: https://stackoverflow.com/questions/34813529/get-list-of-installed-software-of-remote-computer
function Get-InstalledApps {
    <#
    .SYNOPSIS
    Gets a list of installed software on ComputerName device.

    .DESCRIPTION
    May also be able to use a hostname file eventually.

    .PARAMETER ComputerName
    ComputerName / remote device hostname if supplied, if not supplied then it will use the local computer.

    .PARAMETER NameRegex
    A regular expression to filter the results by the name of the application.

    .EXAMPLE
    Get-InstalledApps
    - OR - 
    Get-InstalledApps -ComputerName "computername"

    .NOTES
    Additional notes about the function.
    #>
    param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        [string]$NameRegex = ''
    )
    # ask user for output filename
    $outputfile = Read-Host "Enter output filename (no extension): "
    # add .html and print it back to user
    $outputfile += ".html"

    $rows = @()
    foreach ($comp in $ComputerName) {
        $template = @"
<style>
    body {
        font-family: 'Roboto', Arial, sans-serif;
    }
    
    h1 {
        background-color: #00267f;
        color: white;
        font-size: 16px;
        padding-left: 10px;
        padding-right: 10px;
        padding-top: 6px;
        padding-bottom: 6px;
    }
    
    table {
        width: 100%;
        border-collapse: collapse;
    }
    
    th, td {
        padding: 8px;
        text-align: left;
    }
    
    tr:nth-child(odd) {
        background-color: #A49EFF;
        color: white;
    }
    
    tr:nth-child(even) {
        background-color: #303C9A;
        color: white;
    }
</style>
<h1>Software Audit - <span style="font-size: 16px;"><b>$($comp)</b></span></h1>
<table>
    <tr>
        <th>Software</th>
        <th>Version</th>
        <th>Publisher</th>
        <th>Install Date</th>
    </tr>
"@
        # add title row for Computer
        # $rows += "<tr><td colspan='3' style='background-color: #00194c; color: white;'><strong>$comp</strong></td></tr>"
        $keys = '', '\Wow6432Node'
        foreach ($key in $keys) {
            try {
                $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $comp)
                $apps = $reg.OpenSubKey("SOFTWARE$key\Microsoft\Windows\CurrentVersion\Uninstall").GetSubKeyNames()
            }
            catch {
                continue
            }

            foreach ($app in $apps) {
                $program = $reg.OpenSubKey("SOFTWARE$key\Microsoft\Windows\CurrentVersion\Uninstall\$app")
                $name = $program.GetValue('DisplayName')
                if ($name -and $name -match $NameRegex) {
                    $item = [pscustomobject]@{
                        ComputerName    = $comp
                        DisplayName     = $name
                        DisplayVersion  = $program.GetValue('DisplayVersion')
                        Publisher       = $program.GetValue('Publisher')
                        InstallDate     = $program.GetValue('InstallDate')
                        UninstallString = $program.GetValue('UninstallString')
                        Bits            = $(if ($key -eq '\Wow6432Node') { '64' } else { '32' })
                        Path            = $program.name
                    }
                    $rows += "<tr><td>$($item.DisplayName)</td><td>$($item.DisplayVersion)</td><td>$($item.Publisher)</td><td>$($item.InstallDate)</td></tr>"

                }
            }
        }
    }
    # $htmlContent = $template -replace $output, ($rows -join '')
    $htmlContent = $template + ($rows -join '') + "</table>"
    # $htmlContent = $template -replace '$output', ($rows -join '')
    # output to file:
    $htmlContent | Out-File -FilePath $outputfile
    Write-Host "Output file: $outputfile"
}

function Get-USBdevs {
    <#
    .SYNOPSIS
    Gets a list of USB devices connected to ComputerName device.

    .DESCRIPTION
    May also be able to use a hostname file eventually.

    .PARAMETER ComputerName
    The ComputerName computer to look for a user on.

    .EXAMPLE
    Get-USBDevs
    - OR - 
    Get-USBDevs -ComputerName "computername"

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    param(
        [String]$ComputerName
    )
    # if ComputerName is null, then the function wasn't called using any parameters (i.e. it's being called by GUI, so grab text in textbox for $ComputerName value):
    if (!($PSBoundParameters.ContainsKey('ComputerName'))) {
        # $ComputerName isn't bound, so use textbox input to assign value
        $ComputerName = Read-Host "Please enter ComputerName PC: "
    }

    # start new CIM session (helps to avoid having to use invoke-command cmdlet to do remote command, invoke-command kept freezing up the GUI)
    $session = New-CimSession -ComputerName $ComputerName

    $usblist = Get-PnpDevice -PresentOnly -CIMSession $session | Where-Object { $_.InstanceId -match '^USB' } | Select FriendlyName, Class, Status

    # https://stackoverflow.com/questions/38991984/create-table-using-html-in-powershell
    $head = '<style>
        body {
            background-color: white;
            font-family:      "Calibri";
        }

        table {
            border-width:     1px;
            border-style:     solid;
            border-color:     black;
            border-collapse:  collapse;
            width:            100%;
        }

        th {
            border-width:     1px;
            padding:          5px;
            border-style:     solid;
            border-color:     black;
            background-color: #98C6F3;
        }

        td {
            border-width:     1px;
            padding:          5px;
            border-style:     solid;
            border-color:     black;
            background-color: White;
        }

        tr {
            text-align:       left;
        }
    </style>'
    $usblist | ConvertTo-Html -Head $head -Title "USB Devices on: $ComputerName" | Out-File -FilePath "USBDevices_$ComputerName.html"
    Write-Host "USB devices on $ComputerName :`r`n"
    Write-Host "-----------------------------------------------------------------------------------`r`n"
    # foreach ($usb in $usblist) {
    #     Write-Host "$($usb) `r`n"
    # }
    $usblist | Format-Table -AutoSize
}

# ----------------------------------------------------------------------------------------------------------------
# ------- Functions that use DISM -------
function Get-Npad {
    <#
    .SYNOPSIS
    Disables the local Windows Update server and attempts to install Notepad from Microsoft's servers.

    .DESCRIPTION
    May also be able to supply ComputerName computer or hostname file eventually.

    .EXAMPLE
    Get-Npad
    - OR - 
    # Test the below command
    Invoke-Command -ComputerName <HostName> -ScriptBlock ${function:Get-Npad}

    .NOTES
    Additional notes about the function.
    #>
    Echo 'Setting UseWUServer Registry to 0...'
    Set-Itemproperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'UseWUServer' -value '0'
    Echo 'Restarting Windows Update Service...'
    Restart-Service -Name 'wuauserv'
    Echo 'Installing Notepad...'
    DISM /online /Add-Capability /CapabilityName:Microsoft.Windows.Notepad~~~~0.0.1.0
    Echo 'Setting UseWUServer Registry back to 1...'
    Set-Itemproperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'UseWUServer' -value '1'
    Echo 'Restarting Windows Update Service...'
    Restart-Service -Name 'wuauserv'
    Stop-Process -Name explorer -Force
    Start-Process explorer
}

# Install RSAT (Windows Remote Server Admin Tool)
function Get-RSAT {
    <#
    .SYNOPSIS
    Disables the local Windows Update server and attempts to install RSAT from Microsoft's servers.

    .DESCRIPTION
    May also be able to supply ComputerName computer or hostname file eventually.

    .EXAMPLE
    Get-RSAT
    - OR - 
    # Test the below command
    Invoke-Command -ComputerName <HostName> -ScriptBlock ${function:Get-RSAT}

    .NOTES
    Additional notes about the function.
    #>
    Write-Host "Shutting down Windows Update Service"
    # change windows update service registry key value:
    Set-Itemproperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'UseWUServer' -value '0'
    # restart windows update
    Restart-Service -Name 'wuauserv'
    Write-Host "Attempting to add RSAT capability"
    # use DISM to add RSAT capability
    dism.exe /online /add-capability /capabilityname:Rsat.activedirectory.DS-LDS.Tools~~~~0.0.1.0 /Capabilityname:Rsat.GroupPolicy.Management.tools~~~~0.0.1.0 /capabilityname:rsat.wsus.tools~~~~0.0.1.0
    # set windows update registry key value back to how it was:
    Set-Itemproperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'UseWUServer' -value '1'
    # restart service:
    Restart-Service -Name 'wuauserv'
    Stop-Process -Name explorer -Force
    Start-Process explorer
}

# Clipboard history and WIN+SHIFT+S shortcut
function Get-WinkeyBack {
    <#
    .SYNOPSIS
    Disables the local Windows Update server and attempts to restore the use of the WIN+SHIFT+S screenshot shortcut and Snipping Tool from Microsoft's servers.

    .DESCRIPTION
    May also be able to supply ComputerName computer or hostname file eventually.

    .EXAMPLE
    Get-WinKeyBack
    - OR - 
    # Test the below command
    Invoke-Command -ComputerName <HostName> -ScriptBlock ${function:Get-WinKeyBack}

    .NOTES
    Additional notes about the function.
    #>
    # change windows update service registry key value
    Set-Itemproperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'UseWUServer' -value '0'
    # restart service
    Restart-Service -Name 'wuauserv'
    # use dism to add functionality back
    DISM /Online /Add-Capability /CapabilityName:Windows.Client.ShellComponents~~~~0.0.1.0
    Set-Itemproperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'UseWUServer' -value '1'
    
    Restart-Service -Name 'wuauserv'
    Stop-Process -Name explorer -Force
    Start-Process explorer
}

# Install Powershell ISE
function Get-PowershellISE {
    <#
    .SYNOPSIS
    Disables the local Windows Update server and attempts to install Powershell Integrated Scripting Environment from Microsoft's servers.

    .DESCRIPTION
    May also be able to supply ComputerName computer or hostname file eventually.

    .EXAMPLE
    Get-PowershellISE
    - OR - 
    # Test the below command
    Invoke-Command -ComputerName <HostName> -ScriptBlock ${function:Get-PowershellISE}

    .NOTES
    Additional notes about the function.
    #>
    # change windows update service registry key value
    Set-Itemproperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'UseWUServer' -value '0'
    # restart service
    Restart-Service -Name 'wuauserv'
    # use dism to add powershell ise capability
    dism /online /add-capability /capabilityname:microsoft.windows.powershell.ise~~~~0.0.1.0
    # turn windows update service registry key value back to normal
    Set-Itemproperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'UseWUServer' -value '1'
    Restart-Service -Name 'wuauserv'

    # I've noticed that with installations using DISM, restarting explorer.exe somtimes helpes in lieu of a full reboot to make the changes effective
    Stop-Process -Name explorer -Force
    Start-Process explorer
}

Function remote_registry_query($ComputerName, $key) {
    Try {
        $registry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("Users", $ComputerName)
        ForEach ($sub in $registry.OpenSubKey($key).GetSubKeyNames()) {
            #This is really the list of printers
            write-output $sub
        }

    }
    Catch [System.Security.SecurityException] {
        "Registry - access denied $($key)"
    }
    Catch {
        $_.Exception.Message
    }
}

function Get-UserPrinter {
    <#
    .SYNOPSIS
    Writes the username of user on the ComputerName computer, to the terminal.

    .DESCRIPTION
    May also be able to use a hostname file eventually.

    .PARAMETER ComputerName
    The ComputerName computer to look for a user on.

    .EXAMPLE
    Get-User
    - OR - 
    Get-User -ComputerName "computername"

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    param(
        [String]$ComputerName
    )
    # if ComputerName is null, then the function wasn't called using any parameters (i.e. it's being called by GUI, so grab text in textbox for $ComputerName value):
    if (!($PSBoundParameters.ContainsKey('ComputerName'))) {
        # $ComputerName isn't bound, so use textbox input to assign value
        $ComputerName = Read-Host "Please enter ComputerName PC: "
    }

    $computer = $ComputerName
    # if ($computer -eq "") {
    # 	$computer = Read-Host "Please enter computer name: "
    # }

    # get the logged-in user of the specified computer
    # $user = Get-WmiObject –ComputerName $computer –Class Win32_ComputerSystem | Select-Object UserName
    $user = Get-CimInstance -ComputerName $computer -ClassName Win32_ComputerSystem | Select-Object UserName
    $UserName = $user.UserName
    write-output " "
    write-output " "
    write-output "Logged-in user is $UserName`r`n"
    write-output "Printers are:`r`n"

    # get that user's AD object
    $AdObj = New-Object System.Security.Principal.NTAccount($user.UserName)

    # get the SID for the user's AD Object 
    $strSID = $AdObj.Translate([System.Security.Principal.SecurityIdentifier])

    #remote_registry_query -ComputerName $computer -key $root_key
    $root_key = "$strSID\\Printers\\Connections"
    remote_registry_query -ComputerName $computer -key $root_key

    # get a handle to the "USERS" hive on the computer
    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("Users", $Computer)
    $regKey = $reg.OpenSubKey("$strSID\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Windows")

    # read and show the new value from the Registry for verification
    $regValue = $regKey.GetValue("Device")
    write-output " "
    write-output " "
    write-output "Default printer is $regValue"
    write-output " "
    write-output " "
    [void](Read-Host 'Press Enter to continue…')
}
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
function Install-LoggerPro {
    <#
    .SYNOPSIS
	Installs latest version of Vernier Logger Pro 3 at the time of writing (v3.16.2) on remote or local computer.

    .DESCRIPTION
	Plans to update to do the installation on group of computers.

    .PARAMETER ComputerName
    The ComputerName computer to look for a user on.

    .EXAMPLE
    Install-LoggerPro
    - OR - 
    Install-LoggerPro -ComputerName hosts.txt

    .NOTES
    Additional notes about the function.
    #>
    param (
        [Parameter(Position = 0,
            ParameterSetName = "ComputerName", ValueFromPipeline = $true)]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )
    # set to SilentlyContinue (write status messages to log file) or Continue (print status messages to console and write to log file)
    $VerbosePreference = "Continue"
    # dot source function definitions
    . .\function_definitions.ps1
    # VARIABLE DECLARATIONS:
    # if computername is a file, get-content, if its a hostname, do nothing
    if (Test-Path $ComputerName) {
        $ComputerNames = Get-Content $ComputerName
    }
    else {
        $ComputerNames = $ComputerName
    }
    # get list of online ComputerNames
    foreach ($ComputerName in $ComputerNames) {
        # $testconnect = Test-Connection $ComputerName
        if (test-connection $ComputerName) {
            $online += $ComputerName
        }
        else {
            Write-host "$ComputerName unresponsive" -foregroundcolor yellow
        }

    }
    # test for the source files on the local computer
    if (!(Test-Path "C:\Users\Public\Vernier Logger Pro v3.16.2")) {
        # download the installer if it doesn't exist
        Write-Host "Missing Vernier Logger Pro installation folder. Attempting to download from server..." -ForegroundColor Yellow
        # download the installer

        # NEED TO MAKE CONNECTION TO S DRIVE OR MDT SERVER HERE, but doing it later...for now - exit
        exit
    }
    foreach ($onlinepc in $online) {
        # make sure logger pro installer is in public folder, if not - download it

        # copy logger pro installer directory to ComputerName computer
        copy-item "C:\Users\Public\Vernier Logger Pro v3.16.2" -destination \\$onlinepc\c$\users\public -Recurse
        # save displayversion of LoggerPro3.msi to variable
        # $LoggerProLatestVersion = (Get-ItemProperty -Path C:\Users\Public\LoggerPro3.msi).DisplayVersion
        # install logger pro
        $Result = (Start-Process msiexec.exe -ArgumentList "/i C:\Users\Public\LoggerPro3.msi /qn /L*v C:\Users\Public\LoggerPro3_msilog.txt" -Wait -Passthru).ExitCode
        # check if install was successful
        if ($Result -eq 0) {
            Write-Log -Path $LogPath -Message "Logger Pro installed successfully on $onlinepc" -Level Info
            Write-Verbose "Logger Pro installed successfully on $onlinepc"
        }
        else {
            Write-Log -Path $LogPath -Message "Logger Pro failed to install on $onlinepc" -Level Error
            Write-Verbose "Logger Pro failed to install on $onlinepc"
        }
        # remove logger pro installer from ComputerName computer
        Remove-Item -Path "\\$onlinepc\c$\users\public\Vernier Logger Pro v3.16.2" -Force -Recurse
    }
    # 	$LogPath = (Join-Path -Path "$env:SystemDrive\Maint" -ChildPath "loggerpro3-install.txt")
    # 	$Source = ".\installer.bat"
    # 	$timestamp = Get-Date -Format "MM/dd/yyyy HH:mm"
    # 	# Continue = messages printed to terminal, SilentlyContinue = not printed
    # 	$VerbosePreference = "Continue"

    # 	# start the installation
    # 	Write-Log -Path $LogPath -Message ("### BEGIN INSTALLER FOR $((Get-Item -Path '.\').BaseName) ###").ToUpper() -Level Info
    # 	Write-Verbose "$((Get-Item -Path '.\').BaseName) installation started $timestamp"

    # 	# line to run msi file and save exit code to result variable
    # 	$Result = (Start-Process .\installer.bat -Wait -Passthru).ExitCode

    # 	# there's also this line to install logger pro software including DataShare install:
    # 	# msiexec /i "Logger Pro 3.msi" INSTALLDATASHARE="INSTALL" /qn /L*v %TEMP%\LoggerPro3_msilog.txt

    # 	# write result to console if preference set that way
    # 	if ($Result -eq 0) {
    # 		Write-Log -Path $LogPath -Message ("### INSTALLATION COMPLETED SUCCESSFULLY, EXIT CODE: $Result ###").ToUpper() -Level Info
    # 		Write-Verbose "$((Get-Item -Path '.\').BaseName) successfully installed!"
    # 		Write-Verbose "$((Get-Item -Path '.\').BaseName) exit code: $Result `n"
    # 	}
    #  else {
    # 		Write-Log -Path $LogPath -Message ("### INSTALLATION probably FAILED, EXIT CODE: $Result ###").ToUpper() -Level Info
    # 		Write-Verbose "$((Get-Item -Path '.\').BaseName) install NOT successful"
    # 		Write-Verbose "$((Get-Item -Path '.\').BaseName) exit code: $Result `n"
    # 	}
}
# ----------- end of get users connected printers functions ----------------
function Ping-List {
    <#
    .SYNOPSIS
    Writes the username of user on the ComputerName computer, to the terminal.

    .DESCRIPTION
    May also be able to use a hostname file eventually.

    .PARAMETER ComputerName
    The ComputerName computer to look for a user on.

    .EXAMPLE
    Get-User
    - OR - 
    Get-User -ComputerName "computername"

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    param(
        [String]$ComputerName
    )
    if (!($PSBoundParameters.ContainsKey('ComputerName'))) {
        # get host or host file from user
        $hosts = Read-Host "Enter ComputerName or ComputerName (hosts txt file) path"
        if (Test-Path -Path $hosts) {
            $ComputerName = Get-Content $hosts
        }
        else {
            $ComputerName = $hosts
        }
    }
    else {
        if (Test-Path -Path $ComputerName) {
            $ComputerName = Get-Content $ComputerName
        }
    }
    $complist = $ComputerName

    foreach ($comp in $complist) {
        if (Test-Connection -ComputerName $comp -Quiet -ErrorAction SilentlyContinue) {
            Write-Host "$comp is online" -ForegroundColor Green
        }
        else {
            Write-Host "$comp is unreachable" -ForegroundColor Red
        }
    }
}
function Ping-ListReturn {
    <#
    .SYNOPSIS
    Writes the username of user on the ComputerName computer, to the terminal.

    .DESCRIPTION
    May also be able to use a hostname file eventually.

    .PARAMETER ComputerName
    The ComputerName computer to look for a user on.

    .EXAMPLE
    Get-User
    - OR - 
    Get-User -ComputerName "computername"

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    param(
        [String]$ComputerName
    )
    if (!($PSBoundParameters.ContainsKey('ComputerName'))) {
        # get host or host file from user
        $hosts = Read-Host "Enter ComputerName or ComputerName (hosts txt file) path"
        if (Test-Path -Path $hosts) {
            $ComputerName = Get-Content $hosts
        }
        else {
            $ComputerName = $hosts
        }
    }
    else {
        if (Test-Path -Path $ComputerName) {
            $ComputerName = Get-Content $ComputerName
        }
    }
    $complist = $ComputerName
    $online = @()
    $offline = @()
    foreach ($comp in $complist) {
        if (Test-Connection -ComputerName $comp -Quiet -ErrorAction SilentlyContinue) {
            Write-Host "$comp is online" -ForegroundColor Green
            $online += $comp
        }
        else {
            Write-Host "$comp is unreachable" -ForegroundColor Red
            $offline += $comp
        }
    }
    return $online, $offline
}
function Start-Updates {
    <#
    .SYNOPSIS
    Attempts to start available Microsoft/Windows updates on a single or group of remote PCs.

    .DESCRIPTION
    You can also use a hostname txt file for this function.

    .PARAMETER ComputerName
    The ComputerName computer or hostname txt file to start the updates on.

    .EXAMPLE
    Start-Updates
    - OR - 
    Start-Updates -ComputerName "computername"

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )
    if (Test-Path $ComputerName) {
        $ComputerNames = Get-Content $ComputerName
    }
    else {
        $ComputerNames = $ComputerName
    }

    # Install the PSWindowsUpdate module
    if (!(Get-Module -Name PSWindowsUpdate)) {
        Write-Host "Installing PSWindowsUpdate module..." -ForegroundColor Yellow
        Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
    }
    # Import the PSWindowsUpdate module
    Import-Module -Name PSWindowsUpdate -Force

    # run updates
    Invoke-WUJob -ComputerName $ComputerNames -Script {
        ipmo PSWindowsUpdate;
        Install-WindowsUpdate -AcceptAll -AutoReboot -MicrosoftUpdate | Out-File "$env:SystemDrive\Windows\PSWindowsUpdate.log"
    } -RunNow -Confirm:$false -Verbose -ErrorAction Ignore
    

}

function Import-CopyAsPath {
    <#
    .SYNOPSIS
    Imports a reg file into user's registry, so that 'Copy as Path' is available in the right-click context menu when right-clicking folder/file.

    .DESCRIPTION
    Detailed description

    .EXAMPLE
    Import-CopyAsPath

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    # ask user if they want to import the copy as path reg file
    $copyaspath = Read-Host "Do you want to import the copy as path reg file? (y/n)"
    if ($copyaspath -eq "y") {
        # import the copy as path reg file
        reg import ./add-copy-as-path.reg
        # restart explorer.exe
        Stop-Process -Name explorer -Force
        Start-Process explorer
    }

}

function Restore-NewTextDoc {
    <#
    .SYNOPSIS
    Restores the new text document context menu item in Windows 10.

    .DESCRIPTION
    Detailed description

    .EXAMPLE
    Restore-NewTextDoc

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    # ask user if they want to restore the new text document context menu item
    $newtextdoc = Read-Host "Do you want to restore the new text document context menu item? (y/n)"
    if ($newtextdoc -eq "y") {
        # restore the new text document context menu item
        reg import ./restore-new-text-doc.reg
        # restart explorer.exe
        Stop-Process -Name explorer -Force
        Start-Process explorer
    }
}

function Remove-NewRichText {
    <#
    .SYNOPSIS
    Removes the 'Create New Rich Text Document' from the Windows right-click context menu by editing the registry.

    .DESCRIPTION
    Detailed description

    .EXAMPLE
    Remove-NewRichText

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    # ask user if they want to remove the new rich text document context menu item
    $newrichtext = Read-Host "Do you want to remove the new rich text document context menu item? (y/n)"
    if ($newrichtext -eq "y") {
        # remove the new rich text document context menu item
        reg import ./remove-new-richtext-doc.reg
        # restart explorer.exe
        Stop-Process -Name explorer -Force
        Start-Process explorer
    }
}

# can this function take a hostlist txt file as ComputerName in addition to single hostname?
function Get-ConnectedMonitors {
    <#
    .SYNOPSIS
    Gets information about monitors connected to local/remote PC including manufacturer, serial number, model, and whether they're currently active.

    .DESCRIPTION
    Detailed description

    .EXAMPLE
    Get-ConnectedMonitors

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    param(
        [String]$ComputerName
    )
    if (!($PSBoundParameters.ContainsKey('ComputerName'))) {
        # get host or host file from user
        $hosts = Read-Host "Enter ComputerName or ComputerName (hosts txt file) path"
        if (Test-Path -Path $hosts) {
            $ComputerName = Get-Content $hosts
        }
        else {
            $ComputerName = $hosts
        }
    }
    else {
        if (Test-Path -Path $ComputerName) {
            $ComputerName = Get-Content $ComputerName
        }
    }
    # get the connected monitors and their resolution
    $monitors = Get-CimInstance WmiMonitorId -Namespace root\wmi -ComputerName $ComputerName | Select Active, ManufacturerName, UserFriendlyName, SerialNumberID, YearOfManufacture
    # decode the monitor names, serial numbers, manufactrer names
    $monitors | ForEach-Object {
        $_.UserFriendlyName = [System.Text.Encoding]::ASCII.GetString($_.UserFriendlyName)
        $_.SerialNumberID = [System.Text.Encoding]::ASCII.GetString($_.SerialNumberID -notmatch 0)
        $_.ManufacturerName = [System.Text.Encoding]::ASCII.GetString($_.ManufacturerName)
    }

    # would be nice to output to html or give option to output to html
    foreach ($monitor in $monitors) {
        Write-Host "Active: $($monitor.Active)"
        Write-Host "Manufacturer: $($monitor.ManufacturerName)"
        Write-Host "Model: $($monitor.UserFriendlyName)"
        Write-Host "Serial Number: $($monitor.SerialNumberID)"
        Write-Host "Year of Manufacture: $($monitor.YearOfManufacture)"
        Write-Host ""
    }
}