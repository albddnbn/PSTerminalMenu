function Copy-CannedResponse {
    <#
    .SYNOPSIS
        Pulls files from the ./canned_responses directory, and presents menu to user for selection of canned response.
        User is then prompted for values for any variables in the selected response, and the response is copied to the clipboard.

    .DESCRIPTION
        Canned reponses can contain multiple variables indicated by (($variable$)).
        This function cycles through a list of unique variables in the selected response, and prompts the user to enter values for each one.
        The function inserts these values into the original response in place of the variable names, and copies the canned response to the user's clipboard.

    .EXAMPLE
        Copy-CannedResponse

    .NOTES
        One possible use for this function and it's companion function New-CannedResponse is to create canned responses for use in a ticket system, like OSTicket.
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>

    
    ## 1. Creates a list of all .txt and .html files in the canned_responses directory.
    $CannedResponses = Get-ChildItem -Path "$env:PSMENU_DIR\canned_responses" -Include *.txt, *.html -File -Recurse -ErrorAction SilentlyContinue
    if (-not $CannedResponses) {
        Write-Host "No canned responses found in $env:PSMENU_DIR\canned_responses" -ForegroundColor Red
        return
    }

    ## 2. If created by New-CannedResponse, the files will have names with words separated by dashes (-).
    ##    - To offer a menu of options - the filenames are split at all occurences of - by replacing them with spaces.
    $CannedResponseOptions = $CannedResponses | ForEach-Object { $_.BaseName -replace '-', ' ' } | Sort-Object

    ## 3. Checks for PS-Menu module necessary to display interactive terminal menu.
    ##    - if not found - checks for nuget / tries to install ps-menu
    if (-not (Get-Module -Name PS-Menu -ListAvailable)) {
        Write-Host "Installing PS-Menu module..." -ForegroundColor Yellow
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable)) {
            Write-Host "Installing NuGet package provider..." -ForegroundColor Yellow
            Install-PackageProvider -Name NuGet -MinimumVersion
        }
        Install-Module -Name PS-Menu -Force
    }
    Import-Module -Name PS-Menu -Force

    # presents menu
    $chosen_response = Menu $CannedResponseOptions

    # reconstructs filenames, re-inserting dashes for spaces
    $chosen_response = $chosen_response -replace ' ', '-'

    ## 4. Get the content of the correct file - using original list of .html/.txt file objects
    $chosen_response_file = $CannedResponses | Where-Object { $_.BaseName -eq $chosen_response }
    $chosen_response_content = Get-Content "$($chosen_response_file.fullname)"

    ## 5. Get the variables from the content - variables are enclosed in (($variable$))
    ##    - for loop cycles through each unique variable, prompting the user for values.

    $variables = $chosen_response_content | Select-String -Pattern '\(\(\$.*\$\)\)' -AllMatches | ForEach-Object { $_.Matches.Value } | Sort-Object -Unique
    ForEach ($single_variable in $variables) {
        $formatted_variable_name = $single_variable -split '=' | select -first 1
        # $formatted_variable_name = $formatted_variable_name.replace('(($', '')

        ForEach ($str_item in @('(($', '$))')) {
            $formatted_variable_name = $formatted_variable_name.replace($str_item, '')
        }


        if ($single_variable -like "*=*") {
            $variable_description = $single_variable -split '=' | select -last 1
            $variable_description = $variable_description.replace('$))', '')
        }
        Write-Host "Description: " -nonewline -foregroundcolor yellow
        Write-host "$variable_description"
        $variable_value = Read-Host "Enter value for $formatted_variable_name"
        Write-Host "Replacing $single_variable with $variable_value"
        $chosen_response_content = $chosen_response_content.replace($single_Variable, $variable_value)
    }
    ## 6. Copy chosen response to clipboard, with new variable values inserted
    $chosen_response_content | Set-Clipboard
    Write-Host "Canned response copied to clipboard." -ForegroundColor Green
}
