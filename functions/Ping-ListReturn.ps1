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