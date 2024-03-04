function Install-VeyonRoom {
    <#
    .SYNOPSIS
        Uses the Veyon PS App Deployment Toolkit folder in 'deploy\irregular' to install Veyon on target computers, then creates a script to run on the master computer to create the room list of PCs you can view.

    .DESCRIPTION
        Specify the master computer using the parameter, the /NoMaster installation switch is used to install on all other computers.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .PARAMETER RoomName
        The name of the room to be used in the Veyon room list - only used in the script that's output, not in actual installation.

    .PARAMETER Master_Computer
        The name of the master computer, Veyon installation is run without the /NoMaster switch on this computer.

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
        $TargetComputer,
        [string]$RoomName,
        # comma-separated list of computers that get Veyon master installation.
        [string]$Master_Computer
    )
    ## 1. Handling TargetComputer input if not supplied through pipeline.
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

        ## Creating list of master computers, trim whitespace
        $master_computer_selection = $($Master_Computers -split ',')
        $master_computer_selection | % { $_ = $_.Trim() }

        if (-not $RoomName) {
            $RoomName = Read-Host "Please enter the name of the room/location: "
        }

        # copy the ps app deployment folders over to temp dir
        # get veyon directory from irregular applications:
        $VeyonDeploymentFolder = Get-ChildItem "$env:PSMENU_DIR\deploy\irregular" -Filter "Veyon" -Directory -ErrorAction SilentlyContinue
        if (-not $VeyonDeploymentFolder) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find Veyon deployment folder in $env:PSMENU_DIR\deploy\irregular\Veyon\Veyon, exiting." -foregroundcolor red
            return
        }

        $install_veyon_scriptblock = {
            param(
                $MasterInstall,
                $VeyonDirectory
            )
            Get-ChildItem $VeyonDirectory -Recurse | Unblock-File
            Set-Location $VeyonDirectory
            $DeployVeyonPs1 = Get-ChildItem -Path $VeyonDirectory -Filter "*Deploy-Veyon.ps1" -File -Recurse -ErrorAction SilentlyContinue
            if (-not $DeployVeyonPs1) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find Deploy-Veyon.ps1 in $VeyonDirectory, exiting." -foregroundcolor red
                return
            }
            if ($MasterInstall -eq 'y') {
                Powershell.exe -ExecutionPolicy Bypass "$($DeployVeyonPs1.Fullname)" -DeploymentType "Install" -DeployMode "Silent" -MasterPC
            }
            else {
                Powershell.exe -ExecutionPolicy Bypass "$($DeployVeyonPs1.Fullname)" -DeploymentType "Install" -DeployMode "Silent"
            }

            Remove-Item -Path $VeyonDirectory -Recurse -Force
        }

        ## MASTER INSTALLATIONS:
        Write-Host "`n[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning MASTER INSTALLATIONS."
        Write-Host "[1] Veyon Master, [2] Veyon Student, [3] No Veyon"
        $reply = Read-Host "Would you like your local computer to be installed with Veyon?"
        if ($reply -eq '1') {
            Invoke-Command  -ScriptBlock $install_veyon_scriptblock -ArgumentList 'y', $VeyonDeploymentFolder.FullName
        }
        elseif ($reply -eq '2') {
            Invoke-Command  -ScriptBlock $install_veyon_scriptblock -ArgumentList 'n', $VeyonDeploymentFolder.FullName
        }

        ## Missed computers container
        $missed_computers = [system.collections.arraylist]::new()
        ## Student computers list:
        $Student_Computers = [system.collections.arraylist]::new()
    }
    ## 1. check targetcomputer for null / empty values
    ## 2. ping test target machine
    ## 3. If responsive - copy Veyon install folder over to session, and install Veyon student or master
    ## 4. Add any missed computers to a list, also add student installations to a list for end output.
    PROCESS {
        ## 1.
        if ($TargetComputer) {

            ## 2. Test with ping
            $pingreply = Test-Connection $TargetComputer -Count 1 -Quiet
            if ($pingreply) {
                ## Create Session
                $target_session = New-PSSession -ComputerName $TargetComputer

                ## Remove any existing veyon folder
                Invoke-Command -Session $target_session -Scriptblock {
                    Remove-Item -Path "C:\temp\Veyon" -Recurse -Force -ErrorAction SilentlyContinue
                }
                ## 3. Copy source files
                Copy-Item -Path "$($VeyonDeploymentFolder.fullname)" -Destination C:\temp\ -ToSession $target_session -Recurse -Force

                ## If its a master computer:
                if ($Targetcomputer -in $master_computer_selection) {
                    Invoke-Command -Session $target_session -ScriptBlock $install_veyon_scriptblock -ArgumentList 'y', 'C:\Temp\Veyon'
                }
                else {
                    Invoke-Command -Session $target_session -ScriptBlock $install_veyon_scriptblock -ArgumentList 'n', 'C:\Temp\Veyon'
                    $Student_Computers.Add($TargetComputer) | Out-Null
                }
            }
            else {
                ## 4. Missed list is below, student list = $student_computers
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer is not responding to ping, skipping." -foregroundcolor red
                $missed_computers.Add($TargetComputer) | Out-null
            }
        }
    }
    ## 1. Create script that needs to be run on master computers, to add client computers & make them visible.
    ## 2. Check if user wants to run master script on local computer.
    ## 3. Open an RDP window, targeting the first computer in the master computers list - RDP or some type of graphical
    ##    login is necessary to add clients.
    END {
        ## 1. Create script that needs to be run on master computers, to add client computers & make them visible.
        $scriptstring = @"
`$Student_Computers = @('$($Student_Computers -join "', '")')
`$RoomName = `'$RoomName`'
`$veyon = "C:\Program Files\Veyon\veyon-cli"
&`$veyon networkobjects add location `$RoomName
ForEach (`$single_computer in `$Student_Computers) {		
    Write-Host "[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ::  Adding student computer: `$single_computer."

    If ( Test-Connection -BufferSize 32 -Count 1 -ComputerName `$single_computer -Quiet ) {
        Start-Sleep -m 300
        `$IPAddress = (Resolve-DNSName `$single_computer).IPAddress
        `$MACAddress = Invoke-Command -Computername `$single_computer -scriptblock {
            `$obj = (get-netadapter -physical | where-object {`$_.name -eq 'Ethernet'}).MAcaddress
            `$obj
        }
        Write-Host " `$veyon networkobjects add computer `$single_computer `$IPAddress `$MACAddress `$RoomName "
        &`$veyon networkobjects add computer `$single_computer `$IPADDRESS `$MACAddress `$RoomName
    }
    Else {
        Write-Host "Didn't add `$single_computer because it's offline." -foregroundcolor Red
    }
}
"@
        # create the script that needs to be run on the master computer while RDP'd in (invoke-command is generating errors)
        $scriptfilename = "$RoomName-RunWhileLoggedIntoMaster.ps1"
        New-Item -Path "$env:PSMENU_DIR\output\$scriptfilename" -ItemType "file" -Value $scriptstring -Force | out-null

        $reply = Read-Host "Veyon room build script created, execute script to add student computers on local computer? [y/n]"
        if ($reply.ToLower() -eq 'y') {
            Get-Item "$env:PSMENU_DIR\output\$scriptfilename" | Unblock-File
            try {
                & "$env:PSMENU_DIR\output\$scriptfilename"
            }
            catch {
                WRite-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] " -nonewline
                Write-Host "[ERROR]" -NoNewline -foregroundcolor red
                Write-Host " :: Something went wrong when trying to add student computers to local Veyon master installation. "
            }
        }

        Write-Host "Please run $scriptfilename on $($master_computer_selection -join ', ') to create the room list of PCs you can view." -ForegroundColor Green
        Write-Host ""
        Write-host "These student computers were skipped because they're unresponsive:"
        Write-host "$($missed_computers -join ', ')" -foregroundcolor red

        Invoke-Item "$env:PSMENU_DIR\output\$scriptfilename"

        # select first master computer, open rdp window to it
        $first_master = $master_computer_selection[0]
        Open-RDP -SingleTargetComputer $first_master
    }
}
