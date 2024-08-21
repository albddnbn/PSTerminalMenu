function Get-OutputFileString {
    <#
            .SYNOPSIS
                Takes input values for part of the filename, the root directory, subfolder title, and whether it should 
                b
                e in the reports or executables directory, and returns an acceptable filename.
        #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TitleString,
        [Parameter(Mandatory = $true)]
        [string]$Rootdirectory,
        [string]$FolderTitle,
        [switch]$ReportOutput,
        [switch]$ExecutableOutput
    )
    ForEach ($file_ext in @('.csv', '.xlsx', '.ps1', '.exe')) {
        Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Checking for file extension: $file_ext."
        $TitleString = $TitleString -replace $file_ext, ''
        Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Removed file extension, TitleString is now: $TitleString."
    }

    $thedate = Get-Date -Format 'yyyy-MM-dd'

    # create outputfolder
    if ($Reportoutput) {
        $subfolder = 'reports'
    }
    elseif ($ExecutableOutput) {
        $subfolder = 'executables'
    }

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Subfolder determined to be: $subfolder."

    $outputfolder = "$Rootdirectory\$subfolder\$thedate\$FolderTitle"

    if (-not (Test-Path $outputfolder)) {
        Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find folder at: $outputfolder, creating it now."
        New-Item $outputfolder -itemtype 'directory' -force | Out-null
    }
    $filename = "$TitleString-$thedate"
    $full_output_path = "$outputfolder\$filename"
    # make sure outputfiles dont exist
    if ($ReportOutput) {
        $x = 0
        while ((Test-Path "$full_output_path.csv") -or (Test-Path "$full_output_path.xlsx")) {
            $x++
            $full_output_path = "$outputfolder\$filename-$x"
        }
    }
    elseif ($ExecutableOutput) {
        $x = 0
        while ((Test-Path "$full_output_path.ps1") -or (Test-Path "$full_output_path.exe")) {
            $x++
            $full_output_path = "$outputfolder\$filename-$x"
        }
    }

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Full output path determined to be: $full_output_path."

    return $full_output_path
}