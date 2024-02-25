Function Format-SecondaryDrive {
    <#
    .SYNOPSIS
        1. Uses Get-PhysicalDisk cmdlet to display list of available disks to user in a terminal menu (targets specified computer).
        2. Second menu displayed for filesystem type - NTFS or FAT32.
        3. Prompt for drive label.
        4. Function attempts to clear, initialize, partition, and format chosen drive on target machine(s), using specified parameters.

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

    
    ## Inventory disks so they can be presented in terminal menu scriptblock:
    $get_disks_for_menu_scriptblock = {
        $physical_disks = Get-PhysicalDisk | Where-Object { $_.MediaType -in @('SSD', 'HDD') } | Select DeviceId, FriendlyName, @{n = "Size (GB)"; e = { [math]::Round($_.Size / 1GB, 2) } }
        $physical_disks
    }   
    $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Sort

    if ($TargetComputer -eq '127.0.0.1') {
        $disk_inventory = Invoke-Command -Scriptblock $get_disks_for_menu_scriptblock
        $chosen_computer = '127.0.0.1'
    }
    else {

        Write-Host "Choose computer to get storage drive options:"
        # inventory one of the computers drives:
        $chosen_computer = Menu $Targetcomputer
        $disk_inventory = Invoke-Command -ComputerName $chosen_computer -Scriptblock $get_disks_for_menu_scriptblock
    }
    Clear-Host
    # Write-Host "Disk Inventory from: $chosen_computer"
    # $disk_inventory | ft -AutoSize

    # present menu with names:
    $chosen_disk = Menu $($disk_inventory | select -exp friendlyname)

    $filesystem_type = Menu @('NTFS', 'FAT32')

    $filesystem_label = read-host "Enter the Label for the drive, ex: 'Storage'"

    # format the chosen disk on all computers - computers have to have that disk and have it not as their OS drive
    $format_chosen_disk_scriptblock = {
        param(
            $target_disk,
            $system_type,
            $filesystem_label
        )
        $disk_number = (Get-PhysicalDisk | Where-Object { $_.FriendlyName -eq $target_disk }).deviceid

        Clear-Disk -FriendlyName $target_disk -removedata -confirm:$false
        # create partition: $Disk_Number = $hdd_storage | select -exp deviceid
        Initialize-Disk -Number $Disk_Number -PartitionStyle GPT
        New-Partition -DiskNumber $Disk_Number -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem $system_type -NewFileSystemLabel $filesystem_label -Confirm:$false
    
    }    
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Formatting chosen disk on $Targetcomputer."
    if ($TargetComputer -eq '127.0.0.1') {
        Invoke-Command -Scriptblock $format_chosen_disk_scriptblock -ArgumentList $chosen_disk, $filesystem_type, $filesystem_label
    }
    else {
        Invoke-Command -ComputerNAme $TargetComputer -Scriptblock $format_chosen_disk_scriptblock -ArgumentList $chosen_disk, $filesystem_type, $filesystem_label
    }
    
}