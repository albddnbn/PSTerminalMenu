<#
.SYNOPSIS
Scans target computer(s) for installed applications with 'Sophos' in the display name, and compares this list of app objects to a list created on a computer with known-good Sophos installation.
.DESCRIPTION
Compare-Object is used to compare the two arraylists and output any differences. The script outputs two types of reports - one shows any computer that had a different list of app objects, and the other type of report is for EACH computer that was returned from the comparison scan. The second report just outputs all applications matching 'sophos'.

.PARAMETER Targetcomputer
Target Computer(s) to scan for sophos. Can be single hostname, list of hostnames, or text file containing hostnames.

.EXAMPLE
.\Scan-ForSophos.ps1 -Targetcomputer 's-a227-01'

.EXAMPLE
Scan all computers in the Stanton open computer lab:
.\Scan-ForSophos.ps1 -Targetcomputer 's-a227-'

.NOTES
Additional notes about the function
#>
param(
    $Targetcomputer
)
$REPORT_DIRECTORY = 'SophosScan'
$thedate = Get-Date -Format 'yyyy-MM-dd'

$utils_directory = Get-Item $env:MENU_UTILS

$util_functions = Get-ChildItem -Path "$($utils_directory.fullname)" -File
$util_functions_list = [system.collections.arraylist]::new()
foreach ($function in $util_functions) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Loading function $($function.fullname)..." -foregroundcolor green
    # . "$($function.fullname)"

    $obj = [pscustomobject]@{
        name = $function.basename
        path = $function.fullname
    }
    $util_functions_list.add($obj) | Out-Null
}

# return new targetcomputer value
$TargetComputer = &$($util_functions_list | Where-Object { $_.name -eq 'Return-TargetComputer' } | Select-Object -ExpandProperty path) -TargetComputerInput $TargetComputer
write-host $targetcomputer
# if targetcomputer = localhost, exit - scan won't work because it won't be able to create the list of known-good Sophos app objects
if ($TargetComputer -eq '127.0.0.1') {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: TargetComputer = 127.0.0.1, exiting." -foregroundcolor red
    exit
}

#return new output filepath value
$OutputFile = &$($util_functions_list | Where-Object { $_.name -eq 'Return-OutputFileString' } | Select-Object -ExpandProperty path) -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput

