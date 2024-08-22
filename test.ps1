Function Function-Name {
    <#
    .SYNOPSIS
    See SupportFiles/function_template.ps1 for a more detailed function template.

    .DESCRIPTION
    See SupportFiles/function_template.ps1 for a more detailed function template.

    .PARAMETER ComputerName
    DNS Hostname of remote computer. Ex: 's-a227-26'

    .EXAMPLE
    Function-Name -ComputerName "s-a227-26"

    .NOTES
    Additional notes about the function.
    #>
    param(
        $ComputerName
    )
    Write-Host "This is the function code"
}