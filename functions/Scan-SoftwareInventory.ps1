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
    Additional notes about the function.
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
    BEGIN {
        $REPORT_TITLE = 'SoftwareScan'
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
            return
        }

        if ($TargetComputer.count -lt 20) {
            ## If the Get-LiveHosts utility command is available
            if (Get-Command -Name Get-LiveHosts -ErrorAction SilentlyContinue) {
                $TargetComputer = Get-LiveHosts -TargetComputerInput $TargetComputer
            }
        }

        if ($outputfile.tolower() -ne 'n') {
            ## Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
            if (Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) {
                if ($Outputfile.toLower() -eq '') {
                    $outputfile = "AppScan-$thedate"
                }

                $outputfile = Get-OutputFileString -TitleString $outputfile -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                if ($outputfile.tolower() -eq '') {
                    $outputfile = "AppScan-$thedate"
                }
            }
        }

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning software scan on" -NoNewline
        Write-Host " $TargetComputer..." -Foregroundcolor Green


        ## Collections container:
        $all_results = [system.collections.generic.list[pscustomobject]]::new()
    }


    ###########################################################################
    ## Scan the applications listed in three registry locations:
    ## 1. HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall
    ## 2. HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall
    ## 3. HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
    ###########################################################################
    PROCESS {
        $results = invoke-command -computername $targetcomputer -scriptblock {
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

        $all_results.add($results) | out-null
    }

    ## Get list of unique computer names from results - use it to sort through all results to create a list of apps for 
    ## a specific computer, output apps to report, then move on to next iteration of loop.
    END {
        # get list of UNIQUE pscomputername s from the results - a file needs to be created for EACH computer.
        $unique_computers = $all_results.pscomputername | select -Unique

        ForEach ($single_computer_name in $unique_computers) {
            # get that computers apps
            $apps = $all_results | where-object { $_.pscomputername -eq $single_computer_name }
            # create the full filepaths
            $output_filepath = "$outputfile-$single_computer_name"
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting files for $single_computername to $output_filepath."
            if ($outputfile.tolower() -ne 'n') {
                # export to csv and .xlsx
                Output-Reports -Filepath "$output_filepath" -Content $apps -ReportTitle "SoftwareInventory" -CSVFile $true -XLSXFile $true
            } 
            else {
                # just output to terminalW
                $apps | Out-GridView -Title "$single_computer_name Apps"
                Read-Host "Press enter to show next computer."
            }

        }

        try {
            Invoke-Item "$outputfile"
        }
        catch {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Failed to open $outputfile." -Foregroundcolor Red
        }
    }
}
