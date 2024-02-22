function New-DriveMappingExe {
    <#
    .SYNOPSIS
        Uses the PS2exe module to generate an executable, that when double-clicked by a user, will map the specified drive / drive letter.
        The user must have correct permissions assigned to access specified drive path.

    .DESCRIPTION
        Generates an executable that, when double-clicked, will map a specified drive for user.
        Add a Drivemap.ico file to ./SupportFiles to add custom icon to executable (right now, it's just a hard drive icon).

    .PARAMETER TargetPath
        UNC path of folder to be mapped, ex: '\\server-01\users\lvoldemort'

    .PARAMETER DriveLetter
        Drive letter to map the path to. Ex: 'Z'

    .NOTES
        abuddenb / 2024
        Will not work outside of Terminal Menu right now - 02-17-2024
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]        
        [string]$TargetPath,
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter
    )
    BEGIN {
        $EXECUTABLES_DIRECTORY = 'DriveMap'
        $thedate = Get-Date -Format 'yyyy-MM-dd'
    }
    PROCESS {
        ForEach ($single_target_path in $TargetPath) {
            $DriveLetter = REad-Host "Enter drive letter for $single_target_path"

            ## Script that's compiled into an executable
            $drive_map_scriptblock = @"
Write-Host "Attempting to map  " -NoNewLine
Write-Host "$single_target_path" -Foregroundcolor Yellow -NoNewLine
Write-Host " to " -NoNewLine
Write-Host "$DriveLetter" -NoNewLine -Foregroundcolor Green
Write-Host "..."
# creates the persistent drive mapping
try {
    New-PSDrive -Name $driveletter -PSProvider FileSystem -Root `'$single_target_path`' -Persist
    Write-Host "Successfully mapped " -NoNewLine
    Write-Host "$single_target_path" -Foregroundcolor Yellow -NoNewLine
    Write-Host " to " -NoNewLine
    Write-Host "$DriveLetter" -NoNewLine -Foregroundcolor Green
    Write-Host "."
    Start-Sleep -Seconds 5
} catch {
    Write-Host "Failed to map $single_target_path to $DriveLetter." -Foregroundcolor Red
    Start-Sleep -Seconds 5
}
"@

            # create output filename: get last string from targetpath
            $splitup_targetpath = $single_target_path -split '\\'
            $last_string = $splitup_targetpath[-1]
            $outputfile = "drivemap-$last_string-$driveletter.ps1"
            # create executable output path
            $exe_outputfile = $outputfile -replace '.ps1', '.exe'

            # define absolute paths for .ps1 script output, and generated .exe output
            $ps1_output_path = "$env:PSMENU_DIR\output\$thedate\$EXECUTABLES_DIRECTORY\$outputfile"
            $exe_output_path = "$env:PSMENU_DIR\executables\$thedate\$EXECUTABLES_DIRECTORY\$exe_outputfile"
            foreach ($singledir in @("$env:PSMENU_DIR\output\$thedate\$EXECUTABLES_DIRECTORY", "$env:PSMENU_DIR\executables\$thedate\$EXECUTABLES_DIRECTORY")) {
                if (-not (Test-Path $singledir -ErrorAction SilentlyContinue)) {
                    New-Item -Path $singledir -ItemType 'Directory' -Force | Out-Null
                }
            }
    
            # $drive_map_scriptblock | Out-File "$ps1_output_path" -Force
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Creating $ps1_output_path..."
            Set-Content -Path "$ps1_output_path" -Value $drive_map_scriptblock -Force


            # supportfiles\drivemap.ico just adds a hard drive icon to the executable that's created
            $drivemap_icon_file = Get-ChildItem -Path "$env:SUPPORTFILES_DIR" -Filter "drivemap.ico" -File -ErrorAction SilentlyContinue

            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Compiling $ps1_output_path into $exe_output_path..."
            Start-Sleep -Seconds 1
            if ($drivemap_icon_file) {
                Invoke-PS2exe -inputFile "$ps1_output_path" -outputFile "$exe_output_path" -iconFile "$($drivemap_icon_file.fullname)" -title "Map $($DriveLetter): Drive" -company "Delaware Technical Community College"
            }
            else {
                Invoke-PS2exe -inputFile "$ps1_output_path" -outputFile "$exe_output_path" -title "Map $($DriveLetter): Drive" -company "Delaware Technical Community College"
            }
        }
    }
    END {
        # open the executables output folder
        Invoke-Item "$env:PSMENU_DIR\executables\$thedate\$Executable_DIRECTORY"
    }
}
