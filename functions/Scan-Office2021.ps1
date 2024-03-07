function Scan-Office2021 {
    <#
    .SYNOPSIS
        Checks for a user logged in to a remote computer using the get-process cmdlet to check explorer.exe.

    .DESCRIPTION
        If the process doesn't exist, it returns false, because any user currently logged in to the PC will have explorer.exe running.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .EXAMPLE
        Scan-Office2021 -TargetComputer "t-client-"

    .EXAMPLE
        Scan-Office2021 -ComputerName "t-client-28"

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer
    )
    BEGIN {
        ## Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            if (($TargetComputer -is [System.Collections.IEnumerable]) -and ($TargetComputer -isnot [string[]])) {
                $null
                ## If it's a string - check for commas, try to get-content, then try to ping.
            }
            elseif ($TargetComputer -is [string[]]) {
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
                        $searcher.Filter = "(&(objectclass=computer)(cn=$TargetComputer*))"
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
                        $TargetComputer = $list
    
                    }
                }
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }
        ## 2. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $REPORT_DIRECTORY = 'Office2021Scan'
        if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
            $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
            $iterator_var = 0
            while ($true) {
                $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$REPORT_DIRECTORY-$thedate"
                if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                    $iterator_var++
                    $outputfile += "-$([string]$iterator_var)"
                }
                else {
                    break
                }
            }
            ## Try to get output directory path and make sure it exists.
            try {
                $outputdir = $outputfile | split-path -parent
                if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                    New-Item -ItemType Directory -Path $($outputfile | split-path -parent) | Out-Null
                }
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory." -Foregroundcolor Yellow
            }
        }
        
        ## 3. Create empty results container
        $results = [system.collections.arraylist]::new()
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning Office2021 scan on target computers now."
    }

    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            if ($single_computer) {

                ## test with ping first:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    $office2021_check = Invoke-Command -ComputerName $single_computer -Scriptblock {
                        # Loop through each registry path and retrieve the list of subkeys
                        $uninstallKeys = Get-ChildItem -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue
                        $path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
                        foreach ($key in $uninstallKeys) {
                            $keyPath = Join-Path -Path $path -ChildPath $key.PSChildName
                            $displayName = (Get-ItemProperty -Path $keyPath -Name "DisplayName" -ErrorAction SilentlyContinue).DisplayName

                            if ($displayName -like "*Office*Professional*") {
                                $publisher = (Get-ItemProperty -Path $keyPath -Name "Publisher" -ErrorAction SilentlyContinue).Publisher


                                if ($publisher -like "*Microsoft*") {


                                    $uninstallString = (Get-ItemProperty -Path $keyPath -Name "UninstallString" -ErrorAction SilentlyContinue).UninstallString
                                    $version = (Get-ItemProperty -Path $keyPath -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
                                    $installLocation = (Get-ItemProperty -Path $keyPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
                                    $installdate = (Get-ItemProperty -Path $keyPath -Name "InstallDate" -ErrorAction SilentlyContinue).InstallDate


                                    $obj = [pscustomobject]@{
                                        DisplayName     = $displayName
                                        Publisher       = $publisher
                                        UninstallString = $uninstallString
                                        Version         = $version
                                        InstallLocation = $installLocation
                                        InstallDate     = $installdate
                                        Office2021Found = $false
                                    }
                                    if ($displayname -like "*2021*") {
                                        $obj.Office2021Found = $true
                                        # found a match, so break
                                        break
                                    }
                                }
                            }
                        }

                        $obj
                    }  | Select PSComputerName, * -ExcludeProperty RunspaceId, PSshowcomputername -ErrorAction SilentlyContinue
            
                    $results.Add($office2021_check) | Out-Null
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is not responding to ping, skipping." -Foregroundcolor Yellow
                }
            }
        }
    }
    END {
        if ($results) {
            ## Sort the results
            $results = $results | Sort-Object -Property PSComputerName
            $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
            ## Try ImportExcel
            try {
                ## xlsx attempt:
                $params = @{
                    AutoSize             = $true
                    TitleBackgroundColor = 'Blue'
                    TableName            = "$REPORT_DIRECTORY"
                    TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                    BoldTopRow           = $true
                    WorksheetName        = $REPORT_DIRECTORY
                    PassThru             = $true
                    Path                 = "$Outputfile.xlsx" # => Define where to save it here!
                }
                $Content = Import-Csv "$Outputfile.csv"
                $xlsx = $Content | Export-Excel @params
                $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                Close-ExcelPackage $xlsx
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
            }
            Invoke-item "$($outputfile | split-path -Parent)"
            
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "`nPress [ENTER] to return results."
        return $results
    }
}
