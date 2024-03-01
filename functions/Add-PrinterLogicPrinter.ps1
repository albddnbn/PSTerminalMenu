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
    ## 1. TargetComputer handling if not supplied through pipeline
    ## 2. Outputfile path creation
    ## 3. Scriptblock to connect to printerlogic printer
    ## 4. Results containers for overall results and skipped computers.
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            if (($TargetComputer -is [System.Collections.IEnumerable]) -and ($TargetComputer -isnot [string])) {
                $null
                ## If it's a string - check for commas, try to get-content, then try to ping.
            }
            elseif ($TargetComputer -is [string]) {
                if ($TargetComputer -in @('', '127.0.0.1')) {
                    $TargetComputer = @('127.0.0.1')
                }
                elseif ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                elseif (Test-Path $Targetcomputer -erroraction SilentlyContinue) {
                    $TargetComputer = Get-Content $TargetComputer
                }
                else {
                    $test_ping = Test-Connection -ComputerName $TargetComputer -count 1 -Quiet
                    if ($test_ping) {
                        $TargetComputer = @($TargetComputer)
                    }
                    else {
                        $TargetComputerInput = $TargetComputerInput + "x"
                        $TargetComputerInput = Get-ADComputer -Filter * | Where-Object { $_.DNSHostname -match "^$TargetComputerInput*" } | Select -Exp DNShostname
                        $TargetComputerInput = $TargetComputerInput | Sort-Object   
                    }
                }
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 2. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $str_title_var = "PrtLogicConnect"
        if ($Outputfile.tolower() -eq 'n') {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
        }
        else {
            if (Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) {
                if ($Outputfile.toLower() -eq '') {
                    $REPORT_DIRECTORY = "$str_title_var"
                }
                else {
                    $REPORT_DIRECTORY = $outputfile            
                }
                $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                if ($outputfile.tolower() -eq '') {
                    $iterator_var = 0
                    while ($true) {
                        $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$thedate"
                        if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                            $iterator_var++
                            $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$([string]$iterator_var)"
                        }
                        else {
                            break
                        }
                    }
                }
            }
        }
        ## 3. Define the scriptblock that connects machine to target printer in printerlogic cloud instance
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

        ## 4. Create empty results containers
        $results = [system.collections.arraylist]::new()
        $missed_computers = [system.collections.arraylist]::new()
    }
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responsive, run scriptblock to attempt connection to printerlogic printer, save results to object
    PROCESS {
        ## 1.
        if ($TargetComputer) {
            # may be able to remove the next 3 lines.
            if ($Targetcomputer -eq '127.0.0.1') {
                $TargetComputer = $env:COMPUTERNAME
            }
            ## 2. test with ping:
            $pingreply = Test-Connection $TargetComputer -Count 1 -Quiet
            if ($pingreply) {
                ## 3.
                $printer_connection_results = Invoke-Command -ComputerName $TargetComputer -scriptblock $connect_to_printer_block -ArgumentList $PrinterName
            
                $results.add($printer_connection_results)
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer is not responding to ping." -Foregroundcolor Red
                $missed_computers.Add($TargetComputer)
            }
        }
    }
    ## 1. If there are any results - output to file
    ## 2. Output missed computers to terminal.
    ## 3. Return results arraylist
    END {
        ## 1.
        if ($results) {
            ## Output results list to file:
            ## Sort the results
            if ($outputfile.tolower() -eq 'n') {
                # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
                if ($results.count -le 2) {
                    $results | Format-List
                    # $results | Out-GridView
                }
                else {
                    $results | out-gridview
                }
            }
            else {
                $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                ## Try ImportExcel
                try {
                    ## xlsx attempt:
                    $params = @{
                        AutoSize             = $true
                        TitleBackgroundColor = 'Blue'
                        TableName            = "$REPORT_DIRECTORY"
                        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                        BoldTopRow           = $true
                        WorksheetName        = "$REPORT_DIRECTORY"
                        PassThru             = $true
                        Path                 = "$Outputfile.xlsx" # => Define where to save it here!
                    }
                    $Content = Import-Csv "$Outputfile.csv"
                    $xlsx = $Content | Export-Excel @params
                    $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                    $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                    Close-ExcelPackage $xlsx
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
                }
                Invoke-item "$($outputfile | split-path -Parent)"
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        ## 2. Output unresponsive computers
        Write-Host "These computers did not respond to ping:"
        Write-Host ""
        $missed_computers
        Write-Host ""
        Read-Host "Press enter to return results."

        ## 3. return results arraylist
        return $results
    }
}