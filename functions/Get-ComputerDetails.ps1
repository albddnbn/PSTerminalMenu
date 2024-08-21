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

    .INPUTS
        [String[]] - an array of hostnames can be submitted through pipeline for Targetcomputer parameter.

    .OUTPUTS
        [System.Collections.ArrayList] - Returns an arraylist of objects containing hostname, computer model, bios version/release date, last boot time, and other info.
        The results arraylist is also displayed in a GridView.

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
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$Outputfile
    )

    ## 1. define date variable (used for filename creation)
    ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
    ## 3. Outputfile path needs to be created regardless of how Targetcomputer is submitted to function
    BEGIN {
        ## 1. define date variable (used for filename creation)
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline input for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
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

                        $matching_hostnames = (([adsisearcher]"(&(objectCategory=Computer)(name=$computer*))").findall()).properties
                        $matching_hostnames = $matching_hostnames.name
                        $NewTargetComputer += $matching_hostnames
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
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
                        $outputfile = "reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$thedate"
                        if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                            $iterator_var++
                            $outputfile += "$([string]$iterator_var)"
                        }
                        else {
                            break
                        }
                    }


                }
                try {
                    $outputdir = $outputfile | split-path -parent
                    if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                        New-Item -ItemType Directory -Path $($outputfile | split-path -parent) -Force | Out-Null
                    }
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory." -Foregroundcolor Yellow
                }


            }
        }
        ## 4. Create empty results container
        $results = [system.collections.arraylist]::new()
    }

    ## Collects computer details from specified computers using CIM commands  
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            if ($single_computer) {
                # ping test
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {

                    ## Save results to variable
                    $single_result = Invoke-Command -ComputerName $single_computer -Scriptblock {
                        # Gets active user, computer manufacturer, model, BIOS version & release date, Win Build number, total RAM, last boot time, and total system up time.
                        # object returned to $results list
                        $computersystem = Get-CimInstance -Class Win32_Computersystem
                        $bios = Get-CimInstance -Class Win32_BIOS
                        $operatingsystem = Get-CimInstance -Class Win32_OperatingSystem

                        $lastboot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
                        $uptime = ((Get-Date) - $lastboot).ToString("dd\.hh\:mm\:ss")
                        $obj = [PSCustomObject]@{
                            Manufacturer    = $($computersystem.manufacturer)
                            Model           = $($computersystem.model)
                            CurrentUser     = $((get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username)
                            WindowsBuild    = $($operatingsystem.buildnumber)
                            BiosVersion     = $($bios.smbiosbiosversion)
                            BiosReleaseDate = $($bios.releasedate)
                            TotalRAM        = $((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum / 1gb)
                            LastBoot        = $lastboot
                            SystemUptime    = $uptime
                        }
                        $obj
                    } | Select PSComputerName, * -ExcludeProperty RunspaceId, PSshowcomputername -ErrorAction SilentlyContinue

                    $results.add($single_result) | out-null
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is offline." -Foregroundcolor Yellow
                }
            }
        }
    }

    ## Output of results to CSV, XLSX, terminal, or gridview depending on the $OutputFile parameter
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
                    $results | out-gridview -Title $str_title_var
                }
            }
            else {
                $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                ## Try ImportExcel
                try {

                    Import-Module ImportExcel

                    ## xlsx attempt:
                    $params = @{
                        AutoSize             = $true
                        TitleBackgroundColor = 'Blue'
                        TableName            = $str_title_var
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
                try {
                    Invoke-item "$($outputfile | split-path -Parent)"
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not open output folder." -Foregroundcolor Yellow
                    Invoke-item "$outputfile.csv"
                }
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."

            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output from Get-ComputerDetails." | Out-File -FilePath "$outputfile.csv"

            Invoke-Item "$outputfile.csv"
        }
        # read-host "Press enter to return results."
        return $results
    }
}