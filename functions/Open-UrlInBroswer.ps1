Function  Open-UrlInBroswer {
    <#
    .SYNOPSIS
    Looks at urls.csv to make arraylist of url objects (url / description)

    .DESCRIPTION
    Creates menu of url objects for user, opens whichever one user chooses in default browser.

    .EXAMPLE
    Open-UrlInBrowser

    .NOTES
    Additional notes about the function.
    #>
    # param (
    #     # [Parameter(Mandatory=$true)]
    #     [string]$Url
    # )
    # check if they have PS-Menu module
    if (Get-Module -Name PS-Menu -ListAvailable) {
        # if they do, import it
        Import-Module PS-Menu -Force
    }
    else {
        # if they don't, install it
        Install-Module PS-Menu -Scope CurrentUser -Force
        # and import it
        Import-Module PS-Menu -Force
    }

    # creates list of url objects from urls.csv
    $urls = Import-Csv -Path ".\urls.csv"

    # create menu showing the urls.decsriptions
    $url = menu $urls.description

    $choice = $urls | Where-Object { $_.description -eq $url }
    write-host $choice.url
    try {
        Start-Process $choice.url
    }
    catch {
        Write-Host "Unable to open url."
        Write-Host "Error: $_"
    }
}