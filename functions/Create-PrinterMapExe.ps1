function Create-PrinterMapExe {
    <#
    .SYNOPSIS
    Creates an executable that will map a printer for a regular user, when the regular user runs the exe.

    .DESCRIPTION
    The printer must be accessible through a print server. It can be a PrinterLogic printer as well, but it can't only be a PrinterLogic printer.

    .PARAMETER PrinterName
    The hostname / DNS hostname of the printer. Example: s-prt-a227-02

    .PARAMETER PrintServer
    The hostname / DNS hostname of the print server. Example: s-ps-02

    .EXAMPLE
    Create-PrinterMapExe -PrinterName "s-prt-a227-02" -PrintServer "s-ps-02"
    
    .EXAMPLE
    Create-PrinterMapExe -PrinterName "s-prt-a227-02"

    .NOTES
    If you upload the exe directly to OSTicket, it will be blocked by the email filter. Upload it to OneDrive and share it with the user instead.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [TypeName('String')]
        $PrinterName,
        [Parameter(Mandatory = $false)]
        [TypeName('String')]
        $PrintServer
    )
    # make sure ps2exe module is present
    if (-not (Get-Module -Name ps2exe)) {
        Install-Module -Name ps2exe -Scope CurrentUser -Force
    }
    # if printername wasn't supplied, ask for it, same with print server
    if (-not $PrinterName) {
        $PrinterName = Read-Host "Enter the printer name (ex: s-prt-a228-01)"
    }
    if (-not $PrintServer) {
        $PrintServer = Read-Host "Enter the print server (ex: s-ps-02 for Stanton's print server)"
    }

    # create unc printer path
    $PrinterPath = "\\$PrintServer\$PrinterName"

    # create the .ps1 to be converted to .exe
    $ps1_print_map_script = @"
    Write-Host "Mapping $PrinterName..."
    (New-Object -ComObject Wscript.Network).AddWindowsPrinterConnection($PrinterPath)
    (New-Object -ComObject Wscript.Network).SetDefaultPrinter($PrinterPath)
    Start-Sleep -Seconds 3
"@
    $today = Get-Date -Format "MM-dd-yyyy"

    # create the .ps1 file with the abov econtent
    $ps1_print_map_script | Out-File -FilePath ".\map-$PrinterName.$today.ps1" -Force
    # compile it into an .exe
    try {
        Invoke-PS2Exe ".\map-$PrinterName.ps1" ".\map-$PrinterName.$today.exe"
        Write-Host "Successfully compiled the .exe" -ForegroundColor Green
        Write-Host ""
        Write-Host "The .exe is located at .\map-$PrinterName.$today.exe" -ForegroundColor Green
        Write-Host "--------------------------"
        Write-Host "Please upload it to OneDrive, and share with the user rather than uploading directly to OSTicket." -ForegroundColor Yellow
        Write-Host "Press any key to proceed"
        $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Remove-Item -Path ".\map-$PrinterName.$today.ps1" -Force
    }
    catch {
        Write-Host "Failed to compile the .exe" -ForegroundColor Red
        Write-Host "Press any key to acknowledge."
        $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    }
}