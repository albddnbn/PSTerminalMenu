Function Sample-Function {
    <#
    .SYNOPSIS
        Basic description of what the function does.

    .DESCRIPTION
        More detailed description on what the function does.

    .PARAMETER TargetComputer
        Target computer or computers of the function.
        Single hostname, ex: 's-c136-02' or 's-c136-02.dtcc.edu'
        Path to text file containing one hostname per line, ex: 'D:\computers.txt'
        First section of a hostname to generate a list, ex: s-a227- will create a list of all hostnames that start with 
        s-a227-, in other words the Stanton Open Computer Lab student computers.

    .PARAMETER CreateOutputFile
        'n' or 'no' = terminal output only
        Entering anything else will create an output file in the 'reports' directory, in a folder with name based on function name, and CreateOutputFile input.
        Ex: CreateOutputfile = 'A220', output file(s) will be in $env:PSMENU_DIR\reports\AssetInfo - A220\


    .EXAMPLE
        An example of one way of running the function.

    .EXAMPLE
        You can include as many examples as necessary to reflect different ways of running the function, different parameters, etc.

    .NOTES
        Additional notes about the function.
        Author of the function.
        Sources used to create function / credits.
    #>
    param(
        $TargetComputer,
        [string]$Outputfile
    )
    # dot source utility functions
    ForEach ($utility_function in (Get-ChildItem -Path "$env:MENU_UTILS" -Filter '*.ps1' -File)) {
        . $utility_function.fullname
    }

    # set REPORT_DIRECTORY for output, and set thedate variable
    $REPORT_DIRECTORY = "Sample-Function" # reports outputting to $env:PSMENU_DIR\reports\$thedate\Sample-Function\
    $thedate = Get-Date -Format 'yyyy-MM-dd'


    # Filter TargetComputer input to create hostname list:
    $TargetComputer = Get-TargetComputers -TargetComputerInput $TargetComputer

    # create an output filepath, not including file extension that can be used to create .csv / .xlsx report files at end of function
    if ($outputfile -eq '') {
        # create default filename
        $outputfile = Get-OutputFileString -Titlestring $REPORT_DIRECTORY -rootdirectory $env:PSMENU_DIR -foldertitle $REPORT_DIRECTORY -reportoutput

    }
    elseif ($Outputfile.ToLower() -notin @('n', 'no')) {
        # if outputfile isn't blank and isn't n/no - use it for creation of output filepath
        $outputfile = Get-OutputFileString -Titlestring $outputfile -rootdirectory $env:PSMENU_DIR -foldertitle $REPORT_DIRECTORY -reportoutput
    }
    # if it speeds things up / makes sense - you can ping targets first to filter out offline hosts.
    # this section is important for functions that do things like install software or run bios updates - you want to have a record of the computers that are skipped over.
    $max_hosts = 30
    if ($TargetComputer.count -lt $max_hosts) {
        $TargetComputer = Get-LiveHosts -TargetComputerInput $Targetcomputer
    }

    # Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Beginning function on $($TargetComputer -join ', ')"

    $results = Invoke-Command -ComputerName $Targetcomputer -scriptblock {
        # do stuff here
        $userloggedin = Get-Process -name 'explorer' -includeusername -erroraction SilentlyContinue | Select -exp username
        # return results of a command or any other type of object, so it will be addded to the $results list
        $userloggedin
    } | Select * -ExcludeProperty RunSpaceId, PSShowComputerName # filters out some properties that don't seem necessary for these functions

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting results to $outputfile .csv / .xlsx."

    Output-Reports -Filepath $outputfile -Content $results -ReportTitle $REPORT_DIRECTORY -CSVFile $true -XLSXFile $true

    # open the folder - output-reports will already auto open the .xlsx if it was created
    Invoke-Item -Path "$env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY"

}