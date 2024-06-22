Function Get-InstalledAppsThruUninstallKeys {
    <#
    .SYNOPSIS
    Gets a list of installed software on ComputerName device.

    .DESCRIPTION
    May also be able to use a hostname file eventually.

    .PARAMETER ComputerName
    ComputerName / remote device hostname if supplied, if not supplied then it will use the local computer.

    .PARAMETER NameRegex
    NameRegex / A regular expression to filter the results by the name of the application.

    .EXAMPLE
    Get-InstalledApps
    - OR - 
    Get-InstalledApps -ComputerName "computername"

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        [string]$NameRegex = ''
        # [string]$OutputType = 'HTML'
    )
    # ask user for output filename
    $outputfile = Read-Host "Enter output filename (press 'Enter' for default)"
    if ($outputfile -eq "") {
        $outputfile = "$ComputerName-SoftwareAudit-$(get-date -format "MM-dd-yyyy")"
    }
    # add .html and print it back to user
    if ($outputfile -notlike "*.html") {
        $outputfile += ".html"
    }

    $rows = @()
    foreach ($comp in $ComputerName) {
        $template = @"
<style>
    body {
        font-family: 'Roboto', Arial, sans-serif;
    }
    
    h1 {
        background-image: linear-gradient(to bottom, #1a59ed, #00267f);
        color: white;
        font-size: 16px;
        padding-left: 10px;
        padding-right: 10px;
        padding-top: 6px;
        padding-bottom: 6px;
        line-height: 1.5;
    }
    
    table {
        width: 100%;
        border-collapse: collapse;
    }
    
    th, td {
        padding: 8px;
        text-align: left;
    }
    
    tr:nth-child(odd) {
        background-color:#c1d4ff;
        color: black;
    }
    
    tr:nth-child(even) {
        background-color: #a4b3f2;
        color: black;
    }
</style>
<h1>Software Audit - <span style="font-size: 16px;"><b>$($comp)</b></span></h1>
<table>
    <tr>
        <th>Software</th>
        <th>Version</th>
        <th>Publisher</th>
        <th>Install Date</th>
    </tr>
"@
        # add title row for Computer
        # $rows += "<tr><td colspan='3' style='background-color: #00194c; color: white;'><strong>$comp</strong></td></tr>"
        $keys = '', '\Wow6432Node'
        foreach ($key in $keys) {
            try {
                $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $comp)
                $apps = $reg.OpenSubKey("SOFTWARE$key\Microsoft\Windows\CurrentVersion\Uninstall").GetSubKeyNames()
            }
            catch {
                continue
            }

            foreach ($app in $apps) {
                $program = $reg.OpenSubKey("SOFTWARE$key\Microsoft\Windows\CurrentVersion\Uninstall\$app")
                $name = $program.GetValue('DisplayName')
                if ($name -and $name -match $NameRegex) {
                    $item = [pscustomobject]@{
                        ComputerName    = $comp
                        DisplayName     = $name
                        DisplayVersion  = $program.GetValue('DisplayVersion')
                        Publisher       = $program.GetValue('Publisher')
                        InstallDate     = $program.GetValue('InstallDate')
                        UninstallString = $program.GetValue('UninstallString')
                        Bits            = $(if ($key -eq '\Wow6432Node') { '64' } else { '32' })
                        Path            = $program.name
                    }
                    $rows += "<tr><td>$($item.DisplayName)</td><td>$($item.DisplayVersion)</td><td>$($item.Publisher)</td><td>$($item.InstallDate)</td></tr>"

                }
            }
        }
    }
    # $htmlContent = $template -replace $output, ($rows -join '')
    $htmlContent = $template + ($rows -join '') + "</table>"
    # $htmlContent = $template -replace '$output', ($rows -join '')
    # output to file:
    $htmlContent | Out-File -FilePath $outputfile
    Write-Host "Output file: $outputfile"

    # open the file
    Invoke-Item $outputfile


}