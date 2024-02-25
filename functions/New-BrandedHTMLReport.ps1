function New-BrandedHTMLReport {
    <#
    .SYNOPSIS
        Creates branded HTML report, using files from the SupportFiles directory.
        Add a .png file named it-logo.png to the SupportFiles directory to use that logo in report.
        Add url to attempt to download .png file if not found.

    .DESCRIPTION
        Creates a branded HTML report using logo .png file or URL, and specified colors.

    .PARAMETER CSVFilePath
        Path to CSV file.

    .PARAMETER ReportTitle
        String used to create the HTML report title and .html output filename.

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    param (
        [string]$CSVFilePath,
        [string]$ReportTitle
        # ,[string]$LogoUrl = ""
        #[string]$MainColor = "",
        #[string]$SecondaryColor = ""
    )

    $REPORT_DIRECTORY = 'htmlreports'

    # make sure datefolder exists in reports
    $thedate = get-date -format 'yyyy-MM-dd'
    # make sure the date folder exists in reports
    if (-not (Test-path "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY" -ErrorAction SilentlyContinue)) {
        New-Item -Path "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY" -ItemType 'Directory' -Force | Out-Null
    }

    #create outputfile path
    $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$ReportTitle-$thedate.html"

    # ingest csv
    $ObjectArrayList = Import-Csv -Path $CSVFilePath

    # check if it-logo.png is in the current directory:
    $it_logo_png = Get-ChildItem -Path "$env:SUPPORTFILES_DIR" -Filter "it-logo.png" -File -Recurse -ErrorAction SilentlyContinue
    if (-not ($it_logo_png)) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Unable to find it-logo.png in $env:SUPPORTFILES_DIR, attempting to download from $LogoUrl" -ForegroundColor Red
        # download the png from : 
        try {
            Invoke-WebRequest -Uri "$LogoUrl" -OutFile "$env:PSMENU_DIR\reports\resources\it-logo.png"
        }
        catch {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Unable to find it-logo.png from $LogoUrl." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
    else {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($it_logo_png.fullname) in $env:SUPPORTFILES_DIR."
    }

    $formaldate = Get-Date -Format "dddd, MMMM dd, yyyy"

    # copy resources into datefolder
    Copy-Item "$env:PSMENU_DIR\reports\resources" "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY" -recurse -force

    Write-host $($ObjectArrayList | Select -First 1)

    $html_head = @"
    <!DOCTYPE html>
    <html>
    <head>
        <title>$ReportTitle</title>
        <style>
            header {
                display: flex;
                align-items: center;
                padding: 10px;
                background-color: #f1f1f1;
                color: #00A160;
            }
    
            .logo {
                /* width: 50px;
                height: 50px; */
                margin-right: 10px;
            }
    
            .title {
                font-size: 24px;
                font-weight: bold;
                margin: 0;
            }
    
            .subtitle {
                font-size: 16px;
                margin: 0;
            }
    
            table {
                border-collapse: collapse;
                width: 100%;
                max-width: 800px;
                margin: 0 auto;
                margin-top: 2em;
    
            }
    
            th {
                background-color: #00467f;
                color: #fff;
                padding: 10px;
                text-align: left;
                font-size: 18px;
            }
            tr:nth-child(even) {
                background-color: #acd4f1;
            }
    
            tr:nth-child(odd) {
                background-color: #0073c2;
            }
    
            td {
                border: 1px solid #ddd;
                padding: 10px;
            }
        </style>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <title></title>
        <meta name="description" content="">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href=".\resources\w3.css">
    </head>
    
    <body>
        <header class="w3-row-padding">
        <div class="w3-third">
            <img class="logo" src="./resources/it-logo.png" alt="Logo">
            </div>
            <div class="w3-twothird">
                <h1 class="title">$ReportTitle</h1>
                <p class="subtitle">$formaldate</p>
            </div>
        </header>
        <main>
        <div class="w3-container">
        <table>
        <thead>
            <tr>
"@
    # for every property in the first object in the objectarraylist - create a coolumn header
    $ObjectArrayList[0].psobject.properties | ForEach-Object {
        $html_head += @"
                <th>$($_.Name)</th>
"@}

    # end the th and start the actual table content
    $html_head += @"
    </tr>
    </thead>
    <tbody>
"@

    # cycle through the objectarraylist, creating a row for each pscustomobject
    $ObjectArrayList | ForEach-Object {
        $html_head += @"
    <tr>
"@
        # cycle through each property in the pscustomobject
        $_.psobject.properties | ForEach-Object {
            $html_head += @"
        <td>$($_.Value)</td>
"@
        }
    }
    # and close it up
    $html_head += @"
</tbody>
</table>
</div>
</main>
</body>

</html>
"@
    # create output filepath:



    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Outputting the HTML report to: $outputfile" -ForegroundColor Green

    # out the html to file
    $html_head | Out-File -FilePath "$outputfile" -Force

    $ChromeExe = Get-ChildItem -PAth "C:\Program Files\Google\Chrome\Application" -Filter "chrome.exe" -File -Erroraction SilentlyContinue
    if ($ChromeExe) {
        Start-Process "$ChromeExe" -argumentlist """$outputfile"""
    }
    else {
        $msedge = Get-ChildItem -Path "C:\Program Files (x86)\Microsoft\Edge\Application" -Filter "msedge.exe" -File -Recurse -ErrorAction SilentlyContinue
        if ($msedge) {
            Start-Process "$($msedge.fullname)" -argumentlist """$outputfile"""
        }
        else {
            Invoke-Item "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY"
        }
    }
}
