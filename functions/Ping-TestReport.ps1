function Ping-TestReport {
    <#
    .SYNOPSIS
        Pings a group of computers a specified amount of times, and outputs the successes / total pings to a .csv and .xlsx report.

    .DESCRIPTION
        Script will output to ./reports/<date>/ folder. It calculates average response time, and packet loss percentage.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER PingCount
        Number of times to ping each computer.

    .PARAMETER OutputFile
        'n' or 'no' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and OutputFile input.
        Ex: Outputfile = 'Room1', output file(s) will be in $env:PSMENU_DIR\reports\AssetInfo - Room1\

    .EXAMPLE
        Ping-TestReport -Targetcomputer "g-client-" -PingCount 10 -Outputfile "GClientPings"
    
    .EXAMPLE
        Ping-TestReport -Targetcomputer "g-client-" -PingCount 2

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
        $PingCount,
        [string]$Outputfile = ''
    )
    ## 1. Set date and AM / PM variables
    ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
    ## 3. If provided, use outputfile input to create report output filepath.
    ## 4. Create arraylist to store results
    BEGIN {
        ## 1. Set date and AM / PM variables
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        $am_pm = (Get-Date).ToString('tt')

        ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
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

        ## 2. If provided, use outputfile input to create report output filepath.
        if ($outputfile -eq '') {
            $REPORT_TITLE = "Pings-$(Get-Date -Format 'hh-MM')$($am_pm)"
        }
        ## If they submitted a value that wasn't 'n' - use that value to create filepath
        elseif ($outputfile.ToLower() -ne 'n') {
            $REPORT_TITLE = "Pings-$outputfile-$(Get-Date -Format 'hh-MM')$($am_pm)"
        }
        ## Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $str_title_var = $REPORT_TITLE
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
                        $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$str_title_var"
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
        ## 3. Create arraylist to store results
        $results = [system.collections.arraylist]::new()

        $PingCount = [int]$PingCount
    }

    ## Ping EACH Target computer / record results into ps object, add to arraylist (results_container)
    ## Set object property values:
    ## 3. Send pings - object property values are derived from resulting object
    ## 4. Number of responses
    ## 5. Calculate average response time for successful responses
    ## 6. Calculate packet loss percentage
    PROCESS {
        ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
        if ($TargetComputer) {
            ## 2. Create object to store results of ping test on single machine
            $obj = [pscustomobject]@{
                Sourcecomputer       = $env:COMPUTERNAME
                ComputerHostName     = $TargetComputer
                TotalPings           = $pingcount
                Responses            = 0
                AvgResponseTime      = 0
                PacketLossPercentage = 0
            }
            ## 3. Send $PINGCOUNT number of pings to target device, store results
            $send_pings = Test-Connection -ComputerName $TargetComputer -count $PingCount -ErrorAction SilentlyContinue
            ## 4. Set number of responses from target machine
            $obj.responses = $send_pings.count
            ## 5. Calculate average response time for successful responses
            $sum_of_response_times = $($send_pings | measure-object responsetime -sum)
            if ($obj.Responses -eq 0) {
                $obj.AvgResponseTime = 0
            }
            else {
                $obj.avgresponsetime = $sum_of_response_times.sum / $obj.responses
            }
            ## 6. Calculate packet loss percentage - divide total pings by responses
            $total_drops = $obj.TotalPings - $obj.Responses
            $obj.PacketLossPercentage = ($total_drops / $($obj.TotalPings)) * 100

            ## 7. Add object to container created in BEGIN block
            $results.add($obj) | Out-Null
        }
    }

    ## Report file creation or terminal output
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
                        TableName            = "$REPORT_TITLE"
                        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                        BoldTopRow           = $true
                        WorksheetName        = $REPORT_TITLE
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
        Read-Host "`nPress [ENTER] to return results."
        return $results
    }
}