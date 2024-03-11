
<#
.SYNOPSIS
Reads 'config.json' and creates a menu based on the categories and functions contained within the .json file.

.DESCRIPTION
The user can select any category, and then any function. They'll be prompted for any parameters contained in the 
function, and then the function will attempt to execute based on the input values.

.EXAMPLE
.\Menu.ps1

.NOTES
abuddenb - 02/21/2024
References for menu: https://michael-casey.com/2019/07/03/powershell-terminal-menu-template/ 
PS-Menu module: https://github.com/chrisseroka/ps-menu
PSADT: https://psappdeploytoolkit.com/

#>
function Read-HostNoColon {
    # Read-HostNoColon is just Read-Host except it doesn't automatically add the colon at the end, and the writing is blue!
    param (
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )
    Write-Host $Prompt -NoNewLine -ForegroundColor Yellow
    return $Host.UI.ReadLine()
}

Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}


########################################################################################################
## CONFIG.JSON file --> found in ./supportfiles. It's where the script gets categories/function listings 
## that appear in terminal menu, along with some other configuration variables.
########################################################################################################
$CONFIG_FILENAME = "config.json"

# Set window title:
$host.ui.RawUI.WindowTitle = "Menu - $(Get-Date -Format 'mm-dd-yyyy')"

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -nonewline
Write-Host "Loading $CONFIG_FILENAME.." -ForegroundColor Yellow


## $env:SUPPORTFILES_DIR --> Directory of supportfiles folder, which contains config.json
## ./SupportFiles            Also contains other files used by the menu, including the PS2exe, 
##                           PSMenu, ImportExcel, and other Powershell modules.
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Setting " -nonewline
Write-Host "`$env:SUPPORTFILES_DIR" -foregroundcolor green -NoNewline
Write-Host " environment variable to $((Get-Item './supportfiles').FullName)."
$env:SUPPORTFILES_DIR = (Get-Item './supportfiles').FullName

# SupportFiles env var is necessary to actually 'grab' the config.json file
$config_file = Get-Content -Path "$env:SUPPORTFILES_DIR\$CONFIG_FILENAME" | ConvertFrom-Json

## $env:PSMENU_DIR --> Base directory of terminal menu.
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Setting " -nonewline
Write-Host "`$env:PSMENU_DIR" -ForegroundColor Green -NoNewline
Write-Host " environment variable to $((Get-Item .).FullName)."
$env:PSMENU_DIR = (Get-Item .).FullName

## $env:MENU_UTILS --> Directory of utils folder, which contains scripts used by functions.
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Setting " -NoNewline
Write-Host "`$env:MENU_UTILS" -foregroundcolor green -NoNewline
Write-Host " environment variable to $((Get-Item .\utils).FullName)."
$env:MENU_UTILS = (Get-Item .\utils).FullName

## $env:LOCAL_SCRIPTS --> Directory of scripts that are to be run locally (many of the functions in the menu use 
## Invoke-Command to execute these scripts on local computer, or remote targets).
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Setting " -NoNewline
Write-Host "`$env:LOCAL_SCRIPTS" -foregroundcolor green -NoNewline
Write-Host " environment variable to $((Get-Item .\localscripts).FullName)."
$env:LOCAL_SCRIPTS = (Get-Item .\localscripts).FullName

## Good & Bad alarm beep .wav file paths - used in the ScanInventory function for alert sounds (success or fail at 
## linking a scanned upc code to an item in sheet or online).
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Setting " -NoNewline
Write-Host "`$env:GOOD_ALARM and `$env:BAD_ALARM (absolute paths to .wav files)`r" -foregroundcolor green
$good_alarm_wav = Get-ChildItem -Path "$env:SUPPORTFILES_DIR" -Filter "positivebeep.wav" -File -ErrorAction SilentlyContinue
$bad_alarm_wav = Get-ChildItem -Path "$env:SUPPORTFILES_DIR" -Filter "negativebeep.wav" -File -ErrorAction SilentlyContinue
Foreach ($wavfile in @($good_alarm_wav, $bad_alarm_wav)) {
    if (-not $wavfile) {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -NoNewline
        Write-Host "Couldn't find $wavfile in $env:SUPPORTFILES_DIR, terminal menu won't play some or all of alert sounds." -foregroundcolor red
        Read-Host "Press enter to continue."
    }
}
$env:GOOD_ALARM = $good_alarm_wav.FullName
$env:BAD_ALARM = $bad_alarm_wav.FullName

