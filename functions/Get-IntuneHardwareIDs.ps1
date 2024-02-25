Function Get-IntuneHardwareIDs {
    <#
    .SYNOPSIS
        Generates a .csv containing hardware ID info for target device(s), which can then be imported into Intune / Autopilot.
        If $Targetcomputer = '', function is run on local computer.
        Specify GroupTag using DeviceGroupTag parameter.

    .DESCRIPTION
        Uses Get-WindowsAutopilotInfo from: https://github.com/MikePohatu/Get-WindowsAutoPilotInfo/blob/main/Get-WindowsAutoPilotInfo.ps1
        Get-WindowsAutopilotInfo.ps1 is in the supportfiles directory, so it doesn't have to be installed/downloaded from online.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .PARAMETER DeviceGroupTag
        Specifies the group tag that will be set in target devices' hardware ID info.
        DeviceGroupTag value is used with the -GroupTag parameter of Get-WindowsAutopilotInfo.

    .PARAMETER OutputFile
        Used to create the name of the output .csv file, output to local computer.

    .EXAMPLE
        Get Intune Hardware IDs from all computers in room A227 on Stanton campus:
        Get-IntuneHardwareIDs -TargetComputer "t-client-" -OutputFile "TClientIDs" -DeviceGroupTag 'Student Laptops'

    .EXAMPLE
        Get Intune Hardware ID of single target computer
        Get-IntuneHardwareIDs -TargetComputer "t-client-01" -OutputFile "TClient01-ID"

    .NOTES
        Needs utility functions and menu environment variables to run at this point in time.
        Basically just a wrapper for the Get-WindowsAutopilotInfo function, not created by abuddenb.
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]        
        $TargetComputer,
        [Parameter(Mandatory = $true)]
        [string]$OutputFile,
        [Parameter(Mandatory = $false)]
        [string]$DeviceGroupTag
    )
    ############################################################################################
    ## BEGIN - TargetComputer and Outputfile parameter handling, attempt to filter offline hosts
    ############################################################################################
    $thedate = Get-Date -Format 'yyyy-MM-dd'
    $REPORT_DIRECTORY = "IntuneHardwareIDs"
    ## If Targetcomputer is an array or arraylist - it's already been sorted out.
    ## TARGETCOMPUTER HANDLING:
    ## If Targetcomputer is an array or arraylist - it's already been sorted out.
    if (($TargetComputer -is [System.Collections.IEnumerable]) -and ($TargetComputer -isnot [string])) {
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
                $TargetComputerInput = $TargetComputerInput + "x"
                $TargetComputerInput = Get-ADComputer -Filter * | Where-Object { $_.DNSHostname -match "^$TargetComputerInput*" } | Select -Exp DNShostname
                $TargetComputerInput = $TargetComputerInput | Sort-Object   
            }
        }
    }
    $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }
    # Safety catch to make sure
    if ($null -eq $TargetComputer) {
        # user said to end function:
        return
    }
    ## Generate output filepath
    if ($Outputfile -eq '') {
        $outputfile = Get-OutputFileString -Titlestring $REPORT_DIRECTORY -rootdirectory $env:PSMENU_DIR -foldertitle $REPORT_DIRECTORY -reportoutput
    }
    else {
        $outputfile = Get-OutputFileString -Titlestring $OutputFile -rootdirectory $env:PSMENU_DIR -foldertitle $REPORT_DIRECTORY -reportoutput
    }

    ## With this function - it's especially important to log offline computers, whose hardware IDs weren't taken.
    if ($TargetComputer -ne '127.0.0.1') {
        $online_hosts = [system.collections.arraylist]::new()
        $offline_hosts = [system.collections.arraylist]::new()
        ForEach ($single_computer in $TargetComputer) {
            $ping_result = Test-Connection $single_computer -Count 1 -Quiet
            if ($ping_result) {
                Write-Host "$single_computer is online." -Foregroundcolor Green
                $online_hosts.Add($single_computer) | Out-Null
            }
            else {
                Write-Host "$single_computer is offline." -Foregroundcolor Red
                $offline_hosts.add($single_computer) | out-null
            }
        }

        Write-Host "Copying offline hosts to clipboard." -foregroundcolor Yellow
        "$($offline_hosts -join ', ')" | clip

        $TargetComputer = $online_hosts
    }

    ## Find Get-WindowsAutopilotInfo script and dot source - hopefully from Supportfiles, will check internet if necessary.
    $getwindowsautopilotinfo = Get-ChildItem -Path "$env:SUPPORTFILES_DIR" -Filter "Get-WindowsAutopilotInfo.ps1" -File -ErrorAction SilentlyContinue
    if (-not $getwindowsautopilotinfo) {
        # Attempt to download script if there's Internet
        $check_internet_connection = Test-NetConnection "google.com" -ErrorAction SilentlyContinue
        if ($check_internet_connection.PingSucceeded) {
            # check for nuget / install
            $check_for_nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
            if ($null -eq $check_for_nuget) {
                # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: NuGet not found, installing now."
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
            }
            Install-Script -Name 'Get-WindowsAutopilotInfo.ps1' -Force 
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: " -NoNewline
            Write-Host "No internet connection detected, unable to generate hardware ID .csv." -ForegroundColor Red
            return
        }
    }
    else {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Found $($getwindowsautopilotinfo.fullname), importing.`r" -NoNewline
        Get-ChildItem "$env:SUPPORTFILES_DIR" -recurse | unblock-file
        . "$($getwindowsautopilotinfo.fullname)"
    }
    
    if ($TargetComputer -eq '127.0.0.1') {
        # Get-WindowsAutopilotInfo -outputfile "$outputfile.csv"
        Run-GetWindowsAutopilotInfo -OutputFile "$outputfile.csv" -GroupTag $DeviceGroupTag
    }
    else {
        # Get-WindowsAutopilotInfo -ComputerName $TargetComputer -OutputFile "$outputfile.csv"
        Run-GetWindowsAutopilotInfo -ComputerName $TargetComputer -OutputFile "$outputfile.csv" -GroupTag $DeviceGroupTag
    }

    Invoke-Item "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\"

    Read-Host "Press enter to return to menu."
    
}