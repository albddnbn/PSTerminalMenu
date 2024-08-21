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
    
    .PARAMETER SkipOccupied
        If anything other than 'n' is supplied, the function will skip over computers that have users logged in.
        If 'n' is supplied, the function will install the application(s) regardless of users logged in.

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
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [ValidateScript({
                if (Test-Path "$env:PSMENU_DIR\deploy\applications\$_" -ErrorAction SilentlyContinue) {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($_) in $env:PSMENU_DIR\deploy\applications." -Foregroundcolor Green
                    return $true
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $($_) not found in $env:PSMENU_DIR\deploy\applications." -Foregroundcolor Red
                    return $false
                }
            })]
        [string]$AppName,
        [string]$SkipOccupied
    )
    ## 1. Handle Targetcomputer input if it's not supplied through pipeline.
    ## 2. If AppName parameter was not supplied, apps chosen through menu will be installed on target machine(s).
    ##    - menu presented uses the 'PS-Menu' module: https://github.com/chrisseroka/ps-menu
    ## 3. Define scriptblock - installs specified app using PSADT folder/script on local machine.
    ## 4. Prompt - should this script skip over computers that have users logged in?
    ## 5. create empty containers for reports:
    BEGIN {
        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
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
        
        ## 2. If AppName parameter was not supplied, apps chosen through menu will be installed on target machine(s).
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

            if ($chosen_apps -isnot [array]) {
                $chosen_apps = @($chosen_apps)
            }
            # validate the applist:
            ForEach ($single_app in $chosen_apps) {
                if (-not (Test-Path "$env:PSMENU_DIR\deploy\applications\$single_app")) {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_app not found in $env:PSMENU_DIR\deploy\applications." -Foregroundcolor Red
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Ending function." -Foregroundcolor Red
                    return
                }
            }
        }
        ## 3. Define scriptblock - installs specified app using PSADT folder/script on local machine.
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
        Clear-Host

        ## 4. Prompt - should this script skip over computers that have users logged in?
        ##    - script runs 'silent' installation of PSADT - this means installations will likely close the app / associated processes
        ##      before uninstalling / installing. This could disturb users.
        if ($SkipOccupied.ToLower() -eq 'n') {
            $skip_pcs = 'n'
        }
        else {
            $skip_pcs = 'y'
        }
    
        ## 5. create empty containers for reports:
        ## computers that were unresponsive
        ## apps that weren't able to be installed (weren't found in deployment folder for some reason.)
        ## - If they were presented in menu / chosen, apps should definitely be in deployment folder, though.
        $unresponsive_computers = [system.collections.arraylist]::new()
        $skipped_applications = [system.collections.arraylist]::new()

        ## installation COMPLETED list - not necessarily completed successfully. just to help with tracking / reporting.
        $installation_completed = [system.collections.arraylist]::new()
    
    
    }
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responsive, cycle through chosen apps and run the local psadt install scriptblock for each one,
    ##    on each target machine.
    ##    3.1 --> Check for app/deployment folder in ./deploy/applications, move on to next installation if not found
    ##    3.2 --> Copy PSADT folder to target machine/session
    ##    3.3 --> Execute PSADT installation script on target machine/session
    ##    3.4 --> Cleanup PSADT folder in C:\temp
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
            if ($single_computer) {
                ## 2. Ping test
                if ([System.IO.Directory]::Exists("\\$single_computer\c$")) {
                    if ($single_computer -eq '127.0.0.1') {
                        $single_computer = $env:COMPUTERNAME
                    }
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer responded to one ping, proceeding with installation(s)." -Foregroundcolor Green

                    ## create sesion
                    $single_target_session = New-PSSession $single_computer
                    ## 3. Install chosen apps by creating remote session and cycling through list
                    ForEach ($single_application in $chosen_apps) {

                        $DeploymentFolder = Get-ChildItem -Path "$env:PSMENU_DIR\deploy\applications\" -Filter "$single_application" -Directory -ErrorAction SilentlyContinue
                        if (-not $DeploymentFolder) {
                            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_application not found in $env:PSMENU_DIR\deploy\applications." -Foregroundcolor Red
                            $skipped_applications.Add($single_application) | Out-Null
                            Continue
                        }

                        ## Make sure there isn't an existing deployment folder on target machine:
                        Invoke-Command -Session $single_target_session -scriptblock {
                            Remove-Item -Path "C:\temp\$($using:single_application)" -Recurse -Force -ErrorAction SilentlyContinue
                        }

                        ## 3.2 Copy PSADT folder to target machine/session
                        $something_bad = $null
                        Copy-Item -Path "$($DeploymentFolder.fullname)" -Destination "\\$single_computer\c$\temp\" -Recurse -ErrorAction SilentlyContinue -ErrorVariable something_bad
                        
                        if ($something_bad) {
                            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -Nonewline
                            Write-Host "ERROR - Couldn't copy $($DeploymentFolder.name) to $single_computer." -Foregroundcolor Red
                            Continue
                        }

                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $($DeploymentFolder.name) copied to $single_computer."
                        ## 3.3 Execute PSADT installation script on target mach8ine/session
                        Invoke-Command -Session $single_target_session -scriptblock $install_local_psadt_block -ArgumentList $single_application, $skip_pcs
                        # Start-Sleep -Seconds 1
                        ## 3.4 Cleanup PSADT folder in temp
                        $folder_to_delete = "C:\temp\$($DeploymentFolder.Name)"
                        Invoke-Command -Session $single_target_session -command {
                            Remove-Item -Path "$($using:folder_to_delete)" -Recurse -Force -ErrorAction SilentlyContinue
                        }

                        $installation_completed.add($single_computer) | out-null
                    }
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Ping fail from $single_computer - added to 'unresponsive list'." -Foregroundcolor Red
                    $unresponsive_computers.Add($single_computer) | Out-Null
                }
            }
        }
    }
    ## 1. Open the folder that will contain reports if necessary.
    END {

        # if ($unresponsive_computers) {
        #     Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Unresponsive computers:" -Foregroundcolor Yellow
        #     $unresponsive_computers | Sort-Object
        # }
        # if ($skipped_applications) {
        #     Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Skipped applications:" -Foregroundcolor Yellow
        #     $skipped_applications | Sort-Object
        # }

        "Function completed execution on: [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]" | Out-File "$env:PSMENU_DIR\reports\$thedate\install-application-$thedate.txt" -append -Force
        "Installation process completed (not necessarily successfully) on the following computers:" | Out-File "$env:PSMENU_DIR\reports\$thedate\install-application-$thedate.txt" -append -Force

        $installation_completed | Sort-Object | Out-File "$env:PSMENU_DIR\reports\$thedate\install-application-$thedate.txt" -append -Force

        "Unresponsive computers:" | Out-File "$env:PSMENU_DIR\reports\$thedate\install-application-$thedate.txt" -append -Force

        $unresponsive_computers | Sort-Object | Out-File "$env:PSMENU_DIR\reports\$thedate\install-application-$thedate.txt" -append -Force

        Invoke-Item "$env:PSMENU_DIR\reports\$thedate\install-application-$thedate.txt" 
    }
    
}