# get local / known working sophos results:
# $local_results = [system.collections.arraylist]::new()
# Define the registry paths for uninstall information
$registryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
)
# Loop through each registry path and retrieve the list of subkeys
foreach ($path in $registryPaths) {
    $uninstallKeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
    # Skip if the registry path doesn’t exist
    if (-not $uninstallKeys) {
        continue
    }
    # Loop through each uninstall key and display the properties
    foreach ($key in $uninstallKeys) {
        $keyPath = Join-Path -Path $path -ChildPath $key.PSChildName
        $displayName = (Get-ItemProperty -Path $keyPath -Name "DisplayName" -ErrorAction SilentlyContinue).DisplayName
        if ($displayName -eq 'Sophos Endpoint Self Help') {
            $uninstallString = (Get-ItemProperty -Path $keyPath -Name "UninstallString" -ErrorAction SilentlyContinue).UninstallString
            $version = (Get-ItemProperty -Path $keyPath -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
            $publisher = (Get-ItemProperty -Path $keyPath -Name "Publisher" -ErrorAction SilentlyContinue).Publisher
            $installLocation = (Get-ItemProperty -Path $keyPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
            $productcode = (Get-ItemProperty -Path $keyPath -Name "productcode" -ErrorAction SilentlyContinue).productcode
	
	
            $obj = [pscustomobject]@{
                DisplayName     = $DisplayName
                Uninstallstring = $uninstallString
                DisplayVersion  = $version
                Publisher       = $publisher
                ProductCode     = $productcode
                InstallLocation = $installlocation
            }
            $local_results.add($obj) | out-null
        }
    }
}
write-host $targetcomputer
# check target remote computers and get the sophos app object list from them
$results = Invoke-Command -computername $TargetComputer -scriptblock {

    $desired_results = $using:local_results
	
    $app_results = [system.collections.arraylist]::new()
    # Define the registry paths for uninstall information
    $registryPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    # Loop through each registry path and retrieve the list of subkeys
    foreach ($path in $registryPaths) {
        $uninstallKeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        # Skip if the registry path doesn’t exist
        if (-not $uninstallKeys) {
            continue
        }
        # Loop through each uninstall key and display the properties
        foreach ($key in $uninstallKeys) {
            $keyPath = Join-Path -Path $path -ChildPath $key.PSChildName
            $displayName = (Get-ItemProperty -Path $keyPath -Name "DisplayName" -ErrorAction SilentlyContinue).DisplayName
            if ($displayName -eq 'sophos endpoint agent') {
                $uninstallString = (Get-ItemProperty -Path $keyPath -Name "UninstallString" -ErrorAction SilentlyContinue).UninstallString
                $version = (Get-ItemProperty -Path $keyPath -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
                $publisher = (Get-ItemProperty -Path $keyPath -Name "Publisher" -ErrorAction SilentlyContinue).Publisher
                $installLocation = (Get-ItemProperty -Path $keyPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
                $productcode = (Get-ItemProperty -Path $keyPath -Name "productcode" -ErrorAction SilentlyContinue).productcode
		
		
                $obj = [pscustomobject]@{
                    DisplayName     = $DisplayName
                    Uninstallstring = $uninstallString
                    DisplayVersion  = $version
                    Publisher       = $publisher
                    ProductCode     = $productcode
                    InstallLocation = $installlocation
                }
                $app_results.add($obj) | out-null
	
            }
        }

    }
	
	
    # compare the results:
    $comparison_result = compare-object -referenceobject $desired_results -differenceobject $app_results
    if ($comparison_result) {
        $obj = [pscustomobject]@{
            Comments         = "Sophos endpoint agent nonexistent or differing from known-good."
            ComparisonResult = $comparison_result
        }
        $obj
    } 

} | Select * -ExcludeProperty RunspaceId, PSShowComputerName

# if there ARE any results - output the report to .csv / .xlsx, and then scan suspect computers for sophos app info
if ($results.count -ge 1) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Asset information gathered, exporting to $outputfile.csv/.xlsx..."

    $results | Export-CSV "$outputfile.csv" -NoTypeInformation -Force
    
    # look for the importexcel powershell module
    $CheckForimportExcel = Get-InstalledModule -Name 'importexcel' -ErrorAction SilentlyContinue
    if (-not $CheckForimportExcel) {
        Install-Module -Name ImportExcel -Force
    }
    $params = @{
        AutoSize             = $true
        TitleBackgroundColor = 'Blue'
        TableName            = "$REPORT_DIRECTORY $thedate"
        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
        BoldTopRow           = $true
        WorksheetName        = 'SophosScan'
        PassThru             = $true
        Path                 = "$Outputfile.xlsx" # => Define where to save it here!
    }
    $xlsx = $results | Export-Excel @params
    $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
    $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
    Close-ExcelPackage $xlsx
    


    $suspect_computers = $results | Select -Exp PSComputername

    $query_result = Invoke-Command -ComputerName $suspect_computers -Scriptblock {
		
        # get machine details:
        $computer_model = Get-Ciminstance -class win32_computersystem | select -exp Model
        $bios_version = Get-Ciminstance -class win32_bios | select -exp SMBIOSBIOSVersion
        $lastboottime = Get-CimInstance -ClassName win32_operatingsystem | select -exp lastbootuptime
        # Define the registry paths for uninstall information
        $registryPaths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        # Loop through each registry path and retrieve the list of subkeys
        foreach ($path in $registryPaths) {
            $uninstallKeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
            # Skip if the registry path doesn’t exist
            if (-not $uninstallKeys) {
                continue
            }
            # Loop through each uninstall key and display the properties
            foreach ($key in $uninstallKeys) {
                $keyPath = Join-Path -Path $path -ChildPath $key.PSChildName
                $displayName = (Get-ItemProperty -Path $keyPath -Name "DisplayName" -ErrorAction SilentlyContinue).DisplayName
                if ($displayName -like "*Sophos*") {
                    $uninstallString = (Get-ItemProperty -Path $keyPath -Name "UninstallString" -ErrorAction SilentlyContinue).UninstallString
                    $version = (Get-ItemProperty -Path $keyPath -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
                    $publisher = (Get-ItemProperty -Path $keyPath -Name "Publisher" -ErrorAction SilentlyContinue).Publisher
                    $installLocation = (Get-ItemProperty -Path $keyPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
                    # $productcode = (Get-ItemProperty -Path $keyPath -Name "productcode" -ErrorAction SilentlyContinue).productcode
                    $installdate = (Get-ItemProperty -Path $keyPath -Name "installdate" -ErrorAction SilentlyContinue).installdate

                    $obj = [PSCustomObject]@{
                        # ComputerName    = $env:COMPUTERNAME
                        Model           = $computer_model
                        BiosVersion     = $bios_version
                        LastBoot        = $lastboottime
                        AppName         = $displayName
                        AppVersion      = $version
                        InstallDate     = $installdate
                        InstallLocation = $installLocation
                        Publisher       = $publisher
                        UninstallString = $uninstallString
                    }
                    # $app_matches.add($obj) | out-null
                    $obj
                }
            }
        

        }
        if (-not $obj) {
            $obj = [PSCustomObject]@{
                # ComputerName    = $env:COMPUTERNAME
                Model           = $computer_model
                BiosVersion     = $bios_version
                LastBoot        = $lastboottime
                AppName         = 'Nothing detected from *sophos* search in displaynames'
                AppVersion      = ''
                InstallDate     = ''
                InstallLocation = ''
                Publisher       = ''
                UninstallString = ''
            }
            $obj
        }    
    } | Select * -ExcludeProperty RunspaceId, PSShowComputerName

    # if there's no 'suspect-computer-results' folder, create it
    if (-not (Test-PAth "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\suspect-computer-results")) {
        New-Item -Path "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\suspect-computer-results" -ItemType Directory -Force
    }
    $query_Result | Export-CSV "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\suspect-computer-results\$single_hostname.csv" -NoTypeInformation -Force

    # look for the importexcel powershell module
    $CheckForimportExcel = Get-InstalledModule -Name 'importexcel' -ErrorAction SilentlyContinue
    if (-not $CheckForimportExcel) {
        Install-Module -Name ImportExcel -Force
    }

    $params = @{
        AutoSize             = $true
        TitleBackgroundColor = 'Blue'
        TableName            = "Sophos Scan  $thedate"
        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
        BoldTopRow           = $true
        WorksheetName        = "Sophos Scan $thedate"
        PassThru             = $true
        Path                 = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\suspect-computer-results\$single_hostname.xlsx" # => Define where to save it here!
    }

    $xlsx = $query_result | Export-Excel @params
    $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
    $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
    Close-ExcelPackage $xlsx

    # $unique_hostnames = $query_result | Select -Exp PSComputerName -Unique
    # ForEach ($single_hostname in $unique_hostnames) {
    #     $single_hostname_results = $query_result | Where-Object { $_.PSComputerName -eq $single_hostname }
    #     $single_hostname_results | Export-CSV "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\suspect-computer-results\$single_hostname.csv" -NoTypeInformation -Force
    #     Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exported results for suspect pc: $single_hostname to $env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\suspect-computer-results\$single_hostname.csv"

    #     # look for the importexcel powershell module
    #     $CheckForimportExcel = Get-InstalledModule -Name 'importexcel' -ErrorAction SilentlyContinue
    #     if (-not $CheckForimportExcel) {
    #         Install-Module -Name ImportExcel -Force
    #     }

    #     $params = @{
    #         AutoSize             = $true
    #         TitleBackgroundColor = 'Blue'
    #         TableName            = "Sophos $single_hostname $thedate"
    #         TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
    #         BoldTopRow           = $true
    #         WorksheetName        = "Sophos $single_hostname $thedate"
    #         PassThru             = $true
    #         Path                 = "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\suspect-computer-results\$single_hostname.xlsx" # => Define where to save it here!
    #     }

    #     $xlsx = $single_hostname_results | Export-Excel @params
    #     $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
    #     $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
    #     Close-ExcelPackage $xlsx
    #     Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exported results for suspect pc: $single_hostname to $env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\suspect-computer-results\$single_hostname.xlsx"

}
Explorer.exe "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\"