# GUIDE / HELP (not used)
# $env:HELP_FILE = $config_file.help_file

$functions = @{}
# Keys = Category Names
# Values = List of functions for that category
foreach ($category in $config_file.categories.PSObject.Properties) {
    $functions[$category.Name] = $category.Value
}

## CHECK FOR / INSTALL DEPENDENCIES using the 'Install-NeededModules.ps1' script in the ./utils folder, exit if not found
## (ActiveDirectory, PS_Menu, ImportExcel, PS2Exe)
$InstallNeededModulesPS1 = Get-ChildItem -Path "$env:MENU_UTILS" -Filter "Install-NeededModules.ps1" -File -ErrorAction SilentlyContinue
if (-not $InstallNeededModulesPS1) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: " -nonewline
    Write-Host "Couldn't find Install-NeededModules.ps1 file in $env:MENU_UTILS, exiting." -foregroundcolor red
    exit
}
. "$($InstallNeededModulesPS1.FullName)"
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Found Install-NeededModules.ps1 file in $env:MENU_UTILS, " -NoNewline
Write-Host "attempting to install dependencies" -NoNewline -ForegroundColor Yellow
Write-Host "."
Install-NeededModules


## Dot Source ALL .PS1 Files in ./functions and ./experimental
## *IMPORTANT* --> if a .ps1 file is not structured into a function - the .ps1 code in file will be executed during 
##                 dot source attempt
$allfiles = get-childitem -path "$env:PSMENU_DIR\functions" -filter "*.ps1" -file
$allfiles = $allfiles + $(Get-ChildItem -Path "$env:PSMENU_DIR\experimental" -Filter "*.ps1" -File -ErrorAction SilentlyContinue)

ForEAch ($ps1file in $allfiles) {
    . "$($ps1file.fullname)"
    Write-Host "Dot sourced " -nonewline
    Write-Host "$($ps1file.basename)" -Foregroundcolor Green
}

## ./UTILS functions - Most importantly - Get-TargetComputers, Get-OutputFileString, general
ForEach ($utility_function in (Get-ChildItem -Path "$env:MENU_UTILS" -Filter '*.ps1' -File)) {
    . "$($utility_function.fullname)"
}

