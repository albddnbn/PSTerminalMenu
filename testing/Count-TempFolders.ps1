function Count-TempFolders {
    <#
    .SYNOPSIS
        Cycles through target computers, counting the number of temporary folders on each computer.
        Temporary folders are determined using the $env:USERDOMAIN variable.
        If a user folder contains the $env:USERDOMAIN, it's considered a temporary folder.
        Other domains may have different temp folder suffix settings, so unsure if this will work for other domains.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER Outputfile
        Path to output file, if left blank - default filename will be used based on function name and date.
    
    .NOTES
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [Parameter(
            Mandatory = $true
        )]
        [String]$Outputfile,
        [String]$TempFolderSuffix = $env:USERDNSDOMAIN
    )
    BEGIN {
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
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

        ## 2. output filepath creation

        $str_title_var = "TempProfiles"

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
                    $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$thedate"
                    if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                        $iterator_var++
                        $outputfile += "$([string]$iterator_var)"
                    }
                    else {
                        break
                    }
                }
            }
            ## Try to get output directory path and make sure it exists.
            try {
                $outputdir = $outputfile | split-path -parent
                if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                    New-Item -ItemType Directory -Path $($outputfile | split-path -parent) | Out-Null
                }
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory." -Foregroundcolor Yellow
            }
        }
        
        $results = [system.collections.arraylist]::new()
    }
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            if (Test-Path "\\$single_computer\c$" -erroraction SilentlyContinue) {
                # get all temp profiles on computer / count / create object
                $temp_profile_folders = Get-Childitem -Path "\\$single_computer\c$\Users" -Filter "*.DTCC*" -Directory -ErrorAction SilentlyContinue
                ## create object with  user, computer name, folder count to object, add to arraylist
                ForEach ($single_folder in $temp_profile_folders) {

                    $foldername = $single_folder.name

                    $username = $foldername.split('.')[0]
                    ## if the user and computer combo are not in results - add with count of 1
                    if ($results | Where-Object { ($_.User -eq $username) -and ($_.Computer -eq $single_computer) }) {
                        $results | Where-Object { ($_.User -eq $username) -and ($_.Computer -eq $single_computer) } | ForEach-Object { $_.FolderCount++ }
                        Write-Host "Found existing entry for $username and $single_computer increased FolderCount by 1."
                    }
                    else {
                        $temp_profile = [pscustomobject]@{
                            User        = $username
                            Computer    = $single_computer
                            FolderCount = 1
                        }
                        $results.Add($temp_profile) | Out-Null
                        Write-Host "Added new entry for $username and $single_computer."
                    }
                }
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is not accessible." -Foregroundcolor Yellow
             
            }
        }
    }
    END {
        
        if ($results) {
            ## 1. Sort any existing results by computername
            $results = $results | sort -property pscomputername
            ## 2. Output to gridview if user didn't choose report output.
            if ($outputfile.tolower() -eq 'n') {
                $results | out-gridview -title $str_title_var
            }
            else {
                ## 3. Create .csv/.xlsx reports if possible
                $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                ## Try ImportExcel
                try {
                    $params = @{
                        AutoSize             = $true
                        TitleBackgroundColor = 'Blue'
                        TableName            = "$str_title_var"
                        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                        BoldTopRow           = $true
                        WorksheetName        = "$str_title_var"
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
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
            "No results to output from Count-TempFolders at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')." | out-file "$outputfile.txt"
            Invoke-Item "$outputfile.txt"
        }
        return $results    
    }
}
