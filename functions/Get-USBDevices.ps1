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
        abuddenb / 2024
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
    $thedate = Get-Date -Format 'yyyy-MM-dd'
    ## If Targetcomputer is an array or arraylist - it's already been sorted out.
    if (($TargetComputer -is [System.Collections.IEnumerable])) {
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
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer was not an array, comma-separated list of hostnames, path to hostname text file, or valid single hostname. Exiting." -Foregroundcolor "Red"
                return
            }
        }
    }
    $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
    # Safety catch to make sure
    if ($null -eq $TargetComputer) {
        # user said to end function:
        return
    }
    Write-Host "TargetComputer is: $($TargetComputer -join ', ')"
    if ($TargetComputer.count -lt 20) {
        ## If the Get-LiveHosts utility command is available
        if (Get-Command -Name Get-LiveHosts -ErrorAction SilentlyContinue) {
            $TargetComputer = Get-LiveHosts -TargetComputerInput $TargetComputer
        }
    }

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

    ###########################################
    ## Getting USB info from target machine(s):
    ###########################################
    $results = Invoke-Command -Computername $targetcomputer -scriptblock {
        $connected_usb_devices = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^USB' } | Select FriendlyName, Class, Status

        $connected_usb_devices
    }  | Select * -ExcludeProperty RunspaceId, PSShowComputerName | Sort -Property PSComputerName

    # outputs a file for each computer in the list
    $unique_hostnames = $results | Select -exp PSComputerName -Unique
    # script will create a .txt and/or .csv with result object per computer.

    ForEach ($unique_hostname in $unique_hostnames) {
        $computers_results = $results | where-object { $_.pscomputername -eq $unique_hostname }
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

    Read-Host "Press enter to continue."
}
