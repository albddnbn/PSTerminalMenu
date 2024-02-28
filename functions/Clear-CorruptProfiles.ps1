function Clear-CorruptProfiles {
    <#
    .SYNOPSIS
        Attempts to clean any temp user folders found on target machines, and reports on results.
        Clear-CorruptProfiles uses the Perform_deletions parameter to determine if it should actually perform deletions, or just generate a report on what it WOULD do..

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER Perform_deletions
        'enable'      - script will delete user folders and files on target computers.
        Anything else - script will not delete user folders and files on target computers.

    .EXAMPLE
        Run without making changes to filesystems / deleting profiles or folders
        Clear-CorruptProfiles.ps1 -TargetComputer "t-client-" -Perform_deletions "n"
        Clear-CorruptProfiles.ps1 -TargetComputer "t-client-"

    .EXAMPLE
        Run and make changes to filesystems / delete profiles or folders
        Clear-CorruptProfiles.ps1 -TargetComputer "t-client-" -Perform_deletions "enable"

    .NOTES
        This script is a wrapper for the ./localscripts/Clear-CorruptProfiles.ps1 script.
        Clear-CorruptProfiles can be run locally on a single computer to clear out temporary folders.        
        02-18-2024 - Wrapper will not work outside of Terminal menu without edits, script in localscripts will work.
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
        [string]$Perform_deletions
    )
    ## 1. Set Report Title and date variables
    ## 2. Handle Perform_deletions parameter to decide whether to delete folders or just record findings.
    ## 2.5 Allow user to acknowledge deletions setting before continuing.
    ## 3. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
    ## 4. Create output/report filepath
    ## 5. Make sure Clear-CorruptProfiles.ps1 is found in ./localscripts
    BEGIN {
        $OUTPUTFILE = ''

        ## 1. Set Report Title and date variables
        $REPORT_TITLE = 'TempProfiles' # used to create the output filename, .xlsx worksheet title, and folder name inside the report\yyyy-MM-dd folder for today
        $thedate = Get-Date -Format 'yyyy-MM-dd'

        ## 2. Handle Perform_deletions parameter to decide whether to delete folders or just record findings.
        if ($Perform_deletions.ToLower() -like "enable*") {
            $whatif_setting = $false
            Write-Host "Deletions ENABLED - script will delete files/folders on target computers." -Foregroundcolor Yellow

        }
        else {
            $whatif_setting = $true
            Write-Host "Deletions DISABLED - script won't delete files/folders on target computers." -Foregroundcolor Green

        }

        ## 2.5 Allow user to acknowledge deletions setting before continuing.
        Read-Host "Press enter to continue"
        ## 3. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
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

        ## 4. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $str_title_var = "TempProfiles"
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

        ## 5. Make sure Clear-CorruptProfiles.ps1 is found in ./localscripts
        $get_corrupt_profiles_ps1 = Get-ChildItem -Path "$env:LOCAL_SCRIPTS" -Filter "Clear-CorruptProfiles.ps1" -File -ErrorAction SilentlyContinue
        if (-not $get_corrupt_profiles_ps1) {
            Write-host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
            Write-Host "Clear-CorruptProfiles.ps1 script not found in $env:LOCAL_SCRIPTS." -Foregroundcolor Red
            return
        }

        ## Create empty results container
        $results = [system.collections.arraylist]::new()
    }
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responsive, scan for temp profiles, cleanup if specified.
    PROCESS {
        ## 1.
        if ($Targetcomputer) {
            ## 2.
            $pingreply = Test-Connection $TargetComputer -Count 1 -Quiet
            if ($pingreply) {
                ## 3.
                $temp_profile_search = Invoke-Command -ComputerName $TargetComputer -FilePath "$($get_corrupt_profiles_ps1.fullname)" -ArgumentList $whatif_setting
            
                if ($temp_profile_search) {
                    $temp_profile_search = $temp_profile_search | Select * -ExcludeProperty RunspaceID, PSShowComputerName
                    $results.Add($temp_profile_search) | Out-null
                }
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer is offline." -Foregroundcolor Yellow
            }
        }
    }
    ## 1. If results - output to report or terminal.
    END {
        if ($results) {
            ## Sort the results
            if ($outputfile.tolower() -eq 'n') {
                # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
                if ($results.count -le 2) {
                    $results | Format-List
                    # $results | Out-GridView
                }
                else {
                    $results | out-gridview
                }
            }
            else {
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
                        WorksheetName        = 'TempProfiles'
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
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "Press enter to continue."
    }
}
