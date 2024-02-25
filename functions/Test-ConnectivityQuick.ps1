function Test-ConnectivityQuick {
    <#
    .SYNOPSIS
        Tests connectivity to a single computer or list of computers by using Test-Connection -Quiet.

    .DESCRIPTION
        Works fairly quickly, but doesn't give you any information about the computer's name, IP, or latency - judges online/offline by the 1 ping.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .EXAMPLE
        Check all hostnames starting with t-client- for online/offline status.
        Test-ConnectivityQuick -TargetComputer "t-client-"

    .NOTES
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
        $TargetComputer
    )
    BEGIN {
        ## SCRIPT WILL USE THIS AMOUNT OF PINGS TO DETERMINE TARGET NETWORK RESPONSIVENESS.
        $PING_COUNT = 1
        ## If Targetcomputer is an array or arraylist - it's already been sorted out.
        if (($TargetComputer -is [System.Collections.IEnumerable]) -and (-not($TargetComputer -is [string]))) {
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

        ## COLLECTIONS LISTS - successful/failed pings.
        $list_of_online_computers = [system.collections.arraylist]::new()
        $list_of_offline_computers = [system.collections.arraylist]::new()
    }

    ## Ping target machines $PingCount times and log result to terminal.
    PROCESS {

        ForEach ($single_computer in $Targetcomputer) {
            ## Ping target machine(s) 1 time, add result object to corresponding list.
            # PROCESS {
            $connection_result = Test-Connection $single_computer -count $PING_COUNT -Quiet
            if ($connection_result) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is online." -foregroundcolor green
                $list_of_online_computers.add($single_computer) | Out-Null
            }
            else {

                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
                Write-Host "$single_computer is not online." -foregroundcolor red
                $list_of_offline_computers.add($single_computer) | Out-Null
            }
        }
    }
    ## Try to create sensible output file path from one of the hostnames pinged.
    END {
        $Hostname_substring = $TargetComputer | Select-Object -First 1
        $hostname_substring = $hostname_substring -split '-'
        $hostname_substring = $hostname_substring[1]

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -nonewline
        Write-Host "Outputting list of online/offline hosts to: " -foregroundcolor green

        $list_of_online_computers | Out-File "$env:PSMENU_DIR\output\$hostname_substring-hostname_list-online.txt"
        $list_of_offline_computers | Out-File "$env:PSMENU_DIR\output\$hostname_substring-hostname_list-offline.txt"

        Write-Host "Online hosts are in $hostname_substring-hostname_list-online.txt" -foregroundcolor green
        Write-Host "Offline hosts are in $hostname_substring-hostname_list-offline.txt" -foregroundcolor red
        Start-Sleep -Seconds 2

        Invoke-Item "$env:PSMENU_DIR\output\"
        Read-Host "Press Enter when you're done reading the output."
    }
}
