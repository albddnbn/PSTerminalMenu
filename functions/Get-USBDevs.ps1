
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
    # header for html file
    #     $head = @"

    # <style>
    #     body
    #     {
    #         background-color: Gainsboro;
    #     }

    #     table, th, td{
    #         border: 1px solid;
    #     }

    #     h1{
    #         background-color:Tomato;
    #         color:white;
    #         text-align: center;
    #     }
    # </style>
    # "@

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
