function Copy-RemoteFiles {
    <#
    .SYNOPSIS
        Recursively grabs target files or folders from remote computer(s) and copies them to specified directory on local computer.

    .DESCRIPTION
        TargetPath specifies the target file(s) or folder(s) to target on remote machines.
        TargetPath can be supplied as a single absolute path, comma-separated list, or array.
        OutputPath specifies the directory to store the retrieved files.
        Creates a subfolder for each target computer to store it's retrieved files.

    .PARAMETER TargetPath
        Path to file(s)/folder(s) to be grabbed from remote machines. Ex: 'C:\users\abuddenb\Desktop\test.txt'

    .PARAMETER OutputPath
        Path to folder to store retrieved files. Ex: 'C:\users\abuddenb\Desktop\grabbed-files'

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .EXAMPLE
        Copy-RemoteFiles -TargetPath "Users\Public\Desktop" -OutputPath "C:\Users\Public\Desktop" -TargetComputer "t-client-"

    .NOTES
        abuddenb / 2024
    #>
    param(
        [string]$TargetPath,
        [string]$OutputPath,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        $targetcomputer
    )

    BEGIN {
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
        
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
            # Safety catch to make sure
            if ($null -eq $TargetComputer) {
                # user said to end function:
                return
            }
        }
    
        # allow user to submit comma-separated list of paths?
        if ($TargetPath.GetType().name -eq 'String') {
            if ($TargetPath -like "*,*") {
                $TargetPath = $TargetPath -split ','
            }
            else {
                $TargetPath = @($TargetPath)
            }
            # if its an array
        }

        $temptargetpath = [system.collections.arraylist]::new()
        ForEach ($single_path in $TargetPath) {
            # chop off any drive letters that have been included
            if ($single_path -match '[A-Za-z]:\\*') {
                $single_path = $single_path.substring(3)
            }
            $temptargetpath.add($single_path)
        }

        $TargetPath = $temptargetpath
    }

    ## Copying files from target computers
    PROCESS {
        Foreach ($single_computer in $Targetcomputer) {
            $ping_test = Test-Connection -ComputerName $single_computer -Count 1 -Quiet

            if (-not $ping_test) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer didn't respond to one ping." -Foregroundcolor Red
                continue
            }

            if (-not (Test-Path $OutputPath\$single_computer)) {
                New-Item -Path $OutputPath\$single_computer -ItemType Directory -Force | Out-Null
            }

            ForEach ($single_item in $TargetPath) {
                if (Test-Path "\\$single_computer\C$\$single_item" -ErrorAction SilentlyContinue) {
                    Copy-Item "\\$single_computer\C$\$single_item" -Destination "$OutputPath\$single_computer" -Recurse -Force
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Copied \\$single_computer\C$\$single_item to $OutputPath\$single_computer."
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: \\$single_computer\C$\$single_item does not exist." -Foregroundcolor Red
                }
            }
        }
    }

    END {
        if (Test-Path "$Outputpath" -erroraction SilentlyContinue) {
            Invoke-item "$Outputpath"
        }

        Read-Host "Press enter to continue."
    }
}
