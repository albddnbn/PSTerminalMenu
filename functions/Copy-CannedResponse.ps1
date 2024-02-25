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
    # creates list of html files from the canned_responses directory
    $CannedResponses = Get-ChildItem -Path "$env:PSMENU_DIR\canned_responses" -Filter "*.html" -File

    # Deconstruct html file names into presentable menu options
    $CannedResponseOptions = $CannedResponses | ForEach-Object { $_.BaseName -replace '-', ' ' } | Sort-Object

    if (!(Get-Module -Name PS-Menu)) {
        Write-Host "Installing PS-Menu module..." -ForegroundColor Yellow
        Install-Module -Name PS-Menu -Force -Scope CurrentUser
    }
    Import-Module -Name PS-Menu -Force | Out-Null

    ######################################################
    #
    # PRESENT MENU to the user, menu options correspond 
    # to any .html files in the canned_responses directory
    #
    ######################################################
    $chosen_response = Menu $CannedResponseOptions

    # Reconstruct the html file name
    $chosen_response = $chosen_response -replace ' ', '-'
    Write-Host "You've selected the $chosen_response.html canned response."

    $chosen_response_content = Get-Content "canned_responses\$chosen_response.html"

    # get the variables from the content - variables are enclosed in [$variable$]
    $variables = $chosen_response_content | Select-String -Pattern '\(\(.*\)\)' -AllMatches | ForEach-Object { $_.Matches.Value } | Sort-Object -Unique

    # prompt user for values for each varaible:
    ForEach ($single_variable in $variables) {
        $formatted_variable_name = $single_variable -split '=' | select -first 1
        $formatted_variable_name = $formatted_variable_name.replace('(($', '')
        
        $variable_description = $single_variable -split '=' | select -last 1
        $variable_description = $variable_description.replace('$))', '')

        Write-Host "Description: " -nonewline -foregroundcolor yellow
        Write-host "$variable_description"
        $variable_value = Read-Host "Enter value for $formatted_variable_name"
        Write-Host "Replacing $single_variable with $variable_value"
        $chosen_response_content = $chosen_response_content.replace($single_Variable, $variable_value)
    }

    # copy to clipboard
    $chosen_response_content | Set-Clipboard

    Write-Host "Canned response copied to clipboard." -ForegroundColor Green


}
