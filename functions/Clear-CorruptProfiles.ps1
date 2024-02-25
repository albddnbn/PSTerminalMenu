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
        $TargetComputer,
        [string]$Perform_deletions
    )


    # VARIABLES ---------------------------------
    $REPORT_TITLE = 'TempProfiles' # used to create the output filename, .xlsx worksheet title, and folder name inside the report\yyyy-MM-dd folder for today
    $thedate = Get-Date -Format 'yyyy-MM-dd'

    # setting whatif
    if ($Perform_deletions.ToLower() -like "enable*") {
        $whatif_setting = $false
    }
    else {
        $whatif_setting = $true
    }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
    if ($whatif_setting) {
        Write-Host "Deletions DISABLED - script won't delete files/folders on target computers." -Foregroundcolor Green
    }
    else {
        Write-Host "Deletions ENABLED - script will delete files/folders on target computers." -Foregroundcolor Yellow
    }

    Read-Host "Press enter to continue"

    # End variable section -----------------------   
    $TargetComputer = $TargetComputer | where-object { $_ -ne $null } # remove blank lines from end of text file
    
    if ($TargetComputer.count -lt 30) {
        $TargetComputer = Get-LiveHosts -TargetComputerInput $TargetComputer
        $Targetcomputer = $TargetComputer
    }

    $TargetComputer = $TargetComputer

    # creating output report is mandatory for this function
    $OutputFile = Get-OutputFileString -TitleString $REPORT_TITLE -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_TITLE -ReportOutput

    # get clear-corruptprofiles.ps1 script
    $get_corrupt_profiles_ps1 = Get-ChildItem -Path "$env:LOCAL_SCRIPTS" -Filter "Clear-CorruptProfiles.ps1" -File -ErrorAction SilentlyContinue
    if (-not $get_corrupt_profiles_ps1) {
        Write-host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
        Write-Host "Clear-CorruptProfiles.ps1 script not found in $env:LOCAL_SCRIPTS." -Foregroundcolor Red
        return
    }

    $results = Invoke-Command -ComputerName $TargetComputer -FilePath "$($get_corrupt_profiles_ps1.fullname)" -ArgumentList $whatif_setting

    if ($results) {
        $results = $results | Select * -ExcludeProperty RunspaceID, PSShowComputerName

        $results | sort -property pscomputername
    
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting results to " -NoNewline
        Write-Host "$outputfile.csv and $outputfile.xlsx" -Foregroundcolor Green

        Output-Reports -filepath "$outputfile" -content $results -ReportTitle $REPORT_TITLE -CSVFile $true -XLSXFile $true
        Invoke-Item "$env:PSMENU_DIR\reports\$thedate\$REPORT_TITLE\"
    }
    else {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
        Write-Host "No temporary user folders found on $($Targetcomputer -join ', ')." -Foregroundcolor Green
    }
    REad-Host "Press enter to continue."
}