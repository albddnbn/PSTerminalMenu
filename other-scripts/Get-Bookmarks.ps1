<#
Default bookmark locations:
chrome
C:\Users\username\AppData\Local\Google\Chrome\User Data\Default
firefox
C:\Users\username\AppData\Roaming\Mozilla\Firefox\Profiles\profile_name
    - look for most recently modified one
edge
C:\Users\username\AppData\Local\Microsoft\Edge\User Data\Default
opera gx
C:\Users\username\AppData\Roaming\Opera Software\Opera GX Stable
#>

if (!(Get-Module -Name PS-Menu)) {
    Write-Host "Installing PS-Menu module..." -ForegroundColor Yellow
    Install-Module -Name PS-Menu -Force -Scope CurrentUser
}
Import-Module -Name PS-Menu -Force
$browsers = "Chrome", "Firefox", "Edge", "Opera GX"
Clear-Host
write-host "Select the browser you want to get bookmarks from:"
$browsertype = menu $browsers
Clear-Host
# do this, until get-aduser returns a user
do {
    $username = Read-Host "Enter username: "
} until (Get-ADUser -Filter {SamAccountName -eq $username})
$chrome = "\c$\Users\$username\AppData\Local\Google\Chrome\User Data\Default"
$firefox = "\c$\Users\$username\AppData\Roaming\Mozilla\Firefox\Profiles\"
$edge = "\c$\Users\$username\AppData\Local\Microsoft\Edge\User Data\Default"
$operagx = "\c$\Users\$username\AppData\Roaming\Opera Software\Opera GX Stable"

$locations = @{
    "Chrome" = $chrome
    "Firefox" = $firefox
    "Edge" = $edge
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
} else {
    Write-Host "Firefox and Opera GX bookmarks are in roaming profile and will follow user." -ForegroundColor Yellow
}
