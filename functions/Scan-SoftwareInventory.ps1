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
    param (
        $TargetComputer,
        [string]$OutputFile
    )
    
    $REPORT_TITLE = 'SoftwareScan'
    $thedate = Get-Date -Format 'yyyy-MM-dd'

    try {
        $TargetComputer = Get-TargetComputers -TargetComputerInput $TargetComputer
    }
    catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow

        if (Test-Path $TargetComputer -erroraction silentlycontinue) {
            Write-Host "$TargetComputer is a file, getting content to create hostname list."
            $TargetComputer = Get-Content $TargetComputer
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer is not a valid hostname or file path." -Foregroundcolor Red
            return
        }
    }     
    
    $TargetComputer = $TargetComputer | where-object { $_ -ne $null }
    if ($TargetComputer.count -lt 20) {
        $TargetComputer = Get-LiveHosts -TargetComputerInput $TargetComputer
    }
    if ($outputfile -eq '') {
        $OutputFile = Get-OutputFileString -TitleString $REPORT_TITLE -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_TITLE -ReportOutput
    }
    elseif ($outputfile.tolower() -ne 'n') {
        $OutputFile = Get-OutputFileString -TitleString $outputfile -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_TITLE -ReportOutput
    }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning software scan on" -NoNewline
    Write-Host " $TargetComputer..." -Foregroundcolor Green
    $results = invoke-command -computername $targetcomputer -scriptblock {
        # $applications_list = [system.collections.arraylist]::new()

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
                    # $applications_list.add($obj) | out-null
                    $obj    
                }        
            }
        } 
    } | Select * -ExcludeProperty RunspaceId, PSShowComputerName | Sort -property PSComputerName
    # clean up the result arraylist a bit
    # $results = $results | select PSComputerName, DisplayName, Version, Publisher, InstallLocation, ProductCode, InstallDate
    # $results = $results | sort PSComputerName

    # get list of UNIQUE pscomputername s from the results - a file needs to be created for EACH computer.
    $unique_computers = $results.pscomputername | select -Unique

    ForEach ($single_computer_name in $unique_computers) {
        # get that computers apps
        $apps = $results | where-object { $_.pscomputername -eq $single_computer_name }
        # create the full filepaths
        $output_filepath = "$outputfile-$single_computer_name"
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting files for $single_computername to $output_filepath."
        if ($outputfile.tolower() -ne 'n') {
            # export to csv and .xlsx
            Output-Reports -Filepath "$output_filepath" -Content $apps -ReportTitle "SoftwareInventory" -CSVFile $true -XLSXFile $true
        } 
        else {
            # just output to terminalW
            $apps | format-table -autosize
            Read-Host "Press enter to show next computer."
        }

    }

    # open the folder
    Invoke-Item "$env:PSMENU_DIR\reports\$thedate\$REPORT_TITLE\"

}
