# ONE:
# deals with multiple cases when targetcomputer can be a string
if (($targetcomputer -eq '') -or ($null -eq $targetcomputer)) {
    write-host "assigning localhost value to targetcomputer" -foregroundcolor magenta
    $targetcomputer = @('127.0.0.1')
    Write-host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Targetcomputer value determined to be $targetcomputer."
}
else {
    # Deal with TARGETCOMPUTER --------------------------
    $targetcomputer_typeobj = $targetcomputer.gettype()
    $targetcomputer_typename = $targetcomputer_typeobj | select -exp name
    # $targetcomputer_basetype = $targetcomputer_typeobj | select -exp basetype
    # if its a string
    try {
        $ADCheck = Get-ADComputer $targetcomputer
    }
    catch {
        Write-Host "Unable to get aD Computer."
    }
    if ($targetcomputer_typename -eq 'string') {
        if (Test-Path $targetcomputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Targetcomputer value determined to be a file of hostnames, getting content."
            $targetcomputer = Get-Content $targetcomputer
        }
        elseif ($ADCheck) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Targetcomputer value determined to be a single hostname, getting content."
            $targetcomputer = $Targetcomputer
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: SearchAD = 'y', Searching AD for computers using the provided string: " -NoNewLine
            Write-Host "$targetcomputer..." -foregroundcolor Green
        
            $targetcomputer = $targetcomputer + "x"
            $targetcomputer = Get-ADComputer -Filter * | Where-Object { $_.DNSHostname -match "^$targetcomputer*" } | Select -Exp DNShostname
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found these matching computer names in AD: " -NoNewline
            Write-Host "$($targetcomputer -join ', ')" -Foregroundcolor Green  
        
        }

    }
}

# Test connection to computers using ONE PING (wont always be right)
$connection_results = Test-Connection $targetcomputer -count 1
# get successes
$targetcomputer = $connection_results | where-object { $_.StatusCode -eq 0 } | Select -Exp Address
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Live hosts determined:" -Nonewline
Write-Host "$($targetcomputer -join ', ')" -foregroundcolor green

# TWO:
# cuts any .csv/.xlsx file extension off $outputfile string, and makes sure there is a folder with today's date in the reports directory of the menu
# Create outputfilepath
$outputfile = $outputfile -replace '.csv', ''
$outputfile = $outputfile -replace '.xlsx', ''
$thedate = Get-Date -Format 'yyyy-MM-dd'
# check for date folder
if (-not (Test-Path "$env:PSMENU_DIR\reports\$thedate")) {
    New-Item -Path "$env:PSMENU_DIR\reports\$thedate" -ItemType Directory
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Created $thedate folder in reports directory."
}
# ***CREATE FUNCTION-SPECIFIC OUTPUTFILENAME HERE, that takes whatever the user used as paramter value for outputfile into account, but prepends a default title, and appends the date.***
$Outputfile = "$env:PSMENU_DIR\reports\$thedate\INSERT-TEXT-$outputfile-$thedate"

# THREE:
# Export $results to csv / xlsx using outputfile
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting results to " -NoNewline
Write-Host "$outputfile.csv and $outputfile.xlsx" -Foregroundcolor Green
$results | Export-CSV "$outputfile.csv" -NoTypeInformation -Force

# look for the importexcel powershell module
$CheckForimportExcel = Get-InstalledModule -Name 'importexcel' -ErrorAction SilentlyContinue
if (-not $CheckForimportExcel) {
    Install-Module -Name ImportExcel -Force
}

$params = @{
    AutoSize             = $true
    TitleBackgroundColor = 'Blue'
    TableName            = "INSERT TITLE $filename $thedate"
    TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
    BoldTopRow           = $true
    WorksheetName        = 'INSERT WORKSHEET NAME'
    PassThru             = $true
    Path                 = "$OutPutFile.xlsx" # => Define where to save it here!
}

$xlsx = $results | Export-Excel @params
$ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
$ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
Close-ExcelPackage $xlsx

# FOUR:
# check for a user logged into local computer:
try {
    $loggedinuser = get-process explorer -includeusername | where-object { $_.USername -notlike "*SYSTEM*" } | select -exp username
    $loggedinuser = $loggedinuser.replace("DTCC\", '')
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: User $loggedinuser is logged in to $env:COMPUTERNAME"
}
catch {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No user logged in to $env:COMPUTERNAME"
    Write-Host ""
}


# FIVE:
# attempt to get the chrome.exe to open webpage, if can't find, use & to execute the .html file