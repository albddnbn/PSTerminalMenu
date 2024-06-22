Function Copy-SnippetToClip {
    if (Get-Module -ListAvailable -Name PS-Menu) {
        Import-Module PS-Menu
    }
    else {
        Write-Host "PS-Menu not found. Installing..."
        Install-Module PS-Menu -Scope CurrentUser -Force
        Import-Module PS-Menu
    }

    $snippet_options = Get-ChildItem -Path "$PSScriptRoot\snippets" -Filter *.txt | ForEach-Object { $_.BaseName }
    $snippet_choice = menu $snippet_options

    Get-Content -Path "$PSScriptRoot\snippets\$snippet_choice.txt" | Set-Clipboard
}