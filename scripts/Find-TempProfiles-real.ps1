[CmdletBinding()]
param (
    # ex: s-a22 for stanton, a wing 2nd floor 20s
    [String]$OutputCSVFilePath
    # [String]$SeqOutput
)

### --------
## STAGE 1 - start-transcript, check for prerequisites, and if arguments were supplied
# $TranscriptFile = "temp_profile_transcript.$(Get-Date -Format "yyyy-MM-dd-HH-mm-ss").txt"
#Start-Transcript -Path $TranscriptFile
# check for activedirectory module
if (!(Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Host "ActiveDirectory module not found, installing..." -ForegroundColor Yellow
    # DISM.exe /online /add-package /packagepath:"files\WindowsTH-KB2693643-x64.cab" /LimitAccess
    Add-WindowsPackage -PackagePath "files\WindowsTH-KB2693643-x64.cab" -Online -NoRestart

    Write-Host "ActiveDirectory module installed, proceeding." -ForegroundColor Green
}
Else {
    Write-Host "ActiveDirectory module found, proceeding." -ForegroundColor Green
}

if (-not $OutputCSVFilePath) {
    $OutputCSVFilePath = Read-Host "Enter filepath for output csv"
}
if ($OutputCSVFilePath -notlike "*.csv") {
    $OutputCSVFilePath = "$OutputCSVFilePath.csv"
}

# "Computer,User,Year,Details,Alert" | Out-File -FilePath "$OutputCSVFilePath" -Force -Encoding 'UTF8'
# "Computer,User,Year,Details,Alert" | Out-File -FilePath "C:\users\abuddenb_admin\test.csv" -Force -Encoding 'UTF8'

## ------- End stage 1 ------------------------


## Stage 2 - get list of computers from AD - INSERT HOSTNAME PREFIX HERE -- ex: s-lib-1* for all hostnames starting with 's-lib-1'
$computers = Get-ADComputer -Filter { DNSHostName -like "s-*" }
# $corrupt_computers = [System.Collections.ArrayList]::new() <# uncomment this line for a txt file list of (unique) corrupt pcs #>
## -------- End stage 2 -----------------------

## Stage 3 - contact with each computer in the $computers list
# $master_case_container = [System.Collections.ArrayList]::new()
$query_result = Invoke-Command -ComputerName $($computers | select -exp dnshostname) -ErrorVariable RemError -ScriptBlock {
    # check if a user is logged in, skip computer if it is
    try {
        $loggedinuser = get-process explorer -includeusername | where-object { $_.USername -notlike "*SYSTEM*" } | select -exp username
        $loggedinuser = $loggedinuser.replace("DTCC\", '')
    
        Write-Host "User $loggedinuser is logged in to $env:COMPUTERNAME" -Foregroundcolor Red
        Write-Host "moving on to next computer..."
        Write-Host ""
        continue
    }
    catch {
        Write-Host "No user logged in to $env:COMPUTERNAME, continuing the case loop." -Foregroundcolor Green
        Write-Host ""
    }


    # Get list of ALL Temporary folders on the computer - for ALL users, if none - skip computer, return false
    $AllCorruptFolders = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object { ($_.Name -like "*.DTCC*") -and ($_.NAme -notlike "*.old") }
    if (-not $AllCorruptFolders) {
        return $false
    }

    # create backup folder to hold registry backups on local PC
    $BackupFolder = "C:\temp\regbackups"
    if (-not (Test-Path $BackupFolder)) {
        # Write-Host "Creating $BackupFolder on $env:COMPUTERNAME..."
        New-Item -Path $BackupFolder -ItemType Directory 
    }

    $UniqueCorruptUsers = [System.Collections.ArrayList]::new()
    ForEach ($Fname in $($AllCorruptFolders | Select -Exp Name)) {
        # split / grab real username
        $Fname = $Fname.split(".DTCC")
        $Fname = $Fname[0]
        if ($UniqueCorruptUsers -notcontains $Fname) {
            $UniqueCorruptUsers.Add($Fname) | Out-Null
        }
    }

    # holds all case objects for the current computer
    $current_computer_cases = [System.Collections.ArrayList]::new()

    ## Stage 4 - cycling through each affected username on the individual computer (each case)
    ForEach ($IndividualUser in $UniqueCorruptUsers) {
        # create blank case object to hold case details
        $case = [PSCustomObject]@{
            Computer        = ""
            User            = ""
            Year            = ""
            Details         = ""
            Alert           = ""
            RealUserCurrent = ""
        }
        $case_actions = ""
        $case_year = ""
        # Step 1. List of all folders (temp/normal) that pertain to a specific user on a PC
        $AllFolders = Get-ChildItem -Path "C:\Users" -Filter "$($IndividualUser)*" -Directory -ErrorAction SilentlyContinue
        ## EMPTY FOLDERS
        $deleted_folders = [System.Collections.ArrayList]::new()
        # Step 2. cycle through allfolders, delete any and corresponding profile if they're empty
        ForEach ($SingleFolder in $AllFolders) {
            $profile = Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath.split('\')[-1] -eq $($SingleFolder.Name) }

            $FldrContents = Get-ChildItem -Path "$($SingleFolder.FullName)" -File -Recurse -ErrorAction SilentlyContinue
            if (-not $FldrContents) {
                # Step 2.1 - if there are no files in the folder, delete any corresponding profile from registry after backing up.
                if ($profile) {
                    $user_sid = $profile.sid
                    reg export "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$user_sid" "$BackupFolder\$($SingleFolder.BaseName)-$(Get-Date -Format "yyyy-MM-dd-HH-mm-ss").reg"
                    $profile | Remove-CimInstance -ErrorAction SilentlyContinue 
                    $case_actions += "del prof."

                }
                else {
                    $case_actions += "no prof."
                }
                # Step 2.2 - After deleting any profile in the registry - remove any corresponding folder structure in C:\users. If there was no profile, this folder will remain until it's removed with line below.
                if (Test-Path -Path "$($SingleFolder.FullName)") {
                    Write-Host "Removing $($SingleFolder.FullName) from $env:COMPUTERNAME"
                    Remove-Item -Path "$($SingleFolder.FullName)" -Force -Recurse 
                    $deleted_folders.Add($SingleFolder.Name) | Out-Null
                    $case_actions += "del folder $($SingleFolder.Name);"
                }
                else {
                    $case_actions += "No $($SingleFolder.Name) folder;"
                }
            }
        }

        ## ASSIGN CASE YEAR, after recapturing folders - the remaining ones should contain file(s)
        # Step 2.3 - allow the computer 1 seconds to 'catch up'
        Start-Sleep -Seconds 1
        # Step 3. Recapture list of all folders - folders *remaining* that pertain to this specific user, these folders will all contain files.
        # $AllFolders = Get-ChildItem -Path "C:\Users" -Filter "$($IndividualUser)*" -Directory -ErrorAction SilentlyContinue | where-object { $_.Name -notin $deleted_folders }
        $AllFolders = Get-ChildItem -Path "C:\Users" -Filter "$($IndividualUser)*" -Exclude "*.old" -Directory -ErrorAction SilentlyContinue
        $RemainingFolders = $AllFolders | where-object { $_.Name -notin $deleted_folders }
        if ($RemainingFolders.Count -eq 0) {
            write-host "No more folders found for $IndividualUser on $env:COMPUTERNAME" -foregroundcolor red
            # STILL NEEDS TO ADD OBJECT WITH CASEDETAILS ETC

            # add a resolved case object here
            # before cycling to the next user on current PC - add this user's case to current_comptuer_cases
            $case.Computer = $env:COMPUTERNAME
            $case.User = $IndividualUser
            $case.Year = $case_year
            $case.Details = $case_actions
            $case.Alert = 'resolved'
            $case.RealUserCurrent = $RealUserIsCurrent
            $current_computer_cases.Add($case) | Out-Null
            continue
        }
        # Step 4. Get the 'case year' property value from the file w/latest lastwritetime in the folder structures
        $LatestTimeStamp = ""
        ForEach ($SingleFolder in $AllFolders) {
            $LatestFile = Get-ChildItem -Path "$($SingleFolder.FullName)" -File -Recurse -ErrorAction SilentlyContinue | Sort-Object -Descending -Property LastWriteTime | select -First 1
            if ($LatestFile) {
                if ($LatestTimeStamp -lt $LatestFile.LastWriteTime) {
                    $LatestTimeStamp = $LatestFile.LastWriteTime
                }
            }
        }
        if ($LatestTimeStamp) {
            $case_year = $LatestTimeStamp.Year
        }

        # now if theres a latestfile - use that to get latest directory, if not just use the timestamps of directories
        if ($LatestFile.Exists) {
            $LatestFolder = Get-ChildItem -Path "C:\Users" -Filter "$($LatestFile.Directory.Name)" -Directory -ErrorAction SilentlyContinue
        }
        # else {
        #     $LatestFolder = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$($IndividualUser)*" }
        #     if ($LatestFolder.Name -in $deleted_folders) {
        #         $LatestFolder = $false
        #         $case_year = $false
        #     }
        # }

        if ($LatestFolder.BaseName -eq $IndividualUser) {
            # if real user is the current user, this means they've accessed the computer after having created the temp folders/profiles, and been able to access their regular folder/profile
            $RealUserIsCurrent = $true
            write-host "Real User is current for $individualuser on $env:COMPUTERNAME" -foregroundcolor green
        }
        else {
            $RealUserIsCurrent = $false
        }

        ## FOLDERS WITH FILES
        # Step 5. At this point, any remaining folders have files in them, rename them all to .old to preserve any data
        ForEach ($SingleFolder in $AllFolders) {
            $profile = Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath.split('\')[-1] -eq $($SingleFolder.Name) }

            if ($($SingleFolder.Name) -in $deleted_folders) {
                write-host "skipping $($SingleFolder.Name) because it would have been deleted earlier" -foregroundcolor yellow
                write-host "file contents include:"
                Get-ChildItem -Path "$($SingleFolder.FullName)" -File -Recurse -ErrorAction SilentlyContinue | select -exp fullname
                write-host "-----------------"
                continue
            }
            #  unless the realuser is current, then leave regular user folder alone
            if (($SingleFolder.BaseName -eq $IndividualUser) -and ($RealUserIsCurrent)) {
                continue
            }
            # if the folder isn't from this year, delete it
            if ($SingleFolder.LastWriteTime.Year -lt $($case_year | sort-object -descending | select -first 1)) {

                if ($profile) {
                    $user_sid = $profile.sid
                    reg export "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$user_sid" "$BackupFolder\$($SingleFolder.BaseName)-$(Get-Date -Format "yyyy-MM-dd-HH-mm-ss").reg"
                    $profile | Remove-CimInstance -ErrorAction SilentlyContinue 
                    $case_actions += "del prof."

                }
                else {
                    $case_actions += "no prof."
                }
                Write-Host "Deleting $($SingleFolder.FullName) from $env:COMPUTERNAME"
                Remove-Item -Path "$($SingleFolder.FullName)" -Force -Recurse -ErrorAction SilentlyContinue 
                $case_Actions += "del folder $($SingleFolder.Name); "
                continue
            }
            # if the folder was modified this year, the script will save the data by copying it to the $foldername.old directory
            elseif ($SingleFolder.LastWriteTime.Year -eq $((Get-Date).Year)) {
                # if the folder is from this year, rename it to .old
                Write-Host "Renaming $($SingleFolder.FullName) to $($SingleFolder.FullName).old on $env:COMPUTERNAME"
                # rename folder to old if it still remains (its from this year)
                Rename-Item -Path "$($SingleFolder.FullName)" -NewName "$($SingleFolder.FullName).old" -Force -ErrorAction SilentlyContinue  
                # Copy-Item -Path "$($SingleFolder.FullName)" -Destination "$($SingleFolder.FullName).old" -Force -Recurse -ErrorAction SilentlyContinue 
                $case_actions += ".old folder: $($SingleFolder.BaseName); "
                Start-Sleep -Seconds 1
            }
    
            # if the folder/files weren't written to this year, then script jumps past the above if/elseif and hits here - where both profile and folder are deleted w/only profile backup
            if ($profile) {
                Write-Host "Registry profile found for $($SingleFolder.BaseName)" -Foregroundcolor MAgenta
                if ($profile) {
                    $user_sid = $profile.sid
                    reg export "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$user_sid" "$BackupFolder\$($SingleFolder.BaseName)-$(Get-Date -Format "yyyy-MM-dd-HH-mm-ss").reg"
                    $profile | Remove-CimInstance -ErrorAction SilentlyContinue 
                    $case_actions += "del prof."

                }
                else {
                    $case_actions += "no prof."
                }
            }
            else {
                Write-Host "No profile found for $($SingleFolder.BaseName)" -Foregroundcolor magenta
                $case_actions += "no prof."
            }
            # if folder is still there - delete it
            if (Test-Path -Path "$($SingleFolder.FullName)") {
                Write-Host "Removing $($SingleFolder.FullName) from $env:COMPUTERNAME"
                Remove-Item -Path "$($SingleFolder.FullName)" -Force -Recurse -ErrorAction SilentlyContinue 
                $case_actions += "del folder $($SingleFolder.Name); "
            }
            # $case_actions += "Ren folder/ del prof: $($SingleFolder.Name) "
        }
        # end of looping thru folders w/files

        # UNTIL I/WE can find a better way - set alert to 'check' if the case year is current year
        if ($case_year -eq (Get-Date).Year) {
            $case_actions += "Alert: check"
            $alert_status = $true
        }
        else {
            $case_actions += " no alert"
            $alert_status = $false
        }


        # before cycling to the next user on current PC - add this user's case to current_comptuer_cases
        $case.Computer = $env:COMPUTERNAME
        $case.User = $IndividualUser
        $case.Year = $case_year
        $case.Details = $case_actions
        $case.Alert = $alert_status
        $case.RealUserCurrent = $RealUserIsCurrent
        $current_computer_cases.Add($case) | Out-Null
        # write-host "added case, with $case_year on $env:COMPUTERNAME for $IndividualUser" -foregroundcolor green
        # write-host "contents of c:\users for user that arent in deleted_items:"
        # Get-ChildItem -Path "C:\Users" -Filter "$($IndividualUser)*"-Directory -ErrorAction SilentlyContinue | where-object { $_.Name -notin $deleted_folders } | select -exp fullname
        # write-host "-----------------"
        write-host $case
        # $case | Export-CSV -Path '\\s-a227-26.dtcc.edu\c$\users\abuddenb_admin\test.csv' -NoTypeInformation -Append

    }
    # script shouldn't reach this point if there WERENT any cases - but to be safe i added else / false
    if ($current_computer_cases.Count -ge 1) {
        return $current_computer_cases
    }
    else {
        return $false
    }
}

foreach ($result in $query_result) {
    write-host $item
    ForEach ($case_file in $result) {
        # write-host $case_file
        if ($case_file.Computer) {
            $case = $case_file | Select Computer, User, Year, Details, Alert
            if (($case.Year -eq $((Get-Date).Year)) -or ($case.Computer -like "*01")) {
                # case year has to be something - if it's nothing, all folders were deleted
                if ($case.Year) {
                    $case.Alert = $true
                    write-host "set alert to true for $($case.Computer) - $($case.User) - $($case.Year)" -foregroundcolor red
                }
            }
            # get-adcomputer for case
            $case_computer = Get-ADComputer -Filter { DNSHostName -eq "$($case.Computer)" }
            $computer_dn = $case_computer.DistinguishedName
            if ($computer_dn -like "*Office*") {
                $case.Alert = 'true - office'
                write-host "set alert to true for $($case.Computer) - $($case.User) - $($case.Year) - OFFICE SITUATION" -foregroundcolor red

            }
            $case | Export-CSV -Path $OutputCSVFilePath -NoTypeInformation -Append
        }
    }
}
# output the query_result arraylist to the csv file
# $query_result | Export-Csv -Path $OutputCSVFilePath -NoTypeInformation -Append
Write-Host "Outputted results to $OutputCSVFilePath" -ForegroundColor Cyan

#Stop-Transcript



