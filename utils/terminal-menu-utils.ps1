function Get-TargetComputers {
    <#
    .SYNOPSIS
        Takes user input and returns a list of hostnames.
        Input can be:
            1. Single hostname string, ex: 's-a227-01'
            2. Comma-separated list of hostnames, ex: s-a227-01,s-a227-02
            3. Path to text file containing one hostname per line, ex: 'D:\computers.txt'
            4. First section of a hostname to generate a list, ex: s-a227- will create a list of all hostnames that start with s-a227-.

    .NOTES
        Author :    abuddenb
        Date   :    1-14-2024
    #>
    param(
        $TargetComputerInput
    )
    $gettargetcomputers = get-childitem -path "$env:PSMENU_DIR" -Filter "Get-ComputersLDAP.ps1" -File -Recurse
    . "$($gettargetcomputers.fullname)"
    Write-Verbose "`$Targetcomputerinput : $TargetComputerInput"
    if ($TargetComputerInput -eq '') {
        Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No TargetComputer value provided, assigning '127.0.0.1'."
        $TargetComputerInput = @('127.0.0.1')
    }
    ## Deal with TargetComputer input:
    else {
        
        if ($TargetComputerInput -is [string]) {
            ## if its a file:
            if (Test-Path $TargetComputerInput -Erroraction SilentlyContinue) {
                $TargetComputerInput = Get-Content $TargetComputerInput
            }
            elseif ($TargetComputerInput -like "*,*") {
                $TargetComputerInput = $TargetComputerInput -split ',' | sort
            }
            else {

                ## Try pinging and getting ad computer
                # $ping_result = Test-Connection -ComputerName $TargetComputerInput -Count 1 -Quiet

                # # try {
                # #     $ad_check = get-adcomputer -computername $TargetComputerInput
                # # }
                # # catch {

                # #     $null
                # # }

                # ## If Targetcomputer input can be pinged, or is an AD Computer object
                # if ($ping_result) {
                #     $TargetComputerInput = @($TargetComputerInput)
                # }
                # else {
                #     try {

                ## Gets all AD Computer names that start with the input string (TargetComputerInput)                    
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
                    $searcher.Filter = "(&(objectclass=computer)(cn=$TargetComputerInput*))"
                    $searcher.SearchRoot = "LDAP://$searchRoot"
                    # $distinguishedName = $searcher.FindOne().Properties.distinguishedname
                    # $searcher.Filter = "(member:1.2.840.113556.1.4.1941:=$distinguishedName)"

                    [void]$searcher.PropertiesToLoad.Add("name")

                    $list = [System.Collections.Generic.List[String]]@()

                    $results = $searcher.FindAll()
                    foreach ($result in $results) {
                        $resultItem = $result.Properties
                        [void]$List.add($resultItem.name)
                    }

                    $TargetComputerInput = $list

                }
                # }
                # catch {
                #     #Nothing we can do
                #     Write-Warning $_.Exception.Message
                #     return $null
                # }
                # }
                $TargetComputerInput = $TargetComputerInput | Sort-Object
    
                Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: TargetComputer value determined to be the first section of a hostname, used Get-ADComputer to create hostname list."
    
            }
        }

    }

    $TargetComputerInput = $TargetComputerInput | Where-object { ($_ -ne '') -and ($_ -ne $null) }

    # `a will sound the Windows 'gong' just to get user's attentino so they know they have to enter y/n
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Hosts determined:" -Nonewline
    Write-Host "$($TargetComputerInput -join ', ')" -foregroundcolor green

    # tell user to press enter to accept the list or any other key to deny
    Write-Host "Press 'y' to accept the list, or 'n' to deny it and end the function." -foregroundcolor yellow
    $key = $Host.UI.RawUI.ReadKey()
    [String]$character = $key.Character
    if ($($character.ToLower()) -ne 'y') {
        return $null
    }
    # elseif - they pressed enter 
    elseif ($($character.ToLower()) -eq 'y') {
        return $TargetComputerInput
    }
}

