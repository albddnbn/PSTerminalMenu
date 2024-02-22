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
    
        abuddenb / 02-17-2024
    #>
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        $TargetComputer,
        $AppName
    )
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

    # get the Excute-PSADTInstall.ps1 script from ./files
    # $execute_psadtinstall_ps1 = Get-ChildItem -Path "$env:LOCAL_SCRIPTS" -Filter 'Execute-PSADTInstall.ps1' -File -ErrorAction SilentlyContinue
    # if (-not $execute_psadtinstall_ps1) {
    #     Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Execute-PSADTInstall.ps1 not found in $env:PSMENU_DIR\files, ending function." -Foregroundcolor Red
    #     return
    # }
    # # tell user you found the full filename
    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($execute_psadtinstall_ps1.fullname)."

    ForEach ($chosen_app in $chosen_apps) {
        $DeploymentFolder = $ApplicationList | Where-Object { $_.Name -eq $chosen_app }
        if (-not $DeploymentFolder) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $chosen_app not found in $env:PSMENU_DIR\deploy\applications." -Foregroundcolor Red
            continue
        }
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($DeploymentFolder.FullName), copying to $($TargetComputer -join ', ')"
        Write-Host ""
        Write-Host ""
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Installing " -NoNewLine
        Write-Host "$($chosen_app.ToUpper())" -Foregroundcolor Green
        Write-Host ""
        Write-Host ""
        if ($TargetComputer -eq '127.0.0.1') {
            # can run locally using deployment folder in menu:
            Set-Location "$($DeploymentFolder.FullName)"
            read-host "$(pwd)"
            Powershell.exe -Executionpolicy bypass "./Deploy-$($deploymentfolder.name).ps1" -Deploymenttype 'install' -deploymode 'silent'
        }
        else {

            # clear previous folders:
            ForEach ($single_computer in $TargetComputer) {
                Write-Host "Removing any previous deployment folders for the app, and copying new folder over."
                Remove-Item "\\$single_computer\C$\temp\$($deploymentfolder.name)" -recurse -force -erroraction SilentlyContinue
                Copy-Item "$($DeploymentFolder.fullname)" -Destination "\\$single_computer\C$\temp\$($DeploymentFolder.Name)" -recurse -Force     
            }
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Finished copying deployment folders to remote computers, executing install scripts now..."
            ## Actual installation / running the script from ./menu/files
            Invoke-Command -ComputerName $TargetComputer -scriptblock $install_local_psadt_block -ArgumentList $chosen_app, $skip_pcs
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Finished installing $chosen_app on $($targetcomputer -join ', '). A good addition to this function would be to add something that checks for software on computers afterwards."
            # Cleanup the PSADT Folders in C:\temp
            ForEach ($single_computer in $TargetComputer) {
                Remove-Item "\\$single_computer\C$\temp\$($deploymentfolder.name)" -recurse -force -erroraction SilentlyContinue
            }       
        }
    }
    Set-Location $env:PSMENU_DIR
    Read-Host "Press enter to continue."
}