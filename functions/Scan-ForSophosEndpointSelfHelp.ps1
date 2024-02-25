function Scan-ForSophosEndpointSelfHelp {
    <#
    .SYNOPSIS
        Scans target computer(s) for installed applications with  'Sophos Endpoint Self Help' applications

    .DESCRIPTION
        Looks in the registry for any installed applications with displaynames: 'Sophos Endpoint Self Help' - this is an important part of current Sophos installations, up to date version is important.

    .PARAMETER Targetcomputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .EXAMPLE
        Scan-ForSophosEndpointSelfHelp -Targetcomputer 't-client-01'

    .EXAMPLE
        Scan all computers in the Stanton open computer lab:
        Scan-ForSophosEndpointSelfHelp -Targetcomputer 't-client-'

    .NOTES
        Additional notes about the function
    #>
    param(
        $Targetcomputer
    )
    #####################################################
    ## Output file path creation, Targetcomputer handling
    #####################################################
    BEGIN {
        $REPORT_TITLE = 'SophosScan'
        $thedate = Get-Date -Format 'yyyy-MM-dd'

        ## TARGETCOMPUTER HANDLING:
        ## If Targetcomputer is an array or arraylist - it's already been sorted out.
        if (($TargetComputer -is [System.Collections.IEnumerable]) -and ($TargetComputer -isnot [string])) {
            $null
            ## If it's a string - check for commas, try to get-content, then try to ping.
        }
        elseif ($TargetComputer -is [string]) {
            if ($TargetComputer -in @('', '127.0.0.1')) {
                $TargetComputer = @('127.0.0.1')
            }
            elseif ($Targetcomputer -like "*,*") {
                $TargetComputer = $TargetComputer -split ','
            }
            elseif (Test-Path $Targetcomputer -erroraction SilentlyContinue) {
                $TargetComputer = Get-Content $TargetComputer
            }
            else {
                $test_ping = Test-Connection -ComputerName $TargetComputer -count 1 -Quiet
                if ($test_ping) {
                    $TargetComputer = @($TargetComputer)
                }
                else {
                    $TargetComputerInput = $TargetComputerInput + "x"
                    $TargetComputerInput = Get-ADComputer -Filter * | Where-Object { $_.DNSHostname -match "^$TargetComputerInput*" } | Select -Exp DNShostname
                    $TargetComputerInput = $TargetComputerInput | Sort-Object   
                }
            }
        }
        $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
        $online_hosts = [System.Collections.ArrayList]::new()
        ForEach ($single_computer in $TargetComputer) {
            $ping_result = Test-Connection $single_computer -Count 1 -Quiet
            if ($ping_result) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is online."
                $online_hosts.Add($single_computer) | Out-Null
            }
        }
        $TargetComputer = $online_hosts
        # Safety catch to make sure
        if ($null -eq $TargetComputer) {
            # user said to end function:
            return
        }
        ## Outputfile name creation:
        ## Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        if (Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) {
            $OutputFile = Get-OutputFileString -TitleString $REPORT_TITLE -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_TITLE -ReportOutput
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
            $outputfile = "$REPORT_TITLE-$thedate"
        }
        

        ## Collecting the results
        $all_results = [System.Collections.Generic.List[psobject]]::new()
        #return new output filepath value
    }

    #################################################################################
    ## Searches several registry locations for Sophos Endpoint Self Help display name
    ## Targeted search would be more efficient.
    #################################################################################
    PROCESS {
        # check target remote computers and get the sophos app object list from them
        $results = Invoke-Command -computername $TargetComputer -scriptblock {

            # Define the registry paths for uninstall information
            $registryPaths = @(
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
            )
            # Loop through each registry path and retrieve the list of subkeys
            foreach ($path in $registryPaths) {
                $uninstallKeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                # Skip if the registry path doesn't exist
                if (-not $uninstallKeys) {
                    continue
                }
                # Loop through each uninstall key and display the properties
                foreach ($key in $uninstallKeys) {
                    $keyPath = Join-Path -Path $path -ChildPath $key.PSChildName
                    $displayName = (Get-ItemProperty -Path $keyPath -Name "DisplayName" -ErrorAction SilentlyContinue).DisplayName
                    if ($displayName -eq 'Sophos Endpoint Self Help') {
                        $uninstallString = (Get-ItemProperty -Path $keyPath -Name "UninstallString" -ErrorAction SilentlyContinue).UninstallString
                        $version = (Get-ItemProperty -Path $keyPath -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
                        $publisher = (Get-ItemProperty -Path $keyPath -Name "Publisher" -ErrorAction SilentlyContinue).Publisher
                        $installLocation = (Get-ItemProperty -Path $keyPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
                        $productcode = (Get-ItemProperty -Path $keyPath -Name "productcode" -ErrorAction SilentlyContinue).productcode
		
		
                        $obj = [pscustomobject]@{
                            DisplayName     = $DisplayName
                            Uninstallstring = $uninstallString
                            DisplayVersion  = $version
                            Publisher       = $publisher
                            ProductCode     = $productcode
                            InstallLocation = $installlocation
                        }
                        $obj
                    }
                }
            }
            if (-not $obj) {
                $obj = [pscustomobject]@{
                    DisplayName     = "No Sophos Endpoint Self Help found"
                    Uninstallstring = $uninstallString
                    DisplayVersion  = $version
                    Publisher       = $publisher
                    ProductCode     = $productcode
                    InstallLocation = $installlocation
                }
                $obj
            }
        }  | Select * -ExcludeProperty RunspaceId, PSShowComputerName

        $all_results.Add($results)
    }
    
    ##############################################
    ## Either export to xlsx and csv, or just csv.
    ##############################################
    END {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Information gathered, exporting to $outputfile.csv/.xlsx..."
        Write-Host ""
        Write-Host "If a computer doesn't have Sophos Endpoint Self Help - it's likely not showing as protected in Sophos Central." -foregroundcolor yellow
        Write-Host "If a computer has an older version of Sophos Endpoint Self Help - it may still technically be showing as 'protected' in the console, but will likely be failing the 'Endpoint Self Help Test'" -foregroundcolor yellow
        if (get-command -name 'output-reports' -erroraction silentlycontinue) {
            Output-Reports -Filepath "$outputfile" -Content $all_results -ReportTitle "SophosScan" -CSVFile $true -XLSXFile $true
        }
        else {
            $all_results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation

            notepad.exe "$outputfile.csv"
        }
        Invoke-Item "$env:PSMENU_DIR\reports\$thedate\$REPORT_TITLE\"
    }
}
