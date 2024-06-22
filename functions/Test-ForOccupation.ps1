Function Test-ForOccupation {
    <#
    .SYNOPSIS
    Pings a list of computers, then checks if anyone is logged in to the online computers.

    .DESCRIPTION
    Can take an arraylist of computers, or computer list text file with one hostname on each line.

    .PARAMETER FileName
    The ComputerName computer to look for a user on.

    .EXAMPLE
    Test-ForOccupation -FileName computers.txt
    
    Test-ForOccupation

    .NOTES
    Additional notes about the function.
    #>
    [CmdletBinding()]
    param (
        # can be a file or an arraylist
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

    $online = [System.Collections.ArrayList]::new()
    $offline = [System.Collections.ArrayList]::new()
    $occupied = [System.Collections.ArrayList]::new()


    Foreach ($PC in $Computers) {
        If ((Test-NetConnection $PC -InformationLevel Quiet)) {
            write-host "$PC is online" -Foregroundcolor Green
            # check for occupation
            $result = Get-CimInstance -ComputerName $pc -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Username
            Write-Host "Current user on " -NoNewline
            Write-Host "$pc : " -ForegroundColor White
            switch ($result) {
                "No one." {
                    Write-Host "$result" -ForegroundColor Green
                    $online.add($PC)

                }
                default {
                    Write-Host "$result is logged in to $PC" -ForegroundColor Red
                    $occupied.add($PC)
                }
            }
        }
        else { 
            Write-Host "$PC is offline" -ForegroundColor Red
            $offline.add($PC)
        }
    }

    # get-date in filestring
    $filestring = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    # output each arraylist to a file
    $online | Out-File -FilePath ".\online-and-unoccupied_$filestring.txt"
    $offline | Out-File -FilePath ".\offline_$filestring.txt"
    $occupied | Out-File -FilePath ".\occupied_$filestring.txt"
}