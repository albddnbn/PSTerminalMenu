function Clear-ChromeBrowsingData {
    <#
    .SYNOPSIS
        Deletes any 'Cache Data' folders found in the target user's Chrome profile(s) on target computer.
        Browsing data is not necessarily only in the .\Google\Chrome\User Data\Default\Cache directory, organization-managed profiles may be stored elsewhere.

    .DESCRIPTION
        Deletes all of target user's browsing data for all Chrome profiles stored on computer.
        Browsing data, cookies, history - everything in browser cache.

    .PARAMETER Username
        Target user. If username is not supplied, the script looks for currently logged in user on the TargetPC.

    .PARAMETER TargetPC
        Target computer, if not specified the script assigns localhost (127.0.0.1) target.

    .PARAMETER UseCaution
        'y' will display popup on target computer(s) asking for user consent to kill Chrome processes and delete browsing data.
        'n' will kill Chrome processes and delete browsing data without prompting the user.

    .PARAMETER TargetAllProfiles
        'y' targets ALL Chrome user profiles on target computer, for all users.
        'n' targets only the latest Chrome profile on target computer.

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    # deleting profiles.ini in roaming profile fixed issue
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [String]$Username,
        [Parameter(Mandatory = $true)]
        [String]$TargetPC,
        [string]$UseCaution,
        [string]$TargetAllProfiles
    )

    if (-not $Username) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No username specified, " -nonewline
        Write-Host "will target active user on $TargetPC." -ForegroundColor Yellow
    }

    # scriptblock that will clear chrome browsing data when run locally on computer
    $purge_chrome_browsing_data = {
        param(
            $targeted_user,
            $cautious, # will display popup to user - allow them to choose yes / no to kill chrome and delete their browsing data
            $allprofiles # will either delete browsing data for all user's chrome profiles, or go by latest folder (latest last modified timestamp on folder)
        )
        if (-not $targeted_User) {
            $targeted_user = (Get-Process -name 'explorer' -includeusername -ErrorAction SilentlyContinue).Username
            $targeted_user = $targeted_user.split('\')[1]
        }
        if ($allprofiles -eq 'n') {
            $allprofiles = $false
        }
        else {
            $allprofiles = $true
        }

        if ($cautious.ToLower() -eq 'y') {
            # THIS is not going to work (haven't figured out yet)
            # # source: https://4sysops.com/archives/how-to-display-a-pop-up-message-box-with-powershell/
            # Add-Type -AssemblyName PresentationCore, PresentationFramework
            # $ButtonType = [System.Windows.MessageBoxButton]::YesNo
            # $MessageIcon = [System.Windows.MessageBoxImage]::Warning
            # $MessageBody = "Allow Chrome application to be closed while your browsing data is deleted?"
            # $MessageTitle = "Please confirm"
            # $Result = [System.Windows.MessageBox]::Show($MessageBody, $MessageTitle, $ButtonType, $MessageIcon)
            # if ($result -eq 'No') {
            #     Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: User chose not to delete browsing data." -ForegroundColor Yellow
            #     return
            # }
            if (Get-Process -name "*chrome*" -erroraction silentlycontinue) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Chrome is running, skipping since cautious was specified." -ForegroundColor Yellow
                continue
            } 

        }

        # kill any running chrome process
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] " -NoNewline
        Write-Host "[$env:COMPUTERNAME]" -nonewline -ForegroundColor Yellow
        Write-Host " :: Stopping any running chrome processes."
        Get-Process -name 'chrome' -erroraction SilentlyContinue | Stop-Process -force -ErrorAction SilentlyContinue

        $items_to_remove = @(
            'History',
            'Cookies',
            'Cache',
            'Web Data'
        )

        # get default folder and any profile* folders
        $default_chrome = Get-ChildItem -Path "C:\Users\$targeted_user\AppData\Local\Google\Chrome\User Data\Default\" -Directory -ErrorAction SilentlyContinue
        # any other folders in that start with 'profile'
        $chrome_profiles = Get-ChildItem -Path "C:\Users\$targeted_user\AppData\Local\Google\Chrome\User Data\"  -Filter "Profile*" -Directory -ErrorAction SilentlyContinue
        # get the one with the latest last modified timestamp
        if (-not $allprofiles) {
            $chrome_profiles = $chrome_profiles | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
        } 
    
        ForEach ($profile_folder in @($($default_chrome.fullname), $($chrome_profiles.fullname))) {
            ForEach ($single_item in $items_to_remove) {
                if (Test-Path "$profile_folder\$single_item" -ErrorAction SilentlyContinue) {
                    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] " -NoNewline
                    # Write-Host "[$env:COMPUTERNAME]" -nonewline -ForegroundColor Yellow
                    # Write-Host " :: Removing $single_item from $env:COMPUTERNAME..."
                    Remove-Item -Path "$profile_folder\$single_item" -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        if ($cautious.ToLower() -eq 'y') {
            Add-Type -AssemblyName PresentationCore, PresentationFramework
            $ButtonType = [System.Windows.MessageBoxButton]::Ok
            $MessageIcon = [System.Windows.MessageBoxImage]::Information
            $MessageBody = "Finished deleting Chrome browsing data, you can return to using Chrome normally now. Have a great day!"
            $MessageTitle = "Complete"
            $Result = [System.Windows.MessageBox]::Show($MessageBody, $MessageTitle, $ButtonType, $MessageIcon)
        }

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] " -NoNewline
        Write-Host "[$env:COMPUTERNAME]" -nonewline -ForegroundColor Yellow
        Write-Host " :: Browsing data removed for $targeted_user."

    }

    if ($TargetPC -eq '') {
        Invoke-Command -Scriptblock $purge_chrome_browsing_data -ArgumentList $Username, $UseCaution, $TargetAllProfiles
    }
    else {
        Invoke-Command -ComputerName $TargetPC -Scriptblock $purge_chrome_browsing_data -ArgumentList $Username, $UseCaution, $TargetAllProfiles
    }

    Read-Host "Press enter to continue."
}
