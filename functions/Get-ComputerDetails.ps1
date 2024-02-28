function Get-ComputerDetails {
    <#
    .SYNOPSIS
        Collects: Manufacturer, Model, Current User, Windows Build, BIOS Version, BIOS Release Date, and Total RAM from target machine(s).
        Outputs: A .csv and .xlsx report file if anything other than 'n' is supplied for the $OutputFile parameter.

    .DESCRIPTION

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER OutputFile
        'n' or 'N' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and OutputFile input.
        Ex: Outputfile = 'A220-Info', output file(s) will be in the $env:PSMENU_DIR\reports\2023-11-1\A220-Info\ directory.

    .EXAMPLE
        Output details for a single hostname to "sa227-28-details.csv" and "sa227-28-details.xlsx" in the 'reports' directory.
        Get-ComputerDetails -TargetComputer "t-client-28" -Outputfile "tclient-28-details"

    .EXAMPLE
        Output details for all hostnames starting with g-pc-0 to terminal.
        Get-ComputerDetails -TargetComputer 'g-pc-0' -outputfile 'n'

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

    ## 1. define date variable (used for filename creation)
    ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
    ## 3. Outputfile path needs to be created regardless of how Targetcomputer is submitted to function
    BEGIN {
        ## 1. define date variable (used for filename creation)
        $thedate = Get-Date -Format 'yyyy-MM-dd'
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
        ## 3. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $str_title_var = "PCdetails"
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
        ## 4. Create empty results container
        $results = [system.collections.arraylist]::new()
        Write-host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Getting asset information from computers now..."

    }

    #####################################################################################
    ## PROCESS - Collects computer details from specified computers using CIM commands ##
    #####################################################################################   
    PROCESS {
        if ($Targetcomputer) {
            # ping test
            $pingreply = Test-Connection $TargetComputer -Count 1 -Quiet
            if ($pingreply) {

                ## Save results to variable
                $single_result = Invoke-Command -ComputerName $TargetComputer -Scriptblock {
                    # Gets active user, computer manufacturer, model, BIOS version & release date, Win Build number, total RAM, last boot time, and total system up time.
                    $manufacturer = (get-ciminstance -class win32_computersystem).manufacturer
                    $model = (get-ciminstance -class win32_computersystem).model
                    $biosversion = (get-ciminstance -class win32_bios).smbiosbiosversion
                    $bioreleasedate = (get-ciminstance -class win32_bios).releasedate
                    $winbuild = (get-ciminstance -class win32_operatingsystem).buildnumber
                    $totalram = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum / 1gb
                    $totalram = [string]$totalram + " GB"
                    $lastboottime = (Get-Ciminstance -class win32_operatingsystem).LastBootUpTime
                    # get system up time using current time and last bootup time, format it
                    $system_uptime = $(Get-Date) - $lastboottime
                    $system_uptime = $system_uptime.tostring("hh\:mm\:ss")
                    $system_uptime += " Hours"
                    # current_user
                    $current_user = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username

                    $obj = [PSCustomObject]@{
                        Manufacturer    = $manufacturer
                        Model           = $model
                        CurrentUser     = $current_user
                        WindowsBuild    = $winbuild
                        BiosVersion     = $biosversion
                        BiosReleaseDate = $bioreleasedate
                        TotalRAM        = $totalram
                        LastBoot        = $lastboottime
                        SystemUptime    = $system_uptime
                    }
                    $obj
                } | Select * -ExcludeProperty PSShowComputerName, RunspaceId

                $results.add($single_result) | out-null
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer is offline." -Foregroundcolor Yellow
            }
        }
    }

    ########################################################################################################
    ## END - Output of results to CSV, XLSX, terminal, or gridview depending on the $OutputFile parameter ##
    ########################################################################################################
    END {
        if ($results) {
            ## Sort the results
            $results = $results | sort -property pscomputername
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
                        WorksheetName        = 'Details'
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