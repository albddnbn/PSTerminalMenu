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
        If not supplied, an output filepath will be created using formatted string.

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
        [string]$OutputFile = '',
        [string]$DeviceGroupTag
    )
    ## 1. Set date and report directory variables.
    ## 2. Handle Targetcomputer input if it's not supplied through pipeline.
    ## 3. Create output filepath
    ## 4. Find Get-WindowsAutopilotInfo script and dot source - hopefully from Supportfiles.
    ##    *Making change soon to get rid of the Run-GetWindowsAutopilotinfo file / function setup [02-27-2024].
    BEGIN {
        ## 1. Date / Report Directory (for output file creation / etc.)
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        $REPORT_DIRECTORY = "IntuneHardwareIDs"
        ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
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
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        ## 3. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        if (Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) {
            if ($Outputfile.toLower() -eq '') {
                $REPORT_DIRECTORY = "AssetInfo"
            }
            else {
                $REPORT_DIRECTORY = $outputfile            
            }
            $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
            if ($outputfile.tolower() -eq '') {
                $iterator_var = 0
                while ($true) {
                    $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\AssetInfo-$thedate"
                    if ((Test-Path "$outputfile.csv") -or (Test-Path "$outputfile.xlsx")) {
                        $iterator_var++
                        $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\AssetInfo-$([string]$iterator_var)"
                    }
                    else {
                        break
                    }
                }
            }
        }
        Write-host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Getting asset information from computers now..."

        ## 4. Find Get-WindowsAutopilotInfo script and dot source - hopefully from Supportfiles, will check internet if necessary.
        $getwindowsautopilotinfo = Get-ChildItem -Path "$env:SUPPORTFILES_DIR" -Filter "Get-WindowsAutopilotInfo.ps1" -File -ErrorAction SilentlyContinue
        if (-not $getwindowsautopilotinfo) {

            ## Right now, installing the script in this way won't help to complete the function.
            ## ---------------------------------------------------------------------------------------------------------
            # # Attempt to download script if there's Internet
            # $check_internet_connection = Test-NetConnection "google.com" -ErrorAction SilentlyContinue
            # if ($check_internet_connection.PingSucceeded) {
            #     # check for nuget / install
            #     $check_for_nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
            #     if ($null -eq $check_for_nuget) {
            #         # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: NuGet not found, installing now."
            #         Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
            #     }
            #     Install-Script -Name 'Get-WindowsAutopilotInfo.ps1' -Force 
            # }
            # else {
            #     Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: " -NoNewline
            #     Write-Host "No internet connection detected, unable to generate hardware ID .csv." -ForegroundColor Red
            #     return
            # }
            ## ---------------------------------------------------------------------------------------------------------
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Get-WindowsAutopilotInfo.ps1 not found in supportfiles directory, unable to generate hardware ID .csv." -ForegroundColor Red
            return
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Found $($getwindowsautopilotinfo.fullname), importing.`r" -NoNewline
            Get-ChildItem "$env:SUPPORTFILES_DIR" -recurse | unblock-file
            . "$($getwindowsautopilotinfo.fullname)"
        }
    }
    
    ## 1. Make sure no $null or empty values are submitted to the ping test or scriptblock execution.
    ## 2. Ping the single target computer one time as test before attempting remote session.
    ## 3. If machine was responseive, use Get-WindowsAutopilotInfo.ps1 script to collect hardware ID, group tag, etc 
    ##    and append to csv.
    PROCESS {
        ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
        if ($TargetComputer) {
            ## 2. Send one test ping
            $ping_result = Test-Connection $TargetComputer -count 1 -Quiet
            if ($ping_result) {
                if ($TargetComputer -eq '127.0.0.1') {
                    $TargetComputer = $env:COMPUTERNAME
                }
                ## 3. Use Get-WindowsAutopilotInfo.ps1 script (I wrapped it in a 'Run-GetWindowsAutopilotInfo' function)
                Run-GetWindowsAutopilotInfo -ComputerName $TargetComputer -OutputFile "$outputfile.csv" -GroupTag $DeviceGroupTag -Append
                ## TRY THIS instead of having to use the 'wrapped' method -->
                # Set-ExecutionPolicy Bypass -Scope 'Session' -Force
                # Get-WindowsAutopilotInfo -ComputerName $TargetComputer -OutputFile "$outputfile.csv" -GroupTag $DeviceGroupTag -Append
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Targetcomputer didn't respond to one ping, skipping" -ForegroundColor Yellow
            }
        }
    }
    ## 1. Open the folder that will contain reports if necessary.
    END {
        ## 1. Open reports folder
        if ($outputfile.tolower() -ne 'n') {
            Invoke-Item "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\"
        }
        Read-Host "Press enter to return to menu."
    }
}