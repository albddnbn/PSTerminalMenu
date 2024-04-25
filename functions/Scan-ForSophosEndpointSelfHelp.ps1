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
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer
    )
    ## Targetcomputer handling (if not supplied through pipeline), create output filepath, and create results container.
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
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
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
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
        ## Create output filepath
        $REPORT_DIRECTORY = 'SophosScan'
        if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
            $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
            $iterator_var = 0
            while ($true) {
                $outputfile = "$REPORT_DIRECTORY-$thedate"
                if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                    $iterator_var++
                    $outputfile += "-$([string]$iterator_var)"
                }
                else {
                    break
                }
            }
            ## Try to get output directory path and make sure it exists.
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
        ## Collecting the results
        $results = [system.collections.arraylist]::new()
    }

    ## Searches several registry locations for Sophos Endpoint Self Help display name
    ## Targeted search in registry would be more efficient.
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            if ($single_computer) {

                ## test with ping first:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    # check target remote computers and get the sophos app object list from them
                    $sophos_endpoint_check = Invoke-Command -computername $single_computer -scriptblock {

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
                    }  | Select PSComputerName, * -ExcludeProperty RunspaceId, PSshowcomputername -ErrorAction SilentlyContinue

                    $results.Add($sophos_endpoint_check)
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is not responding to ping, skipping." -Foregroundcolor Yellow
                }
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
            ## Try opening directory (that might contain xlsx and csv reports), default to opening csv which should always exist
            try {
                Invoke-item "$($outputfile | split-path -Parent)"
            }
            catch {
                # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not open output folder." -Foregroundcolor Yellow
                Invoke-item "$outputfile.csv"
            }            
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        # Read-Host "`nPress [ENTER] to return results."
        return $results
    }
}
