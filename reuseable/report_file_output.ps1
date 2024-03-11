## if there are any results in the $results variable - will output to gridview if $outputfile='n', otherwise will attempt to create .csv/.xlsx reports.
## External variables: $results (arraylist containing objects), $outputfile (string containing path to output file), $str_title_var (string containing title for output file)
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
                TableName            = $str_title_var
                TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                BoldTopRow           = $true
                WorksheetName        = $str_title_var
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
}
Read-Host "Press enter to return results."
return $results
