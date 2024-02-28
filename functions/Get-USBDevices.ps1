function Get-USBDevices {
    <#
    .SYNOPSIS
        Gets a list of USB devices connected to ComputerName device(s) and outputs one report per computer.

    .DESCRIPTION
        May also be able to use a hostname file eventually.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER OutputFile
        If set to 'n' then no file will be created.
        If blank, default filename will be created.
        Any other input will be used for creation of output folder/file names.

    .EXAMPLE
        Get-USBDevicess

    .EXAMPLE
        Get-USBDevices -Targetcomputer "computername"

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        $TargetComputer,
        [String]$Outputfile
    )
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## TARGETCOMPUTER HANDLING:
        ## If Targetcomputer is an array or arraylist - it's already been sorted out.
        ## TargetComputer is mandatory - if its null, its been provided through pipeline - don't touch it in begin block
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
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

            ## At this point - if targetcomputer is null - its been provided as a parameter
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
            Write-Host "TargetComputer is: $($TargetComputer -join ', ')"

            ## With this function - it's especially important to log offline computers, whose hardware IDs weren't taken.
            if ($TargetComputer -ne '127.0.0.1') {
                $online_hosts = [system.collections.arraylist]::new()
                $offline_hosts = [system.collections.arraylist]::new()
                ForEach ($single_computer in $TargetComputer) {
                    $ping_result = Test-Connection $single_computer -Count 1 -Quiet
                    if ($ping_result) {
                        Write-Host "$single_computer is online." -Foregroundcolor Green
                        $online_hosts.Add($single_computer) | Out-Null
                    }
                    else {
                        Write-Host "$single_computer is offline." -Foregroundcolor Red
                        $offline_hosts.add($single_computer) | out-null
                    }
                }

                Write-Host "Copying offline hosts to clipboard." -foregroundcolor Yellow
                "$($offline_hosts -join ', ')" | clip

                $TargetComputer = $online_hosts
            }
        }

        ## Output file path needs to be created (if specified) regardless of how Targetcomputer is submitted to function.
        if ($outputfile.tolower() -ne 'n') {
            ## Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
            if (Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) {
                if ($Outputfile.toLower() -eq '') {
                    $outputfile = "CurrentUsers"
                }

                $outputfile = Get-OutputFileString -TitleString $outputfile -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
                if ($outputfile.tolower() -eq '') {
                    $outputfile = "CurrentUsers-$thedate"
                }
            }
        }
        ## empty results container
        $all_results = [system.collections.arraylist]::new()
    }

    PROCESS {
        
        ###########################################
        ## Getting USB info from target machine(s):
        ###########################################
        $results = Invoke-Command -Computername $targetcomputer -scriptblock {
            $connected_usb_devices = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^USB' } | Select FriendlyName, Class, Status

            $connected_usb_devices
        }  | Select * -ExcludeProperty RunspaceId, PSshowcomputername

        $all_results.add($results) | out-null
    }

    END {
        if ($all_results) {
            $all_results = $all_results | sort -property pscomputername
            # outputs a file for each computer in the list
            $unique_hostnames = $all_results | Select -exp PSComputerName -Unique
            # script will create a .txt and/or .csv with result object per computer.

            ForEach ($unique_hostname in $unique_hostnames) {
                $computers_results = $all_results | where-object { $_.pscomputername -eq $unique_hostname }
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting $outputfile-$unique_hostname.csv/$outputfile-$unique_hostname.xlsx..."
                if ($outputfile.tolower() -ne 'n') {
                    if (Get-Command -Name 'Output-Reports' -ErrorAction SilentlyContinue) {
                        Output-Reports -Filepath "$outputfile-$unique_hostname" -Content $computers_results -ReportTitle "$REPORT_TITLE - $thedate" -CSVFile $true -XLSXFile $true
                    }
                    else {
                        $computers_results | Export-Csv -Path "$outputfile-$unique_hostname.csv" -NoTypeInformation -Force
                    }
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
    
                    $computers_results |  format-table -autosize

                    Read-Host "Press enter to show next computer's results"
    
                }
            }
            try {
                Invoke-Item "$($env:PSMENU_DIR)\reports\$thedate\$REPORT_TITLE"
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Unable to open folder for reports."
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "Press enter to continue."
    }
}
