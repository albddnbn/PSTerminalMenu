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
        abuddenb / 2024
        Will not work outside of Terminal Menu at this time: 02-17-2024
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        $TargetComputer,
        [string]$RoomName
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
        }
        $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
        # Safety catch to make sure
        if ($null -eq $TargetComputer) {
            # user said to end function:
            return
        }

        ## Definitely want to filter offline hosts in this one, and not depend on utility function.
        # create list of online / offline hosts
        $offline_hosts = @()
        $online_hosts = @()
        ForEach ($single_computer in $TargetComputer) {
            $test_ping = Test-Connection $single_computer -Count 1 -Quiet
            if ($test_ping) {
                $online_hosts += $single_computer
            }
            else {
                $offline_hosts += $single_computer
            }
        }
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Offline hosts: $($offline_hosts -join ', ') copied to clipboard." -foregroundcolor red
        "$($offline_hosts -join ', ')" | clip

        $TargetComputer = $online_hosts

        # selecting master computer:
        Write-Host "Use [SPACE] to select master computers."
        Write-Host "Computers not selected with have Veyon installed with the /NoMaster switch."
        $master_computer_selection = Menu $TargetComputer -Multiselect

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: MASTER COMPUTER(S) SET TO: " -NoNewline
        Write-Host "$($master_computer_selection -join ', ')" -foregroundcolor green
        Write-Host ""

        if (-not $RoomName) {
            $RoomName = Read-Host "Please enter the name of the room/location: "
        }
        # getting student computers:
        $student_computers = $targetcomputer | Where-Object { $_ -notin $master_computer_selection }
        Write-Host ""
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: STUDENT COMPUTERS SET TO: " -NoNewline
        Write-Host "$($student_computers -join ', ')" -foregroundcolor green
        Write-Host ""

        Read-Host "Press enter to proceed with the installation."
        Clear-Host

        # copy the ps app deployment folders over to temp dir
        # get veyon directory from irregular applications:
        $VeyonDeploymentFolder = Get-ChildItem "$env:PSMENU_DIR\deploy\irregular" -Filter "Veyon" -Directory -ErrorAction SilentlyContinue
        if (-not $VeyonDeploymentFolder) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find Veyon deployment folder in $env:PSMENU_DIR\deploy\irregular\Veyon\Veyon, exiting." -foregroundcolor red
            return
        }

        Write-Host ""
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Copying files to target computers: $($TargetComputer -join ', ')" -foregroundcolor green
        Write-Host ""

        ForEach ($single_computer in $TargetComputer) {
            $TargetPath = "C:\temp\Veyon"
            if ($single_computer -ne '127.0.0.1') {
                $TargetPAth = $TargetPath.replace('C:', "\\$single_computer\c$")
            }

            # delete existing veyon directory
            REmove-ITem -Path "C:\temp\Veyon" -Recurse -Force -ErrorAction SilentlyContinue

            Copy-Item -Path "$($VeyonDeploymentFolder.FullName)" -Destination $TargetPath -Recurse -Force
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$single_computer] :: Veyon folder copied to $TargetPath"
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
    }
    PROCESS {
        # run rest of master installs:
        Invoke-Command -ComputerName $master_computer_selection -ScriptBlock $install_veyon_scriptblock -ArgumentList 'y', 'C:\Temp\Veyon'

        # Write-Host "`n[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning STUDENT INSTALLATIONS."
        ## STUDENT INSTALLATIONS:
        Invoke-Command -ComputerName $student_computers -ScriptBlock $install_veyon_scriptblock -ArgumentList 'n', 'C:\temp\Veyon'
    }
    END {
        # create the string to add into the script
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

        Write-Host "Please run $scriptfilename on $($Master_Computers -join ', ') to create the room list of PCs you can view." -ForegroundColor Green
        Write-Host ""
        Write-host "These student computers were skipped because they're unresponsive:"
        Write-host "$($skipped_student_computers -join ', ')" -foregroundcolor red

        Invoke-Item "$env:PSMENU_DIR\output\$scriptfilename"

        # select first master computer, open rdp window to it
        $first_master = $Master_Computers[0]
        Open-RDP -SingleTargetComputer $first_master
    }
}
