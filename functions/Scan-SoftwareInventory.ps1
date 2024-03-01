function Scan-SoftwareInventory {
    <#
    .SYNOPSIS
        Scans a group of computers for installed applications and exports results to .csv/.xlsx - one per computer.

    .DESCRIPTION
        Scan-SoftwareInventory can handle a single string hostname as a target, a single string filepath to hostname list, or an array/arraylist of hostnames.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .PARAMETER Outputfile
        A string used to create the output .csv and .xlsx files. If not specified, a default filename is created.

    .EXAMPLE
        Scan-SoftwareInventory -TargetComputer "t-client-28" -Title "tclient-28-details"

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
        [string]$OutputFile
    )
    ## 1. Define title, date variables
    ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
    ## 3. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
    ## 4. Create empty results container
    BEGIN {
        ## 1. Define title, date variables
        $REPORT_TITLE = 'SoftwareScan'
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
    }
    ## Scan the applications listed in three registry locations:
    ## 1. HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall
    ## 2. HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall
    ## 3. HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
    PROCESS {
        if ($TargetComputer) {
            if ($Targetcomputer -eq '127.0.0.1') {
                $TargetComputer = $env:COMPUTERNAME
            }
            ## test with ping:
            $pingreply = Test-Connection $TargetComputer -Count 1 -Quiet
            if ($pingreply) {
                $target_software_inventory = invoke-command -computername $targetcomputer -scriptblock {
                    $registryPaths = @(
                        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
                        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
                    )
                    foreach ($path in $registryPaths) {
                        $uninstallKeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                        # Skip if the registry path doesn't exist
                        if (-not $uninstallKeys) {
                            continue
                        }
                        # Loop through each uninstall key and display the properties
                        foreach ($key in $uninstallKeys) {
                            $keyPath = Join-Path -Path $path -ChildPath $key.PSChildName
                            $displayName = (Get-ItemProperty -Path $keyPath -Name "DisplayName" -ErrorAction SilentlyContinue).DisplayName
                            $uninstallString = (Get-ItemProperty -Path $keyPath -Name "UninstallString" -ErrorAction SilentlyContinue).UninstallString
                            $version = (Get-ItemProperty -Path $keyPath -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
                            $publisher = (Get-ItemProperty -Path $keyPath -Name "Publisher" -ErrorAction SilentlyContinue).Publisher
                            $installLocation = (Get-ItemProperty -Path $keyPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
                            $productcode = (Get-ItemProperty -Path $keyPath -Name "productcode" -ErrorAction SilentlyContinue).productcode
                            $installdate = (Get-ItemProperty -Path $keyPath -Name "installdate" -ErrorAction SilentlyContinue).installdate
            
                            if (($displayname -ne '') -and ($null -ne $displayname)) {

                                $obj = [pscustomobject]@{
                                    DisplayName     = $displayName
                                    UninstallString = $uninstallString
                                    Version         = $version
                                    Publisher       = $publisher
                                    InstallLocation = $installLocation
                                    ProductCode     = $productcode
                                    InstallDate     = $installdate
                                }
                                $obj    
                            }        
                        }
                    } 
                } | Select * -ExcludeProperty RunspaceId, PSShowComputerName
                $results.add($target_software_inventory) | out-null
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $targetcomputer is not responding to ping." -Foregroundcolor Red
            }
        }
    }

    ## 1. Get list of unique computer names from results - use it to sort through all results to create a list of apps for 
    ##    a specific computer, output apps to report, then move on to next iteration of loop.
    END {
        if ($results) {
            ## 1. get list of UNIQUE pscomputername s from the results - a file needs to be created for EACH computer.
            $unique_computers = $results.pscomputername | select -Unique

            ForEach ($single_computer_name in $unique_computers) {
                # get that computers apps
                $apps = $results | where-object { $_.pscomputername -eq $single_computer_name }
                if ($outputfile.tolower() -eq 'n') {
                    $apps | out-gridview -Title "$single_computer_name Apps"
                }
                else {
                    # create the full filepaths
                    $output_filepath = "$outputfile-$single_computer_name"
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting files for $single_computername to $output_filepath."

                    $apps | Export-Csv -Path "$outputfile-$single_computer_name.csv" -NoTypeInformation
                    ## Try ImportExcel
                    try {
                        ## xlsx attempt:
                        $params = @{
                            AutoSize             = $true
                            TitleBackgroundColor = 'Blue'
                            TableName            = "$REPORT_DIRECTORY"
                            TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                            BoldTopRow           = $true
                            WorksheetName        = "$single_computer_name Apps"
                            PassThru             = $true
                            Path                 = "$Outputfile.xlsx" # => Define where to save it here!
                        }
                        $Content = Import-Csv "$outputfile-$single_computer_name.csv"
                        $xlsx = $Content | Export-Excel @params
                        $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                        $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                        Close-ExcelPackage $xlsx
                    }
                    catch {
                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
                    }
                }
            }
            Invoke-Item "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\"

        }
        Read-Host "`nPress [ENTER] to return results."
        return $results
    }
}

