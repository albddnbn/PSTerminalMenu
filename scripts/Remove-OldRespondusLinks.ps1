function remove-oldresponduslinks {
    param(
        $TargetComputer
    )

    $utils_directory = Get-ChildItem -Path "$env:PSMENU_DIR" -filter 'utils' -Directory -Erroraction SilentlyContinue
    if (-not $utils_directory) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find utils directory in $env:PSMENU_DIR, exiting." -foregroundcolor red
        exit
    }

    $util_functions = Get-ChildItem -Path "$($utils_directory.fullname)" -File
    $util_functions_list = [system.collections.arraylist]::new()
    foreach ($function in $util_functions) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Loading function $($function.fullname)..." -foregroundcolor green
        # . "$($function.fullname)"

        $obj = [pscustomobject]@{
            name = $function.basename
            path = $function.fullname
        }
        $util_functions_list.add($obj) | Out-Null
    }

    # return new targetcomputer value
    $TargetComputer = &$($util_functions_list | Where-Object { $_.name -eq 'Return-TargetComputer' } | Select-Object -ExpandProperty path) -TargetComputerInput $TargetComputer
    $TargetComputer = $TargetComputer | where-object { $_ -ne $null }
}