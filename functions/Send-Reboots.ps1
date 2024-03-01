function Send-Reboots {
    <#
    .SYNOPSIS
        Reboots the target computer(s) either with/without a message displayed to logged in users.

    .DESCRIPTION
        If a reboot msg isn't provided, no reboot msg/warning will be shown to logged in users.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .EXAMPLE
        Send-Reboot -TargetComputer "t-client-" -RebootMessage "This computer will reboot in 5 minutes." -RebootTimeInSeconds 300

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
        [string]$TargetComputer,
        [Parameter(Mandatory = $false)]
        [string]$RebootMessage,
        # the time before reboot in seconds, 3600 = 1hr, 300 = 5min
        [Parameter(Mandatory = $false)]
        [string]$RebootTimeInSeconds = 300
    )
    ## 1. Confirm time before reboot w/user
    ## 2. Handling of TargetComputer input
    ## 3. typecast reboot time to double to be sure
    ## 4. container for offline computers
    BEGIN {
        ## 1. Confirmation
        $reply = Read-Host "Sending reboot in $RebootTimeInSeconds seconds, or $([double]$RebootTimeInSeconds / 60) minutes, OK? (y/n)"
        if ($reply.ToLower() -eq 'y') {
    
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
        }
        ## 3. typecast to double
        $RebootTimeInSeconds = [double]$RebootTimeInSeconds

        ## 4. container for offline computers
        $offline_computers = [system.collections.arraylist]::new()

    }
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session and/or reboot.
    ## 3. Send reboot either with or without message
    ## 4. If machine was offline - add it to list to output at end.
    PROCESS {
        ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
        if ($TargetComputer) {
            ## 2. Ping test
            $ping_result = Test-Connection $TargetComputer -count 1 -Quiet
            if ($ping_result) {
                if ($TargetComputer -eq '127.0.0.1') {
                    $TargetComputer = $env:COMPUTERNAME
                }
                if ($RebootMessage) {
                    Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                        shutdown  /r /t $using:reboottime /c "$using:RebootMessage"
                    }
                    $reboot_method = "Reboot w/popup msg"
                }
                else {
                    Restart-Computer $TargetComputer
                    $reboot_method = "Reboot using Restart-Computer (no Force)" # 2-28-2024
                }
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Reboot sent to $TargetComputer using $reboot_method." -ForegroundColor Green
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer is offline." -Foregroundcolor Yellow
                $offline_computers.add($TargetComputer) | Out-Null
            }
        }
    }
    ## Output offline computers to terminal, and to file if requested
    END {
        if ($offline_computers) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Offline computers include:"
            Write-Host ""
            $offline_computers
            Write-Host ""
            $output_file = Read-Host "Output offline computers to txt file in ./output? [y/n]"
            if ($output_file.tolower() -eq 'y') {
                $offline_computers | Out-File -FilePath "./output/$thedate/Offline-NoReboot-$thedate.txt" -Force
            }
        }
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Reboot(s) sent."
    }
}

