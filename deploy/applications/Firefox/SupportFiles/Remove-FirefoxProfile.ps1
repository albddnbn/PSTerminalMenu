# deleting profiles.ini in roaming profile fixed issue
function Remove-FirefoxProfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [String]$Username,
        [Parameter(Mandatory = $false)]
        [String]$TargetPC,
        [switch]$ClearLocalProfile = $false
    )

    if (-not $username) {
        $Username = Read-Host "Enter username"
    }
    if (-not $TargetPC) {
        $TargetPC = Read-Host "Enter computername"
    }


    Invoke-Command -ComputerName $TargetPC -ScriptBlock {
        # if username hasn't been provided, get it from the current logged on user
        $targetuser = $using:username
        if (-not ($targetuser)) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No username supplied, targeting currently logged in user."
            $targetuser = Get-Process -Name 'explorer' -IncludeUsername -ErrorAction silentlycontinue | Select -exp username

        }
        # stop the running firefox processes
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Stopping any running firefox processes..."
        get-process 'firefox' | stop-process -force

        $ClearProfile = $using:ClearLocalProfile

        if ($ClearProfile) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Clearing local profiles..." -foregroundcolor yellow
            Remove-Item -Path "C:\Users\$targetuser\AppData\Local\Mozilla\Firefox\Profiles\*" -Recurse -Force
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Skipping deletion of local Firefox profiles."
        }
        # get rid of profiles.ini in roaming
        $profilesini = Get-ChildItem -Path "C:\Users\$($using:username)\AppData\Roaming\Mozilla\Firefox" -Filter "profiles.ini" -File -ErrorAction SilentlyContinue
        if ($profilesini) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($profilesini.fullname), removing $($profilesini.fullname) from $env:COMPUTERNAME..."
            Remove-Item -Path $($profilesini.fullname) -Force

            Write-Host "Please ask the user to start firefox back up to see if the issue is resolved." -ForegroundColor Green
            Exit 0
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No profiles.ini file found in C:\Users\$($using:username)\AppData\Roaming\Mozilla\Firefox" -ForegroundColor Red
            Exit 1
        }
    }
}