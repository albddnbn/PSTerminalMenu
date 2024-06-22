function Test-ForFile {
    <#
    .SYNOPSIS
    Writes the username of user on the ComputerName computer, to the terminal.

    .DESCRIPTION
    May also be able to use a hostname file eventually.

    .PARAMETER ComputerName
    The ComputerName computer or computer list file to test.

    .EXAMPLE
    Get-User
    - OR - 
    Get-User -ComputerName "computername"

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $ComputerName,
        [Parameter(Mandatory = $false)]
        $LocalPath
    )
    # if computername is a file, get-content it, if its an arraylist writehost
    if (Test-Path $ComputerName -PathType Leaf) {
        $ComputerName = Get-Content $ComputerName
        # Write-Host "ComputerName is a file, getting content"
    }
    # elseif ($ComputerName -is [System.Collections.ArrayList]) {
    #     Write-Host "ComputerName is an arraylist"
    # }

    # ask for localpath if it wasnt supplied
    if (!$LocalPath) {
        $LocalPath = Read-Host "Enter the local path to test"
    }
    # "$env:ProgramData\Autodesk\ACA 2024\enu"
    $Results = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # $folders = Get-ChildItem -Path $args[0]  | Where-Object { $_.Name -Like "Details*" } | Select -Exp FullName	
        # if ($folders) {
        #     ForEach ($filepath in $folders) {
        #         $file = Get-ChildItem -Path $filepath -Include "*AecDtlComponents*.mdb" -File -Recurse -ErrorAction SilentlyContinue
        #         if ($file.Exists) {
        #             $PathExists = $true
        #         }
        #     }
        # }
        # else {
        #     $PathExists = $false
        # }
        # return [PSCustomObject]@{
        #     ComputerName = $env:COMPUTERNAME
        #     PathExists   = $PathExists
        # }
        $result = Test-Path -Path $args[0] -ErrorAction SilentlyContinue
        return [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            PathExists   = $result
        }

    } -ArgumentList $LocalPath

    # create a html table / file from results
    $Date = Get-Date -Format "yyyyMMdd-HHmmss"
    $Results | ConvertTo-Html -Property ComputerName, PathExists | Out-File -FilePath ./Test-ForFile-$Date.html
}