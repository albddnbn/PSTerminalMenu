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
    if (-not (Get-Module -ListAvailable -Name PS-Menu)) {
        # check for nuget
        $nuget_check = get-packageprovider | where-object { $_.name -eq 'nuget' }
        if (-not $nuget_check) {
            Write-Host "Nuget not found. Installing..." -ForegroundColor Yellow
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        }
        Write-Host "PS-Menu not found. Installing..."
        Install-Module PS-Menu -Scope CurrentUser -Force
    }
    Import-Module PS-Menu | out-null

    $snippet_options = Get-ChildItem -Path "$env:PSMENU_DIR\snippets" -Filter *.txt | ForEach-Object { $_.BaseName }
    $snippet_choice = menu $snippet_options

    Get-Content -Path "$env:PSMENU_DIR\snippets\$snippet_choice.txt" | Set-Clipboard

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Content from $env:PSMENU_DIR\snippets\$snippet_choice.txt copied to clipboard."
}
