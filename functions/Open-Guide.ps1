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

    $PSTERMINALMENU_WIKI_URL = "https://github.com/albddnbn/PSTerminalMenu/wiki"

    try {
        Start-Process "https://github.com/albddnbn/PSTerminalMenu/wiki"
    }
    catch {
        Write-Host "Failed to open the guide. Please visit $PSTERMINALMENU_WIKI_URL" -ForegroundColor Red
    }
}
