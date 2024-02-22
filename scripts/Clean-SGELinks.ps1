param(
    $TargetComputer,
    [string]$DISABLE_to_disable_whatif
)
if ($DISABLE_to_disable_whatif.ToLower() -eq 'disabled') {
    $whatif_setting = $false
}

$REPORT_DIRECTORY = 'LoggedInUsers'
$thedate = Get-Date -Format 'yyyy-MM-dd'

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


# good links have Chrome in them
$results = Invoke-Command -ComputerName $TargetComputer -Scriptblock {
    # few rounds of cleanup
    $file_extensions = @('.lnk', '.url')

    ForEach ($FileExtension in $file_extensions) {
        # get all links with 'guard' and 'security' in them
        $GuardLinks = Get-ChildItem -Path "C:\Users\public\desktop" -Filter "*Guard*$($FileExtension)" -File -ErrorAction SilentlyContinue
        if ($GuardLinks) {
            Write-Host "Found $($FileExtension) links containing 'Guard' on  $env:COMPUTERNAME, removing..."
            Foreach ($single_shortcut in $guardlinks) {
                Write-Host "Removing $($single_shortcut.FullName) from $env:COMPUTERNAME."
                Remove-Item -Path "$($single_shortcut.FullName)" -Force -whatif:$whatif_setting
            }
        }

        $SecurityLinks = Get-ChildItem -Path "C:\Users\public\desktop" -Filter "*Security*$($FileExtension)" -File -ErrorAction SilentlyContinue 
        if ($SecurityLinks) {
            Write-Host "Found $($FileExtension) links containing 'Security' on  $env:COMPUTERNAME, removing..."
            Foreach ($single_shortcut in $SecurityLinks) {
                Write-Host "Removing $($single_shortcut.FullName) from $env:COMPUTERNAME."
                Remove-Item -Path "$($single_shortcut.FullName)" -Force -whatif:$whatif_setting
            }
        }

        $SGELinks = Get-ChildItem -Path "C:\Users\public\desktop" -Filter "*SGE*$($FileExtension)" -File -ErrorAction SilentlyContinue
        if ($SGELinks) {
            Write-Host "Found $($FileExtension) links containing 'SGE' on  $env:COMPUTERNAME, removing..."
            Foreach ($single_shortcut in $SGELinks) {

                Write-Host "Removing $($single_shortcut.FullName) from $env:COMPUTERNAME."
                Remove-Item -Path "$($single_shortcut.FullName)" -Force -whatif:$whatif_setting
            }
        }
    }
}

#now copy over the good/chrome link:
$SGEExamChromeShortCut = Get-ChildItem -Path "$env:SUPPORTFILES_DIR" -Filter "SGE Exam Chrome.lnk" -File -ErrorAction SilentlyContinue

if ($SGEExamChromeShortCut) {
    Write-Host "Found $($SGEExamChromeShortCut.Fullname) on local machine, preparing to copy to target machines..." -Foregroundcolor Green
}
ForEach ($single_computer in $computerlist) {
    Copy-Item "$($SGEExamChromeShortCut.fullname)" -destination "\\$($single_computer)\c$\Users\public\desktop" -Force -whatif:$whatif_setting
}