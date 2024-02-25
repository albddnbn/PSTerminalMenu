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
    BEGIN {
        $reply = Read-Host "Sending reboot in $RebootTimeInSeconds seconds, or $([int]$RebootTimeInSeconds / 60) minutes, OK? (y/n)"
        if ($reply.ToLower() -eq 'y') {
    
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
            # get reboot time in mins
            # $rebootmins = [int]$RebootTimeInSeconds / 60
        }
        $RebootTimeInSeconds = [int]$RebootTimeInSeconds

    }
    PROCESS {
        if ($RebootMessage) {
            Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                shutdown  /r /t $using:reboottime /c "$using:RebootMessage"
            }
        }
        else {
            Restart-Computer $TargetComputer
        }
        Start-Sleep -Seconds 5
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Sending pings to verify they are offline..."
        ForEach ($single_computer in $TargetComputer) {
            $pingresult = $(Test-Connection $single_computer -count 1 -quiet)
            if ($pingresult) {
                $pingresult = "online" 
            }
            else {
                $pingresult = "offline"
            }
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer : $pingresult"
        }
    }
    END {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Reboot(s) sent."
    }
}
