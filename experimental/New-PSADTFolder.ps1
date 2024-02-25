Function New-PSADTFolder {
    <#
    .SYNOPSIS
        Looks for the PSADT folder in support files, prompts user for application name and other details, then creates a new PSADT folder (branded) with application name/details filled out.

    .DESCRIPTION
        More detailed description on what the function does.

    .PARAMETER OutputFolder
        Output location for new PSDAT folder.

    .EXAMPLE
        An example of one way of running the function.

    .EXAMPLE
        You can include as many examples as necessary to reflect different ways of running the function, different parameters, etc.

    .NOTES
        Additional notes about the function.
        Author of the function.
        Sources used to create function / credits.
    #>
    param(
        [string]$Outputfolder
    )
    # dot source utility functions
    ForEach ($utility_function in (Get-ChildItem -Path "$env:MENU_UTILS" -Filter '*.ps1' -File)) {
        . $utility_function.fullname
    }

    if (-not ($outputfolder)) {
        $outputfolder = Read-Host "Enter output path for new PSADT folder"
    }

    if (-not (Test-Path "$outputfolder" -erroraction silentlycontinue)) {
        New-Item "$outputfolder" -Itemtype 'directory' | out-null
    }

    $psadt_folder = Get-Childitem -path "$env:SUPPORTFILES_DIR" -filter 'PSADT' -directory -erroraction SilentlyContinue
    if (-not $psadt_folder) {
        Write-Host "PSADT folder not found in $env:SUPPORTFILES_DIR, please configure to run function." -Foregroundcolor Red
        return
    }

    # appname
    # apppublisher
    # author
    $application_name = read-host "enter the application's name"
    # $app_publisher = read-host "enter publisher's name"
    # $app_author = read-host "enter script author's name"


    Write-Host "Found $($psadt_folder.fullname), copying to $outputfolder\$application_name."

    New-Item -Path "$outputfolder\$application_name" -itemtype 'directory' -force | out-null

    Copy-Item -Path "$($psadt_folder.fullname)\*" -destination "$outputfolder\$application_name\" -Recurse

    $psadt_file = Get-Childitem -path "$outputfolder\$application_name" -Filter "Deploy-application.ps1" -File

    $psadt_file_content = get-content -path "$($psadt_file.fullname)"

    $variables = $psadt_file_content | Select-String -Pattern '\(\(.*\)\)' -AllMatches | ForEach-Object { $_.Matches.Value } | Sort-Object -Unique

    # prompt user for values for each varaible:
    ForEach ($single_variable in $variables) {
        $formatted_variable_name = $single_variable -split '=' | select -first 1
        $formatted_variable_name = $formatted_variable_name.replace('(($', '')
        if ($formatted_Variable_name -in @('appname', 'apppublisher', 'author')) {
        
            $variable_description = $single_variable -split '=' | select -last 1
            $variable_description = $variable_description.replace('$))', '')

            Write-Host "Description: " -nonewline -foregroundcolor yellow
            Write-host "$variable_description"
            $variable_value = Read-Host "Enter value for $formatted_variable_name"
            Write-Host "Replacing $single_variable with $variable_value"
            $psadt_file_content = $psadt_file_content.replace($single_Variable, $variable_value)
        }
    }
    REmove-ITem -Path "$($psadt_file.fullname)"

    $deploy_Script_path = "$($psadt_file.psparentpath)\Deploy-$application_name.ps1"

    new-item -path "$deploy_script_path" -itemtype 'file' | Out-Null
    $psadt_file_content | Set-Content "$deploy_script_path"
    Write-Host "New Deploy-$application_name folder and script created."

    Read-host "Press enter to continue."
}