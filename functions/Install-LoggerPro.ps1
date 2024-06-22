
function Install-LoggerPro {
    <#
    .SYNOPSIS
	Installs latest version of Vernier Logger Pro 3 at the time of writing (v3.16.2) on remote or local computer.

    .DESCRIPTION
	Plans to update to do the installation on group of computers.

    .PARAMETER ComputerName
    The ComputerName computer to look for a user on.

    .EXAMPLE
    Install-LoggerPro
    - OR - 
    Install-LoggerPro -ComputerName hosts.txt

    .NOTES
    Additional notes about the function.
    #>
    param (
        [Parameter(Position = 0,
            ParameterSetName = "ComputerName", ValueFromPipeline = $true)]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )
    # set to SilentlyContinue (write status messages to log file) or Continue (print status messages to console and write to log file)
    $VerbosePreference = "Continue"
    # dot source function definitions
    . .\function_definitions.ps1
    # VARIABLE DECLARATIONS:
    # if computername is a file, get-content, if its a hostname, do nothing
    if (Test-Path $ComputerName) {
        $ComputerNames = Get-Content $ComputerName
    }
    else {
        $ComputerNames = $ComputerName
    }
    # get list of online ComputerNames
    foreach ($ComputerName in $ComputerNames) {
        # $testconnect = Test-Connection $ComputerName
        if (test-connection $ComputerName) {
            $online += $ComputerName
        }
        else {
            Write-host "$ComputerName unresponsive" -foregroundcolor yellow
        }

    }
    # test for the source files on the local computer
    if (!(Test-Path "C:\Users\Public\Vernier Logger Pro v3.16.2")) {
        # download the installer if it doesn't exist
        Write-Host "Missing Vernier Logger Pro installation folder. Attempting to download from server..." -ForegroundColor Yellow
        # download the installer

        # NEED TO MAKE CONNECTION TO S DRIVE OR MDT SERVER HERE, but doing it later...for now - exit
        exit
    }
    foreach ($onlinepc in $online) {
        # make sure logger pro installer is in public folder, if not - download it

        # copy logger pro installer directory to ComputerName computer
        copy-item "C:\Users\Public\Vernier Logger Pro v3.16.2" -destination \\$onlinepc\c$\users\public -Recurse
        # save displayversion of LoggerPro3.msi to variable
        # $LoggerProLatestVersion = (Get-ItemProperty -Path C:\Users\Public\LoggerPro3.msi).DisplayVersion
        # install logger pro
        $Result = (Start-Process msiexec.exe -ArgumentList "/i C:\Users\Public\LoggerPro3.msi /qn /L*v C:\Users\Public\LoggerPro3_msilog.txt" -Wait -Passthru).ExitCode
        # check if install was successful
        if ($Result -eq 0) {
            Write-Log -Path $LogPath -Message "Logger Pro installed successfully on $onlinepc" -Level Info
            Write-Verbose "Logger Pro installed successfully on $onlinepc"
        }
        else {
            Write-Log -Path $LogPath -Message "Logger Pro failed to install on $onlinepc" -Level Error
            Write-Verbose "Logger Pro failed to install on $onlinepc"
        }
        # remove logger pro installer from ComputerName computer
        Remove-Item -Path "\\$onlinepc\c$\users\public\Vernier Logger Pro v3.16.2" -Force -Recurse
    }

}