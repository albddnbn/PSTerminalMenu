function Get-CurrentUser {
    <#
    .SYNOPSIS
        Gets user logged into target system(s).
        Checks if teams or zoom processes are running and returns True/False for each in report/terminal output.

    .DESCRIPTION
        Creates report with current user, computer model, and if Teams or Zoom are running.
        If no output file is specified, terminal output only ($Outputfile = 'n').

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

    .EXAMPLE
        1. Get users on all S-A231 computers:
        Get-CurrentUser -Targetcomputer "s-a231-"

    .EXAMPLE
        2. Get user on a single target computer:
        Get-CurrentUser -TargetComputer "t-client-28"

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
        [string]$Outputfile
    )
    BEGIN {
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
            # user said to end function:
            return
        }
        # Write-Host "TargetComputer is: $($TargetComputer -join ', ')"
        # if ($TargetComputer.count -lt 20) {
        #     ## If the Get-LiveHosts utility command is available
        #     if (Get-Command -Name Get-LiveHosts -ErrorAction SilentlyContinue) {
        #         $TargetComputer = Get-LiveHosts -TargetComputerInput $TargetComputer
        #     }
        # }

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

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Getting current users on: " -NoNewLine
        Write-Host "$($targetcomputer -join ', ')" -Foregroundcolor Green

        $all_results = [system.collections.arraylist]::new()
    }

    PROCESS {
        $ping_result = Test-Connection $TargetComputer -count 1 -Quiet
        if (-not ($ping_result)) {
            Write-Host "$Targetcomputer didn't respond."
            continue
        }
        # Get Computers details and create an object
        $results = Invoke-Command -ComputerName $TargetComputer -Scriptblock {
            $model = (get-ciminstance -class win32_computersystem).model
            # $current_user = Get-Ciminstance -class win32_computersystem | select -exp username # different way
            $current_user = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
            # see if teams and/or zoom are running
            $teams_running = get-process -name 'teams' -erroraction SilentlyContinue
            $zoom_running = get-process -name 'zoom' -erroraction SilentlyContinue
            ForEach ($process_check in @($teams_running, $zoom_running)) {
                if ($process_check) {
                    $process_check = $true
                }
                else {
                    $process_check = $false
                }
            }
            $obj = [PSCustomObject]@{
                Model        = $model
                CurrentUser  = $current_user
                TeamsRunning = $teams_running
                ZoomRunning  = $zoom_running

            }
            $obj
        } 
	
        $results = $results | Select PSComputerName, CurrentUser, Model, TeamsRunning, ZoomRunning
        # $results = $results | Sort -Property PSComputerName
        $all_results.add($results) | out-null
    }

    END {
        if ($all_results) {
            $all_results = $all_results | sort -property pscomputername
            ## If Outputfile not desired:
            if ($outputfile.tolower() -eq 'n') {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
                if ($results.count -le 2) {
                    $results | Format-List
                }
                else {
                    $results | out-gridview
                }
            }
            ## If Output-Reports is available:
            elseif (Get-Command -Name "Output-Reports" -Erroraction SilentlyContinue) {
                if ($outputfile.tolower() -ne 'n') {

                    Output-Reports -Filepath "$outputfile" -Content $results -ReportTitle "$REPORT_DIRECTORY $thedate" -CSVFile $true -XLSXFile $true
                    Invoke-Item "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\"
                }
            }
            elseif ($outputfile -ne 'n') {
                $results | Export-Csv -Path "$outputfile.csv" -NoTypeInformation

                notepad.exe "$outputfile.csv"
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "Press enter to continue."
    }
}
