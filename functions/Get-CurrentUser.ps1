function Get-CurrentUser {
    <#
    .SYNOPSIS
        Gets user logged into target system(s).
        Checks if teams or zoom processes are running and returns True/False for each in report/terminal output.

    .DESCRIPTION
        Creates report with current user, computer model, and if Teams or Zoom are running.
        If no output file is specified, terminal output only ($Outputfile = 'n').

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

    .EXAMPLE
        1. Get users on all S-A231 computers:
        Get-CurrentUser -Targetcomputer "s-a231-"

    .EXAMPLE
        2. Get user on a single target computer:
        Get-CurrentUser -TargetComputer "t-client-28"

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
        [string]$Outputfile = ''
    )
    ## 1. Handle Targetcomputer input if it's not supplied through pipeline.
    ## 2. Create output filepath if necessary.
    ## 3. Create empty results arraylist to hold results from each target machine (collected during the PROCESS block).
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

        ## 2. Create output filepath if necessary.
        if ($outputfile.tolower() -ne 'n') {
            ## Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
            if (Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) {
                if ($Outputfile.toLower() -eq '') {
                    $outputfile = "CurrentUsers"
                }

                $outputfile = Get-OutputFileString -TitleString $outputfile -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                if ($outputfile.tolower() -eq '') {
                    $outputfile = "CurrentUsers-$thedate"
                }
            }
        }

        ## 3. Create empty results container
        $results = [system.collections.arraylist]::new()
    }

    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responseive, run scriptblock to logged in user, info on teams/zoom processes, etc.
    PROCESS {
        ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
        if ($TargetComputer) {
            ## 2. Send one test ping
            $ping_result = Test-Connection $TargetComputer -count 1 -Quiet
            if ($ping_result) {
                # Get Computers details and create an object
                $logged_in_user_info = Invoke-Command -ComputerName $TargetComputer -Scriptblock {
                    $model = (get-ciminstance -class win32_computersystem).model
                    # $current_user = Get-Ciminstance -class win32_computersystem | select -exp username # different way
                    $current_user = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
                    # see if teams and/or zoom are running
                    $teams_running = get-process -name 'teams' -erroraction SilentlyContinue
                    $zoom_running = get-process -name 'zoom' -erroraction SilentlyContinue
                    ForEach ($process_check in @($teams_running, $zoom_running)) {
                        if ($process_check) {
                            $process_check = $true
                        }
                        else {
                            $process_check = $false
                        }
                    }
                    $obj = [PSCustomObject]@{
                        Model        = $model
                        CurrentUser  = $current_user
                        TeamsRunning = $teams_running
                        ZoomRunning  = $zoom_running

                    }
                    $obj
                } 
                $logged_in_user_info = $logged_in_user_info | Select PSComputerName, CurrentUser, Model, TeamsRunning, ZoomRunning
                # $logged_in_user_info = $logged_in_user_info | Sort -Property PSComputerName
                $results.add($logged_in_user_info) | out-null
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer is offline." -Foregroundcolor Yellow
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
                        WorksheetName        = 'CurrentUsers'
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
        Read-Host "Press enter to continue."
    }
}
