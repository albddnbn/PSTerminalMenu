<#
.SYNOPSIS
    Connects to a PrinterLogic printer on the local computer.
    Called by functions/Connect-ToPrinterLogicPrinter to connect to a printer on a group of target computers.
    Uses the PrinterInstallerConsle.exe file found in C:\Program Files (x86)\Printer Properties Pro\bin after installing PrinterLogic client software.

.PARAMETER PrtName
    Specifies the name of the printer to connect to.
    Ex: 's-prt-c136-02'

.NOTES
    PrinterLogic instance      : https://dtcc.printercloud.com
    PrinterLogic Admin console : https://dtcc.printercloud.com/admin
#>
param(
    [string]$PrtName
)

$obj = [pscustomobject]@{
    hostname       = $env:COMPUTERNAME
    printer        = $PrtName
    connectstatus  = 'NO'
    clientsoftware = 'NO'
}
# get installerconsole.exe
$exepath = get-childitem -path "C:\Program Files (x86)\Printer Properties Pro\Printer Installer Client\bin" -Filter "PrinterInstallerConsole.exe" -File -Erroraction SilentlyContinue
if (-not $exepath) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: PrinterLogic PrinterInstallerConsole.exe was not found in C:\Program Files (x86)\Printer Properties Pro\Printer Installer Client\bin." -Foregroundcolor Red
    return $obj
}

$obj.clientsoftware = 'YES'

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Found $($exepath.fullname), mapping $PrtName now..."
$map_result = (Start-Process "$($exepath.fullname)" -Argumentlist "InstallPrinter=$PrtName" -Wait -Passthru).ExitCode

# 0 = good, 1 = bad
if ($map_result -eq 0) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Connected to $PrtName successfully." -Foregroundcolor Green
    # Write-Host "*Remember that this script does not set default printer, user has to do that themselves."
    $obj.connectstatus = 'YES'
    return $obj
}
else {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: failed to connect to $PrtName." -Foregroundcolor Red
    return $obj
}