# this line is here just so it will stop if there are errors when trying to install/import modules
Write-Host "`nDebugging point in case errors are encountered - please screenshot and share if you're able." -Foregroundcolor Yellow
Read-Host "Thank you! Press enter to continue."
# create variable, when true - exits program loop
$exit_program = $false
while ($exit_program -eq $false) {
    Clear-Host
    # splitting function options into a list - it was string divided by spaces before
    $split_options = $functions.keys -split ' '
    $options = [system.collections.arraylist]::new()
    Foreach ($option in $split_options) {
        $newoption = $option -replace '_', ' '
        $options.add($newoption) | out-null
    }

    ## Allow the user to choose category - CORRESPONDS to categories listed in config.json
    $chosen_category = Menu $($options | sort)
    #########
    ## SEARCH functionality - returns any file/functions in the functions directory with name containing the input search term.
    if ($chosen_category -eq 'search') {
        Write-Host "Search will return any functions that contain the search term."
        $search_term = Read-Host "Enter search term"
        $allfunctionfiles = Get-ChildItem -Path "$env:PSMENU_DIR\functions" -Filter "*.ps1" -File -Erroraction SilentlyContinue
        $filenames = $allfunctionfiles | select -exp basename
        $function_list = $filenames | Where-Object { $_ -like "*$search_term*" }
    }
    else {
        #reassemble the chosen category with _, if that method was chosen, if it wasn't - nothing will happen
        $chosen_category = $chosen_category -replace ' ', '_'
        # get the functions from the chosen category so they can be presented in the second menu
        $function_list = $functions[$chosen_category]
    }
    Clear-Host
    $function_list = $function_list -replace '-', ' '
    $function_list = $function_list | sort
    if ($function_list.getType().name -eq 'String') {
        $function_list = @($function_list)
    }
    # put 'Return-ToPreviousMenu' at bottom of list - allows user to return to category choices
    $function_list += 'Return-ToPreviousMenu'

    ## FUNCTION SELECTION - menu is presented using psmenu module
    $function_selection = Menu $function_list

    Clear-Host
    # reconstruct the actual filename
    $function_selection = $function_selection -replace ' ', '-'
    # If return was chosen, continue to next iteration of infinite loop - continues until user chooses to exit
    if ($function_selection -eq 'Return-ToPreviousMenu') {
        continue
    }

    # 'Get' info on the command, if there is 1+ parameter(s) - cycle through them prompting the user for values.
    $command = Get-Command $function_selection
    if ($command.Parameters.Count -gt 0) {
        # Getting detailed info on the command is what allows printing of parameter descriptions to terminal, above where user is being prompted for their values.
        $functionhelper = get-help $command -Detailed
        # WRITE functions Description from the comment block / help to terminal at top, above where user will be prompted for parameter values:
        $functions_synopsis = $functionhelper.synopsis
        $functions_synopsis = $functions_synopsis -replace '@{Text=', ''
        $functions_synopsis = $functions_synopsis -replace '}', ''


        $function_description = $functionhelper.description
        $function_description = $function_description -replace '@{Text=', ''
        $function_description = $function_description -replace '}', ''
        ## I think this might work too:
        # $functions_synopsis = $functionhelper.synopsis.text
        # $function_description = $functionhelper.description.text


        Write-Host "$function_selection -> " -foregroundcolor Green
        Write-Host "Function description: " -nonewline -foregroundcolor yellow
        Write-Host "$function_description"
        Write-Host "`n$functions_synopsis"
        Write-Host ""

        # Parameter names
        $parameters = $command.Parameters.Keys
        # Hashtable: Keys = Parameter names, Values = values input by user
        $splat = @{}

        foreach ($parameter in $parameters) {
            ## SKIPS COMMON PARAMETERS: Verbose, Debug, ErrorAction, WarningAction, InformationAction, ErrorVariable, WarningVariable, InformationVariable, OutVariable, OutBuffer, PipelineVariable
            if ($parameter -in ('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable')) {
                continue
            }

            ## TARGETCOMPUTER IS HANDLED HERE if menu is being used - otherwise functions should be able to handle 
            ## TargetComputer in their own way.
            ## If the parameter is TargetComputer - have user enter value, run through get-targetcomputers now.
            if ($parameter -eq 'TargetComputer') {
                Write-Host "Please input value for TargetComputer." -foregroundcolor yellow
                Write-Host "Input can be:"
                Write-Host "    1. Single hostname string, ex: 's-a227-01'"
                Write-Host "    2. Comma-separated list of hostnames, ex: s-a227-01,s-a227-02"
                Write-Host "    3. Path to text file containing one hostname per line, ex:" -NoNewline
                Write-Host " 'D:\computers.txt'" -Foregroundcolor Yellow
                Write-Host "    4. First section of a hostname to generate a list, ex: " -nonewline
                Write-Host "s-a227-" -nonewline -foregroundcolor Yellow
                Write-Host " will create a list of all hostnames that start with s-a227-."
                $target_computers = read-host "Enter target computer value"
                $target_computers = Get-TargetComputers -TargetComputerInput $target_computers
                $target_computers = [String[]]$target_computers
            }
            else {
                $current_parameter_info = $functionhelper.parameters.parameter | Where-Object { $_.name -eq $parameter }
                # For each line in that text block (underneath .PARAMETER parameterName)
                Write-Host "`n$parameter parameter description: " -NoNewLine -Foregroundcolor Yellow
                ForEach ($textitem in $current_parameter_info.description) {
                    # Write each line to terminal.
                    $textitem.text
                }
                # Read-HostNoColon is just Read-Host without the colon at the end, so that an = can be used.
                $value = Read-HostNoColon -Prompt "$parameter = "
                # adds whatever value user input to the hashtable containing parameter names and values.
                $splat.Add($parameter, $value)
            }

        }
        # execute the command using parameter names, and their accompanying values
        # If targetcomputers was set - use it
        ## We could ALSO try PIPING Target computers into the cmdlets that allow it
        if ($target_computers) { 
            $target_computers | & $command @splat
        }
        else {
            & $command @splat
        }
        # Reset Target_computers to null so it is ready for next loop
        $target_computers = $null
    }
    else {
        # execute the command without parameters if it doesn't have any.
        & $command
    }
    ## USER can press x to exit, or enter to return to main menu (category selection)
    Write-Host "`nPress " -NoNewLine
    Write-Host "'x'" -ForegroundColor Red -NoNewline
    Write-Host " to exit, or " -NoNewline 
    Write-Host "[ENTER] to return to menu." -ForegroundColor Yellow -NoNewline

    $key = $Host.UI.RawUI.ReadKey()
    [String]$character = $key.Character
    if ($($character.ToLower()) -eq 'x') {
        exit
    }
    elseif ($($character.ToLower()) -eq '') {
        continue
    }
}