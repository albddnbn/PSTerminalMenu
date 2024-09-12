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

    .PARAMETER SkipOccupiedComputers
        'y' is default - script will skip computers with users logged in.
        Anything else - script will run on computers with users logged in.

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
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$Perform_deletions,
        [string]$SkipOccupiedComputers = 'y'
    )

    ## 1. Set date and report title variables to be used in output filename creation
    ## 2. Check for clear-corruptprofiles.ps1 script in ./localscripts
    ## 3. Assign 'perform_deletions' a boolean value
    ## 4. Handle Targetcomputer if not supplied through pipeline
    ## 5. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
    ## 6. Create empty results container
    BEGIN {
        if ($SkipOCcupiedComputers -eq '') {
            $SkipOccupiedComputers = 'y'
        }
        ## 1. Set date and report title variables to be used in output filename creation
        $REPORT_TITLE = 'TempProfiles' # used to create the output filename, .xlsx worksheet title, and folder name inside the report\yyyy-MM-dd folder for today
        $thedate = Get-Date -Format 'yyyy-MM-dd'

        ## 2. Check for clear-corruptprofiles.ps1 script in ./localscripts
        $get_corrupt_profiles_ps1 = Get-ChildItem -Path "$env:LOCAL_SCRIPTS" -Filter "Clear-CorruptProfiles.ps1" -File -ErrorAction SilentlyContinue
        if (-not $get_corrupt_profiles_ps1) {
            Write-host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
            Write-Host "Clear-CorruptProfiles.ps1 script not found in $env:LOCAL_SCRIPTS." -Foregroundcolor Red
            return
        }

        ## 3. Perform_deletions and get use acknowledgement before proceeding
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
        if ($Perform_deletions.ToLower() -like "enable*") {
            $whatif_setting = $false
            Write-Host "Deletions ENABLED - script will delete files/folders on target computers." -Foregroundcolor Yellow
        }
        else {
            $whatif_setting = $true
            Write-Host "Deletions DISABLED - script won't delete files/folders on target computers." -Foregroundcolor Green
        }
        # read-host "Press enter to acknowledge perform_deletions value."

        ## 4. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
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

        ## 5. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $str_title_var = "TempProfiles"

        if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
            $REPORT_DIRECTORY = "$str_title_var"
            $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
            $iterator_var = 0
            while ($true) {
                $outputfile = "reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$thedate"
                if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                    $iterator_var++
                    $outputfile += "$([string]$iterator_var)"
                }
                else {
                    break
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
        

        ## 6. Create empty results container
        $results = [system.collections.arraylist]::new()
    }
    ## 1. Check Targetcomputer for null/empty values
    ## 2. Ping test
    ## 3. If responsive, run Clear-CorruptProfiles.ps1 script on target computer
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            ## 1.
            if ($single_computer) {

                ## 2. test with ping:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {

                    if ($SkipOccupiedComputers.ToLower() -eq 'y') {
                        $check_for_user = Invoke-Command -Computername $single_computer -scriptblock {
                            (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
                        }
                        if ($check_for_user) {
                            $check_for_user = $check_for_user -replace "$env:USERDOMAIN\\", ''
                            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -Nonewline
                            Write-Host "$check_for_user is logged in to $single_computer, skipping this computer." -Foregroundcolor Yellow
                            continue
                        }
                    }
                    ## 3. Run script
                    $temp_profile_results = Invoke-Command -ComputerName $single_computer -FilePath "$($get_corrupt_profiles_ps1.fullname)" -ArgumentList $whatif_setting
                    $results.add($temp_profile_results) | Out-Null
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
                    Write-Host "$single_computer is offline." -Foregroundcolor Red
                }
            }
        }
    }
    ## 1. If there are any results - output them to report .csv/.xlsx files
    END {
        if ($results) {
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
            ## Open the report folder
            Invoke-item "$($outputfile | split-path -Parent)"
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }

        ## This is included for menu purposes, so there's a pause before the function ends and terminal window reverts
        ## to opening menu options.
        # read-host "Press enter to return results."
        return $results
    }
}
