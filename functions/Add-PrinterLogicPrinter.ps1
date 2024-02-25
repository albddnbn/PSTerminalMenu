function Add-PrinterLogicPrinter {
    <#
    .SYNOPSIS
        Connects local or remote computer to target printerlogic printer by executing C:\Program Files (x86)\Printer Properties Pro\Printer Installer Client\bin\PrinterInstallerConsole.exe.
        Connection fails if PrinterLogic Client software is not installed on target machine(s).
        The user does NOT have to be a PrinterLogic user to be able to access connected PrinterLogic printers.

    .DESCRIPTION
        PrinterLogic Client software has to be installed on target machine(s) and connecting to your organization's 'Printercloud' instance using the registration key.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER PrinterName
        Name of the printer in printerlogic. Ex: 't-prt-lib-01', you can use the name or the full 'path' to the printer, ex: 'STANTON\B WING..\s-prt-b220-01'
        Name must match the exact 'name' of the printer, as listed in PrinterLogic.
    .EXAMPLE
        Connect single remote target computer to t-prt-lib-01 printer:
        Add-PrinterLogicPrinter -TargetComputer "t-client-28" -PrinterName "t-prt-lib-01"
        
    .EXAMPLE
        Connect a group of computers using hostname txt filepath to t-prt-lib-02 printer:
        Add-PrinterLogicPrinter -TargetComputer "D:\computers.txt" -PrinterName "t-prt-lib-02"
        
    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        $TargetComputer,
        [string]$PrinterName
    )   
    $TargetComputer = $TargetComputer | where-object { $_ -ne $null }
    
    $connect_to_printer_block = {
        param(
            $printer_name
        )

        $obj = [pscustomobject]@{
            hostname       = $env:COMPUTERNAME
            printer        = $printer_name
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
        
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Found $($exepath.fullname), mapping $printer_name now..."
        $map_result = (Start-Process "$($exepath.fullname)" -Argumentlist "InstallPrinter=$printer_name" -Wait -Passthru).ExitCode
        
        # 0 = good, 1 = bad
        if ($map_result -eq 0) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Connected to $printer_name successfully." -Foregroundcolor Green
            # Write-Host "*Remember that this script does not set default printer, user has to do that themselves."
            $obj.connectstatus = 'YES'
            return $obj
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: failed to connect to $printer_name." -Foregroundcolor Red
            return $obj
        }
    }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Connecting printer: " -NoNewLine
    Write-Host "$printername" -Foregroundcolor Yellow
    Write-Host ""

    if ($TargetComputer -eq '127.0.0.1') {
        $results = Invoke-Command -Scriptblock $connect_to_printer_block -ArgumentList $PrinterName
        $results | add-member -MemberType NoteProperty -Name 'PSComputerName' -Value $env:COMPUTERNAME
    }
    else {
        $results = Invoke-Command -ComputerName $TargetComputer -scriptblock $connect_to_printer_block -ArgumentList $PrinterName
    }

    $need_software_installed = ($results | where-object { $_.clientsoftware -eq 'NO' }).PSComputerName

    $failed_connections = ($results | Where-Object { $_.connectstatus -eq 'NO' }).PSComputerName
    # no need to repeat the ones that need software installed
    $failed_connections = $failed_connections | where-object { $_ -notin $($need_software_installed) }

    if ($need_software_installed) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
        Write-Host "These computers " -NoNewline
        Write-Host "need PrinterLogic software installed" -Foregroundcolor Red -NoNewline
        Write-Host "."
        # Write-Host "$($need_software_installed -join ', ')"
        $need_software_installed
        Write-Host ""
    }

    if ($failed_connections) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
        Write-Host "These computers " -NoNewline
        Write-Host "failed to connect to $printername" -Foregroundcolor Red -NoNewline
        Write-Host ", but have Printer Logic software installed."
        Write-Host ""
        # Write-Host "$($failed_connections -join ', ')" -Foregroundcolor red
        $failed_connections
    }
    Read-Host "Press enter to continue."
}
