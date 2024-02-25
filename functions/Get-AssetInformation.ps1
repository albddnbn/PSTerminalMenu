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
            ValueFromPipeline = $true
        )]
        $TargetComputer,
        [string]$Outputfile
    )
    BEGIN {
        ##################################################################################
        ##  Asset info scriptblock used to get local asset info from each target computer.
        ##################################################################################
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

            # get monitor info:
            $monitors = Get-CimInstance WmiMonitorId -Namespace root\wmi -ComputerName $ComputerName | Select Active, ManufacturerName, UserFriendlyName, SerialNumberID, YearOfManufacture
            $monitors | ForEach-Object {
                $_.UserFriendlyName = [System.Text.Encoding]::ASCII.GetString($_.UserFriendlyName)
                $_.SerialNumberID = [System.Text.Encoding]::ASCII.GetString($_.SerialNumberID -notmatch 0)
                $_.ManufacturerName = [System.Text.Encoding]::ASCII.GetString($_.ManufacturerName)
            }

            $obj = [PSCustomObject]@{
                model               = $computer_model
                biosversion         = $biosversion
                bioreleasedate      = $bioreleasedate
                asset_tag           = $asset_tag
                computer_serial_num = $computer_serial_num
                monitors            = $monitors
                NumMonitors         = $monitors.count
            }

            return $obj
        }

        #####################
        ##  Start of function
        #####################
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
        # Safety catch to make sure
        if ($null -eq $TargetComputer) {
            Read-Host "No valid target computeres found. Press enter to continue."
            # user said to end function:
            return
        }
        Write-Host "TargetComputer is: $($TargetComputer -join ', ')"

        if (($TargetComputer.count -lt 20) -and ($Targetcomputer -ne '127.0.0.1')) {
            if (Get-Command -Name "Get-LiveHosts" -ErrorAction SilentlyContinue) {
                $TargetComputer = Get-LiveHosts -TargetComputerInput $TargetComputer
            }
        }

        ## Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        if ($Outputfile.tolower() -eq 'n') {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
        }
        else {
            ## outputfile will not be 'n' at this point
            if (Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) {
                if ($Outputfile.toLower() -eq '') {
                    $REPORT_DIRECTORY = "AssetInfo"
                }
                else {
                    $REPORT_DIRECTORY = $outputfile            
                }
                $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                if ($outputfile.tolower() -eq '') {
                    $outputfile = "AssetInfo-$thedate"
                }
            }
        }

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($single_pc_asset_info_ps1.fullname)."


        Write-host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Getting asset information from computers now..."

        $all_results = [system.collections.arraylist]::new()

    }

    PROCESS {
        $results = Invoke-Command -ComputerName $Targetcomputer -ScriptBlock $asset_info_scriptblock | Select * -ExcludeProperty RunspaceId, PSshowcomputername
        if ($results) {
            $all_results.add($results) | out-null
        }
    }

    END {
        if ($all_results) {
            ## Sort results
            $all_results = $all_results | Sort-Object -Property PSComputername

            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Asset information gathered, exporting to $outputfile.csv/.xlsx..."

            ## Terminal / gridview output
            if ($outputfile -eq 'n') {
                if ($all_results.count -le 2) { 
                    $all_results | Format-Table -AutoSize
                }
                else {
                    $all_results | Out-GridView
                }
            }
            ## Report output, use Output-Reports if available
            else {
                if (Get-Command -Name "Output-Reports" -Erroraction SilentlyContinue) {

                    Output-Reports -Filepath "$outputfile" -Content $all_results -ReportTitle "$REPORT_DIRECTORY $thedate" -CSVFile $true -XLSXFile $true
                    Invoke-Item "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\"
                }
                else {
                    $all_results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation

                    notepad.exe "$outputfile.csv"        
                }
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "Press enter to continue."
    }
}
