# some things are done for almost every function, like:
# --------------------------------------------------------------------------------------
# 3. possibly better method for #1
$targetcomputer_type = $targetcomputer.gettype()
$targetcomputer_name = $targetcomputer_type | select -exp name
$targetcomputer_basetype = $targetcomputer_type | select -exp basetype
# if its a string
if ($targetcomputer_name -eq 'string') {
    if (Test-Path $targetcomputer) {
        Write-Host "Targetcomputer value determined to be a file of hostnames, getting content."
        $targetcomputer = Get-Content $targetcomputer
    }
}
# Test connection to computers using ONE PING (wont always be right)
$connection_results = Test-Connection $targetcomputer -count 1
# get successes
$targetcomputer = $connection_results | where-object { $_.StatusCode -eq 0 } | Select -Exp Address
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Live hosts determined:"
Write-Host "$($targetcomputer -join ', ')" -foregroundcolor green
# ------------------------------------------------------------------------------------
# 1. Validating a 'ComputerName' -like parameter. For ex: TargetComputer
# This makes sure that the user can submit a single string hostname, single string containing a path to .txt file, or an array / arraylist of hostnames generated using something like get-adcomputer / selecting dnshostname
# if it IS is list of multiple computers - it takes the list and filters out unresponsive ones
# end result = variable $targetcomputer contains only live hosts
$targetcomputer_type = $targetcomputer.gettype()
$targetcomputer_name = $targetcomputer_type | select -exp name
$targetcomputer_basetype = $targetcomputer_type | select -exp basetype
# if its a string
if ($targetcomputer_name -eq 'string') {
    if (Test-Path $targetcomputer) {
        Write-Host "Targetcomputer value determined to be a file of hostnames, getting content."
        $targetcomputer = Get-Content $targetcomputer
    }
    else {
        Write-Host "Targetcomputer value determined to be a single hostname, testing connection."
        $connection_result = Test-Connection $Targetcomputer -count 1 -Quiet
        if (-not $connection_result) {
            Write-Host "Unable to contact $TargetComputer, exiting." -ForegroundColor Red
            return
        }
    }
}
# else if --> the input is an array (created from get-adcomputer / dnshostname)
elseif (($targetcomputer_name -eq 'object[]') -and ($targetcomputer_basetype -like "*array*")) {
    Write-Host "Targetcomputer value determined to be an array of hostnames, testing connection."
    $online_computers = [system.collections.arraylist]::new()
    $offline_computers = [system.collections.arraylist]::new()

    ForEAch ($hostname in $targetcomputer) {
        $connection_result = Test-Connection $hostname -count 1 -Quiet
        if ($connection_result) {
            $online_computers.add($hostname) | Out-Null
        }
        else {
            $offline_computers.add($hostname) | Out-Null
        }
    }
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: These computers are online: " -NoNewLine
    Write-Host "$($online_computers -join ', ')" -Foregroundcolor Green
    Write-Host ""
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: These computers are offline: " -NoNewLine
    Write-Host "$($offline_computers -join ', ')" -Foregroundcolor Red
    Write-Host "Excluding offline computers from the list."
    $targetcomputer = $online_computers
}

# ------------------------------------------------------------------------------------
# 2. Check for outputfile, assign it to a default name if it doesn't exist, cut .csv /.xlsx off
$outputfile = $outputfile -replace '.csv', ''
$outputfile = $outputfile -replace '.xlsx', ''
$thedate = get-date -format 'yyyy-MM-dd'

# makes sure there is an outputfile
if (-not $outputfile) {
    $x = 0
    # makes sure we get output file(s) that don't delete existing ones
    if ($(Test-Path "$outputfile.csv") -or $(Test-Path "$outputfile.xlsx")) {
        do {
            $outputfile = "$env:PSMENU_DIR\reports\$thedate\current-users-$($targetcomputer.substri)-$thedate-$x"
            $x += 1
        } until (-not ($(Test-Path "$outputfile.csv") -and $(Test-Path "$outputfile.xlsx")))
    }
    else {
        $outputfile = "$env:PSMENU_DIR\reports\$thedate\computerdetails-$thedate"
    }
}
# make sure the reports/$thedate folder exists
if (-not (Test-Path "$env:PSMENU_DIR\reports\$thedate")) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Didn't find $env:PSMENU_DIR\reports\$thedate, creating it now."
    New-Item -Path "$env:PSMENU_DIR\reports\$thedate" -ItemType Directory -Force
}