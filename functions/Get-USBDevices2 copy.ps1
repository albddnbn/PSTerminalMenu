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


    ForEach ($pc in $ComputerName) {
        $template = @"
<style>
    body {
        font-family: 'Roboto', Arial, sans-serif;
    }
    
    h1 {
        background-image: linear-gradient(to bottom, #1a59ed, #00267f);
        color: white;
        font-size: 16px;
        padding-left: 10px;
        padding-right: 10px;
        padding-top: 6px;
        padding-bottom: 6px;
        line-height: 1.5;
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
        background-color:#c1d4ff;
        color: black;
    }
    
    tr:nth-child(even) {
        background-color: #a4b3f2;
        color: black;
    }
</style>
<h1>USB Devices on <span style="font-size: 16px;"><b>$($pc)</b></span></h1>
<table>
    <tr>
        <th>Name</th>
        <th>Class</th>
        <th>Status</th>
    </tr>
"@

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