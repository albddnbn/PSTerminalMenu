Function Output-Reports {
    <#
    .SYNOPSIS
        Creates a .csv and/or .xlsx file, using filename supplied in parameter..
        Should definitely be able to generate the .csv with built-in Powershell cmdlets, but script will only attempt to import/install the ImportExcel module, and then write an error message to terminal in the event of a failure.
    
    .PARAMETER Filepath
        The path to the file to be created, should not include any file extension.

        #>
    param(
        $Filepath,
        $Content,
        $ReportTitle,
        [bool]$CSVFile = $true,
        [bool]$XLSXFile = $true
    )
    write-host "$content"
    # chops any file extension off of filepath
    ForEach ($file_ext in @('pdf', 'html', 'txt', 'csv', 'xlsx')) {
        $Filepath = $Filepath -replace "\.$file_ext", ''
    }

    $files_created = @()
    if ($CSVFile) {
        $Content | Export-CSV "$Filepath.csv" -NoTypeInformation -Force

        $files_created += "CSV"
    }

    if ($XLSXFile) {
        # look for the importexcel powershell module
        $CheckForimportExcel = Get-InstalledModule -Name 'importexcel' -ErrorAction SilentlyContinue
        if (-not $CheckForimportExcel) {
            try {
                $check_internet_connection = Test-NetConnection Google.com -ErrorAction SilentlyContinue
                if ($check_internet_connection.PingSucceeded) {
                    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
                        Write-Host "Installing nuget."
                        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
                        $continue_creating_xlsx = $false
                    }
                    else {
                        Install-PackageProvider -Name NuGet -Force
                    }
                    Install-Module -Name ImportExcel -Force
                    $continue_creating_xlsx = $true
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
                    Write-Host "No connection to internet detected, skipping .xlsx file creation." -ForegroundColor Red
                    $continue_creating_xlsx = $false
                }
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
                Write-Host "Unable to install ImportExcel module, skipping .xlsx file creation." -ForegroundColor Red
                $continue_creating_xlsx = $false

            }
        }
        else {
            $continue_creating_xlsx = $true

        }
        if ($continue_creating_xlsx) {
            $params = @{
                AutoSize             = $true
                TitleBackgroundColor = 'Blue'
                TableName            = "$ReportTitle"
                TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                BoldTopRow           = $true
                WorksheetName        = 'Users'
                PassThru             = $true
                Path                 = "$Outputfile.xlsx" # => Define where to save it here!
            }
            $xlsx = $Content | Export-Excel @params
            $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
            $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
            Close-ExcelPackage $xlsx

            # $report_dir_path = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\"

            # Explorer.exe $report_dir_path
            Invoke-Item "$outputfile.xlsx"
            $files_created += "XLSX"
        }
    }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Created $($files_created -join ' and ') file(s) at: $Filepath" -foregroundcolor green

}

function Sound-Alarm {
    param(
        $absolute_wav_path
    )
    if ($absolute_wav_path -eq $null) {
        # play default windows 'gong'
        Write-Host "`a"
    }
    else {
        $play_wav = [System.Media.SoundPlayer]::new()
        $play_wav.SoundLocation = $absolute_wav_path
        $play_wav.PlaySync()
    }

}