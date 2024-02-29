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
    ## 1. Set PingCount - # of pings sent to each target machine.
    ## 2. Handle Targetcomputer if not supplied through the pipeline.
    BEGIN {
        ## 1. Set PingCount - # of pings sent to each target machine.
        $PING_COUNT = 1
        ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
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
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## COLLECTIONS LISTS - successful/failed pings.
        $list_of_online_computers = [system.collections.arraylist]::new()
        $list_of_offline_computers = [system.collections.arraylist]::new()
    }

    ## Ping target machines $PingCount times and log result to terminal.
    PROCESS {
        if ($TargetComputer) {
            $connection_result = Test-Connection $TargetComputer -count $PING_COUNT -Quiet
            $ping_responses = ($connection_result | Measure-Object -Sum).Count
            if ($connection_result) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is online [$ping_responses responses]" -foregroundcolor green
                $list_of_online_computers.add($single_computer) | Out-Null
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
                Write-Host "$single_computer is not online." -foregroundcolor red
                $list_of_offline_computers.add($single_computer) | Out-Null
            }
        }
    }
    ## Output offline/online hosts to txt files in output folder
    END {
        ## Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        if ($Outputfile.tolower() -eq 'n') {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
        }
        else {
            $iterator_var = 0
            while ($true) {
                $outputfile = "$env:PSMENU_DIR\output\$thedate\hostname_list"
                if ((Test-Path "$outputfile-online.txt") -or (Test-Path "$outputfile-offline.txt")) {
                    $outputfile = "$env:PSMENU_DIR\output\$thedate\hostname_list-$([string]$iterator_var)"
                    $iterator_var++
                }
                else {
                    break
                }
            }
        }

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -nonewline
        Write-Host "Outputting list of online/offline hosts to: " -foregroundcolor green

        $list_of_online_computers | Out-File "$outputfile-online.txt"
        $list_of_offline_computers | Out-File "$outputfile-offline.txt"

        Write-Host "Online hosts are in $outputfile-online.txt" -foregroundcolor green
        Write-Host "Offline hosts are in $outputfile-offline.txt" -foregroundcolor red
        Start-Sleep -Seconds 2

        Invoke-Item "$env:PSMENU_DIR\output\$thedate"
        Read-Host "Press Enter when you're done reading the output."
    }

}