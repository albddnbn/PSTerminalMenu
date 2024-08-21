## functions that don't return any results still need to have some kind of output for when they are run as jobs
## Required variables: $outputfile variable should be set to output file path, which would normally be an actual report, if there were results..
$FUNCTION_NAME = $MyInvocation.MyCommand

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output from $FUNCTION_NAME." | Out-File -FilePath "$outputfile.csv"

Invoke-Item "$outputfile.csv"
