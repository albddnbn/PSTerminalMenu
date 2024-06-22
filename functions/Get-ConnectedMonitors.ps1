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