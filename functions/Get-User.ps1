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