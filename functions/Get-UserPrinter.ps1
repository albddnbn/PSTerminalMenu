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
    Writes the username of user on the ComputerName computer, to the terminal. Also lists printers they are connected to.

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
    try {
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
    }
    catch {
        <#Do this if a terminating exception happens#>
        Write-Host "Sorry, something went wrong. It's possible that the computer is offline, or no one is logged in right now."
    }
}