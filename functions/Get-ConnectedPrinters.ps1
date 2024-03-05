function Get-ConnectedPrinters {
    <#
    .SYNOPSIS
        Checks the target computer, and returns the user that's logged in, and the printers that user has access to.

    .DESCRIPTION
        This function, unlike some others, only takes a single string DNS hostname of a target computer.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER OutputFile
        'n' or 'no' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and OutputFile input.
        Ex: Outputfile = 'A220', output file(s) will be in $env:PSMENU_DIR\reports\AssetInfo - A220\

    .PARAMETER FolderTitleSubstring
        If specified, the function will create a folder in the 'reports' directory with the specified substring in the title, appended to the $REPORT_DIRECTORY String (relates to the function title).

    .EXAMPLE
        Get-ConnectedPrinters -TargetComputer 't-client-07'

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        $TargetComputer,
        [string]$Outputfile = ''
    )

    ## 1. Handle Targetcomputer input if it's not supplied through pipeline.
    ## 2. Create output filepath if necessary.
    ## 3. Scriptblock that is executed on each target computer to retrieve connected printer info.
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
                        $TargetComputer = $TargetComputer + "x"
                        $TargetComputer = Get-ADComputer -Filter * | Where-Object { $_.DNSHostname -match "^$TargetComputer*" } | Select -Exp DNShostname
                        $TargetComputer = $TargetComputer | Sort-Object   
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
        $str_title_var = "Printers"
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
        ## 3. Scriptblock - lists connected/default printers
        $list_local_printers_block = {
            # Everything will stay null, if there is no user logged in
            $obj = [PScustomObject]@{
                Username          = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
                DefaultPrinter    = $null
                ConnectedPrinters = $null
            }

            # Only need to check for connected printers if a user is logged in.
            if ($obj.Username) {
                # get connected printers:
                get-ciminstance -class win32_printer | select name, Default | ForEach-Object {
                    if (($_.name -notin ('Microsoft Print to PDF', 'Fax')) -and ($_.name -notlike "*OneNote*")) {
                        if ($_.name -notlike "Send to*") {
                            $obj.ConnectedPrinters = "$($obj.ConnectedPrinters), $($_.name)"
                        }
                    }   
                }
            }
            $obj
        }
        ## Create empty results container to use during process block
        $results = [system.collections.arraylist]::new()
    }

    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responseive, run the 'get connected printers' scriptblock.
    PROCESS {
        ## 1. TargetComputer can't be $null or '', it will display error during test-connection
        if ($TargetComputer) {
            ## 2. Single ping test to target computer
            $pingreply = Test-connection $TargetComputer -Count 1 -Quiet
            if ($pingreply) {
                ## 3. If computer responded - collect printer info and add to results list.
                $connected_printer_info = Invoke-Command -ComputerName $TargetComputer -Scriptblock $list_local_printers_block | Select * -ExcludeProperty RunspaceId, PSShowComputerName
                $results.Add($connected_printer_info) | out-null
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer didn't respond to one ping, skipping." -Foregroundcolor Yellow
            }
        } 
    }

    ## 1. If there are results - sort them by the hostname (pscomputername) property.
    ## 2. If the user specified 'n' for outputfile - just output to terminal or gridview.
    ## 3. Create .csv/.xlsx reports as necessary.
    END {
        if ($results) {
            ## 1. Sort any existing results by computername
            $results = $results | sort -property pscomputername
            ## 2. Output to gridview if user didn't choose report output.
            if ($outputfile.tolower() -eq 'n') {
                $results | out-gridview
            }
            else {
                ## 3. Create .csv/.xlsx reports if possible
                $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                ## Try ImportExcel
                try {
                    $params = @{
                        AutoSize             = $true
                        TitleBackgroundColor = 'Blue'
                        TableName            = "$REPORT_DIRECTORY"
                        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                        BoldTopRow           = $true
                        WorksheetName        = 'Printers'
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
        Read-Host "Press enter to return results."
        return $results
    }
}
