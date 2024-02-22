param(
    $TargetComputer
)
if (($targetcomputer -eq '') -or ($null -eq $targetcomputer)) {
    write-host "assigning localhost value to targetcomputer" -foregroundcolor magenta
    $targetcomputer = @('127.0.0.1')
    Write-host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Targetcomputer value determined to be $targetcomputer."
}
else {
    # Deal with TARGETCOMPUTER --------------------------
    $targetcomputer_typeobj = $targetcomputer.gettype()
    $targetcomputer_typename = $targetcomputer_typeobj | select -exp name
    # $targetcomputer_basetype = $targetcomputer_typeobj | select -exp basetype
    # if its a string
    try {
        $ADCheck = Get-ADComputer $targetcomputer
    }
    catch {
        Write-Host "Unable to get aD Computer."
    }
    if ($targetcomputer_typename -eq 'string') {
        if (Test-Path $targetcomputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Targetcomputer value determined to be a file of hostnames, getting content."
            $targetcomputer = Get-Content $targetcomputer
        }
        elseif ($ADCheck) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Targetcomputer value determined to be a single hostname, getting content."
            $targetcomputer = $Targetcomputer
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Searching AD for computers using the provided string: " -NoNewLine
            Write-Host "$targetcomputer..." -foregroundcolor Green
        
            $targetcomputer = $targetcomputer + "x"
            $targetcomputer = Get-ADComputer -Filter * | Where-Object { $_.DNSHostname -match "^$targetcomputer*" } | Select -Exp DNShostname
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found these matching computer names in AD: " -NoNewline
            $targetcomputer = $targetcomputer | Sort-Object

            # filter intermittent connectivity rooms that greatly slow down script speed:
            if ($env:FILTER_TARGETS) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Filtering targets because it was specified in the" -foregroundcolor yellow
                $targetcomputer = &".\Filter-IntermittentConnPCs.ps1" -ComputerList $targetcomputer
            }
        }
    }
}

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Hosts determined:" -Nonewline
Write-Host "$($targetcomputer -join ', ')" -foregroundcolor green

$results = Invoke-Command -ComputerName $TargetComputer -Scriptblock {
    $linknames = @("*SGE*", "*Guard*", "*Security*")
    $file_extensions = @('.lnk', '.url')

    $ShortCutList = [system.collections.arraylist]::new()

    ForEach ($linkname in $linknames) {
        ForEach ($fileext in $file_extensions) {
            $linkstring = "$linkname$fileext"
            $link = Get-ChildItem -Path "C:\Users\public\desktop" -Filter $linkstring -File -ErrorAction SilentlyContinue
            $linknameproperty = $link | select -exp name
            if (($linknameproperty -ne '') -and ($linknameproperty -notin $Shortcutlist)) {
                $ShortCutList.add($linknameproperty) | out-null
            }
        }
    }
    if ($ShortCutList.count -ge 1) {
        $obj = [pscustomobject]@{
            Shortcuts = $($Shortcutlist -join ', ')
        }
        $obj
    }

}

$results | export-csv "D:\SGE-link-scan-11-29-2023.csv" -notypeinformation
Start-Sleep -Seconds 5
Invoke-Item "D:\SGE-link-scan-11-29-2023.csv"