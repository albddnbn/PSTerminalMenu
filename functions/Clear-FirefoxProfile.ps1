function Clear-FirefoxProfile {
    <#
    .SYNOPSIS
        Removes the profiles.ini file from the user's roaming profile, which will cause Firefox to recreate it on next launch.

    .PARAMETER Username
        Username of the user to remove the profiles.ini file from - used to target that users folder on the target computer.

    .PARAMETER TargetPC
        The single target computer from which to remove the profiles.ini file (Hasn't seemed useful to add ability to target multiple computers yet).
        Enter '' (Press [ENTER]) for localhost.

    .PARAMETER ClearLocalProfile
        'y' clears Local Firefox profile, which ' will delete all bookmarks, history, etc.
        Submitting any other value will only target the profiles.ini file.

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [String]$Username,
        [Parameter(Mandatory = $false)]
        [String]$TargetPC,
        [string]$ClearLocalProfile
    )
    if ($ClearLocalProfile.ToLower() -eq 'y') { $ClearLocalProfile = $true }
    else { $ClearLocalProfile = $false }
    
    ######################################################################################
    ## Scriptblock - removes Firefox profiles.ini / profile data from local profile folder
    ######################################################################################
    $delete_firefox_profile_Scriptblock = {
        param(
            $Targeted_user,
            $ClearProfile
        )
        # stop the running firefox processes
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Stopping any running firefox processes..."
        get-process 'firefox' | stop-process -force

        if ($ClearProfile) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Clearing local profiles..." -foregroundcolor yellow
            Remove-Item -Path "C:\Users\$targetuser\AppData\Local\Mozilla\Firefox\Profiles\*" -Recurse -Force
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Skipping deletion of local Firefox profiles."
        }
        # get rid of profiles.ini in roaming
        $profilesini = Get-ChildItem -Path "C:\Users\$Targeted_user\AppData\Roaming\Mozilla\Firefox" -Filter "profiles.ini" -File -ErrorAction SilentlyContinue
        if ($profilesini) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($profilesini.fullname), removing $($profilesini.fullname) from $env:COMPUTERNAME..."
            Remove-Item -Path $($profilesini.fullname) -Force

            Write-Host "Please ask the user to start firefox back up to see if the issue is resolved." -ForegroundColor Green
            return 0
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No profiles.ini file found in C:\Users\$Targeted_user\AppData\Roaming\Mozilla\Firefox" -ForegroundColor Red
            return 1
        }
    }

    ## If TargetPC isn't supplied, script is run on local computer
    if ($TargetPC -eq '') {
        $result = Invoke-Command -Scriptblock $delete_firefox_profile_Scriptblock -ArgumentList $Username, $ClearLocalProfile
        $result | Add-Member -MemberType NoteProperty -Name PScomputerName -Value $env:COMPUTERNAME
    }
    else {
        $result = Invoke-Command -ComputerName $TargetPC -Scriptblock $delete_firefox_profile_Scriptblock -ArgumentList $Username, $ClearLocalProfile
    }

    ## Display success/failure message
    if ($result -eq 0) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Successfully removed profiles.ini from $TargetPC." -ForegroundColor Green
    }
    else {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Failed to remove profiles.ini from $TargetPC, or it wasn't there for $Username." -ForegroundColor Red
    }

    # read-host "Press enter to continue."
}
