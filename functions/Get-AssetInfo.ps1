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
    
    .EXAMPLE
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