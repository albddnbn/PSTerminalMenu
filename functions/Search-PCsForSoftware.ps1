function Search-PCsForSoftware {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $ComputerName,
        [Parameter(Mandatory = $false)]
        [String]
        $AppName,
        [Parameter(Mandatory = $false)]
        [String]
        $AppVersion,
        [Parameter(Mandatory = $false)]
        [String]
        $OutputTitle
    )

    # if computername is a string
    if ($ComputerName.GetType().Name -eq 'String') {
        # if it has commas, then create an arraylist
        if ($ComputerName.Contains(',')) {
            $ComputerName = $ComputerName.Split(',')
        }
        else {
            try {
                $ComputerName = Get-ADComputer -Identity $ComputerName
                $tempv = [System.Collections.ArrayList]::new()
                $tempv.Add($ComputerName.DNSHostName)
                $ComputerName = $tempv
            }
            catch {
                $ComputerName = Get-Content $ComputerName
            }
        }
    }
    elseif ($ComputerName.GetType().Name -eq 'ArrayList') {
        Write-Host "Loaded the following computers: $($ComputerName -join ',')"
    }
    else {
        Write-Host "ComputerName must be a string - single computer, filepath, or comma-separated list...or an arraylist." -ForegroundColor Yellow
        return
    }

    if (-not $AppName) {
        $AppName = Read-Host "Enter name or part of app name, it will be used in regex with asterisks surrounding your input"
    }

    if (-not $AppVersion) {
        $AppVersion = Read-Host "Enter version, or leave blank for any version - same applies with regex"
    }
    # Define the registry paths for uninstall information
    $registryPaths = @(
        “HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall”,
        “HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall”,
        “HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall”
    )
    # Loop through each registry path and retrieve the list of subkeys
    foreach ($path in $registryPaths) {
        $uninstallKeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
    
        # Skip if the registry path doesn’t exist
        if (-not $uninstallKeys) {
            continue
        }



        Invoke-Command -ComputerName $ComputerName -ScriptBlock {

            $hostname = $env:COMPUTERNAME
            # each computer returns an object with its hostname, and any matching software details
            $Single_computer_return_obj = [PSCustomObject]@{
                ComputerName = $hostname
                Results      = [System.Collections.ArrayList]::new()
            }
            # Loop through each uninstall key and display the properties
            foreach ($key in $using:uninstallKeys) {
                $keyPath = Join-Path -Path $path -ChildPath $key.PSChildName
    
                $displayName = (Get-ItemProperty -Path $keyPath -Name “DisplayName” -ErrorAction SilentlyContinue).DisplayName
                $version = (Get-ItemProperty -Path $keyPath -Name “DisplayVersion” -ErrorAction SilentlyContinue).DisplayVersion

                if (($displayName -like "*$using:AppName*") -and ($version -like "*$using:AppVersion*")) {
                    $uninstallString = (Get-ItemProperty -Path $keyPath -Name “UninstallString” -ErrorAction SilentlyContinue).UninstallString
                    $publisher = (Get-ItemProperty -Path $keyPath -Name “Publisher” -ErrorAction SilentlyContinue).Publisher
                    $installLocation = (Get-ItemProperty -Path $keyPath -Name “InstallLocation” -ErrorAction SilentlyContinue).InstallLocation
    
                    $obj = [PSCustomObject]@{
                        DisplayName     = $displayName
                        UninstallString = $uninstallString
                        Version         = $version
                        # Publisher       = $publisher
                        # InstallLocation = $installLocation
                    }

                    $Single_computer_return_obj.Results.Add($obj)


                    # if ($displayName) {
                    #     Write-Host “DisplayName: $displayName”
                    #     Write-Host “UninstallString: $uninstallString”
                    #     Write-Host “Version: $version”
                    #     Write-Host “Publisher: $publisher”
                    #     Write-Host “InstallLocation: $installLocation”
                    #     Write-Host “—————————————————”
                    # }
                }
            }
            return $Single_computer_return_obj
        }

    }

    if (-not $OutputTitle) {
        # date date in good looking string 
        $date = Get-Date -Format "dddd, MMMM dd, yyyy"
        $OutputTitle = "Software Report - $date"
    }
    # then call the create-dtcchtmlreport.ps1 function/file thats in the same directory with the singlecomputerreturnobj as arraylist argument
    &.\Create-DTCCHtmlReport.ps1 -InputList $Single_computer_return_obj -ReportTitle $OutputTitle



}