function Install-NVIDIADriverAndSoftware {
    <#
.SYNOPSIS
    Checks the menu/drivers/nvidia folder for folders, and presents them as a menu to choose from.
    Copies chosen folder to target computers and executes setup.exe with /s /qn arguments.

.DESCRIPTION
    To create an NVIDIA Driver 'folder' - download the NVIDIA driver executable from their website and use 7zip to extract contents to a folder.
    There should be a 'setup.exe' file inside, which will be used to install the drivers and NVIDIA Control Panel software.

.PARAMETER TargetComputer
    Target computer or computers of the function.
    Single hostname, ex: 's-c136-02' or 's-c136-02.dtcc.edu'
    Path to text file containing one hostname per line, ex: 'D:\computers.txt'
    First section of a hostname to generate a list, ex: s-a227- will create a list of all hostnames that start with 
    s-a227-, in other words the Stanton Open Computer Lab student computers.

.EXAMPLE
    Install-NVIDIADriverAndSoftware -TargetComputer "s-a227-28"

.EXAMPLE
    Install / update NVIDIA drivers and software on all computers starting with 's-b220-2'
    Install-NVIDIADriverAndSoftware -TargetComputer "s-b220-2"

.NOTES
    Function validates the input Computer name by pinging it one time, if it fails - function fails to execute.
#>
    param(
        $TargetComputer
    )
    
    # UTILITY Functions - Dealing with TargetComputer and OutputFile
    # return new targetcomputer value
    . "$env:PSMENU_DIR\utils\Get-TargetComputers.ps1"
    $TargetComputer = Get-TargetComputers -TargetComputerInput $TargetComputer    
    $TargetComputer = $TargetComputer | where-object { $_ -ne $null }
    if ($TargetComputer.count -lt 20) {
        . "$env:MENU_UTILS\Get-LiveHosts.ps1"
        $TargetComputer = Get-LiveHosts -TargetComputerInput $TargetComputer
    }

    # get options - all directories in the drivers/nvidia folder
    $driver_options = Get-ChildItem -Path "$env:PSMENU_DIR\drivers\nvidia" -Directory -ErrorAction SilentlyContinue
    $driver_option_names = $driver_options | Select-Object -ExpandProperty Name
    $driver_choice = Menu $driver_option_names

    $chosen_driver_folder = $driver_options | Where-Object { $_.name -eq $driver_choice }
    $UpdateFolder = Get-CHildItem -Path "$env:PSMENU_DIR\drivers\nvidia" -Filter "$($chosen_driver_folder | select -exp name)" -Directory -ErrorAction SilentlyContinue
    if (($UpdateFolder) -and (Test-Path "$($UpdateFolder.fullname)\setup.exe")) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($UpdateFolder.Fullname) and setup.exe inside, copying folder to target computers."
    }
    else {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not find GPU driver folder, exiting." -Foregroundcolor Red
        Exit
    }
    # copy the files/folder over to target computers
    ForEach ($single_computer in $TargetComputer) {
        Copy-Item -Path "$($UpdateFolder.FullName)" -Destination "\\$single_computer\c$\users\abuddenb_admin" -Recurse -Force
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Copied folder to \\$single_computer\c$\users\abuddenb_admin"
    }
    
    # execute .exe on target computers
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Executing .exe on target computers."
    $results = Invoke-Command -ComputerName $TargetComputer -Scriptblock {
        $userpresent = get-process -name 'explorer' -includeusername -erroraction silentlycontinue | select -exp username
        $executed = $false
        $foldername = $using:UpdateFolder
        $foldername = $foldername | select -exp name
        $setupExe = Get-ChildItem -Path "C:\users\abuddenb_admin\$foldername" -Filter 'setup.exe' -File -ErrorAction SilentlyContinue
        if ($userpresent) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: User $($userpresent.split('\')[1]) is logged in, skipping execution on $env:COMPUTERNAME without checking for setup.exe file."
        }
        elseif ($setupExe) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($setupExe.Fullname), executing on $env:COMPUTERNAME."
            Start-Process -FilePath "$($setupExe.Fullname)" -ArgumentList '/s /qn' -Wait
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Executed $($setupExe.Fullname) on $env:COMPUTERNAME."
            $executed = $true
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not find setup.exe, exiting." -Foregroundcolor Red
            Exit
        }
    
        $obj = [pscustomobject]@{
            Userpresent = $userpresent
            Executed    = $executed
        }
        $obj
    } | Select * -ExcludeProperty RunspaceId, PSShowComputerName
    
    # check for users, reboot if no users are logged in
    $computers_with_no_users = $results | where-object { ($_.userpresent -eq $null) -and ($_.executed -eq $true) } | Select -exp pscomputername
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: The following computers have no users logged in: $computers_with_no_users, rebooting."
    
    Restart-Computer $computers_with_no_users -force
    

}

