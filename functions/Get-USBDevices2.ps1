# get list of usb devices connected to target computer
Function Get-USBDevices2 {
    param (
        [Parameter(ValueFromPipeline = $true)]
        # eventually, it'd be nice to run this on list of pcs
        [string[]]$ComputerName = $env:COMPUTERNAME
        # [string]$NameRegex = ''
    )

    if (!($PSBoundParameters.ContainsKey('ComputerName'))) {
        while ($null -eq $ComputerName) {
            $ComputerName = Read-Host "Please enter the target computer name"
        }
    }
    $search_string = $null

    while ($null -eq $search_string) {
        $search_string = Read-Host "Enter string to search for in USB device names, or press enter for all usb names"
    }


    Write-Host "Searching target computer..."
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # format in same html as software scan script - could use that for group usb scan too
        if ($search_string -eq '') {
            $usblist = Get-PnpDevice -PresentOnly | Select FriendlyName, Class, Status
        }
        else {
            $usblist = Get-PnpDevice -PresentOnly | Where-Object { $_.FriendlyName -match $search_string } | Select FriendlyName, Class, Status
        }
    }


    
}