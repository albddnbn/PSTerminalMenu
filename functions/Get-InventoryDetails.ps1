function Get-InventoryDetails {
    <#
    .SYNOPSIS
        Targets supplied computer names, and takes inventory of computer asset tag/serial number, and any other
        details that can be gathered from the connected monitors.
        Outputs a csv with results.

    .DESCRIPTION
        This has mainly been tested with Dell equipment - computers and monitors.
        Still in testing/development phase but should work.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .PARAMETER OutputFile
        'n' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and OutputFile input.
        Ex: Outputfile = 'A220', output file(s) will be in $env:PSMENU_DIR\reports\AssetInfo - A220\

    .INPUTS
        [String[]] - an array of hostnames can be submitted through pipeline for Targetcomputer parameter.

    .OUTPUTS
        [System.Collections.ArrayList] - Returns an arraylist of objects containing hostname, logged in user, and whether the Teams/Zoom processes are running.
        The results arraylist is also displayed in a GridView.

    .EXAMPLE
        1. Get users on all S-A231 computers:
        Sample-Function -Targetcomputer "s-a231-"

    .EXAMPLE
        2. Get user on a single target computer:
        Sample-Function -TargetComputer "t-client-28"

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
        [String[]]$TargetComputer,
        [string]$Outputfile = ''
    )
    ## 1. Handle Targetcomputer input if it's not supplied through pipeline.
    ## 2. Create output filepath if necessary.
    ## 3. Create empty results arraylist to hold results from each target machine (collected during the PROCESS block).
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
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
        ###
        ### *** INSERT THE TITLE OF YOUR FUNCTION / REPORT FOR $str_title_var ***
        ###
        $str_title_var = "Inventory"
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
                        $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$str_title_var-$thedate"
                        if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                            $iterator_var++
                            $outputfile += "$([string]$iterator_var)"
                        }
                        else {
                            break
                        }
                    }
                }
                ## Try to get output directory path and make sure it exists.
                try {
                    $outputdir = $outputfile | split-path -parent
                    if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                        New-Item -ItemType Directory -Path $($outputfile | split-path -parent) -Force | Out-Null
                    }
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory." -Foregroundcolor Yellow
                }
            }
        }

        ## 3. Create empty results container
        $results = [system.collections.arraylist]::new()

        $not_inventoried = [system.collections.arraylist]::new()
    }

    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responseive, run scriptblock to logged in user, info on teams/zoom processes, etc.
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
            if ($single_computer) {
                ## 2. Check if computer is repsonsive on the network.
                if (Test-Connection $single_computer -Count 2 -Quiet -ErrorAction SilentlyContinue) {
                    $result_obj = Invoke-Command -ComputerName $single_computer -scriptblock {
                        $pc_asset_tag = Get-Ciminstance -class win32_systemenclosure | select -exp smbiosassettag
                        $pc_model = Get-Ciminstance -class win32_computersystem | select -exp model
                        $pc_serial = Get-Ciminstance -class Win32_SystemEnclosure | select -exp serialnumber
                        $pc_manufacturer = Get-Ciminstance -class Win32_ComputerSystem | select -exp manufacturer
                        $monitors = Get-CimInstance WmiMonitorId -Namespace root\wmi | Select SerialNumberID, ManufacturerName, UserFriendlyName
                        $monitors | % { 
                            # $_.serialnumberid = [System.Text.Encoding]::ASCII.GetString($_.SerialNumberID -notmatch 0)
                            # 
                            $_.UserFriendlyName = [System.Text.Encoding]::ASCII.GetString($_.UserFriendlyName)
                            if ($_.UserFriendlyName -like "*P19*") {
                                $_.serialnumberid = $(([System.Text.Encoding]::ASCII.GetString($_.SerialNumberID -notmatch 0)).Trim())
                            }
                            else {
                                ## from copilot: his will replace any character that is not in the range from hex 20 (space) to hex 7E (tilde), which includes all printable ASCII characters, with nothing.
                                $_.serialnumberid = ($([System.Text.Encoding]::ASCII.GetString($_.SerialNumberID ).Trim()) -replace '[^\x20-\x7E]', '')
                            }
                            
                            $_.ManufacturerName = [System.Text.Encoding]::ASCII.GetString($_.ManufacturerName)
                        }
                        
                        $obj = [pscustomobject]@{
                            
                            computer_asset        = $pc_asset_tag
                            computer_location     = $(($env:COMPUTERNAME -split '-')[1]) ## at least make an attempt to get location.
                            computer_model        = $pc_model
                            computer_serial       = $pc_serial
                            computer_manufacturer = $pc_manufacturer
                            monitor_serials       = $(($monitors.serialnumberid) -join ',')
                            monitor_manufacturers = $(($monitors.ManufacturerName) -join ',')
                            monitor_models        = $(($monitors.UserFriendlyName) -join ',')
                            inventoried           = $true
                        }
                        # Write-Host "Gathered details from $env:COMPUTERNAME"
                        # Write-Host "$obj"
                        $obj
                    } | Select * -ExcludeProperty PSShowComputerName, RunspaceId

                    if (-not ($result_obj.pscomputername)) {
                        $result_obj = [pscustomobject]@{
                            pscomputername        = $single_computer
                            computer_asset        = ''
                            computer_location     = $(($single_computer -split '-')[1]) ## at least make an attempt to get location.
                            computer_model        = ''
                            computer_serial       = ''
                            computer_manufacturer = ''
                            monitor_serials       = ''
                            monitor_manufacturers = ''
                            monitor_models        = ''
                            inventoried           = $false
                        }
                    }
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is offline." -Foregroundcolor Yellow
                    $result_obj = [pscustomobject]@{
                        pscomputername        = $single_computer
                        computer_asset        = ''
                        computer_location     = $(($single_computer -split '-')[1]) ## at least make an attempt to get location.
                        computer_model        = ''
                        computer_serial       = ''
                        computer_manufacturer = ''
                        monitor_serials       = ''
                        monitor_manufacturers = ''
                        monitor_models        = ''
                        inventoried           = $false
                    }
                }
                $results.Add($result_obj) | out-null

            }
        }
    }

    ## This section will attempt to output a CSV and XLSX report if anything other than 'n' was used for $Outputfile.
    ## If $Outputfile = 'n', results will be displayed in a gridview, with title set to $str_title_var.
    END {
        if ($results) {
            ## 1. Sort any existing results by computername
            $results = $results | sort -property pscomputername
            ## 2. Output to gridview if user didn't choose report output.
            if ($outputfile.tolower() -eq 'n') {
                $results | out-gridview -title $str_title_var
            }
            else {
                ## 3. Create .csv/.xlsx reports if possible
                $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation
                ## Try ImportExcel
                try {

                    Import-Module ImportExcel

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
                    $xlsx = $Content | Export-Excel @params
                    $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
                    $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
                    Close-ExcelPackage $xlsx
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: ImportExcel module not found, skipping xlsx creation." -Foregroundcolor Yellow
                }
                ## Try opening directory (that might contain xlsx and csv reports), default to opening csv which should always exist
                try {
                    Invoke-item "$($outputfile | split-path -Parent)"
                }
                catch {
                    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not open output folder." -Foregroundcolor Yellow
                    Invoke-item "$outputfile.csv"
                }
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."

            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output from Sample-Function." | Out-File -FilePath "$outputfile.csv"

            Invoke-Item "$outputfile.csv"
        }
        # read-host "Press enter to return results."
        return $results
    }
}