function Get-OutputFileString {
    <#
            .SYNOPSIS
                Takes input values for part of the filename, the root directory, subfolder title, and whether it should 
                b
                e in the reports or executables directory, and returns an acceptable filename.
        #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TitleString,
        [Parameter(Mandatory = $true)]
        [string]$Rootdirectory,
        [string]$FolderTitle,
        [switch]$ReportOutput,
        [switch]$ExecutableOutput
    )
    ForEach ($file_ext in @('.csv', '.xlsx', '.ps1', '.exe')) {
        Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Checking for file extension: $file_ext."
        $TitleString = $TitleString -replace $file_ext, ''
        Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Removed file extension, TitleString is now: $TitleString."
    }

    $thedate = Get-Date -Format 'yyyy-MM-dd'

    # create outputfolder
    if ($Reportoutput) {
        $subfolder = 'reports'
    }
    elseif ($ExecutableOutput) {
        $subfolder = 'executables'
    }

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Subfolder determined to be: $subfolder."

    $outputfolder = "$Rootdirectory\$subfolder\$thedate\$FolderTitle"

    if (-not (Test-Path $outputfolder)) {
        Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find folder at: $outputfolder, creating it now."
        New-Item $outputfolder -itemtype 'directory' -force | Out-null
    }
    $filename = "$TitleString-$thedate"
    $full_output_path = "$outputfolder\$filename"
    # make sure outputfiles dont exist
    if ($ReportOutput) {
        $x = 0
        while ((Test-Path "$full_output_path.csv") -or (Test-Path "$full_output_path.xlsx")) {
            $x++
            $full_output_path = "$outputfolder\$filename-$x"
        }
    }
    elseif ($ExecutableOutput) {
        $x = 0
        while ((Test-Path "$full_output_path.ps1") -or (Test-Path "$full_output_path.exe")) {
            $x++
            $full_output_path = "$outputfolder\$filename-$x"
        }
    }

    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Full output path determined to be: $full_output_path."

    return $full_output_path
}
Function Output-Reports {
    <#
    .SYNOPSIS
        Creates a .csv and/or .xlsx file, using filename supplied in parameter..
        Should definitely be able to generate the .csv with built-in Powershell cmdlets, but script will only attempt to import/install the ImportExcel module, and then write an error message to terminal in the event of a failure.
    
    .PARAMETER Filepath
        The path to the file to be created, should not include any file extension.

        #>
    param(
        $Filepath,
        $Content,
        $ReportTitle,
        [bool]$CSVFile = $true,
        [bool]$XLSXFile = $true
    )
    $parent_path = $filepath | split-path -Parent
    if (-not (Test-path $parent_path -erroraction silentlycontinue)) {
        New-Item -Path $parent_path -ItemType Directory -Force | out-null
    }
    write-host "$content"
    # chops any file extension off of filepath
    ForEach ($file_ext in @('pdf', 'html', 'txt', 'csv', 'xlsx')) {
        $Filepath = $Filepath -replace "\.$file_ext", ''
    }

    $files_created = @()
    if ($CSVFile) {
        ## Make sure the parent path exists:

        ## This was resolved by doing $results | sort -property pscomputername in the end block of functions that create \
        ## reports
        # if ($Content -is [System.Collections.ArrayList]) {
        #     ForEach ($single_object in $Content) {
        #         $single_object | Export-CSV -Path "$Filepath.csv" -NoTypeInformation -Append -Force
        #     }

        # }
        $files_created += "CSV"
    }

    if ($XLSXFile) {
        # look for the importexcel powershell module
        $CheckForimportExcel = Get-InstalledModule -Name 'importexcel' -ErrorAction SilentlyContinue
        if (-not $CheckForimportExcel) {
            try {
                $check_internet_connection = Test-NetConnection Google.com -ErrorAction SilentlyContinue
                if ($check_internet_connection.PingSucceeded) {
                    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
                        Write-Host "Installing nuget."
                        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
                        $continue_creating_xlsx = $false
                    }
                    else {
                        Install-PackageProvider -Name NuGet -Force
                    }
                    Install-Module -Name ImportExcel -Force
                    $continue_creating_xlsx = $true
                }
                else {
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
                    Write-Host "No connection to internet detected, skipping .xlsx file creation." -ForegroundColor Red
                    $continue_creating_xlsx = $false
                }
            }
            catch {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
                Write-Host "Unable to install ImportExcel module, skipping .xlsx file creation." -ForegroundColor Red
                $continue_creating_xlsx = $false

            }
        }
        else {
            $continue_creating_xlsx = $true

        }
        if ($continue_creating_xlsx) {
            $params = @{
                AutoSize             = $true
                TitleBackgroundColor = 'Blue'
                TableName            = "$ReportTitle"
                TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
                BoldTopRow           = $true
                WorksheetName        = 'Users'
                PassThru             = $true
                Path                 = "$Outputfile.xlsx" # => Define where to save it here!
            }
            $Content = Import-Csv "$Outputfile.csv"
            $xlsx = $Content | Export-Excel @params
            $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
            $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
            Close-ExcelPackage $xlsx

            # $report_dir_path = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\"

            # Explorer.exe $report_dir_path
            Invoke-Item "$outputfile.xlsx"
            $files_created += "XLSX"
        }
    }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Created $($files_created -join ' and ') file(s) at: $Filepath" -foregroundcolor green

}

function Get-LiveHosts {
    <#
    .SYNOPSIS
        Takes a list of hostnames as input, and returns list of live hosts (hosts that are reponsive on the network).
        The script gauges a 'live' host as 'live' if it responds to one ping.
        This filters out offline/unresponsive hosts so any use of Invoke-Command won't waste time with those computers.

    .NOTES
        Author :    abuddenb
        Date   :    1-14-2024
    #>
    param(
        $TargetComputerInput
    )

    $responsive_hosts = [system.collections.arraylist]::new()
    ForEach ($single_host in $TargetComputerInput) {
        if (($single_host -ne '') -and ($single_host -ne $null)) {
            $connection_result = Test-Connection $single_host -Count 1 -Quiet
            if ($connection_result) {
                $responsive_hosts.add($single_host) | Out-Null
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewLine
                Write-Host "$single_host" -NoNewLine -Foregroundcolor Green
                Write-Host " is online."
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewLine
                Write-Host "$single_host" -NoNewLine -Foregroundcolor Red
                Write-Host " did not respond to one ping."
            }
        }
    }

    Start-Sleep -seconds 2

    Clear-Host

    $unresponsive_hosts = $TargetComputerInput | Where-Object { $_ -notin $responsive_hosts }
    Write-Host ""
    Write-Host "LIVE hosts determined: " -nonewline
    Write-Host "$($responsive_hosts -join ', ')" -Foregroundcolor Green

    Write-Host "OFFLINE hosts: " -NoNewline
    Write-Host "$($unresponsive_hosts -join ', ')" -Foregroundcolor Red

    $TargetComputerInput = $TargetComputerInput | Where-object { $_ -notin $unresponsive_hosts }

    return $TargetComputerInput
    

}
function Sound-Alarm {
    param(
        $absolute_wav_path
    )
    if ($absolute_wav_path -eq $null) {
        # play default windows 'gong'
        Write-Host "`a"
    }
    else {
        $play_wav = [System.Media.SoundPlayer]::new()
        $play_wav.SoundLocation = $absolute_wav_path
        $play_wav.PlaySync()
    }

}