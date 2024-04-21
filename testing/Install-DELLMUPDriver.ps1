Function Install-DellMUPDriver {
    <#
    .SYNOPSIS
        Presents menu of executables found in the drivers folder. Copies chosen executable to target systems, and
        attempts to install them silently using predetermined installation switches.

    .DESCRIPTION
        More detailed description on what the function does.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 's-c136-02' or 's-c136-02.dtcc.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: s-a227- will create a list of all hostnames that start with 
        s-a227-, in other words the Stanton Open Computer Lab student computers.

    .PARAMETER TargetFile
        Enter at least enough of target filename for it to be uniquely identified in specified folder.

    .EXAMPLE
        An example of one way of running the function.

    .EXAMPLE
        You can include as many examples as necessary to reflect different ways of running the function, different parameters, etc.

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
        )]
        [String[]]$TargetComputer,
        [string]$TargetFile
    )

    BEGIN {

        ## Make sure the Ps-menu module is installed/imported:
        if (-not (Get-Module -Name 'PSMenu' -ListAvailable)) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: The PSMenu module is not installed. Attempting to install it now." -foregroundcolor Yellow
            Install-Module -Name 'PSMenu' -Force
        }


        ## Get list of all executables matching supplied Targetfile string, from ./drivers folder:
        if (Test-Path 'drivers' -PathType 'container' -ErrorAction Silentlycontinue) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found the drivers folder in $(pwd)."
            $executables = Get-ChildItem -Path "drivers" -Filter "$TargetFile*.exe" -File -Recurse -ErrorAction SilentlyContinue
        }
        ## Exit function if the 'drivers' folder isn't present.
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: The drivers folder was not found in $(pwd)." -Foregroundcolor Yellow
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exiting function." -foregroundcolor Red
            return
        }

        ## PResent menu to the user of all matching files in the directory:
        $exe_filenames = $executables | select -exp name
        $chosen_executable = Menu $exe_filenames

        ## Get chosen executable
        $chosen_executable = $executables | Where-Object { $_.Name -eq $chosen_executable }

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Proceeding with driver executable: $($chosen_executable.fullname)." -ForegroundColor Green
    
        ## create results lists:
        $driver_installed = [System.Collections.ArrayList]::new()
        $skipped_machines = [System.Collections.ArrayList]::new()
        $failed_machines = [System.Collections.ArrayList]::new()
        
    }


    PROCESS {
        ForEach ($single_computer in $TargetComputer) {

            ## 1. empty Targetcomputer values will cause errors to display during test-connection / rest of code
            if ($single_computer) {
                ## 2. Send one test ping
                if ([System.IO.Directory]::Exists("\\$single_computer\c$")) {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is online." -ForegroundColor Green

                    ## create ps session
                    $session = New-PSSession -ComputerName $single_computer

                    ## Copy executable to C:\temp directory
                    Copy-Item -Path "$($chosen_executable.fullname)" -Destination "C:\temp\$($chosen_executable.name)" -ToSession $session -Force

                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Copied file to \\$single_computer\c$\temp\$($chosen_executable.name)"
                    $chosen_filename = $chosen_executable.name
                    ## execute file:
                    Invoke-Command -Session $session -Scriptblock {
                        ## get the exe:
                        $filename = $using:chosen_filename
                        $exe_file = Get-Childitem -Path 'C:\temp' -filter "$filename" -ErrorAction SilentlyContinue
                        if (-not ($exe_file)) {
                            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $filename not found in C:\temp. Exiting." -ForegroundColor Red
                            continue
                        }

                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Found $($exe_file.fullname), executing with /S paramter."

                        $install_result = (Start-Process -Path "$($exe_file.fullname)" -ArgumentList '/S' -Wait -Passthru).ExitCode
                        if ($install_result -eq 0) {
                            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Installation of $filename was successful." -ForegroundColor Green
                            ($using:driver_installed).Add($env:COMPUTERNAME) | Out-Null
                        }
                        else {
                            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$env:COMPUTERNAME] :: Installation of $filename failed with exit code $install_result." -ForegroundColor Red
                            ($using:failed_machines).Add($env:COMPUTERNAME) | Out-Null
                        }
                    }

                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $single_computer is offline." -ForegroundColor Red
                    $skipped_machines.Add($single_computer) | Out-Null
                    continue

                }

            }
        }
    }
    ## This section definitely needs some work.
    END {
        if (-not $env:PSMENU_DIR) {
            $env:PSMENU_DIR = pwd
        }
        ## create simple output path to reports directory
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        $DIRECTORY_NAME = 'DellMUPDriver'
        $OUTPUT_FILENAME = 'install_results'
        if (-not (Test-Path "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME" -ErrorAction SilentlyContinue)) {
            New-Item -Path "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME" -ItemType Directory -Force | Out-Null
        }
        
        $counter = 0
        do {
            $output_filepath = "$env:PSMENU_DIR\reports\$thedate\$DIRECTORY_NAME\$OUTPUT_FILENAME-$counter.txt"
        } until (-not (Test-Path $output_filepath -ErrorAction SilentlyContinue))
        
        ## Append text to file here:
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $($chosen_executable.name) installed on $($driver_installed -join ', ')" | Out-File -FilePath $output_filepath -Append
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: FAILED (did not return exit code 0) on:" | Out-File -FilePath $output_filepath -Append
        $failed_machines | Out-File -FilePath $output_filepath -Append
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: These machines were skipped: " | Out-File -FilePath $output_filepath -Append
        $skipped_machines | Out-File -FilePath $output_filepath -Append

        ## then open the file:
        Invoke-Item "$output_filepath"
    }

}