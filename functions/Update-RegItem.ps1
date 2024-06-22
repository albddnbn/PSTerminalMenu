<#
script to offer user choice of different reg edits to make
#>
Function Update-RegItem {
    param(
        [String]$regFile
    )

    # if the regFile argument isn't provided, then present a PS-Menu
    if (!($PSBoundParameters.ContainsKey('regFile')) -or ($regFile -eq "")) {
        if (Get-Module -ListAvailable -Name PS-Menu) {
            Import-Module PS-Menu
        }
        else {
            Write-Host "PS-Menu not found. Installing..."
            Install-Module PS-Menu -Scope CurrentUser -Force
            Import-Module PS-Menu
        }

        # **CREATE ARRAYLIST FROM THE .REG FILES IN THE 'REG' FILDER (WITHOUT FILE EXTENSION)**
        $reg_edit_options = Get-ChildItem -Path "$PSScriptRoot\reg" -Filter *.reg | ForEach-Object { $_.BaseName }
        $reg_choice = menu $reg_edit_options
        # $reg_choice = "./reg/$(menu $reg_edit_options).reg"
    }
    else {

        # present menu with all reg file in reg directory
        # $reg_edit_options = Get-ChildItem -Path "$PSScriptRoot\reg" -Filter *.reg | ForEach-Object { $_.BaseName }

        # make sure regFile is an actual .reg file
        if ($regFile -notlike "*.reg") {
            $regFile += ".reg"
            Write-Host "regfile: $regFile"
        }
        if (!(Test-Path -Path $regFile)) {
            Write-Host "Please provide the path to valid .reg file." -ForegroundColor Yellow
            return
        }
        $reg_choice = $regFile
    }

    try {
        if ($reg_choice -like "*\\reg\\*") {
            $reg_choice = $reg_choice -replace ".*\\reg\\", ""
        }
        write-host "./reg/$reg_choice.reg"
        reg import "./reg/$reg_choice.reg"
        Write-Host "Registry edit complete." -ForegroundColor Green
        Stop-Process -Name explorer -Force
        Start-Process -FilePath "C:\WINDOWS\explorer.exe"
    }
    catch {
        Write-Host "Unable to import reg file."
        Write-Host "Error: $_"
    }
}