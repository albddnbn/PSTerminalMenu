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
        Function validates the input Computer name by pinging it one time, if it fails - function fails to execute.
    #>
    [CmdletBinding()]
    param(
        [string]$sourcepath,
        [string]$destinationpath,
        $targetcomputer
    )
    BEGIN {
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
        if ($TargetComputer.count -lt 20) {
            $TargetComputer = Get-LiveHosts -TargetComputerInput $TargetComputer
        }

        if (-not (Test-Path "$sourcepath" -ErrorAction SilentlyContinue)) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -nonewline
            Write-Host "Source path $sourcepath does not exist." -foregroundcolor red

            Read-host "Press enter to continue."
            return
        }

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Starting file transfer(s) to " -nonewline
        Write-Host "$targetcomputer" -nonewline -foregroundcolor green
        Write-Host "."
        # chop off any drive letters that have been included
        if ($destinationpath -match '[A-Za-z]:\\*') {
            $destinationpath = $destinationpath.substring(3)
        }
    }
    PROCESS {
        ForEach ($single_computer in $targetcomputer) {

            $computer_target_path = "\\$single_Computer\C$\$destinationpath"

            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Destination path set to: $computer_target_path"

            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Copying $sourcepath to $computer_target_path."
            try {
                Copy-Item -Path $sourcepath -Destination $computer_target_path -Recurse -Force
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -nonewline
                \Write-Host "Failed to copy $sourcepath to $computer_target_path." -foregroundcolor red
            }
            Start-Sleep -Seconds 1
        }
    }
    END {

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: File transfer complete." -foregroundcolor green  
        Write-Host "If you'd like to check for file/folder's existence on computers, use: " -NoNewline
        Write-Host "Filesystem operations -> Scan-ForApporFilepath" -Foregroundcolor Yellow
    }
}
