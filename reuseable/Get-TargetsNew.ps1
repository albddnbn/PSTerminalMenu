Function Get-Targets {
    # Standalone 'get target machines' function
    ## Tested with single/multiple hostnames and hostname substrings, as well as localhost values.

    param(
        [String[]]$TargetComputer
    )

    # if ($null -eq $TargetComputer) {
    #     Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
    # }
    # else {

    ## Do we have to add if targetcomputer eq $null? Will function ever be used like: Get-Targets

    # if (($TargetComputer -is [System.Collections.IEnumerable]) -and ($TargetComputer -isnot [string[]])) {
    #     if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
    #         $TargetComputer = @('127.0.0.1')
    #     }
    #     else {
    #         $null
    #     }
    # }
    # elseif ($TargetComputer -is [string[]]) {
    if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
        $TargetComputer = @('127.0.0.1')
    }
    elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
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
        $NewTargetComputer = [System.Collections.Arraylist]::new()
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

    # }
    $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
    # Safety catch
    if ($null -eq $TargetComputer) {
        return
    }
    # }
    return $TargetComputer
}