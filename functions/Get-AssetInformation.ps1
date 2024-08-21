function Get-AssetInformation {
    <#
    .SYNOPSIS
        Attempts to use Dell Command Configure to get asset tag, if not available uses built-in powershell cmdlets.

    .DESCRIPTION
        Function will work as a part of the Terminal menu or outside of it.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER OutputFile
        'n' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and OutputFile input.
        Ex: Outputfile = 'A220', output file(s) will be in $env:PSMENU_DIR\reports\AssetInfo - A220\

    .INPUTS
        [String[]] - an array of hostnames can be submitted through pipeline for Targetcomputer parameter.

    .OUTPUTS
        [System.Collections.ArrayList] - Returns an arraylist of objects containing hostname, computer model, bios version/release date, asset tag/serial number, and connected monitor information.
        The results arraylist is also displayed in a GridView.

    .EXAMPLE
        Get-AssetInformation

    .EXAMPLE
        Get-AssetInformation -TargetComputer s-c127-01 -Outputfile C127-01-AssetInfo

    .NOTES
        Monitor details show up in .csv but not .xlsx right now - 12.1.2023
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$Outputfile = ''
    )
    ## 1. Handling TargetComputer input if not supplied through pipeline.
    ## 2. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
    ## 3. Define scriptblock that retrieves asset info from local computer.
    ## 4. Create empty results container.
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline input for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
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

                        $matching_hostnames = (([adsisearcher]"(&(objectCategory=Computer)(name=$computer*))").findall()).properties
                        $matching_hostnames = $matching_hostnames.name
                        $NewTargetComputer += $matching_hostnames
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 2. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        $str_title_var = "AssetInfo"
        if ($Outputfile.tolower() -eq 'n') {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
        }
        else {
            if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
                if ($Outputfile.toLower() -eq '') {
                    $REPORT_DIRECTORY = "$str_title_var"
                }
                else {
                    $REPORT_DIRECTORY = $outputfile            
                }
                $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                if ($outputfile.tolower() -eq '') {
                    $iterator_var = 0
                    while ($true) {
                        $outputfile = "reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$thedate"
                        if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                            $iterator_var++
                            $outputfile = "reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$([string]$iterator_var)"


                        }
                        else {
                            break
                        }
                    }

                    if (-not (Test-Path $($outputfile | split-path -parent) -ErrorAction SilentlyContinue)) {
                        New-Item -ItemType Directory -Path $($outputfile | split-path -parent) -Force | Out-Null
                    }
                }
            }
        }
        ## 3. Asset info scriptblock used to get local asset info from each target computer.
        $asset_info_scriptblock = {
            # computer model (ex: 'precision 3630 tower'), BIOS version, and BIOS release date
            $computer_model = get-ciminstance -class win32_computersystem | select -exp model
            $biosversion = get-ciminstance -class win32_bios | select -exp smbiosbiosversion
            $bioreleasedate = get-ciminstance -class win32_bios | select -exp releasedate
            # Asset tag from BIOS (tested with dell computer)
            try {
                $command_configure_exe = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Dell\Command Configure\x86_64" -Filter "cctk.exe" -File -ErrorAction Silentlycontinue
                # returns a string like: 'Asset=2001234'
                $asset_tag = &"$($command_configure_exe.fullname)" --asset
                $asset_tag = $asset_tag -replace 'Asset=', ''
            }
            catch {
                $asset_tag = Get-Ciminstance -class win32_systemenclosure | select -exp smbiosassettag
                # asus motherboard returned 'default string'
                if ($asset_tag.ToLower() -eq 'default string') {
                    $asset_tag = 'No asset tag set in BIOS'
                }    
            }
            $computer_serial_num = get-ciminstance -class win32_bios | select -exp serialnumber
            # get monitor info and create a string from it (might be unnecessary, or a lengthy approach):
            $monitors = Get-CimInstance WmiMonitorId -Namespace root\wmi -ComputerName $ComputerName | Select Active, ManufacturerName, UserFriendlyName, SerialNumberID, YearOfManufacture
            $monitor_string = ""
            $monitor_count = 0
            $monitors | ForEach-Object {
                $_.UserFriendlyName = [System.Text.Encoding]::ASCII.GetString($_.UserFriendlyName)
                $_.SerialNumberID = [System.Text.Encoding]::ASCII.GetString($_.SerialNumberID -notmatch 0)
                $_.ManufacturerName = [System.Text.Encoding]::ASCII.GetString($_.ManufacturerName)
                $manufacturername = $($_.ManufacturerName).trim()
                $monitor_string += "Maker: $manufacturername,Mod: $($_.UserFriendlyName),Ser: $($_.SerialNumberID),Yr: $($_.YearOfManufacture)"
                $monitor_count++
            }
        
            $obj = [PSCustomObject]@{
                model               = $computer_model
                biosversion         = $biosversion
                bioreleasedate      = $bioreleasedate
                asset_tag           = $asset_tag
                computer_serial_num = $computer_serial_num
                monitors            = $monitor_string
                NumMonitors         = $monitor_count
            }
            return $obj
        }
        ## 4. Create empty results container
        $results = [system.collections.arraylist]::new()
        write-host "$($Targetcomputer -join ', ')" -ForegroundColor cyan

    }
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responsive, Collect local asset information from computer
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {
            if ($single_computer) {

                ## test with ping first:
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    Write-Host "Pinged $single_computer successfully, attempting to get asset info."
                    $target_asset_info = Invoke-Command -ComputerName $single_computer -ScriptBlock $asset_info_scriptblock | Select PSComputerName, * -ExcludeProperty RunspaceId, PSshowcomputername -ErrorAction SilentlyContinue
                    if ($target_asset_info) {
                        $results.add($target_asset_info) | out-null
                    }
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer didn't respond to one ping, skipping." -ForegroundColor Yellow
                }
            }
        }
    }

    ## 1. If there were any results - output them to terminal and/or report files as necessary.
    END {
        if ($results) {
            ## Sort the results
            $results = $results | sort -property pscomputername
            if ($outputfile.tolower() -eq 'n') {
                $results | out-gridview -Title $str_title_var
            }
            else {
                $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                ## Try ImportExcel
                try {

                    Import-Module ImportExcel

                    ## xlsx attempt:
                    $params = @{
                        AutoSize             = $true
                        TitleBackgroundColor = 'Blue'
                        TableName            = $str_title_var
                        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                        BoldTopRow           = $true
                        WorksheetName        = $str_title_var
                        PassThru             = $true
                        Path                 = "$Outputfile.xlsx" # => Define where to save it here!
                    }
                    $Content = Import-Csv "$Outputfile.csv"
                    $xlsx = $Content | Export-Excel @params # -ErrorAction SilentlyContinue
                    $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                    $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                    Close-ExcelPackage $xlsx
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
                }
                Invoke-item "$($outputfile | split-path -Parent)"
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."

        }
        # read-host "Press enter to return results."
        return $results
    }
}
