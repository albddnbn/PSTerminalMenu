Function DNS-ADCrossReference {
    <#
    .SYNOPSIS
    Takes a CSV from SysManage as input, and tests each host for network connectivity, and presence in Active Directory.

    .DESCRIPTION
    Outputs HTML report containing DNS records that should be looked at (devices that haven't checked in in a while, etc.)

    .PARAMETER FileName
    CSV exported from Sysmanage.

    .EXAMPLE
    DNS-ADCrossReference -FileName export.csv

    DNS-ADCrossReference

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    param (
        # sysmanage csv file input
        [Parameter()]
        $FileName
    )
    # deal with filename as long as its string or arraylist
    if ($filename.gettype().name -eq "String") {
        try {
            $computers = Get-Content $FileName
        }
        catch {
            $filename = Read-Host "Enter the path to the file containing the list of computers"
            $computers = Get-Content $FileName
        }
    }
    elseif ($filename.getType().Name -eq "ArrayList") {
        $computers = $filename
    }
    else {
        $computers = Read-Host "Enter the path to the file containing the list of computers"
        $computers = Get-Content $computers
    }

    $online_and_in_AD = [System.Collections.ArrayList]::new()
    $not_in_AD = [System.Collections.ArrayList]::new()
    $havent_checked_into_DHCP = [System.Collections.ArrayList]::new()


    Foreach ($PC in $Computers) {
        If ((Test-NetConnection $PC -InformationLevel Quiet)) {
            write-host "$PC is online, testing AD status" -Foregroundcolor Green
            $ADTest = Get-ADComputer -Identity $PC -ErrorAction SilentlyContinue
            if ($ADTest) {
                write-host "$PC is in AD" -ForegroundColor Green
                $online_and_in_AD.add($PC)
            }
            else {
                write-host "$PC is not in AD" -ForegroundColor Red
                $not_in_AD.add($PC)
            }
        }
        else { 
            Write-Host "$PC is offline" -ForegroundColor Red
            # check the sysmanage last checked into dhcp time here, report if its bad
            $offline.add($PC)
        }
    }
}