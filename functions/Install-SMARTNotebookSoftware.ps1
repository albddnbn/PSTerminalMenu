function Install-SMARTNotebookSoftware {
    <#
    .SYNOPSIS
        Installs SMART Learning Suite software on target computers.
        Info: https://www.smarttech.com/en/education/products/software/smart-notebook

    .DESCRIPTION
        May also be able to use a hostname file eventually.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .EXAMPLE
        Install-SMARTNotebookSoftware -TargetComputer "s-c136-02"

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

    
        if ($TargetComputer.count -lt 20) {
            ## If the Get-LiveHosts utility command is available
            if (Get-Command -Name Get-LiveHosts -ErrorAction SilentlyContinue) {
                $TargetComputer = Get-LiveHosts -TargetComputerInput $TargetComputer
            }
        }

        # get the smartnotebook folder from irregular applications
        $SmartNotebookFolder = Get-ChildItem -path "$env:PSMENU_DIR\deploy\irregular" -Filter 'SMARTNotebook' -Directory -Erroraction SilentlyContinue
        if ($SmartNotebookFolder) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($SmartNotebookFolder.FullName), copying to target computers." -foregroundcolor green
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: SMARTNotebook folder not found in irregular applications, exiting." -foregroundcolor red
            exit
        }

        ## For each target computer - assign installation method - either office or classroom. Classroom installs the smartboard and ink drivers.
        $installation_methods = [system.collections.arraylist]::new()

        ForEach ($single_computer in $Targetcomputer) {
            $computer_target_path = "\\$single_Computer\C$\TEMP\SMARTNotebook"
            Copy-Item -Path "$($SmartNotebookFolder.FullName)" -Destination $computer_target_path -Recurse -Force
            Write-Host "Select SMART Software installation type for $single_computer below."
            $InstallationTypeReply = Menu @('Office', 'Classroom')


            $obj = [pscustomobject]@{
                computer      = $single_computer
                installmethod = $InstallationTypeReply
            }

            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$single_computer]:: Copied $($SmartNotebookFolder.FullName) to $computer_target_path."
    
            $installation_methods.add($obj) | Out-Null
        }

    }
    PROCESS {
        ## Run PSADT installation on target computers.
        Invoke-Command -ComputerName $TargetComputer -Scriptblock {
            $installation_method = $using:installation_methods | Where-Object { $_.computer -eq $env:COMPUTERNAME }
            $installation_method = $installation_method.installmethod
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME]:: Installation method set to: $installation_method"
            # unblock files
            Get-ChildItem -Path "C:\TEMP\SMARTNotebook" -Recurse | Unblock-File
            # get Deploy-SMARTNotebook.ps1
            $DeployScript = Get-ChildItem -Path "C:\TEMP\SMARTNotebook" -Filter 'Deploy-SMARTNotebook.ps1' -File -ErrorAction SilentlyContinue
            if ($DeployScript) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($DeployScript.FullName), executing." -foregroundcolor green
                Powershell.exe -ExecutionPolicy Bypass "$($DeployScript.FullName)" -DeploymentType "Install" -DeployMode "Silent" -InstallationType "$installation_method"
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Deploy-SMARTNotebook.ps1 not found, exiting." -foregroundcolor red
                exit
            }
        }
    }
    END {
        Write-Host ""
        Write-Host "Finished SMART Learning Suite installation(s)."
        Read-Host "Press enter to continue."
    }
}