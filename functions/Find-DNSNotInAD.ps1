function Find-DNSNotInAD {
    param(
        [Parameter(Mandatory = $true)]
        $wingletter,
        [Parameter(Mandatory = $false)]
        $filename
    )

    # this section makes sure that there is some kind of file to read from
    if ($filename) {
        $ComputersInWing = Get-Content $filename
    }
    else {
        try {
            $ComputersInWing = Get-Content ".\$wingletter-devices.txt"
        }
        catch {
            write-host "Error opening the hostname list." -ForegroundColor Red
            Write-Host "Please designate a file containing one hostname per line (from a SysManage .csv file),"
            Write-Host "or place a file in the same directory as this script following this naming convention:"
            Write-Host "A-devices.txt" -ForegroundColor Yellow -NoNewline; Write-Host " for A wing hostnames."
            Write-Host "B-devices.txt" -ForegroundColor Yellow -NoNewline; Write-Host " for B wing hostnames."
            exit
        }
    }


    $object_list = [System.Collections.ArrayList]::new()

    # get current date and time in filestring form
    $now = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $outputfilename = "$wingletter-wing-NOT_IN_AD-$now.txt"
    # deletes any existing file with the same name
    New-Item -Path $outputfilename -ItemType File -Force
    ForEach ($device in $ComputersInWing) {
        write-host "TOP OF LOOP - $device" -ForegroundColor Yellow

        # if the device name includes a period, then set $device = to the left of the first period
        if ($device -like "*.*") {
            $device = $($device -split ".")[0]
        }

        # if the name doesn't match the regex S-A###*
        if ($device -notmatch "^S-$wingletter\d{3}") {
            write-host "skipping $device"
            # if a name doesn't match that regex, it's probably not a user computer (doesn't take into account unique names)
            continue
        }
        if ($device -like "*dock*") {
            write-host "Contains 'dock' - skipping $device because it will not be in AD." -ForegroundColor Yellow
            continue
        }
        else {
            # attempt to get the computer object from AD
            $computer = Get-ADComputer -Identity $device -ErrorAction SilentlyContinue
            $computer = $computer | Select -Exp DNSHostName

            if ($computer) {
                Write-Host "Found $device in AD" -ForegroundColor Green
                # create ps custom object with the device name and whether it was found in AD
                $obj = [PSCustomObject]@{
                    DeviceName = $device
                    FoundInAD  = $true
                    DNSRecord  = $true
                }
                $object_list.add($obj)
            }
            else {
                Write-Host "Could not find $device in AD" -ForegroundColor Red
                "$device" | Out-File $outputfilename -Append

                $obj = [PSCustomObject]@{
                    DeviceName = $device
                    FoundInAD  = $false
                    DNSRecord  = $true
                }
                $object_list.add($obj)

            }
        }
    }
    # create styled html report from the arraylist of pscustom objects.

    # for some reason, I couldnt get script to filter out names with "dock" to work thru normal/quicker methods so this is a workaround for now
    $results = Get-Content $outputfilename
    foreach ($hostname in $results) {
        write-host "results - $hostname"
        # if it has dock anywhere in it - remove it from the list
        if ($hostname -like "*dock*") {
            write-host "$hostname has dock in the name"
            $results = $results -ne $hostname
        }
    }
    New-Item -Path $outputfilename -ItemType File -Force 
    Start-Sleep 1
    $results | Out-File $outputfilename -Append
}