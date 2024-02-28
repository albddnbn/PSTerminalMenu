function Get-ConnectedPrinters {
    <#
    .SYNOPSIS
        Checks the target computer, and returns the user that's logged in, and the printers that user has access to.

    .DESCRIPTION
        This function, unlike some others, only takes a single string DNS hostname of a target computer.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 't-client-01' or 't-client-01.domain.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: t-pc-0 will create a list of all hostnames that start with t-pc-0. (Possibly t-pc-01, t-pc-02, t-pc-03, etc.)

    .PARAMETER OutputFile
        'n' or 'no' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and OutputFile input.
        Ex: Outputfile = 'A220', output file(s) will be in $env:PSMENU_DIR\reports\AssetInfo - A220\

    .PARAMETER FolderTitleSubstring
        If specified, the function will create a folder in the 'reports' directory with the specified substring in the title, appended to the $REPORT_DIRECTORY String (relates to the function title).

    .EXAMPLE
        Get-ConnectedPrinters -TargetComputer 't-client-07'

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
        $TargetComputer,
        $Outputfile
    )

    BEGIN {
        $thedate = Get-Date -Format 'yyyy-MM-dd'
        ## TARGETCOMPUTER HANDLING:
        ## If Targetcomputer is an array or arraylist - it's already been sorted out.
        ## TargetComputer is mandatory - if its null, its been provided through pipeline - don't touch it in begin block
        if ($null -eq $TargetComputer) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected pipeline for targetcomputer." -Foregroundcolor Yellow
        }
        else {
            if (($TargetComputer -is [System.Collections.IEnumerable]) -and ($TargetComputer -isnot [string])) {
                $null
                ## If it's a string - check for commas, try to get-content, then try to ping.
            }
            elseif ($TargetComputer -is [string]) {
                if ($TargetComputer -in @('', '127.0.0.1')) {
                    $TargetComputer = @('127.0.0.1')
                }
                elseif ($Targetcomputer -like "*,*") {
                    $TargetComputer = $TargetComputer -split ','
                }
                elseif (Test-Path $Targetcomputer -erroraction SilentlyContinue) {
                    $TargetComputer = Get-Content $TargetComputer
                }
                else {
                    $test_ping = Test-Connection -ComputerName $TargetComputer -count 1 -Quiet
                    if ($test_ping) {
                        $TargetComputer = @($TargetComputer)
                    }
                    else {
                        $TargetComputerInput = $TargetComputerInput + "x"
                        $TargetComputerInput = Get-ADComputer -Filter * | Where-Object { $_.DNSHostname -match "^$TargetComputerInput*" } | Select -Exp DNShostname
                        $TargetComputerInput = $TargetComputerInput | Sort-Object   
                    }
                }
            }
            $TargetComputer = $TargetComputer | Where-object { $_ -ne $null }

            ## At this point - if targetcomputer is null - its been provided as a parameter
            # Safety catch
            if ($null -eq $TargetComputer) {
                return
            }
            Write-Host "TargetComputer is: $($TargetComputer -join ', ')"

            if (($TargetComputer.count -lt 20) -and ($Targetcomputer -ne '127.0.0.1')) {
                if (Get-Command -Name "Get-LiveHosts" -ErrorAction SilentlyContinue) {
                    $TargetComputer = Get-LiveHosts -TargetComputerInput $TargetComputer
                }
            }
        }       
        
        ## Outputfile handling - either create default, create filenames using input, or skip creation if $outputfile = 'n'.
        if (Get-Command -Name "Get-OutputFileString" -ErrorAction SilentlyContinue) {
            if ($Outputfile.toLower() -eq '') {
                $REPORT_DIRECTORY = "ConnectedPrinters"
    
                $OutputFile = Get-OutputFileString -TitleString $REPORT_DIRECTORY -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            elseif ($outputfile.tolower() -ne 'n') {
                $REPORT_DIRECTORY = $outputfile
                $outputfile = Get-OutputFileString -TitleString $outputfile -Rootdirectory $env:PSMENU_DIR -FolderTitle $REPORT_DIRECTORY -ReportOutput
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -Nonewline
                Write-Host "Terminal output only." -Foregroundcolor Green
            }    
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Function was not run as part of Terminal Menu - does not have utility functions." -Foregroundcolor Yellow
            if ($outputfile.tolower() -eq '') {
                $outputfile = "ConnectedPrinters"
            }
        }

        #################################################
        ## Scriptblock - lists connected/default printers
        #################################################
        $list_local_printers_block = {
            # Everything will stay null, if there is no user logged in
            $obj = [PScustomObject]@{
                Username          = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
                DefaultPrinter    = $null
                ConnectedPrinters = $null
            }

            # Only need to check for connected printers if a user is logged in.
            if ($obj.Username) {
                # get connected printers:
                $printers = get-ciminstance -class win32_printer | select name, Default
                # $obj.DefaultPrinter = $printers | where-object { $_.default } | select -exp name

                ForEach ($single_printer in $printers) {
                    # if (-not $printer.default) {
                    # make sure its not a 'OneNote' printer, or Microsoft Printer to PDF.
                    if (($single_printer.name -notin ('Microsoft Print to PDF', 'Fax')) -and ($single_printer.name -notlike "*OneNote*")) {
                        if ($single_printer.name -notlike "Send to*") {
                            $obj.ConnectedPrinters = "$($obj.ConnectedPrinters), $($single_printer.name)"
                        }
                    }
                    # }
                }
            }

            $obj
        }

        ## COLLECTIONS - holds all computers connected printer details
        $all_results = [system.collections.arraylist]::new()
    }

    ## Run 'get connected printers' scriptblock on target machine(s)
    PROCESS {

        if ($TargetComputer) {

            ## ping test first:
            $pingreply = Test-connection $TargetComputer -Count 1 -Quiet

            if ($pingreply) {


                $results = Invoke-Command -ComputerName $TargetComputer -Scriptblock {
                    # Everything will stay null, if there is no user logged in
                    $obj = [PScustomObject]@{
                        Username          = ''
                        DefaultPrinter    = $null
                        ConnectedPrinters = $null
                    }
                    $getusername = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username

                    # Only need to check for connected printers if a user is logged in.

                    # get connected printers:
                    $printers = get-ciminstance -class win32_printer | select name, Default
                    $obj.DefaultPrinter = $printers | where-object { $_.default } | select -exp name
            
                    ForEach ($single_printer in $printers) {
                        # if (-not $printer.default) {
                        # make sure its not a 'OneNote' printer, or Microsoft Printer to PDF.
                        if (($single_printer.name -notin ('Microsoft Print to PDF', 'Fax')) -and ($single_printer.name -notlike "*OneNote*")) {
                            if (($single_printer.name -notlike "Send to*") -and ($single_printer.name -notlike "*Microsoft*")) {
                                $obj.ConnectedPrinters = "$($obj.ConnectedPrinters), $($single_printer.name)"
                            }
                        }
                        # }
                    }
            
                    if ($getusername) {
                        $obj.Username = $getusername
                    }
                    $obj
                } | Select * -ExcludeProperty RunspaceId, PSShowComputerName

                $all_results.Add($results) | out-null
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: $TargetComputer didn't respond to one ping, skipping." -Foregroundcolor Yellow
            }
        } 
    }

    END {
        if ($all_results) {
            $all_results = $all_results | sort -property pscomputername
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Details on connected printers gathered, exporting to $outputfile.csv/.xlsx..."


            if ($outputfile.tolower() -ne 'n') {

                Output-Reports -Filepath "$outputfile" -Content $all_results -ReportTitle "Printers$thedate" -CSVFile $true -XLSXFile $true

                Invoke-Item "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY\"
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Detected 'N' input for outputfile, skipping creation of outputfile."

                # if ($all_results.count -lt 2) {
                $all_results | Format-Table -Wrap
                # }
                # else {
                #     $all_results | Out-GridView
                # }
            }
        }
        else {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: No results to output."
        }
        Read-Host "Press enter to continue"
    }
}
