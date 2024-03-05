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
        [String]$Item
    )
    ## 1. Set date
    ## 2. Handle targetcomputer if not submitted through pipeline
    ## 3. Create output filepath, clean any input file search paths that are local,  
    ## and handle TargetComputer input / filter offline hosts.
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            if (($TargetComputer -is [System.Collections.IEnumerable]) -and ($TargetComputer -isnot [string[]])) {
                $null
                ## If it's a string - check for commas, try to get-content, then try to ping.
            }
            elseif ($TargetComputer -is [string[]]) {
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
                        write-host "getting AD computer"
                        $TargetComputer = $TargetComputer
                        $TargetComputer = Get-ADComputer -Filter * | Where-Object { $_.DNSHostname -match "^$TargetComputer.*" } | Select -Exp DNShostname
                        $TargetComputer = $TargetComputer | Sort-Object 
                        read-host "target $($Targetcomputer -join ', ')" -ForegroundColor cyan  
                    }
                }
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 3. Outputfile handling - either create default, create filenames using input - report files are mandatory 
        ##    in this function.
        $str_title_var = "$SearchType-scan"
        $REPORT_DIRECTORY = "$str_title_var"
        if (Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) {
            $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
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
        
        ## Collecting the results
        $results = [System.Collections.ArrayList]::new()
    }
    ## 1/2. Check Targetcomputer for null/empty values and test ping.
    ## 3. If machine was responsive, check for file/folder or application, add to $results.
    ##    --> If searching for filepaths - creates object with some details / file attributes
    ##    --> If searching for apps - creates object with some details / app attributes
    PROCESS {
        ## 1.
        if ($TargetComputer) {

            ## 2. Test with ping first:
            $pingreply = Test-Connection $TargetComputer -Count 1 -Quiet
            if ($pingreply) {
                ## File/Folder search
                if (@('path', 'file', 'folder') -contains $SearchType.ToLower()) {

                    $search_result = Invoke-Command -ComputerName $targetcomputer -ScriptBlock {
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
                    }  | Select * -ExcludeProperty RunspaceId, PSShowComputerName
                }
                ## Application search
                elseif ($SearchType -eq 'App') {

                    $search_result = Invoke-Command -ComputerName $targetcomputer -Scriptblock {
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
                                ComputerName    = $TargetComputer
                                AppName         = "No matching apps found for $using:Item"
                                AppVersion      = $null
                                InstallDate     = $null
                                InstallLocation = $null
                                Publisher       = $null
                                UninstallString = "No matching apps found"
                            }
                            $obj
                        }
                    } | Select * -ExcludeProperty RunspaceId, PSShowComputerName
                }

                $results.add($search_result) | out-null
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer is offline, skipping." -ForegroundColor Yellow
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
            Invoke-item "$($outputfile | split-path -Parent)"
            
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "`nPress [ENTER] to return results."
        return $results
    }
}

