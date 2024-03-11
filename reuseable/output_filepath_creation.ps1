## 2. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
## External variables: $outputfile (string containing path to output file, or 'n' for no output file(s))
## Directions: Set $str_title_var variable to the title or subject of the function's output.
## Ex: "CurrentUsers" is used for the Get-CurrentUsers function.
## If the function is being run with the menu (has access to the get-outputfilestring utlity function, and the PSMENU_DIR environment variable), it will use the utility function to create the output file.
## If it doesn't - the output file will be created in the current directory, or the directory specified in the $outputfile variable.
$str_title_var = "CurrentUsers"
if ($Outputfile.tolower() -eq 'n') {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
}
else {
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
}
