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

# read config.json
$config = Get-Content -Path config.json | ConvertFrom-Json
# get the names and values and save into a config pscustomobject
$config = [PSCustomObject]$config
# write the techname value
# Write-Host "Techname: $($config.techname)" -ForegroundColor Yellow
Write-Host "Applying values from configuration file..." -ForegroundColor Yellow
# for now, just directly rewrite those two txt files to replace $techname with the techname from config.json
# look in the ./functions/snippets directory for any .txt files beginning with 'OSTicket - '
$files = Get-ChildItem -Path .\functions\snippets -Filter "OSTicket - *.txt"
# look thru files for '$techname' and replace with $config.techname
foreach ($file in $files) {
    # get the content of the file
    $content = Get-Content -Path $file.FullName
    # replace the techname with the one from config.json
    $content = $content -replace '\$techname', $($config.techname)
    # write the content back to the file
    $content | Set-Content -Path $($file.FullName)
}

# unblock files
Get-ChildItem -Path .\* -Recurse | Unblock-File



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

# below is the regex that looks for the specified format
# Get-ChildItem -Path .\[A-Z]*.ps1 | Where-Object { $_.Name -cmatch '^[A-Z][A-Za-z]*-(?:-[A-Z][A-Za-z]*)*' } | ForEach-Object { . ./$_.FullName }
Get-ChildItem -Path .\functions\[A-Z]*.ps1 | Where-Object { $_.Name -cmatch '^[A-Z][A-Za-z]*-(?:-[A-Z][A-Za-z]*)*' } | ForEach-Object {
    try {
        # dot source the function file
        . "./functions/$($_.Name)"
        # Write-Host "Successfully dot sourced function file: $($_)" -ForegroundColor Green
        # Write-Host $_.Name  
    }
    catch {
        Write-Host "Error dot sourcing the $($_.Name) function - check that names are synchronous." -ForegroundColor Red
        Start-Sleep -Seconds 3
    }

}
# create variable, when true - exits program
$exit_program = $false
while ($exit_program -eq $false) {
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
            while ($true) {
                Write-Host "Enter d for parameter description"
                # ask for value and show any default value for variable
                $defaultvalue = $command.Parameters[$parameter].DefaultValue
                if ($defaultvalue) {
                    $value = Read-HostNoColon -Prompt "$parameter [$defaultvalue] = "
                }
                else {
                    $value = Read-HostNoColon -Prompt "$parameter = "
                }
                # $value = Read-HostNoColon -Prompt "$parameter = "
                if ($value -eq 'd') {
                    $helper = get-help $command -Detailed
                    foreach ($paraminfo in $helper.parameters) {
                        if ($paraminfo.parameter.name -eq $parameter) {
                            Clear-Host
                            $paraminfo.parameter.description
                        }
                    }
                    continue
                }
                else {
                    break
                }
            }
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

    Write-Host "Press " -NoNewLine
    Write-Host "'x'" -ForegroundColor Red -NoNewline
    Write-Host " to exit, or " -NoNewline 
    Write-Host "any other key" -ForegroundColor Yellow -NoNewline
    Write-Host " to continue..."
    [Console]::TreatControlCAsInput = $true
    $key = $Host.UI.RawUI.ReadKey()
    [String]$character = $key.Character
    if ($($character.ToLower()) -eq 'x') {
        exit
    }
}

