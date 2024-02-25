function Scan-Office2021 {
    <#
    .SYNOPSIS
        Checks for a user logged in to a remote computer using the get-process cmdlet to check explorer.exe.

    .DESCRIPTION
        If the process doesn't exist, it returns false, because any user currently logged in to the PC will have explorer.exe running.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .EXAMPLE
        Scan-Office2021 -TargetComputer "t-client-"

    .EXAMPLE
        Scan-Office2021 -ComputerName "t-client-28"

    .NOTES
        Additional notes about the function.
    #>
    param (
        $TargetComputer
        # $Outputfile
    )

    $REPORT_TITLE = 'Office2021Scan'
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
    if ($TargetComputer.count -lt 20) {
        $TargetComputer = Get-LiveHosts -TargetComputerInput $TargetComputer
    }
    $outputfile = ''
    #return new output filepath value
    if ($Outputfile -eq '') {
        $OutputFile = Get-OutputFileString -TitleString $REPORT_TITLE -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_TITLE -ReportOutput
    }
    elseif ($outputfile.ToLower() -ne 'n') {    
        $OutputFile = Get-OutputFileString -TitleString $OutputFile -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_TITLE -ReportOutput
    }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning Office2021 scan on target computers now."

    $results = Invoke-Command -ComputerName $TargetComputer -Scriptblock {
        # Loop through each registry path and retrieve the list of subkeys
        $uninstallKeys = Get-ChildItem -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue
        $path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
        foreach ($key in $uninstallKeys) {
            $keyPath = Join-Path -Path $path -ChildPath $key.PSChildName
            $displayName = (Get-ItemProperty -Path $keyPath -Name "DisplayName" -ErrorAction SilentlyContinue).DisplayName

            if ($displayName -like "*Office*Professional*") {
                $publisher = (Get-ItemProperty -Path $keyPath -Name "Publisher" -ErrorAction SilentlyContinue).Publisher


                if ($publisher -like "*Microsoft*") {


                    $uninstallString = (Get-ItemProperty -Path $keyPath -Name "UninstallString" -ErrorAction SilentlyContinue).UninstallString
                    $version = (Get-ItemProperty -Path $keyPath -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
                    $installLocation = (Get-ItemProperty -Path $keyPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
                    $installdate = (Get-ItemProperty -Path $keyPath -Name "InstallDate" -ErrorAction SilentlyContinue).InstallDate


                    $obj = [pscustomobject]@{
                        DisplayName     = $displayName
                        Publisher       = $publisher
                        UninstallString = $uninstallString
                        Version         = $version
                        InstallLocation = $installLocation
                        InstallDate     = $installdate
                        Office2021Found = $false
                    }
                    if ($displayname -like "*2021*") {
                        $obj.Office2021Found = $true
                        # found a match, so break
                        break
                    }
                }
            }
        }

        $obj
    }  | Select * -ExcludeProperty RunspaceId, PSShowComputerName | Sort -Property PSComputerName

    $results | sort-object -property PSComputerName | format-table -autosize

    if ($outputfile.ToLower() -ne 'n') {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting results to " -NoNewline
        Write-Host "$outputfile.csv and $outputfile.xlsx" -Foregroundcolor Green

        Output-Reports -Filepath "$outputfile" -Content $results -ReportTitle "Office2021Scan" -CSVFile $true -XLSXFile $true

        Invoke-Item "$env:PSMENU_DIR\reports\$thedate\$REPORT_TITLE\"
    }
    else {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."
    }
}