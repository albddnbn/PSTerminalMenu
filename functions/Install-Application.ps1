function Install-Application {
    <#
	.SYNOPSIS
        Uses $env:PSMENU_DIR/deploy/applications folder to present menu to user. 
        Multiple app selections can be made, and then installed sequentially on target machine(s).
        Application folders should be PSADT folders, this function uses the traditional PSADT silent installation line to execute.
            Ex: For the Notepad++ application, the folder name is 'Notepad++', and installation script is 'Deploy-Notepad++.ps1'.

	.DESCRIPTION
        You can find some pre-made PSADT installation folders here:
        https://dtccedu-my.sharepoint.com/:f:/g/personal/abuddenb_dtcc_edu/Ervb5x-KkbdHvVcCBb9SK5kBCINk2Jtuvh240abVnpsS_A?e=kRsjKx
        Applications in the 'working' folder have been tested and are working for the most part.

	.PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).
        
    .PARAMETER AppName
        If supplied, the function will look for a folder in $env:PSMENU_DIR\deploy\applications with a name that = $AppName.
        If not supplied, the function will present menu of all folders in $env:PSMENU_DIR\deploy\applications to user.

	.EXAMPLE
        Run installation(s) on all hostnames starting with 's-a231-':
		Install-Application -TargetComputer 's-a231-'

    .EXAMPLE
        Run installation(s) on local computer:
        Install-Application

    .EXAMPLE
        Install Chrome on all hostnames starting with 's-c137-'.
        Install-Application -Targetcomputer 's-c137-' -AppName 'Chrome'

	.NOTES
        PSADT Folders: https://dtccedu-my.sharepoint.com/:f:/g/personal/abuddenb_dtcc_edu/Ervb5x-KkbdHvVcCBb9SK5kBCINk2Jtuvh240abVnpsS_A?e=kRsjKx
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
        $AppName
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
        ## Filter offline hosts.
        $online_computers = [system.collections.arraylist]::new()
        ForEach ($single_computer in $TargetComputer) {
            $test_ping = Test-Connection -ComputerName $single_computer -count 1 -Quiet
            if ($test_ping) {
                $online_computers.Add($single_computer) | Out-Null
            }
        }
        $TargetComputer = $online_computers
        # Safety catch to make sure
        if ($null -eq $TargetComputer) {
            # user said to end function:
            return
        }    
        if (-not $appName) {
            # present script/ADMIN with a list of apps to choose from
            $ApplicationList = Get-ChildItem -Path "$env:PSMENU_DIR\deploy\applications" -Directory | Where-object { $_.name -notin @('Veyon', 'SMARTNotebook') }

            Clear-Host
            $applist = ($ApplicationList).Name

            # divide applist into app_list_one and app_list_two
            ## THIS HAS TO BE DONE (AT LEAST WITH THIS PS-MENU MODULE - ANYTHING OVER ~30 ITEMS WILL CAUSE THE MENU TO FREEZE UP)
            $app_list_one = [system.collections.arraylist]::new()
            $app_list_two = [system.collections.arraylist]::new()
            $app_name_counter = 0
            ForEach ($single_app_name in $applist) {
                if ($app_name_counter -lt 29) {
                    $app_list_one.Add($single_app_name) | Out-Null
                }
                else {
                    $app_list_two.Add($single_app_name) | Out-Null
                }
                $app_name_counter++
            }

            # First 29 apps|
            Write-Host "Displaying the first 29 applications available:" -ForegroundColor Yellow
            $chosen_apps_one = Menu $app_list_one -MultiSelect
            Write-Host "More applications:" -ForegroundColor Yellow
            # Last 29 apps
            $chosen_apps_two = Menu $app_list_two -MultiSelect

            $chosen_apps = @()
            ForEach ($applist in @($chosen_apps_one, $chosen_apps_two)) {
                $appnames = $applist -split ' '
                $chosen_apps += $appnames
            }
        }
        elseif ($AppName) {
            $chosen_apps = $AppName -split ','
            # validate the applist:
            ForEach ($single_app in $chosen_apps) {
                if (-not (Test-Path "$env:PSMENU_DIR\deploy\applications\$single_app")) {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_app not found in $env:PSMENU_DIR\deploy\applications." -Foregroundcolor Red
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Ending function." -Foregroundcolor Red
                    return
                }
            }
        }

        # install local PSADT app scriptblock
        $install_local_psadt_block = {
            param(
                $app_to_install,
                $do_not_disturb
            )
            ## Remove previous psadt folders:
            # Remove-Item -Path "C:\temp\$app_to_install" -Recurse -Force -ErrorAction SilentlyContinue
            # Safety net since psadt script silent installs close app-related processes w/o prompting user
            $check_for_user = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
            if ($check_for_user) {
                if ($($do_not_disturb) -eq 'y') {
                    Write-Host "[$env:COMPUTERNAME] :: Skipping, $check_for_user logged in."
                    Continue
                }
            }

            # get the installation script
            $Installationscript = Get-ChildItem -Path "C:\temp" -Filter "Deploy-$app_to_install.ps1" -File -Recurse -ErrorAction SilentlyContinue
            # unblock files:
            Get-ChildItem -Path "C:\temp" -Recurse | Unblock-File
            # $AppFolder = Get-ChildItem -Path 'C:\temp' -Filter "$app_to_install" -Directory -Erroraction silentlycontinue
            if ($Installationscript) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Found $($Installationscript.Fullname), installing."
                Set-Location "$($Installationscript.DirectoryName)"
                Powershell.exe -ExecutionPolicy Bypass ".\Deploy-$($app_to_install).ps1" -DeploymentType "Install" -DeployMode "Silent"
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: ERROR - Couldn't find the app deployment script!" -Foregroundcolor Red
            }

        }



        # $chosen_apps = $chosen_apps_one + $chosen_apps_two
        # $applist = $applist | select -first 29
        Clear-Host

        $skip_pcs = Read-Host "Scripts are set to close the application (if running) before installing - skip computers with users logged in? [y/n]"

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Installing " -NoNewLine
        Write-Host "$($chosen_apps -join ', ')" -ForegroundColor Yellow
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: On $($targetcomputer -join ', ')" -ForegroundColor Yellow

        ## Copy deployment folders over, remove old ones:
        ForEach ($single_computer in $TargetComputer) {
            ForEach ($chosen_app in $chosen_apps) {

                if ($single_computer -ne '127.0.0.1') {
                    $DeploymentFolder = $ApplicationList | Where-Object { $_.Name -eq $chosen_app }
                    if (-not $DeploymentFolder) {
                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $chosen_app not found in $env:PSMENU_DIR\deploy\applications." -Foregroundcolor Red
                        continue
                    }

                    Remove-Item -Path "\\$single_computer\c$\temp\$($deploymentfolder.name)" -Recurse -Force -ErrorAction SilentlyContinue

                    Copy-Item -Path "$($DeploymentFolder.fullname)" -Destination "\\$single_computer\c$\temp\$($DeploymentFolder.Name)" -Recurse -Force

                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $($DeploymentFolder.name) copied to $single_computer"
                }
            }
        }
    }
    PROCESS {
        ForEach ($chosen_app in $chosen_apps) {
            $DeploymentFolder = $ApplicationList | Where-Object { $_.Name -eq $chosen_app }
            if (-not $DeploymentFolder) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $chosen_app not found in $env:PSMENU_DIR\deploy\applications." -Foregroundcolor Red
                continue
            }
            if ($TargetComputer -eq '127.0.0.1') {
                # can run locally using deployment folder in menu:
                Set-Location "$($DeploymentFolder.FullName)"
                read-host "$(pwd)"
                Powershell.exe -Executionpolicy bypass "./Deploy-$($deploymentfolder.name).ps1" -Deploymenttype 'install' -deploymode 'silent'
            }
            else { 
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Finished copying deployment folders to remote computers, executing install scripts now..."
                ## Actual installation / running the script from ./menu/files
                Invoke-Command -ComputerName $TargetComputer -scriptblock $install_local_psadt_block -ArgumentList $chosen_app, $skip_pcs   
            }
        }
    }

    END {
        ## Cleanup folders
        ForEach ($single_computer in $Targetcomputer) {
            if ($single_computer -ne '127.0.0.1') {
                ForEach ($single_app in $chosen_apps) {
                    Remove-Item -Path "\\$single_computer\c$\temp\$single_app" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Removed C:\temp\$single_app folder from from $single_computer."
                }
            }
        }


        Read-Host "Press enter to continue."

    }
    
}