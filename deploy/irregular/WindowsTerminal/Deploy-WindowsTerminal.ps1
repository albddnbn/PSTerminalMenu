## Install Windows Terminal Appx Package script
## by Alex B.
## 3-1-24
param(
    [switch]$CloseApps
)
## Get the msixbundle
$WindowsTerminal_Msix = Get-ChildItem -Path "." -Include Microsoft.WindowsTerminal*.msixbundle -File -ErrorAction SilentlyContinue
if (-not $WindowsTerminal_Msix) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find WindowsTerminal msixbundle in current directory!" -ForegroundColor Yellow
    return
}

## Install the msixbundle
try {
    $install_params = @{
        Path = "$($WindowsTerminal_Msix.FullName)"
    }
    
    if ($CloseApps) {
        $install_params['ForceApplicationShutdown'] = $true
    }

    Add-AppxPackage @install_params
}
catch {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't install WindowsTerminal msixbundle!" -ForegroundColor Yellow
    return
}