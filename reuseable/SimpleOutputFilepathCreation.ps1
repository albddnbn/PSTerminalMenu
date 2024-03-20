if (-not $env:PSMENU_DIR) {
    $env:PSMENU_DIR = pwd
}
## create simple output path to reports directory
$thedate = Get-Date -Format 'yyyy-MM-dd'
$DIRECTORY_NAME = ''
$OUTPUT_FILENAME = ''
if (-not (Test-Path "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME" -ErrorAction SilentlyContinue)) {
    New-Item -Path "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME" -ItemType Directory -Force | Out-Null
}

$counter = 0
do {
    $output_filepath = "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME\$OUTPUT_FILENAME-$counter.txt"
} until (-not (Test-Path $output_filepath -ErrorAction SilentlyContinue))


## Append text to file here:
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " | Out-File -FilePath $output_filepath -Append
$TargetComputer | Out-File -FilePath $output_filepath -Append


## then open the file:
Invoke-Item "$output_filepath"
