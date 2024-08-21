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

    .INPUTS
        [String[]] - an array of hostnames can be submitted through pipeline for Targetcomputer parameter.

    .OUTPUTS
        Outputs .csv file containing HWID information for target devices, to upload them into Intune.

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
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
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

        ## 2. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline input for targetcomputer." -Foregroundcolor Yellow
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

                        $matching_hostnames = (([adsisearcher]"(&(objectCategory=Computer)(name=$computer*))").findall()).properties
                        $matching_hostnames = $matching_hostnames.name
                        $NewTargetComputer += $matching_hostnames
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

        ## 3. Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        if ((Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) -and ($null -ne $env:PSMENU_DIR)) {
            if ($Outputfile.toLower() -ne '') {
                $REPORT_DIRECTORY = "$outputfile"
            }
            else {
                $REPORT_DIRECTORY = "IntuneHardwareIDs"          
            }
            $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
            if ($outputfile.tolower() -eq '') {
                $iterator_var = 0
                while ($true) {
                    $outputfile = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\$REPORT_DIRECTORY-$thedate"
                    if ((Test-Path "$outputfile.csv" -ErrorAction Silentcontinue)) {
                        $iterator_var++
                        $outputfile += "$([string]$iterator_var)"                    
                    }
                    else {
                        break
                    }
                }
            }
            ## Try to get output directory path and make sure it exists.
            try {
                $outputdir = $outputfile | split-path -parent
                if (-not (Test-Path $outputdir -ErrorAction SilentlyContinue)) {
                    New-Item -ItemType Directory -Path $($outputfile | split-path -parent) | Out-Null
                }
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $Outputfile has no parent directory." -Foregroundcolor Yellow
            }
        }

        ## make sure there's a .csv on the end of output file?
        if ($outputfile -notlike "*.csv") {
            $outputfile += ".csv"
        }
        ## 4. Find Get-WindowsAutopilotInfo script and dot source - hopefully from Supportfiles, will check internet if necessary.
        $getwindowsautopilotinfo = Get-ChildItem -Path "$env:SUPPORTFILES_DIR" -Filter "Get-WindowsAutoPilotInfo.ps1" -File -ErrorAction SilentlyContinue
        if (-not $getwindowsautopilotinfo) {
            # Attempt to download script if there's Internet
            # $check_internet_connection = Test-NetConnection "google.com" -ErrorAction SilentlyContinue
            $check_internet_connection = Test-Connection "google.com" -Count 2 -ErrorAction SilentlyContinue
            if ($check_internet_connection) {
                # check for nuget / install
                $check_for_nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
                if ($null -eq $check_for_nuget) {
                    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: NuGet not found, installing now."
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
                }
                Install-Script -Name 'Get-WindowsAutopilotInfo' -Force 
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: " -NoNewline
                Write-Host "No internet connection detected, unable to generate hardware ID .csv." -ForegroundColor Red
                return
            }
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Get-WindowsAutopilotInfo.ps1 not found in supportfiles directory, unable to generate hardware ID .csv." -ForegroundColor Red
            return
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Found $($getwindowsautopilotinfo.fullname), importing.`r" -NoNewline
            Get-ChildItem "$env:SUPPORTFILES_DIR" -recurse | unblock-file
        }
    }

    ## 1/2. Filter Targetcomputer for null/empty values and ping test machine.
    ## 3. If machine was responsive:
    ##    - Attempt to use cmdlet to get hwid
    ##    - if Fails (unrecognized because wasn't installed using install-script)
    ##    - Execute from support files.
    ##    * I read that using a @splat like this for parameters gives you the advantage of having only one set to modify,
    ##      as opposed to having to modify two sets of parameters (one for each command in the try/catch)
    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
            if ($single_computer) {
                ## 2. Make sure machine is responsive on the network
                if ([System.IO.Directory]::Exists("\\$single_computer\c$")) {
                    ## chop the domain off end of computer name
                    $single_computer = $single_computer.split('.')[0]
                    ## Define parameters to be used when executing Get-WindowsAutoPilotInfo
                    $params = @{
                        ComputerName = $single_computer
                        OutputFile   = "$outputfile"
                        GroupTag     = $DeviceGroupTag
                        Append       = $true
                    }
                    ## Attempt to use cmdlet from installing script from internet, if fails - revert to script in support 
                    ## files (it should have to exist at this point).
                    try {
                        . "$($getwindowsautopilotinfo.fullname)" @params
                    }
                    catch {
                        Get-WindowsAutoPilotInfo @params
                    }
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer didn't respond to one ping, skipping" -ForegroundColor Yellow
                }
            }
        }
    }
    ## 1. Open the folder that will contain reports if necessary.
    END {
        ## 1. Open reports folder
        ## Try opening directory (that might contain xlsx and csv reports), default to opening csv which should always exist
        try {
            Invoke-item "$($outputfile | split-path -Parent)"
        }
        catch {
            # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Could not open output folder." -Foregroundcolor Yellow
            Invoke-item "$outputfile"
        }

        # read-host "Press enter to return to menu."
    }
}
