<#
Gets bookmarks for 4 browser types if theyre stored locally
#>
Function Get-Bookmarks {
    [cmdletbinding()]
    param(
        [String]$SourcePC,
        [String]$TargetPC,
        [String]$BrowserType
    )
    # first get the source and target pc if they haven't been provided
    if (!($PSBoundParameters.ContainsKey('SourcePC'))) {
        $SourcePC = Read-Host "Enter source PC name: "
    }
    if (!($PSBoundParameters.ContainsKey('TargetPC'))) {
        $TargetPC = Read-Host "Enter target PC name: "
    }
    # if the browser type isn't provided, then present a PS-Menu
    if (!($PSBoundParameters.ContainsKey('BrowserType'))) {
        if (Get-Module -ListAvailable -Name PS-Menu) {
            Import-Module PS-Menu
        }
        else {
            Write-Host "PS-Menu not found. Installing..."
            Install-Module PS-Menu -Scope CurrentUser -Force
            Import-Module PS-Menu
        }

        # **CREATE ARRAYLIST FROM THE .REG FILES IN THE 'REG' FILDER (WITHOUT FILE EXTENSION)**
        $browsers = "Chrome", "Firefox", "Edge", "Opera GX"
        $BrowserType = menu $browsers
    }
    # make sure they have ability to run get-aduser
    if (!(Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-Host "ActiveDirectory module not found. Installing..."
        Install-Module ActiveDirectory -Scope CurrentUser -Force
    }                                                                    
    do {
        $username = Read-Host "Enter username: "
    } until (Get-ADUser -Filter { SamAccountName -eq $username })
    $chrome = "\c$\Users\$username\AppData\Local\Google\Chrome\User Data\Default"
    $firefox = "\c$\Users\$username\AppData\Roaming\Mozilla\Firefox\Profiles\"
    $edge = "\c$\Users\$username\AppData\Local\Microsoft\Edge\User Data\Default"
    $operagx = "\c$\Users\$username\AppData\Roaming\Opera Software\Opera GX Stable"
    
    $locations = @{
        "Chrome"   = $chrome
        "Firefox"  = $firefox
        "Edge"     = $edge
        "Opera GX" = $operagx
    }
    # its probably possible to get the PC the user last logged into
    # but for now, just ask for the PC name
    $sourcepc = Read-Host "Enter source PC name: "
    $targetpc = Read-Host "Enter target PC name: "
    
    # create source and destination paths
    
    
    if (@("Chrome", "Edge") -contains $browwsertype) {
        # check if there's already a bookmarks file on target and rename it to .old if so
        if (Test-Path -Path "\\$targetpc$($locations[$browsertype])\Bookmarks") {
            Rename-Item -Path "\\$targetpc$($locations[$browsertype])\Bookmarks" -NewName "Bookmarks.old"
        }
        Copy-Item -Path "\\$sourcepc$($locations[$browsertype])\Bookmarks" -Destination "\\$targetpc$($locations[$browsertype])\"
    }
    else {
        Write-Host "Firefox and Opera GX bookmarks are in roaming profile and will follow user." -ForegroundColor Yellow
    }
    


}