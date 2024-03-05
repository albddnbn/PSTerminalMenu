function Get-ComputersLDAP {
    param(
        [parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    # process {
    write-host "Testing $ComputerNAme"
    try {

        if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
            Write-Error "Security group filtering won't work because `$env:USERDNSDOMAIN is not available!"
            Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
        }
        else {

            # if no domain specified fallback to PowerShell environment variable
            if ([string]::IsNullOrEmpty($searchRoot)) {
                $searchRoot = $env:USERDNSDOMAIN
            }

            $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
            $searcher.Filter = "(&(objectclass=computer)(cn=$ComputerName*))"
            $searcher.SearchRoot = "LDAP://$searchRoot"
            # $distinguishedName = $searcher.FindOne().Properties.distinguishedname
            # $searcher.Filter = "(member:1.2.840.113556.1.4.1941:=$distinguishedName)"

            [void]$searcher.PropertiesToLoad.Add("name")

            $list = [System.Collections.Generic.List[String]]@()

            $results = $searcher.FindAll()
            foreach ($result in $results) {
                $resultItem = $result.Properties
                [void]$List.add($resultItem.name)
            }

            return $list

        }
    }
    catch {
        #Nothing we can do
        Write-Warning $_.Exception.Message
        return $null
    }
    # }
}