<#
.SYNOPSIS
Script for adding a group of workstations into veyon instructor.

.DESCRIPTION
Script for adding a group of workstations into veyon instructor. This script
needs to be run as administrator in a powershell window. The script will iterate
through the list starting at one to the number you have chosen. It will only
add computers that are on and exist.  

.PARAMETER Room
This is the room number that you want to add. EX. s-c137

.PARAMETER Count
The amount of computers in the room. If you chose a large number than is in the
room it will only error out on the ones that don't exist or aren’t accessible. DON'T PANIC
 
.PARAMETER nozero
remove the zero padding on system numbers

.PARAMETER Suffix
The suffix you want to use in order to fully qualify the system name.
dtcc.edu is the default behavior and you won’t have to use this normally.

.PARAMETER trabajo
This is to add a single workstation to a room. Input the workstation name.

.EXAMPLE
this will add systems s-c129-01 to s-c129-22 to veyon instructor.
veyon_add.ps1 -r s-c129 -c 22

this will add systems s-c129-1 to s-c129-22 to veyon instructor. Notice that this is without
a leading zero.
veyon_add.ps1 -r s-c129 -c 22 -n

this will add systems s-c129-01.del.gov to s-c129-22.del.gov to veyon instructor.
veyon_add.ps1 -r s-c129 -c 22 -s del.gov

.NOTES
Author: Anthony Hamilton
#>

#$count = 1
#$suffix = "dtcc.edu"

param (

    [Parameter(Mandatory = $true)][string]$room,
    [Parameter(Mandatory = $false)][string]$count,
    [Parameter(Mandatory = $false)][string]$trabajo,
    [switch]$nozero = $false,
    [switch]$helpy = $false
)
$suffix = "dtcc.edu"
$veyon = "C:\Program Files\Veyon\veyon-cli"

#if ( [string]::IsNullOrEmpty($trabajo))
if ( ($trabajo)) {

    $single = $trabajo + "." + $suffix

    Write-Host "adding a single workstation $single "

    If ( Test-Connection -BufferSize 32 -Count 1 -ComputerName $single -Quiet ) {

        Start-Sleep -m 300

        $IPAddress = ([System.Net.Dns]::GetHostByName($single).AddressList[0]).IpAddressToString

        $MACAddress = Get-WmiObject -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled='True'" -ComputerName $single | where { $_.Description -ne "Hyper-V Virtual Ethernet Adapter" } | Select-Object -Expand MACAddress

        echo " $veyon networkobjects add computer $single $IPAddress $MACAddress $room "

        &$veyon networkobjects add computer $single $IPAddress $MACAddress $room

    }

}
else {

    &$veyon networkobjects add location $room

    For ( $num = 1; $num -le $count; $num++ ) {

        #add a leading zero unless you choose not to

        If ( $nozero )
        { $begin = $room + "-" }

        Elseif ( $num -lt 10 )
        { $begin = $room + "-0" }

        Elseif ( $num -ge 10 )

        { $begin = $room + "-" }

        $workstation = $begin + $num + "." + $suffix

        Write-Host "adding $workstation "
        If ( Test-Connection -BufferSize 32 -Count 1 -ComputerName $workstation -Quiet ) {

            Start-Sleep -m 300

            $IPAddress = ([System.Net.Dns]::GetHostByName($workstation).AddressList[0]).IpAddressToString

            $MACAddress = Get-WmiObject -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled='True'" -ComputerName $workstation | where { $_.Description -ne "Hyper-V Virtual Ethernet Adapter" } | Select-Object -Expand MACAddress

            Write-Host " $veyon networkobjects add computer $workstation $IPAddress $MACAddress $room "

            &$veyon networkobjects add computer $workstation $IPAddress $MACAddress $room

        }
        Else {

            Write-Host " $workstation is not available "
        }

    }
}

Write-Host "restarting Veyon Service"

Restart-Service -Name VeyonService