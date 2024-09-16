function Open-Guide {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Opens PSTerminalMenu Wiki in browser.

    .DESCRIPTION
        The guide explains the menu's directory structure, functionality, and configuration.

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>

    $HELP_URL = "https://github.com/albddnbn/PSTerminalMenu/wiki"
    Write-Host "Attempting to open " -nonewline
    Write-Host "$HELP_URL" -Foregroundcolor Yellow -NoNewline
    Write-Host " in default browser."


    try {
        $chrome_exe = Get-ChildItem -Path "C:\Program Files\Google\Chrome\Application" -Filter "chrome.exe" -File -ErrorAction SilentlyContinue
        Start-Process "$($chrome_exe.fullname)" -argumentlist "$HELP_URL"
    }
    catch {
        Start-Process "msedge.exe" -argumentlist "$HELP_URL"
    }
    Read-Host "Press enter to continue."
}
