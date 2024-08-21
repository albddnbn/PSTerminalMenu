## Function was built to target a group of computers and sort through each one of the computers' PrinterLogic log files
## to look for a specific error message. I was attempting to diagnose an issue that was affecting most computers in
## a subnet, when trying to communicate the PrinterLogic cloud instance.
function Get-PrinterLogicLogs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    ## PASTED IN FROM ANOTHER FILE - will have to be edited / made into function
    $computers = get-adcomputer -filter { dnshostname -like "s-e223-*" } | select -exp dnshostname

    ForEach ($single_computer in $computers) {
        $log_content = Get-Content "\\$single_computer\c$\WINDOWS\TEMP\PPP\Log\PrinterInstallerClient.log"

        ForEach ($single_line in $log_content) {
            if ($single_line -like "*Error initiating refreshing of IDP information: Timed out*") {
                Write-Host "IDP errors found on $single_computer" -foregroundcolor yellow
                break
            }
        }
    }
}