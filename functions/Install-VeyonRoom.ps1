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
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$RoomName,
        # comma-separated list of computers that get Veyon master installation.
        [string]$Master_Computer
    )
    ## 1. Handling TargetComputer input if not supplied through pipeline.
    ## 2. Create list of master computers from $Master_computer parameter
    BEGIN {
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline input for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
                    ## CREDITS FOR The code this was adapted from: https://intunedrivemapping.azurewebsites.net/DriveMapping
                    if ([string]::IsNullOrEmpty($env:USERDNSDOMAIN) -and [string]::IsNullOrEmpty($searchRoot)) {
                        Write-Error "LDAP query `$env:USERDNSDOMAIN is not available!"
                        Write-Warning "You can override your AD Domain in the `$overrideUserDnsDomain variable"
                    }
                    else {
        
                        # if no domain specified fallback to PowerShell environment variable
                        if ([string]::IsNullOrEmpty($searchRoot)) {
                            $searchRoot = $env:USERDNSDOMAIN
                        }

                        $matching_hostnames = (([adsisearcher]"(&(objectCategory=Computer)(name=$computer*))").findall()).properties
                        $matching_hostnames = $matching_hostnames.name
                        $NewTargetComputer += $matching_hostnames
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 2. Creating list of master computers, trim whitespace
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
                $VeyonDirectory,
                $DeleteFolder
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
            if ($DeleteFolder -eq 'y') {
                Remove-Item -Path $VeyonDirectory -Recurse -Force
            }
        }

        ## MASTER INSTALLATIONS:
        Write-Host "`n[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning MASTER INSTALLATIONS."
        Write-Host "[1] Veyon Master, [2] Veyon Student, [3] No Veyon"
        $reply = Read-Host "Would you like your local computer to be installed with Veyon?"
        if ($reply -eq '1') {
            Invoke-Command  -ScriptBlock $install_veyon_scriptblock -ArgumentList 'y', $VeyonDeploymentFolder.FullName, 'n'
            $master_computer_selection += @($env:COMPUTERNAME)
        }
        elseif ($reply -eq '2') {
            Invoke-Command  -ScriptBlock $install_veyon_scriptblock -ArgumentList 'n', $VeyonDeploymentFolder.FullName, 'n'
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
        ForEach ($single_computer in $TargetComputer) {

            # If there aren't any master computers yet - ask if this one should be master
            if (-not $master_computer_selection) {
                $reply = Read-Host "Would you like to make $single_computer a master computer? [y/n]"
                if ($reply.tolower() -eq 'y') {
                    $master_computer_selection = @($single_computer)
                }
            }

            ## 1.
            if ($single_computer) {

                ## 2. Test with ping
                $pingreply = Test-Connection $single_computer -Count 1 -Quiet
                if ($pingreply) {
                    ## Create Session
                    $target_session = New-PSSession -ComputerName $single_computer
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is responsive to ping, proceeding." -foregroundcolor green
                    ## Remove any existing veyon folder
                    Invoke-Command -Session $target_session -Scriptblock {
                        Remove-Item -Path "C:\temp\Veyon" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Copying Veyon source files to $single_computer." -foregroundcolor green
                    ## 3. Copy source files
                    Copy-Item -Path "$($VeyonDeploymentFolder.fullname)" -Destination C:\temp\ -ToSession $target_session -Recurse -Force

                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Installing Veyon on $single_computer." -foregroundcolor green
                    ## If its a master computer:
                    if ($single_computer -in $master_computer_selection) {
                        Invoke-Command -Session $target_session -ScriptBlock $install_veyon_scriptblock -ArgumentList 'y', 'C:\Temp\Veyon', 'y'
                    }
                    else {
                        Invoke-Command -Session $target_session -ScriptBlock $install_veyon_scriptblock -ArgumentList 'n', 'C:\Temp\Veyon', 'y'
                        $Student_Computers.Add($single_computer) | Out-Null
                    }
                }
                else {
                    ## 4. Missed list is below, student list = $student_computers
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is not responding to ping, skipping." -foregroundcolor red
                    $missed_computers.Add($single_computer) | Out-null
                }
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
