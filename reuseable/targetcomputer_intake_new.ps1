## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
## External variables: $TargetComputer (string or array of strings)
## Description: Used in the BEGIN Block of most functions in the 'functions' directory.
## If TargetComputer is null - it means it's been passed in through the pipeline since all functions have it as a 
## mandatory parameter.
## If it's a string, create an array of hostnames:
##     - '' = @('127.0.0.1')
##     - anything with commas will be split at , and turned into an array
##     - if it's a file, get-content and turn into an array
##     - if it doesn't match any of the categories listed above - use LDAP query to get all AD computer hostnames that 
##       begin with the string.
## End/return if nothing is found.
if ($null -eq $TargetComputer) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
}
else {
    if (($TargetComputer -is [System.Collections.IEnumerable]) -and ($TargetComputer -isnot [string[]])) {
        $null
        ## If it's a string - check for commas, try to get-content, then try to ping.
    }
    elseif ($TargetComputer -is [string[]]) {
        if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
            $TargetComputer = @('127.0.0.1')
        }
        elseif (Test-Path $Targetcomputer -erroraction SilentlyContinue) {
            $TargetComputer = Get-Content $TargetComputer
        }

        else {
            ## Prepare TargetComputer for LDAP query in ForEach loop
            ## if TargetComputer contains commas - it's either multiple comma separated hostnames, or multiple comma separated hostname substrings - either way LDAP query will verify
            if ($Targetcomputer -like "*,*") {
                $TargetComputer = $TargetComputer -split ','
            }
            else {
                $Targetcomputer = @($Targetcomputer)
            }

            ## LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
            $NewTargetComputer = [System.Collections.Generic.List[string]]
            foreach ($computer in $TargetComputer) {
                ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                    Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                    Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                }
                else {

                    # if no domain specified fallback to PowerShell environment variable
                    if ([string]::IsNullOrEmpty($searchRoot)) {
                        $searchRoot = $env:USERDNSDOMAIN
                    }
                    $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                    $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                    $searcher.SearchRoot = "LDAP://$searchRoot"
                    [void]$searcher.PropertiesToLoad.Add("name")
                    $list = [System.Collections.Generic.List[String]]@()
                    $results = $searcher.FindAll()
                    foreach ($result in $results) {
                        $resultItem = $result.Properties
                        [void]$List.add($resultItem.name)
                    }
                    $NewTargetComputer += $list
                }
            }
            $TargetComputer = $NewTargetComputer
        }

    }
    $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
    # Safety catch
    if ($null -eq $TargetComputer) {
        return
    }
}