function Scan-ForAppOrFilePath {
    <#
    .SYNOPSIS
        Scan a group of computers for a specified file/folder or application, and output the results to a .csv and .xlsx report.

    .DESCRIPTION
        The script searches application DisplayNames when the -type 'app' argument is used, and searches for files/folders when the -type 'path' argument is used.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER SearchType
        The type of search to perform. 
        This can be either 'app' or 'path'. 
        If 'app' is specified, the script will search for the specified application in the registry. 
        If 'path' is specified, the script will search for the specified file/folder path on the target's filesystem.

    .PARAMETER Item
        The item to search for. 
        If the -SearchType 'app' argument is used, this should be the application's DisplayName. 
        If the -SearchType 'path' argument is used, this should be the path to search for, Ex: C:\users\public\test.txt.

    .PARAMETER OutputFile
        Used to create the output filename/path if supplied.

    .EXAMPLE
        Scan-ForAppOrFilePath -ComputerList 't-client-01' -SearchType 'app' -Item 'Microsoft Teams' -outputfile 'teams'

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
        [Parameter(Mandatory = $true)]
        [ValidateSet('Path', 'App', 'File', 'Folder')]
        [String]$SearchType,
        [Parameter(Mandatory = $true)]
        [String]$Item,
        [String]$Outputfile
    )
    ## 1. Set date
    ## 2. Handle targetcomputer if not submitted through pipeline
    ## 3. Create output filepath, clean any input file search paths that are local,  
    ## and handle TargetComputer input / filter offline hosts.
    BEGIN {
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

        ## 3. Outputfile handling - either create default, create filenames using input - report files are mandatory 
        ##    in this function.
        $str_title_var = "$SearchType-scan"
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
                        $outputfile = "reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$([string]$iterator_var)"
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
        
        ## Collecting the results
        $results = [System.Collections.ArrayList]::new()
    }
    ## 1/2. Check Targetcomputer for null/empty values and test ping.
    ## 3. If machine was responsive, check for file/folder or application, add to $results.
    ##    --> If searching for filepaths - creates object with some details / file attributes
    ##    --> If searching for apps - creates object with some details / app attributes
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1.
            if ($single_computer) {

                ## 2. Test with ping first:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    ## File/Folder search
                    if (@('path', 'file', 'folder') -contains $SearchType.ToLower()) {

                        $search_result = Invoke-Command -ComputerName $single_computer -ScriptBlock {
                            $obj = [PSCustomObject]@{
                                Name           = $env:COMPUTERNAME
                                Path           = $using:item
                                PathPresent    = $false
                                PathType       = $null
                                LastWriteTime  = $null
                                CreationTime   = $null
                                LastAccessTime = $null
                                Attributes     = $null
                            }
                            $GetSpecifiedItem = Get-Item -Path "$using:item" -ErrorAction SilentlyContinue
                            if ($GetSpecifiedItem.Exists) {
                                $details = $GetSpecifiedItem | Select FullName, *Time, Attributes, Length
                                $obj.PathPresent = $true
                                if ($GetSpecifiedItem.PSIsContainer) {
                                    $obj.PathType = 'Folder'
                                }
                                else {
                                    $obj.PathType = 'File'
                                }
                                $obj.LastWriteTime = $details.LastWriteTime
                                $obj.CreationTime = $details.CreationTime
                                $obj.LastAccessTime = $details.LastAccessTime
                                $obj.Attributes = $details.Attributes
                            }
                            else {
                                $obj.PathPresent = "Filepath not found"
                            }
                            $obj
                        }  | Select PSComputerName, * -ExcludeProperty RunspaceId, PSshowcomputername -ErrorAction SilentlyContinue
                    }
                    ## Application search
                    elseif ($SearchType -eq 'App') {

                        $search_result = Invoke-Command -ComputerName $single_computer -Scriptblock {
                            # $app_matches = [System.Collections.ArrayList]::new()
                            # Define the registry paths for uninstall information
                            $registryPaths = @(
                                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
                                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
                            )
                            $obj = $null
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
                                    if ($displayName -like "*$using:Item*") {
                                        $uninstallString = (Get-ItemProperty -Path $keyPath -Name "UninstallString" -ErrorAction SilentlyContinue).UninstallString
                                        $version = (Get-ItemProperty -Path $keyPath -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
                                        $publisher = (Get-ItemProperty -Path $keyPath -Name "Publisher" -ErrorAction SilentlyContinue).Publisher
                                        $installLocation = (Get-ItemProperty -Path $keyPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
                                        # $productcode = (Get-ItemProperty -Path $keyPath -Name "productcode" -ErrorAction SilentlyContinue).productcode
                                        $installdate = (Get-ItemProperty -Path $keyPath -Name "installdate" -ErrorAction SilentlyContinue).installdate

                                        $obj = [PSCustomObject]@{
                                            ComputerName    = $env:COMPUTERNAME
                                            AppName         = $displayName
                                            AppVersion      = $version
                                            InstallDate     = $installdate
                                            InstallLocation = $installLocation
                                            Publisher       = $publisher
                                            UninstallString = $uninstallString
                                        }
                                        $obj
                                    }
                                }
                            }
                            if ($null -eq $obj) {
                                $obj = [PSCustomObject]@{
                                    ComputerName    = $single_computer
                                    AppName         = "No matching apps found for $using:Item"
                                    AppVersion      = $null
                                    InstallDate     = $null
                                    InstallLocation = $null
                                    Publisher       = $null
                                    UninstallString = "No matching apps found"
                                }
                                $obj
                            }
                        } | Select PSComputerName, * -ExcludeProperty RunspaceId, PSShowComputerName -ErrorAction SilentlyContinue

                        # $search_result
                        # read-host "enter"
                    }
                    ForEach ($single_result_obj in $Search_result) {
                        $results.add($single_result_obj) | out-null
                    }
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is offline, skipping." -ForegroundColor Yellow
                }
            }
        }
    }
    ## 1. Output findings (if any) to report files or terminal
    END {
        if ($results) {
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
                    WorksheetName        = "$SearchType-Search"
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
