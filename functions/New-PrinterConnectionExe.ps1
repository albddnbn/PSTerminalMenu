function New-PrinterConnectionExe {
    <#
    .SYNOPSIS
        Generates executable using the PS2exe powershell module that will map a printer.
        Either PrinterLogic or on print server, specified by $PrinterType parameter.

    .DESCRIPTION
        PrinterLogic  - Printer Installer Client software must be installed on machines where executable is being used.
        Print servers - Print server must be accessible over the network, on machines where executable will be used.

    .PARAMETER Printername
        Name of the printer to map. Ex: 'printer-c136-01'
        PrinterLogic - needs to match printer's name as listed in PrinterLogic Printercloud instance.
        Print server - needs to match printer's hostname as listed in print server and on DNS server.

    .PARAMETER PrinterType
        Set to 'printerlogic' or the name of a printer server, ex: 's-ps-02', 'org-printserv-001'

    .EXAMPLE
        Generate-PrinterLogicExe -PrinterName "printer-c136-01"

    .NOTES
        Executable will be created in the 'executables' directory.
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName,
        # [ValidateSet('printerlogic', 'ps')]
        $PrinterType
    )
    $EXECUTABLES_DIRECTORY = 'PrinterMapping'
    $thedate = Get-Date -Format 'yyyy-MM-dd'

    ### Make sure the executables and output directories for today exist / create if not.
    foreach ($singledir in @("$env:PSMENU_DIR\executables\$thedate\$EXECUTABLES_DIRECTORY", "$env:PSMENU_DIR\output\$thedate")) {
        if (-not (Test-Path $singledir -ErrorAction SilentlyContinue)) {
            New-Item -Path $singledir -ItemType 'Directory' -Force | Out-Null
        }
    }

    ## creates $exe_script variable depending on what kind of printer needs to be mapped
    if ($PrinterType -notlike "*print*logic*") {
        $exe_script = @"
`$printername = '\\$PrinterType\$PrinterName'
try {
    (New-Object -comobject wscript.network).addwindowsprinterconnection(`$printername)
    (New-Object -comobject wscript.network).setdefaultprinter(`$printername)
    Write-Host "Mapped `$printername successfully." -Foregroundcolor Green
} catch {
    Write-Host "Failed to map printer: `$printername, please let Tech Support know." -Foregroundcolor Red
}
Start-Sleep -Seconds 5
"@

        # create output filename for print server mapping:
        $output_filename = "$PrinterType-connect-$PrinterName"
    }
    else {
        # generate text for .ps1 file
        $exe_script = @"
# 'get' the .exe
`$printerinstallerconsoleexe = Get-Childitem -Path "C:\Program Files (x86)\Printer Properties Pro\Printer Installer Client\bin\" -Filter "PrinterInstallerconsole.exe" -File -ErrorAction silentlycontinue
# run install command:
`$execution_result = Start-Process "`$(`$printerinstallerconsoleexe.FullName)" -ArgumentList "InstallPrinter=$printername"
# if (`$execution_result -eq 0) {
#     Write-Host "[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Successfully installed printer: `$printername" -Foregroundcolor Green
# } else {
#     Write-Host "[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Failed to install printer: `$printername, please let tech support know." -Foregroundcolor Red
# }
Start-Sleep -Seconds 5
"@

        $output_filename = "plogic-connect-$PrinterName"

    }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Creating executable that will map $PrinterType printer: $printername when double-clicked by user..."

    $exe_script | Out-File -FilePath "$env:PSMENU_DIR\output\$thedate\$output_filename.ps1" -Force

    Invoke-PS2EXE -inputfile "$env:PSMENU_DIR\output\$thedate\$output_filename.ps1" `
        -outputfile "$env:PSMENU_DIR\executables\$thedate\$EXECUTABLES_DIRECTORY\$output_filename.exe"

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Executable created successfully: $env:PSMENU_DIR\executables\$thedate\$EXECUTABLES_DIRECTORY\$output_filename.exe" -ForegroundColor Green

    Invoke-Item "$env:PSMENU_DIR\executables\$thedate\$EXECUTABLES_DIRECTORY"
}
