function Open-Guide {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Opens the application guide in web browser. The guide explains the basics of using the menu.
        Attempts to force Chrome usage - uses default browser if not.

    .DESCRIPTION
        The guide explains the menu's directory structure, functionality, and configuration.

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>

    ##
    ## Terminal Menu guide 'landing page' = ./docs/index.html - 02-20-2024
    $GuideHtmlFile = Get-ChildItem -Path "$env:PSMENU_DIR\docs" -Filter "index.html" -File -Recurse -ErrorAction SilentlyContinue

    if ($GuideHtmlFile) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found $($GuideHtmlFile.Fullname), opening now." -Foregroundcolor Green
        # get chrome exe
        try {
            Invoke-Expression "$($guidehtmlfile.fullname)"
        }
        catch {
            $chrome_exe = Get-ChildItem -Path "C:\Program Files\Google\Chrome\Application" -Filter "chrome.exe" -File -ErrorAction SilentlyContinue
            if ($chrome_exe) {
                &"$($chrome_exe.fullname)" "$($GuideHtmlFile.fullname)"
            }
            else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Unable to open in default browser or Chrome, opening docs folder." -Foregroundcolor Red
                Invoke-Item "$env:PSMENU_DIR\docs"
            }
        }

    }
    else {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Couldn't find the guide.html file in $env:PSMENU_DIR, unable to open." -Foregroundcolor Red
    }
}
