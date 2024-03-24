Function Format-SecondaryDrive {
    <#
    .SYNOPSIS
        1. Uses Get-PhysicalDisk cmdlet to display list of available disks to user in a terminal menu (targets specified computer).
        2. Second menu displayed for filesystem type - NTFS or FAT32.
        3. Prompt for drive label.
        4. Function attempts to clear, initialize, partition, and format chosen drive on target machine(s), using specified parameters.
        If the main OS drive has the same friendly name as the drive to be formatted - 

    .DESCRIPTION
        After OS has been installed on a device, secondary storage can be offered to the end-user.
        This function automates the formatting process, on groups of computers.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .EXAMPLE
        Target secondary drives on all computers with hostnames starting with: 't-client-'
        Format-SecondaryDrive -TargetComputer 't-client-'

    .NOTES
        abuddenb
    #>
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        $TargetComputer
    )
    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
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
                        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
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

        ## Define scriptblocks
        ## Inventory disks so they can be presented in terminal menu scriptblock:
        $get_disks_for_menu_scriptblock = {
            $physical_disks = Get-PhysicalDisk | Select DeviceId, FriendlyName, @{n = "DiskSize"; e = { [math]::Round($_.Size / 1GB, 2) } }
            $physical_disks
        }


        # format the chosen disk on all computers - computers have to have that disk and have it not as their OS drive
        $format_chosen_disk_scriptblock = {
            param(
                $target_disk,
                $system_type,
                $filesystem_label
            )
            $disk_number = (Get-PhysicalDisk | Where-Object { $_.FriendlyName -eq $target_disk }).deviceid

            Clear-Disk -Number $disk_number -removedata -confirm:$false
            # create partition: $Disk_Number = $hdd_storage | select -exp deviceid
            Initialize-Disk -Number $Disk_Number -PartitionStyle GPT
            New-Partition -DiskNumber $Disk_Number -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem $system_type -NewFileSystemLabel $filesystem_label -Confirm:$false
    
        }    

    }

    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
            if ($single_computer) {
                ## 2. Send one test ping
                $ping_result = Test-Connection $single_computer -count 1 -Quiet
                if ($ping_result) {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is online." -ForegroundColor Green

                    $disk_inventory = Invoke-command -computername $single_computer -scriptblock $get_disks_for_menu_scriptblock

                    ## create object list from disks
                    $disk_objects = [system.collections.arraylist]::new()
                    ForEach ($single_disk in $disk_inventory) {
                        $disk_objects.add([pscustomobject]@{
                                DeviceID     = $single_disk.deviceid
                                FriendlyName = $single_disk.friendlyname
                                Size         = $single_disk.DiskSize
                                MenuString   = "$($single_disk.friendlyname) - DeviceID: $($single_disk.deviceid) - Size: $($single_disk.disksize)"
                            })
                    
                    }

                    ## Prompt for user choice
                    $chosen_disk = Menu $($disk_objects | select -exp menustring)

                    ## Prompt for filesystem choice:
                    $filesystem_type = Menu @('NTFS', 'FAT32')

                    ## Prompt for drive label
                    $filesystem_label = read-host "Enter the Label for the drive, ex: 'Storage'"

                    ## Format the chosen disk
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Formatting chosen disk on $single_computer."

                    Invoke-Command -ComputerName $single_computer -Scriptblock $format_chosen_disk_scriptblock -ArgumentList $chosen_disk, $filesystem_type, $filesystem_label

                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is offline." -ForegroundColor Red
                    continue
                }
            }
        }
    }
    END {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Script completed." -ForegroundColor Green
    }
    
}