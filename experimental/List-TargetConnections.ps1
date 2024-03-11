Function List-TargetConnections {
    <#
    .SYNOPSIS
        Target local or remote computers and list net TCP connections for a specific process, or all processes.

    .DESCRIPTION
        Create report of Get-NetTCPConnection output for target computers, over period of time.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .PARAMETER OutputFile
        'n' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and OutputFile input.
        Ex: Outputfile = 'A220', output file(s) will be in $env:PSMENU_DIR\reports\AssetInfo - A220\

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TargetComputer,
        [Parameter(Mandatory = $false)]
        $ProcessName,
        [Parameter(Mandatory = $false)]
        $TimeInterval = 1,
        [Parameter(Mandatory = $false)]
        $TimeLength = 60
    )
    BEGIN {
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            if (($TargetComputer -is [System.Collections.IEnumerable]) -and ($TargetComputer -isnot [string[]])) {
                $null
                ## If it's a string - check for commas, try to get-content, then try to ping.
            }
            elseif ($TargetComputer -is [string[]]) {
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
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
    
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }
    
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$TargetComputer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        # $distinguishedName = $searcher.FindOne().Properties.distinguishedname
                        # $searcher.Filter = "(member:1.2.840.113556.1.4.1941:=$distinguishedName)"
    
                        [void]$searcher.PropertiesToLoad.Add("name")
    
                        $list = [System.Collections.Generic.List[String]]@()
    
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $TargetComputer = $list
    
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
        $str_title_var = "NetConnections"
        
        if ($Outputfile.tolower() -eq 'n') {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
        }
        else {
            if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
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
                            $outputfile += "$([string]$iterator_var)"
                        }
                        else {
                            break
                        }
                    }
                }
                ## Try to get output directory path and make sure it exists.
                try {
                    $outputdir = $outputfile | split-path -parent
                    if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                        New-Item -ItemType Directory -Path $($outputfile | split-path -parent) | Out-Null
                    }
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory, will be output to $(pwd)" -Foregroundcolor Yellow
                }
            }
        }

        Write-Host "These are the conditions of the 'Get Network Connection' loop:"
        Write-Host "Process name: $ProcessName (if nothing is displayed here, all connections will be output for target computers)"
        Write-Host "Time interval: $TimeInterval seconds (connections output at this frequency)"
        Write-Host "Time length: $TimeLength seconds (connections will be output for this long)"

        Write-Host ""
        Write-Host "Please check the conditions listed above." -Foregroundcolor Yellow
        Start-Sleep -Seconds 2
        Read-Host "Press enter to continue, CTRL+C to cancel"

        
        ## 3. Create empty results container
        $results = [system.collections.arraylist]::new()
    }

    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
            if ($single_computer) {
                ## 2. Send one test ping
                $ping_result = Test-Connection $single_computer -count 1 -Quiet
                if ($ping_result) {
                    $netconnection_results = Invoke-Command -computername $TargetComputer -scriptblock {

                        $NETTCP_PARAMS = @{
                            ErrorAction = 'SilentlyContinue'
                        }

                        ## if processname was specified, use it:
                        if ($using:ProcessName) {
                            $NETTCP_PARAMS.Add('OwningProcess', (Get-Process -Name "$using:ProcessName" -ErrorAction SilentlyContinue | Select -Exp ID))
                        }


                        $counter = 0
                        while ($counter -le ($using:TimeLength)) {
                            $processids = Get-Process -Name "$using:ProcessName" -ErrorAction SilentlyContinue | Select -Exp ID
                            if ($processids) {
                                ForEach ($single_process in $processids) {
                                    $connections_obj = Get-NetTCPConnection -OwningProcess $single_process -ErrorAction SilentlyContinue | Select LocalAddress, LocalPort, RemoteAddress, RemotePort, State, CreationTime, OwningProcess
                                    $connections_obj
                                }
                            }
                            Start-Sleep -Seconds $TimeInterval
                            $counter += $TimeInterval
                        }
                    }

                    ForEach ($single_result in $netconnection_results) {
                        $results.Add($single_result) | Out-Null
                    }
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is offline." -Foregroundcolor Yellow
                }
            }
        }

    }

    END {
        if ($results) {
            ## 1. Sort any existing results by computername
            $results = $results | sort -property pscomputername
            ## 2. Output to gridview if user didn't choose report output.
            if ($outputfile.tolower() -eq 'n') {
                $results | out-gridview -title $str_title_var
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
                        WorksheetName        = $str_title_var
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
                ## Try opening directory (that might contain xlsx and csv reports), default to opening csv which should always exist
                try {
                    Invoke-item "$($outputfile | split-path -Parent)"
                }
                catch {
                    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not open output folder." -Foregroundcolor Yellow
                    Invoke-item "$outputfile.csv"
                }
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
    }
}