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

    .PARAMETER ShowMisses
        *Work in progress, should work for apps at least rn - 12-6-23*
        Whether to show missed searches. 
        If the -SearchType 'app' argument is used, this will show any applications that were not found. 
        If the -SearchType 'path' argument is used, this will show any files/folders that were not found.

    .EXAMPLE
        Scan-ForAppOrFilePath -ComputerList 't-client-01' -SearchType 'app' -Item 'Microsoft Teams' -outputfile 'teams'

    .NOTES
        Additional notes about the function
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        $targetcomputer,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Path', 'App', 'File', 'Folder')]
        [String]$SearchType,
        [Parameter(Mandatory = $true)]
        [String]$Item,
        [ValidateSet('y', 'n', 'N', 'Y')]
        [String]$ShowMisses
        # [STring]$Outputfile
    )
    ############################################################################
    ## Create output filepath, clean any input file search paths that are local,  
    ## and handle TargetComputer input / filter offline hosts.
    ############################################################################
    BEGIN {
        $outputfile = ''
        ## If item is a filepath - have to get rid of drive letter and \ since script scans network paths
        if ($Item -match '[A-Za-z]:\\*') {
            $filename_substring = $Item.substring(3)

            $filename_substring = $filename_substring -replace '\\', '-'
            $filename_substring = $filename_substring -split '-'
            $filename_substring = $filename_substring[0]        
        }
        else {
            $filename_substring = $Item
        }

        $REPORT_DIRECTORY = "AppFileScan"

        ## TARGETCOMPUTER HANDLING:
        ## If Targetcomputer is an array or arraylist - it's already been sorted out.
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

        $online_hosts = [system.collections.arraylist]::new()
        ForEach ($single_computer in $TargetComputer) {
            $ping_result = Test-Connection $single_computer -Count 1 -Quiet
            if ($ping_result) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is online."
                $online_hosts.Add($single_computer) | Out-Null
            }
        }
        $TargetComputer = $online_hosts
        # Safety catch to make sure
        if ($null -eq $TargetComputer) {
            # user said to end function:
            return
        }

        ## Outputfile name creation:
        if ($outputfile.tolower() -ne 'n') {
            ## Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
            if (Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) {
                # if ($Outputfile.toLower() -eq '') {
                #     $outputfile = "$($SearchType)scan-$filename_substring"
                # }

                $outputfile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                if ($outputfile.tolower() -eq '') {
                    $outputfile = "$($SearchType)scan-$filename_substring-$thedate"
                }
            }
        }
        ## Collecting the results
        $all_results = [System.Collections.ArrayList]::new()
    }
    #################################################################################
    ## If searching for filepaths - create object with some details / file attributes
    ## If searching for apps - create object with some details / app attributes
    #################################################################################
    PROCESS {
        if (@('path', 'file', 'folder') -contains $SearchType.ToLower()) {

            $results = Invoke-Command -ComputerName $targetcomputer -ScriptBlock {
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
                ## SHOWMISSES variable
                $show_misses = $using:ShowMisses
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
                elseif (($show_misses.tolower()) -eq 'y') {
                    $obj.PathPresent = "Filepath not found"
                }
                $obj
            }  | Select * -ExcludeProperty RunspaceId, PSShowComputerName

            # $misses = $results | where-object { $_.pathpresent -eq 'Filepath not found' }
            # if (($ShowMisses.ToLower() -eq 'n')) {
            #     $results = $results | where-object { $_.pscomputername -notin $misses.pscomputername }
            # }
        }
        elseif ($SearchType -eq 'App') {

            $results = Invoke-Command -ComputerName $targetcomputer -Scriptblock {
                # $app_matches = [System.Collections.ArrayList]::new()
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
                $ShowMissedSearches = $using:ShowMisses
                $ShowMissedSearches = $ShowMissedSearches.ToLower()
                if ($ShowMissedSearches -eq 'y') {
                    if (-not $obj) {
                        $obj = [pscustomobject]@{
                            DisplayName     = "$using:item not found"
                            Uninstallstring = $uninstallString
                            DisplayVersion  = $version
                            Publisher       = $publisher
                            ProductCode     = $productcode
                            InstallLocation = $installlocation
                        }
                        $obj
                    }
                }
            } | Select * -ExcludeProperty RunspaceId, PSShowComputerName
        }
        $results
        $all_results.add($results) | out-null
    }
    ######################################################
    ## Output findings (if any) to report files or terminal
    #######################################################
    END {
        $all_results = $all_results | sort -property pscomputername
        $all_results | export-csv "c:\temp\all_results.csv" -NoTypeInformation
        if ($all_results) {
            ## Sort the results
            if ($outputfile.tolower() -eq 'n') {
                # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
                if ($all_results.count -le 2) {
                    $all_results | Format-List
                    # $all_results | Out-GridView
                }
                else {
                    $all_results | out-gridview
                }
            }
            else {
                if (Get-Command -Name "Output-Reports" -Erroraction SilentlyContinue) {
                    Output-Reports -Filepath "$outputfile" -Content $all_results -ReportTitle "$REPORT_DIRECTORY $thedate" -CSVFile $true -XLSXFile $true
                    Invoke-Item "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\"

                }
                else {
                    $all_results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                    notepad.exe "$outputfile.csv"
                }
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "Press enter to continue."
    }
}

