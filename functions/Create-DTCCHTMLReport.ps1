function Create-DTCCHtmlReport {
    [CmdletBinding()]
    param (
        # can be array or array list
        $ObjectArrayList,
        $ReportTitle
    )
    <#    
    --color-primary-g: #00A160;
    --color-primary-b: #00467f;
    --color-secondary-g: #CEE0B3;
    --color-secondary-mb: #5091CD;
    --color-secondary-lb: #ACD4F1;
    --color-secondary-o: #CE7019;
    --color-secondary-p: #956E8E;
    --color-secondary-t: #629080;
    --color-secondary-y: #C2A204;
    --color-wht: #FFFFFF;
    --color-gray-xlt: #f5f5f5;
    --color-gray-lt: #E4E4E4;
    --color-gray-md: #ABB2AF;
    --color-gray-drk: #949494;
    --color-blk: #000000;
    --text-sans: 'proxima';
    --text-sans-bold: 'proximaSemiBold';
    #>
    # check if it-logo.png is in the current directory:
    $it_logo_png = Get-ChildItem -Path "." -Include "*it-logo.png" -File -Recurse -ErrorAction SilentlyContinue
    if (-not ($it_logo_png)) {
        # download the png from : https://iit.dtcc.edu/wp-content/uploads/2023/07/it-logo.png
        try {
            Invoke-WebRequest -Uri "https://iit.dtcc.edu/wp-content/uploads/2023/07/it-logo.png" -OutFile ".\it-logo.png"
        }
        catch {
            Write-Host "Couldn't download the IIT Logo png file, and did not find it in the current directory." -ForegroundColor Red
        }
    }

    if (-not($ReportTitle)) {
        $ReportTitle = Read-Host "Enter report title"
    }
    $date = Get-Date -Format "dddd, MMMM dd, yyyy"

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
                /* color: #ACD4F1;
                color: #5091CD; */
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
                border-radius: 5px;
    
            }
    
            th {
                background-color: #00467f;
                color: #fff;
                padding: 10px;
                text-align: left;
                font-size: 18px;
                border-top-left-radius: 5px;
                border-top-right-radius: 5px;
            }
    
            thead {
                border-top-left-radius: 5px;
                border-top-right-radius: 5px;
            }
    
            tr:nth-child(even) {
                background-color: #ACD4F1;
            }
    
            tr:nth-child(odd) {
                background-color: #5091CD;
            }
    
            td {
                border: 1px solid #ddd;
                padding: 10px;
            }
        </style>
    </head>
    
    <body>
        <header>
            <img class="logo" src="it-logo.png" alt="Logo">
            <div>
                <h1 class="title">$ReportTitle</h1>
                <p class="subtitle">$date</p>
            </div>
        </header>
        <main>
        <div class="table-container">
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

<footer>
<!-- Your footer content goes here -->
</footer>
</body>

</html>
"@

    # out the html to file
    $html_head | Out-File -FilePath ".\$reporttitle.html" -Force

}
