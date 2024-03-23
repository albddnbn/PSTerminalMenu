function Copy-SnippetToClipboard {
    <#
    .SYNOPSIS
        Uses .txt files found in the ./snippets directory to present terminal menu to user.
        User selects item to be copied to clipboard.

    .DESCRIPTION
        IT Helpdesk Contact Info.txt                  --> Campus help desk phone numbers.
        OSTicket - Big Number Ordered List.txt        --> HTML/CSS for an ordered list that uses big numbers, horizontal to text.
        PS1 1-Liner - Get Size of Folder.txt          --> Powershell one-liner to get size of all items in folder.
        PS1 1-Liner - Last Boot Time.txt              --> Powershell one-liner to get last boot time of computer.
        PS1 1-Liner - List All Apps.txt               --> Powershell one-liner to list all installed applications.
        PS1 Code - List App Info From Reg.txt         --> Powershell code to list application info from registry.
        PS1 Code - PS App Deployment Install Line.txt --> Powershell PSADT module silent installation line.

    .EXAMPLE
        Copy-SnippetToClipboard
        
    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>

    ## 1. Checks for PS-Menu module necessary to display interactive terminal menu.
    ##    - if not found - checks for nuget / tries to install ps-menu
    if (-not (Get-Module -Name PS-Menu -ListAvailable)) {
        Write-Host "Installing PS-Menu module..." -ForegroundColor Yellow
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable)) {
            Write-Host "Installing NuGet package provider..." -ForegroundColor Yellow
            Install-PackageProvider -Name NuGet -MinimumVersion -Force
        }
        Install-Module -Name PS-Menu -Force
    }
    Import-Module -Name PS-Menu -Force | Out-Null

    ## 2. Creates a list of filenames from the ./snippets directory that end in .txt (resulting filenames in list will
    ##    not include the .txt extension because of the BaseName property).
    $snippet_options = Get-ChildItem -Path "$env:PSMENU_DIR\snippets" -Include *.txt -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName }
    $snippet_choice = menu $snippet_options

    ## 3. Get the content of the chosen file and copy to clipboard
    Get-Content -Path "$env:PSMENU_DIR\snippets\$snippet_choice.txt" | Set-Clipboard
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Content from $env:PSMENU_DIR\snippets\$snippet_choice.txt copied to clipboard."
}
