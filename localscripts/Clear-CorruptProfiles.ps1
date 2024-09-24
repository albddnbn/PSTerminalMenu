<#
.SYNOPSIS
    Searches local computer for any temporary user folders (ending in .DTCC), and any user profiles with signs of corruption.
    If a temporary user folder is found on a computer - the folder is either renamed or deleted based on whether it has files.
    User profiles linked to the owner of a temporary user folder are also cleared out.

.PARAMETER WhatIf_Setting
    Specifies whether the script will actually make changes to filesytem (perform deletions), or if script will just make note of signs of corruption.
#>
param(
    $WhatIf_Setting,
    $DomainName
)

# if whatif is disabled - script checks for logged in user
if (-not $whatif_setting) {
    $check_for_user = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
    if ($check_for_user) {
        # $check_for_user = $check_for_user -replace 'DTCC\\', ''
        $check_for_user = $check_for_user -replace "$DomainName\\", ''

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -Nonewline
        Write-Host "$check_for_user is logged in to $env:COMPUTERNAME and -WHATIF is disabled, skipping this computer." -Foregroundcolor Yellow
        return            
    }
}

$AllCorruptFolders = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object { ($_.Name -like "*.$DomainName*") -and ($_.NAme -notlike "*.old") }
$UniqueCorruptUsers = [System.Collections.ArrayList]::new()
        
# if there are no corrupt folders, continue to next computer
if (-not $AllCorruptFolders) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: No temp/corrupt folders found on computer, continuing to next one." -Foregroundcolor Green
    return
}

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: " -nonewline
Write-Host "Found $($AllCorruptFolders.count) temporary user folders on computer." -Foregroundcolor Yellow
ForEach ($Fname in $($AllCorruptFolders | Select -Exp Name)) {
    # split / grab real username
    $Fname = $Fname.split(".$DomainName")
    $Fname = $Fname[0]
    if ($UniqueCorruptUsers -notcontains $Fname) {
        $UniqueCorruptUsers.Add($Fname) | Out-Null
    }
}

# holds all case objects for the current computer

## Stage 4 - cycling through each affected username on the individual computer (each case)
ForEach ($IndividualUser in $UniqueCorruptUsers) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Clearing temp/corrupt data for: " -nonewline
    Write-Host "$IndividualUser" -Foregroundcolor Yellow
    # create blank case object to hold case details
    $case = [PSCustomObject]@{
        User           = $IndividualUser
        Year           = ""
        DeletedFolders = ""
        DeletedProfile = ""
        RenamedFolders = ""
    }
    $case_year = ""
    $deleted_folders = ""
    $deleted_profile = ""
    $renamed_folders = ""
    # Step 1. List of all folders (temp/normal) that pertain to a specific user on a PC
    # $Folders_for_current_user = Get-ChildItem -Path "C:\Users" -Filter "$($IndividualUser)*" -Directory -ErrorAction SilentlyContinue
    $Folders_for_current_user = Get-Item -Path "C:\Users\*" -Include $IndividualUser, "$IndividualUser.$DomainName*" | ? { $_.mode -eq 'd-----' }

    ## EMPTY FOLDERS
    # $deleted_folders = [System.Collections.ArrayList]::new()

    # clear all profiles for user from registry:
    # $users_profiles = Get-Ciminstance -class win32_userprofile | where-object { $_.LocalPath.split('\')[-1] -like "*$IndividualUser*" }
    ## tune line below - like may be unnecessary
    $users_profiles = Get-Ciminstance -class win32_userprofile | % { $_.localpath.split('\')[-1] } | ? { ($_ -eq "$IndividualUser") -or ($_ -like "$IndividualUser.$DomainName*") }

    if ($users_profiles) {
        ForEach ($profile in $users_profiles) {
            $user_sid = $profile.sid
            reg export "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$user_sid" "$BackupFolder\$($SingleFolder.BaseName)-$(Get-Date -Format "yyyy-MM-dd-HH-mm-ss").reg"
            $profile | Remove-CimInstance -ErrorAction SilentlyContinue -whatif:$whatif_setting
            $deleted_profile += "$($profile.localpath.split('\')[-1]); "
                    
        }
    }

    # clear all empty folders, rename all folders with files to <name>.old
    $LatestTimeStamp = ""

    $Folders_for_current_user | ForEach-Object {
        $check_for_files = Get-ChildItem -Path "$($_.FullName)" -File -Recurse -ErrorAction SilentlyContinue
        if (-not $check_for_files) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Removing empty folder: " -nonewline
            Write-Host "$($_.Name)" -Foregroundcolor Yellow
            Remove-Item -Path "$($_.FullName)" -Force -Recurse -ErrorAction SilentlyContinue -whatif:$whatif_setting
            $deleted_folders += "$($_.Name); "
        }
        else {
            # get latest timestamp for case year:
            $LatestFile = Get-ChildItem -Path "$($_.FullName)" -File -Recurse -ErrorAction SilentlyContinue | Sort-Object -Descending -Property LastWriteTime | select -First 1
            $Latest_timestamp_in_folder = $LatestFile | Select -Exp LastWriteTime
            # if latestfile is more recent that latesttimestamp, set latesttimestamp to latestfile
            if ($LatestTimestamp -eq "") {
                $LatestTimeStamp = $Latest_timestamp_in_folder
            }
            elseif ($Latest_timestamp_in_folder -gt $LatestTimeStamp) {
                $LatestTimeStamp = $Latest_timestamp_in_folder
            }
            # if latest_timestamp_in_folder.year -eq this year - rename to .old, otherwise delete
            if ($Latest_timestamp_in_folder.Year -eq $(Get-Date | Select -exp year)) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: " -nonewline
                Write-Host "$($_.Name) is not empty and has files modified this year, renaming to $($_.Name).old."
                Copy-Item "$($_.FullName)" -Destination "$($_.Fullname).old" -Recurse -Force -ErrorAction SilentlyContinue -whatif:$whatif_setting
                Remove-Item "$($_.FullName)" -Recurse -Force -WhatIf:$whatif_setting
                $deleted_folders += "$($_.Name); "
                $renamed_folders += "$($_.Name).old; "
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: " -nonewline
                Write-Host "$($_.Name) is not empty and has no files modified this year, deleting."
                Remove-Item "$($_.FullName)" -Force -Recurse -ErrorAction SilentlyContinue -whatif:$whatif_setting
                $deleted_folders += "$($_.Name); "
            }
        }
    }

    $case_year = $LatestTimeStamp.Year
    if ($LatestFile) {
        $users_latest_folder = $LatestFile | Select -Exp FullName
        $users_latest_folder = $users_latest_folder -split '\\'
        # index 0 = C:, index 1 = Users, index 2 will be the user foldername
        $users_latest_folder = $users_latest_folder[2]
    }

    # SET remaining CASE OBJECT PROPERTIES, ADD TO LIST
    $case.Year = $case_year
    $case.DeletedFolders = $deleted_folders
    $case.DeletedProfile = $deleted_profile
    $case.RenamedFolders = $renamed_folders
    return $case
}
