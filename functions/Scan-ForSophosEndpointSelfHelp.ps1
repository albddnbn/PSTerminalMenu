function Scan-ForSophosEndpointSelfHelp {
    <#
    .SYNOPSIS
        Scans target computer(s) for installed applications with  'Sophos Endpoint Self Help' applications

    .DESCRIPTION
        Looks in the registry for any installed applications with displaynames: 'Sophos Endpoint Self Help' - this is an important part of current Sophos installations, up to date version is important.

    .PARAMETER Targetcomputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .EXAMPLE
        Scan-ForSophosEndpointSelfHelp -Targetcomputer 't-client-01'

    .EXAMPLE
        Scan all computers in the Stanton open computer lab:
        Scan-ForSophosEndpointSelfHelp -Targetcomputer 't-client-'

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
        $Targetcomputer
    )
    ## Targetcomputer handling (if not supplied through pipeline), create output filepath, and create results container.
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
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
        ## Create output filepath
        $REPORT_DIRECTORY = 'SophosScan'
        if (Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) {
            $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
            $iterator_var = 0
            while ($true) {
                $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$REPORT_DIRECTORY-$thedate"
                if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                    $iterator_var++
                    $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$REPORT_DIRECTORY-$([string]$iterator_var)"
                }
                else {
                    break
                }
            }
        }
        ## Collecting the results
        $results = [system.collections.arraylist]::new()
    }

    ## Searches several registry locations for Sophos Endpoint Self Help display name
    ## Targeted search in registry would be more efficient.
    PROCESS {
        if ($TargetComputer) {

            ## test with ping first:
            $pingreply = Test-Connection $TargetComputer -Count 1 -Quiet
            if ($pingreply) {
                # check target remote computers and get the sophos app object list from them
                $sophos_endpoint_check = Invoke-Command -computername $TargetComputer -scriptblock {

                    # Define the registry paths for uninstall information
                    $registryPaths = @(
                        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
                        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
                    )
                    # Loop through each registry path and retrieve the list of subkeys
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
                            if ($displayName -eq 'Sophos Endpoint Self Help') {
                                $uninstallString = (Get-ItemProperty -Path $keyPath -Name "UninstallString" -ErrorAction SilentlyContinue).UninstallString
                                $version = (Get-ItemProperty -Path $keyPath -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
                                $publisher = (Get-ItemProperty -Path $keyPath -Name "Publisher" -ErrorAction SilentlyContinue).Publisher
                                $installLocation = (Get-ItemProperty -Path $keyPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
                                $productcode = (Get-ItemProperty -Path $keyPath -Name "productcode" -ErrorAction SilentlyContinue).productcode
		
		
                                $obj = [pscustomobject]@{
                                    DisplayName     = $DisplayName
                                    Uninstallstring = $uninstallString
                                    DisplayVersion  = $version
                                    Publisher       = $publisher
                                    ProductCode     = $productcode
                                    InstallLocation = $installlocation
                                }
                                $obj
                            }
                        }
                    }
                    if (-not $obj) {
                        $obj = [pscustomobject]@{
                            DisplayName     = "No Sophos Endpoint Self Help found"
                            Uninstallstring = $uninstallString
                            DisplayVersion  = $version
                            Publisher       = $publisher
                            ProductCode     = $productcode
                            InstallLocation = $installlocation
                        }
                        $obj
                    }
                }  | Select * -ExcludeProperty RunspaceId, PSShowComputerName

                $results.Add($sophos_endpoint_check)
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer is not responding to ping, skipping." -Foregroundcolor Yellow
            }
        }
    }
    
    ## Either export to xlsx and csv, or just csv.
    END {
        if ($results) {
            ## Sort the results
            $results = $results | sort -property pscomputername

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
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "`nPress [ENTER] to return results."
        return $results
    }
}
