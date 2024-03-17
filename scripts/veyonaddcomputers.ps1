function Get-ComputersLDAP {
    param(
        [parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    # process {
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
$HOSTNAME_SUBSTRING = ''
$ROOM_NAME = ''
## IF Veyon is already installed on master and client computers - you just need to readd the clients to master if not present
$Student_Computers = Get-ComputersLDAP -ComputerName "$HOSTNAME_SUBSTRING"
$RoomName = "$ROOM_NAME"
$veyon = "C:\Program Files\Veyon\veyon-cli"
&$veyon networkobjects add location $RoomName
ForEach ($single_computer in $Student_Computers) {		
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ::  Adding student computer: $single_computer."

    If ( Test-Connection -BufferSize 32 -Count 1 -ComputerName $single_computer -Quiet ) {
        Start-Sleep -m 300
        $IPAddress = (Resolve-DNSName $single_computer).IPAddress
        $MACAddress = Invoke-Command -Computername $single_computer -scriptblock {
            $obj = (get-netadapter -physical | where-object { $_.name -eq 'Ethernet' }).MAcaddress
            $obj
        }
        Write-Host " $veyon networkobjects add computer $single_computer $IPAddress $MACAddress $RoomName "
        &$veyon networkobjects add computer $single_computer $IPADDRESS $MACAddress $RoomName
    }
    Else {
        Write-Host "Didn't add $single_computer because it's offline." -foregroundcolor Red
    }
}
