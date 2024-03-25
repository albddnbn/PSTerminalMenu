Function Run-SophosScan {
    <#
    .SYNOPSIS
        Runs sophos scans on target computers, hopefully returns results to arraylist / output to .csv and .xlsx.
        Creates scheduled task on the local computer, which will run a script to collect the results of scans, 6 hours in the future.
        Full system scans, even without the use of the ExpandArchives (--expand_archives) parameter, take a fairly long time.

    .DESCRIPTION
        Script will check for 'live' computers first, and filter out ones that don't respond to one ping.
        On live computers - script will check for the C:\Program Files/Sophos/Endpoint Defense\sophosinterceptxcli.exe file.
            - also check for logged in users, script will skip if specified.
        Returns an object for each computer that spcifies whether Sophos exe was found, and whether a user was logged in.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: g-labpc- will create a list of all hostnames that start with 
        g-labpc- (g-labpc-01. g-labpc-02, g-labpc-03..).

    .PARAMETER Targetpaths
        Target paths to scan on target computers.

    .PARAMETER Outputfile
        Output file for the function, if not specified will create a default filename.

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [String[]]$TargetComputer,
        # should be comma separated list of target folders/files to scan for on target computers.
        $Targetpaths,
        [string]$Outputfile
    )
    BEGIN {
        # set REPORT_DIRECTORY for output, and set thedate variable
        $REPORT_DIRECTORY = "Sophos-AVScans" # reports outputting to $env:PSMENU_DIR\reports\$thedate\Sample-Function\
        $thedate = Get-Date -Format 'yyyy-MM-dd'


        ## 1. Handle TargetComputer input if not supplied through pipeline (will be $null in BEGIN if so)
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            ## Assigns localhost value
            if ($TargetComputer -in @('', '127.0.0.1', 'localhost')) {
                $TargetComputer = @('127.0.0.1')
            }
            ## If input is a file, gets content
            elseif ($(Test-Path $Targetcomputer -erroraction SilentlyContinue) -and ($TargetComputer.count -eq 1)) {
                $TargetComputer = Get-Content $TargetComputer
            }
            ## A. Separates any comma-separated strings into an array, otherwise just creates array
            ## B. Then, cycles through the array to process each hostname/hostname substring using LDAP query
            else {
                ## A.
                if ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                else {
                    $Targetcomputer = @($Targetcomputer)
                }
        
                ## B. LDAP query each TargetComputer item, create new list / sets back to Targetcomputer when done.
                $NewTargetComputer = [System.Collections.Arraylist]::new()
                foreach ($computer in $TargetComputer) {
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
                        $searcher.Filter = "(&(objectclass=computer)(cn=$computer*))"
                        $searcher.SearchRoot = "LDAP://$searchRoot"
                        [void]$searcher.PropertiesToLoad.Add("name")
                        $list = [System.Collections.Generic.List[String]]@()
                        $results = $searcher.FindAll()
                        foreach ($result in $results) {
                            $resultItem = $result.Properties
                            [void]$List.add($resultItem.name)
                        }
                        $NewTargetComputer += $list
                    }
                }
                $TargetComputer = $NewTargetComputer
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null } | Select -Unique
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
        }

        # create an output filepath, not including file extension that can be used to create .csv / .xlsx report files at end of function
        if ($outputfile -eq '') {
            # create default filename
            $outputfile = Get-OutputFileString -Titlestring $REPORT_DIRECTORY -rootdirectory $env:PSMENU_DIR -foldertitle $REPORT_DIRECTORY -reportoutput

        }
        elseif ($Outputfile.ToLower() -notin @('n', 'no')) {
            # if outputfile isn't blank and isn't n/no - use it for creation of output filepath
            $outputfile = Get-OutputFileString -Titlestring $outputfile -rootdirectory $env:PSMENU_DIR -foldertitle $REPORT_DIRECTORY -reportoutput
        }

        # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning function on $($TargetComputer -join ', ')"

        # scans likely tie the system down a bit offer to skip occupied computers:
        $skip_occupied = Read-Host "Skip computers that have users logged in? [y/n]"
        $skip_occupied = $skip_occupied.ToLower()
    }
    PROCESS {
        $results = Invoke-Command -ComputerName $Targetcomputer -scriptblock {
            $skipthis = $using:skip_occupied
            # do stuff here
            $userloggedin = Get-Process -name 'explorer' -includeusername -erroraction SilentlyContinue | Select -exp username
            # return results of a command or any other type of object, so it will be addded to the $results list
            if (($userloggedin) -and ($skipthis -eq 'y')) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Skipping $($env:COMPUTERNAME) - user $($userloggedin) is logged in."
                break
            }
            else {

                $obj = [pscustomobject]@{
                    SophosInstalled = "No"
                }


                $sophos_scanner = get-childitem -path 'C:\Program Files\Sophos\Endpoint Defense' -filter "sophosinterceptxcli.exe" -file -erroraction SilentlyContinue
                if (-not $sophos_scanner) {
                    Write-Host "Check Sophos on $($env:COMPUTERNAME) - Sophos may not be installed, scanner.exe is not present"
                    $obj
                }
                else {
                    $obj.SophosInstalled = "No"
                }

            }
        } | Select * -ExcludeProperty RunSpaceId, PSShowComputerName # filters out some properties that don't seem necessary for these functions
    } END {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting results to $outputfile .csv / .xlsx."

        Output-Reports -Filepath $outputfile -Content $results -ReportTitle $REPORT_DIRECTORY -CSVFile $true -XLSXFile $true

        # open the folder - output-reports will already auto open the .xlsx if it was created
        Invoke-Item -Path "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY"
    }
}