function Send-Files {
    <#
    .SYNOPSIS
        Sends a target file/folder from local computer to target path on remote computers.

    .DESCRIPTION
        You can enter both paths as if they're on local filesystem, the script should cut out any drive letters and insert the \\hostname\c$ for UNC path. The script only works for C drive on target computers right now.

    .PARAMETER SourcePath
        The path of the file/folder you want to send to target computers. 
        ex: C:\users\public\desktop\test.txt, 
        ex: \\networkshare\folder\test.txt

    .PARAMETER DestinationPath
        The path on the target computer where you want to send the file/folder. 
        The script will cut off any preceding drive letters and insert \\hostname\c$ - so destination paths should be on C drive of target computers.
        ex: C:\users\public\desktop\test.txt

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .EXAMPLE
        copy the test.txt file to all computers in stanton open lab
        Send-Files -sourcepath "C:\Users\Public\Desktop\test.txt" -destinationpath "Users\Public\Desktop" -targetcomputer "t-client-"

    .EXAMPLE
        Get-User -ComputerName "t-client-28"

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        $targetcomputer,
        [ValidateScript({
                Test-Path $_ -ErrorAction SilentlyContinue
            })]
        [string]$sourcepath,
        [string]$destinationpath
    )
    ## 1. Handle Targetcomputer input if it's not supplied through pipeline.
    BEGIN {
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
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
                        $TargetComputer = $TargetComputer + "x"
                        $TargetComputer = Get-ADComputer -Filter * | Where-Object { $_.DNSHostname -match "^$TargetComputer*" } | Select -Exp DNShostname
                        $TargetComputer = $TargetComputer | Sort-Object   
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
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. Use session to copy file from local computer.
    ##    Report on success/fail
    ## 4. Remove the pssession.
    PROCESS {
        ## 1. no empty Targetcomputer values past this point
        if ($targetcomputer) {
            ## 2. Ping target machine one time
            $pingreply = Test-Connection $TargetComputer -Count 1 -Quiet
            if ($pingreply) {
                $target_session = New-PSSession $TargetComputer
                try {
                    Copy-Item -Path "$sourcepath" -Destination "$destinationpath" -ToSession $target_session -Recurse
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Transfer of $sourcepath to $destinationpath ($Targetcomputer) complete." -foregroundcolor green
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Failed to copy $sourcepath to $destinationpath on $targetcomputer." -foregroundcolor red
                }
                ## 4. Bye pssession
                Remove-PSSession $target_session
            }
        }
    }
    ## 1. Write an ending message to terminal.
    END {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: File transfer(s) complete." -foregroundcolor green  
        Write-Host "If you'd like to check for file/folder's existence on computers, use: " -NoNewline
        Write-Host "Filesystem operations -> Scan-ForApporFilepath" -Foregroundcolor Yellow

        Read-Host "`nPress [ENTER] to continue."
    }
}
