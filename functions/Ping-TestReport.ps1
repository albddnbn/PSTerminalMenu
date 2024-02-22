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
        abuddenb / 2024
    #>
    param(
        $TargetComputer,
        $PingCount,
        $Outputfile
    )
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'

        ## If Targetcomputer is an array or arraylist - it's already been sorted out.
        if (($TargetComputer -is [System.Collections.IEnumerable])) {
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
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer was not an array, comma-separated list of hostnames, path to hostname text file, or valid single hostname. Exiting." -Foregroundcolor "Red"
                    return
                }
            }
        }
        $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
        # Safety catch to make sure
        if ($null -eq $TargetComputer) {
            # user said to end function:
            return
        }

        # get the hour/min of day in filestring
        if ($([int](Get-Date -Format 'HH')) -le 11) {
            $am_pm = "AM"
        }
        else {
            $am_pm = "PM"
        }

        ## If the user didn't submit outputfile value - use default
        if ($outputfile -eq '') {
            $REPORT_TITLE = "PingTest-$(Get-Date -Format 'hh-MM')$($am_pm)"
        }
        ## If they submitted a value that wasn't 'n' - use that value to create filepath
        elseif ($outputfile.ToLower() -ne 'n') {
            $REPORT_TITLE = "PingTest-$outputfile-$(Get-Date -Format 'hh-MM')$($am_pm)"
            # if ($Outputfile -eq '') { $outputfile = $REPORT_TITLE } elseif ($outputfile.ToLower() -ne 'n') {
        }

        ## If Get-OutputFileString is available, use it to create outputfile string
        if (Get-Command -Name 'Get-OutputFileString' -ErrorAction SilentlyContinue) {
            $outputfile = Get-OutputFileString -Titlestring $REPORT_TITLE -rootdirectory $env:PSMENU_DIR -foldertitle $REPORT_TITLE -reportoutput
        }
        ## Otherwise - just assign filename to be report title
        else {
            $outputfile = $REPORT_TITLE
        }

        $results_container = [system.collections.arraylist]::new()

        $PingCount = [int]$PingCount
    }

    ## Ping EACH Target computer / record results into ps object, add to arraylist (results_container)
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            $obj = [pscustomobject]@{
                Sourcecomputer       = $env:COMPUTERNAME
                ComputerHostName     = $single_computer
                TotalPings           = $pingcount
                Responses            = 0
                AvgResponseTime      = 0
                PacketLossPercentage = 0
            }
            for ($i = 0; $i -lt $pingcount; $i++) {
                # $ping = Test-NetConnection -ComputerName $single_computer -Count 1 -ErrorAction SilentlyContinue
                # $details = $ping.pingreplydetails
                # $triptime = $details.roundtriptime
                $ping = Test-Connection -ComputerName $single_computer -Count 1 -ErrorAction SilentlyContinue
                if ($ping) {
                    $obj.Responses += 1
                    $intresponsetime = [int]$ping.ResponseTime
                    $obj.AvgResponseTime += $intresponsetime
                }
            }
            # avg response time
            if ($obj.Responses -eq 0) {

                $obj.AvgResponseTime = 0
            }
            else {

                $obj.AvgResponseTime = $($obj.AvgResponseTime) / $($obj.Responses)
            }

            # calculate packet loss percentage - divide total pings by responses
            $total_drops = $obj.TotalPings - $obj.Responses
            $obj.PacketLossPercentage = ($total_drops / $($obj.TotalPings)) * 100

            $results_container.add($obj) | Out-Null
        }
    }

    ## Report file creation or terminal output
    END {

        if ($outputfile.tolower() -eq 'n') {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
            # $results_container | format-table -autosize
            $results_container | out-gridview
        }
        else {
            if (Get-Command -name 'output-reports' -erroraction SilentlyContinue) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting " -nonewline
                Write-Host "$outputfile" -foregroundcolor green -NoNewline
                Write-Host " to .csv/.xlsx."
    
                Output-Reports -Filepath "$outputfile" -Content $results_container -ReportTitle "Ping Test $thedate" -CSVFile $true -XLSXFile $true
    
                # /-- Open in File explorer
                Invoke-Item "$env:PSMENU_DIR\reports\$thedate\$REPORT_TITLE\"
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting " -nonewline
                Write-Host "$outputfile" -foregroundcolor green -NoNewline
                Write-Host " to .csv only"
                $results_container | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                # /-- Open in File explorer
                try {
                    Invoke-Item "$outputfile.csv"
                }
                catch {
                    Write-Host "Failed to open $outputfile.csv."
                }
            }
        }
    }
}