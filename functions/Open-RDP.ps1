function Open-RDP {
    <#
    .SYNOPSIS
        Basic function to open RDP window with target computer and _admin username inserted.

    .PARAMETER SingleTargetComputer
        Single hostname of target computer - script will open RDP window with _admin username and target computer hostname already inserted.

    .NOTES
        Function is just meant to save a few seconds.
    #>
    param(
        $SingleTargetComputer
    )
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Opening RDP session to " -Nonewline
    Write-Host "$SingleTargetComputer" -ForegroundColor Green
    mstsc /v:$($singletargetcomputer):3389
}