# References for menu: https://michael-casey.com/2019/07/03/powershell-terminal-menu-template/ 

# --------------- Powershell Menu in Terminal ---------------------------------
<#
.SYNOPSIS
    First, the script using the category names in the 'categories.txt' file to create a hashtable w/the cateogry names as keys. Then, the script creates an array from each of the .txt files in the 'functions' directory (each txt filename corresponds to a function category).
Script generates a menu in the Powershell terminal. Options in the terminal menu are generated, by default, using the functionlist.txt file. The functions (what actually happens when an option is picked) are sourced using (by default) any functions in the the menu_functions.ps1 file, and any .ps1 files in the same directory following the conventional Powershell cmdlet casing format.

.DESCRIPTION
    Using the hashtable, the script first presents a menu of the categories, and after user has selected a category, script presents a second menu with all of the functions in that category. This is to prevent the list getting really long from just having all functions lumped into one category.

.EXAMPLE
    ./menu.ps1 is all that's needed to run script provided that configuration is right.

.NOTES
    Author: Alex B. - https://github.com/albddnbn/PSTerminalMenu
    *Some functions that are already a part of the menu were written by others, including Jon Stack - https://github.com/jstack3
    These authors are also credited in the comments of the functions they wrote.
    Created: 5/20/2023
    Last Modified: 5/28/2023
#>
function Read-HostNoColon {
    <#
    SYNOPIS
        Read-HostNoColon is just Read-Host except it doesn't automatically add the colon at the end, and the writing is blue!
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )
    Write-Host $Prompt -NoNewLine -ForegroundColor Blue
    return $Host.UI.ReadLine()
}

# hashtable that will hold the categories from categories.txt and functions from functionlist and their corresponding functions
$categories = @{}
$categories.Keys = Get-Content -Path categories.txt


# cycle through functionlist.txt and add the functions to the hashtable
foreach ($category in $categories.Keys) {
    $categories[$category] = Get-Content -Path ".\categories\$($category.ToLower()).txt"
}

# Install the PSWindowsUpdate module
if (!(Get-Module -Name PS-Menu)) {
    Write-Host "Installing PS-Menu module..." -ForegroundColor Yellow
    Install-Module -Name PS-Menu -Force -Scope CurrentUser
}
# Import the PSWindowsUpdate module
Import-Module -Name PS-Menu -Force


# DEFAULT filenames that the menu works with can be changed here: menu_functions.ps1, functionlist.txt
$main_functions_file = "menu_functions.ps1"
# $function_name_txt_file = "functionlist.txt"

# look for the menufunctions.ps1 file in the same directory as this script, if its not there - prompt user for the main functions file
if (!(Test-Path -Path .\$main_functions_file)) {
    Write-Host "Could not find menu_functions.ps1 file in current directory." -ForegroundColor Red
    $askforfunctionsfile = Read-Host "Please enter the path to the main functions file: "
    if (Test-Path -Path $askforfunctionsfile) {
        Write-Host "Found main functions file at $askforfunctionsfile" -ForegroundColor Green
        Copy-Item -Path $askforfunctionsfile -Destination .\menu_functions.ps1
    }
    else {
        Write-Host "Could not find main functions file at $askforfunctionsfile" -ForegroundColor Red
        $asktoexit = Read-Host "Press the:'e' key to exit..."
        if ($asktoexit.ToLower() -eq 'e') {
            exit
        }
    }
}

# either way, script will get the main functions file, because it's created if it isn't there to begin with
# $List = Get-Content -Path $function_name_txt_file

# dot source the functions in menu_functions.ps1
try {
    . .\$main_functions_file
}
catch {
    Write-Host "ERROR dot sourcing main functions file: !" -ForegroundColor Red
    $asktoexit = Read-Host "Press the:'e' key to exit..."
    if ($asktoexit.ToLower() -eq 'e') {
        exit
    }
}
# ***The script will look for any .ps1 files in the same directory with filenames that:  1. start with a capital letter followed by any number of other upper/lowercase letters, 2. have a dash in the middle, 3. dash is followed by a capital letter and any number of other letters.***
try {
    # below is the regex that looks for the specified format
    # Get-ChildItem -Path .\[A-Z]*.ps1 | Where-Object { $_.Name -cmatch '^[A-Z][A-Za-z]*-(?:-[A-Z][A-Za-z]*)*' } | ForEach-Object { . ./$_.FullName }
    Get-ChildItem -Path .\functions\[A-Z]*.ps1 | Where-Object { $_.Name -cmatch '^[A-Z][A-Za-z]*-(?:-[A-Z][A-Za-z]*)*' } | ForEach-Object {
        # dot source the function file
        . "./functions/$($_.Name)"
        # Write-Host "Successfully dot sourced function file: $($_)" -ForegroundColor Green
        # Write-Host $_.Name
    }
}
catch {
    Write-Host "Error dot sourcing functions from $_" -ForegroundColor Red
}

Clear-Host
# so to add a function, someone just has to add the function name to the right category txt file (or any category txt file)
# and then add the function to the menu_functions.ps1 file
$chosen_category = Menu $categories.Keys
write-host $chosen_category
# get the functions from the chosen category
$function_list = $categories[$chosen_category]

Clear-Host

$selection = Menu $function_list
Clear-Host

# Functions menu (2nd menu shown) dissapears, if function has parameters - user is prompted for their values
$command = Get-Command $selection
if ($command.Parameters.Count -gt 0) {
    # get the parameters
    $parameters = $command.Parameters.Keys
    # create a hashtable to splat with
    $splat = @{}
    # loop through the parameters
    foreach ($parameter in $parameters) {
        # if the parameter is a default one that comes with advanced functions - May have to take these into account at some point
        if ($parameter -in ('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable')) {
            # skip it
            continue
        }
        # get the parameter value from the user
        # ** WHICH IS EASIER FOR USER? **
        $value = Read-HostNoColon -Prompt "$parameter = "
        # $value = Read-Host "Enter a value for parameter $parameter"
        # add the parameter and value to the splatting hashtable
        $splat.Add($parameter, $value)
    }
    # execute the command with the splatting hashtable
    & $command @splat
}
else {
    # execute the command without parameters (if it has any, they will be ignored
    & $command
}

