

function Scan-Inventory {
    <#
    .SYNOPSIS
        Helps to generate an inventory spreadsheet of items, their current stock values, along with other item details.
        The script tries to link scanned input to an item in 3 ways, in this order: 
        1. currently scanned item list
        2. master item list
        3. API lookup

    .DESCRIPTION
        If the script fails to automatically link scanned input to an item, and also fails to find the item details 
        through the API - it will prompt the user to manually enter item details. The item object will then be added to 
        the currently scanned items list (and also master item list).

    .PARAMETER ScanTitle
        Title of the scan, will be used to name the output file(s).
    
    .PARAMETER ScanList
        Absolute path to a file containing codes scanned using barcode scanner.
        You can scan all codes to a text file and then submit them as a list to speed things up.
        Note to add catch in the list scanning - functionality so user can make sure items don't look off.
        For Ex: I've scanned some printer-related items, and RARELY had a wierd item returned, like Denim Jeans.
        This isn't common, especially for major brand toner-related items - Dell, HP, Lexmark, Brother.

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [String]$ScanTitle = 'Inventory',
        [string]$ScanList
    )
    # if (-not (Get-Module -Name 'PSADT' -ListAvailable)) {
    #     Install-Module -Name 'PSADT' -Force
    # }
    # ipmo psadt


    ## Creates item with specified properties (in parameters) and then prompts user to keep or change each value, 
    ## returns changed object
    Function Create-NewItemObject {
        param(
            $Description = '',
            $Compatible_printers = '',
            $code = '',
            $UPC = '',
            $Stock = '',
            $Part_num = '',
            $color = '',
            $brand = '',
            $yield = '',
            $type = '',
            $comments = '',
            $ean = '',
            $Seek_input = $true
        )
        ## "description","compatible_printers","code","upc","stock","part_num","color","brand","yield","type","comments","ean"
        $obj = [pscustomobject]@{
            Description         = $Description
            Compatible_printers = $Compatible_printers
            code                = $code
            UPC                 = $UPC
            Stock               = $Stock
            # need to see how i can parse this
            Part_num            = $Part_num
            color               = $color
            brand               = $brand
            yield               = $yield
            type                = $type
            comments            = $comments
            ean                 = $ean
        }
        if (-not $Seek_input) {
            return $obj
        }
        # These property values are SKIPPED when item is scanned / prompting for new values:
        $SKIPPED_PROPERTY_VALUES = @('upc', 'type', 'Compatible_printers', 'ean', 'yield', 'color', 'stock')
        $obj.PSObject.Properties | ForEach-Object {
            if ($_.Name -notin $SKIPPED_PROPERTY_VALUES) {
                
                $current_value = $_.Value
                Write-Host "Current value of $($_.Name) is: $($_.Value), enter 'k' to retain value."
                $_.Value = Read-Host "Enter value for $($_.Name)"
                if ($_.Value -eq 'k') {
                    $_.Value = $current_value
                }
            }
        }
        return $obj
    }

    ## --- SCRIPT VARIABLES ---
    $MASTER_CSV_FILE = "$env:PSMENU_DIR\inventory\master-inventory.csv" # holds all items that have been scanned in, for all time
    $API_URL = "https://api.upcitemdb.com/prod/trial/lookup?upc="

    # SOUNDS for success/failure at linking scanned items to existing or api items.
    $POSITIVE_BEEP_PATH = "$env:PSMENU_DIR\inventory\sounds\positivebeep.wav"
    $NEGATIVE_BEEP_PATH = "$env:PSMENU_DIR\inventory\sounds\negativebeep.wav"

    # making sure master .csv file exists
    if (-not (Test-path "$env:PSMENU_DIR\inventory\master-inventory.csv" -erroraction SilentlyContinue)) {
        New-Item -Path "$env:PSMENU_DIR\inventory\master-inventory.csv" -ItemType 'File' -Force | Out-Null
    }
    # New-File -Path "$env:PSMENU_DIR\inventory\master-inventory.csv"
    # get filesize of master csv file
    $reply = Read-Host "Import items from $MASTER_CSV_FILE ? (y/n)"
    if ($reply.tolower() -eq 'y') {
        try {
            $MASTER_ITEM_LIST = import-csv $MASTER_CSV_FILE
        }
        catch {
            Write-Host "Failed to import $MASTER_CSV_FILE, continuing in 5 seconds.." -foregroundcolor yellow
            Start-Sleep -Seconds 5        
        }
    }
    if (Get-Command -Name 'Get-Outputfilestring' -ErrorAction SilentlyContinue) {
        # create output filename for inventory report (this is different from the master list file, this is the report being generated by this current/run of the function)
        $outputfile = Get-OutputFileString -Titlestring $ScanTitle -rootdirectory $env:PSMENU_DIR -foldertitle $REPORT_DIRECTORY -reportoutput
    }
    else {
        $outputfile = "Inventory-$ScanTitle"
    }
    Write-Host "Output file(s) will be at: $outputfile .csv and/or .xlsx" -foregroundcolor green
    
    ## Holds items scanned during this run of the function, will be output to report .csv/.xlsx
    $CURRENT_INVENTORY = [System.collections.arraylist]::new()

    ## add items from master item list to current inventory, set stock to 0
    $MASTER_ITEM_LIST | ForEach-Object {
        $_.stock = '0'
        $CURRENT_INVENTORY.Add($_) | Out-Null
    }

    Function Get-ScannedItems {
        param(
            $scanned_codes,
            $inventory_list
        )

        $missed_items = [System.Collections.ArrayList]::new()

        # if api lookup can't recognize a code, the code won't be looked up again.
        $invalid_upcs = [System.Collections.ArrayList]::new()
        $API_LOOKUP_LIMIT_REACHED = $false
        ForEach ($scanned_code in $scanned_codes) {
            write-host "Checking: $scanned_code"
            $ITEM_FOUND = $false
            # CHECK CURRENT INVENTORY ARRAYLIST
            $inventory_list | ForEach-Object {
                ## Search upc codes
                # write-host "checking $($_.upc), $($_.description)"
                # $upctest = $_.upc
                # $upctest.gettype().name
                if ($scanned_code -eq ([string]$($_.upc))) {
                    Write-Host "Found match for $scanned_code in upc/ean columns of current inventory, increasing stock by 1."
                    $player = New-Object System.Media.SoundPlayer
                    $player.SoundLocation = $POSITIVE_BEEP_PATH
                    $player.Load()
                    $player.Play()

                    $matched_item_index = $inventory_list.IndexOf($_)
                    $matched_item = $inventory_list[$matched_item_index]
                    Write-Host "Set matched item to: $($matched_item.description)"

                    $inventory_list | ForEach-Object {
                        if ($matched_item.description -eq $_.description) {
                            $_.stock = [string]$([int]$_.stock + 1)
                            Write-Host "`rIncreased stock of $($_.description) by 1, to: $($_.stock).`n"
                        }
                    }
                    $ITEM_FOUND = $true
                }
            }

            ## Continue to next iteration / scanned item if item was found
            if ($ITEM_FOUND) {
                continue
            }
            else {
                ## If the API has already said the code is invalid, or returned an 'exceeded limit' response
                ## - no point in continuing
                if ($scanned_code -in $invalid_upcs) {
                    Write-Host "Skipping $scanned_code, it was already determined to be an invalid upc." -foregroundcolor yellow
                    $missed_items.add($scanned_code) | Out-Null
                    continue
                }
                elseif ($API_LOOKUP_LIMIT_REACHED) {
                    Write-Host "API LOOKUP LIMIT REACHED FOR THE DAY! (~100 for free last checked)" -Foregroundcolor red
                    $missed_items.add($scanned_code) | Out-Null
                    continue
                }
                ## IF - the user input has a space or dash - it's not gonna work, no point continuing. 
                elseif (($scanned_code -like "* *") -or ($scanned_code -like "*-*")) {
                    Write-Host "Skipping $scanned_code, it contains a space or dash." -foregroundcolor yellow
                    $missed_items.add($scanned_code) | Out-Null
                    continue
                }
                ## IF - the user input has any letters in it - not a upc code
                elseif ($scanned_code -cmatch "^*[A-Z][a-z]*$") { 
                    Write-Host "Skipping $scanned_code, it has letters." -foregroundcolor yellow
                    $missed_items.add($scanned_code) | Out-Null
                    continue
                }

                ## If CODE not 'invalid' / limit not reached - continue with API lookup

                Write-Host "input: $scanned_code not found in current inventory list, checking api.."
                ## API LOOKUP
                ## Play 'BAD BEEP'       
                $player = New-Object System.Media.SoundPlayer
                $player.SoundLocation = $NEGATIVE_BEEP_PATH
                $player.Load()
                $player.Play()
                # if reaches this point, then item is not already in the lists so API has to be checked.
                try {
                    $api_response = Invoke-WebRequest -URI "$API_URL$($scanned_code)"
                }
                catch [System.Net.WebException] {
                    # Handle WebException here
                    Write-Host "API response was for invalud upc or to slow down."
                    ## if the exception error message contains TOO_FAST - start - sleep 15 seconds
                    Write-Host "This is the exception:`n$($_.errordetails)"
                    if ($($_.errordetails) -like "*INVALID_UPC*") {
                        Write-Host "API returned INVALID UPC for: $scanned_code." -Foregroundcolor Yellow
                        $missed_items.add($scanned_code) | Out-Null
                        $invalid_upcs.add($scanned_code) | Out-Null

                        Write-Host "Adding: $scanned_code to list of items that need to be accounted for manually." -foregroundcolor yellow
                    }
                    ## Sending API lookups too fast - slow down for 90s
                    elseif ($($_.errordetails) -like "*TOO_FAST*") {
                        Write-Host "API returned TOO_FAST for: $scanned_code." -Foregroundcolor Yellow
                        $missed_items.add($scanned_code) | Out-Null
                        Write-Host "Slowing down for 90 seconds." -foregroundcolor yellow
                        Start-Sleep -Seconds 90
                    }
                    ## API Lookup limit reached for the day - api lookups won't continue in next loop iterations
                    elseif ($($_.errordetails) -like "*EXCEED_LIMIT*") {
                        Write-Host "API LOOKUP LIMIT REACHED FOR THE DAY! (~100 for free last checked)" -Foregroundcolor red
                        $missed_items.add($scanned_code) | Out-Null
                        Write-Host "Slowing down for 90 seconds." -foregroundcolor yellow
                        $API_LOOKUP_LIMIT_REACHED = $true
                    }
                    continue
                }
                # convert api_response content from json
                $json_response_content = $api_response | ConvertFrom-Json
                # make sure response was 'ok'
                ## if the items.title isn't a system/object (psobject)?
                if (($([string]($json_response_content.code)) -eq 'OK') -and ($json_response_content.items.title)) {
                    Write-Host "API response for $scanned_code was 'OK'" -Foregroundcolor Green
                    $menu_options = $json_response_content.items.title | sort
                    ## "description","compatible_printers","code","upc","stock","part_num","color","brand","yield","type","comments","ean"
                    ## this gets info from first result
                    # present menu - user can choose between multiple item results (theoretically):
                    $chosen_item_name = $Menu_options | select -first 1

                    # get item object - translate it to new object
                    $item_obj = $json_response_content.items | where-object { $_.title -eq $chosen_item_name }

                    ## create item object using default / values from the itenm object
                    $obj = Create-NewItemObject -Description $chosen_item_name -code $item_obj.model -stock '1' -UPC $item_obj.upc -Part_num $item_obj.model -color $item_obj.color -brand $item_obj.brand -ean $item_obj.ean -seek_input $false
                    # read-host "press enter to continue"
                    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Adding the object to inventory_csv variable.." -ForegroundColor green
                    $inventory_list.add($obj) | Out-Null

                }
                else {
                    $missed_items.add($scanned_code) | Out-Null
                    Write-Host "Adding: $scanned_code to list of items that need to be accounted for manually." -foregroundcolor yellow
                }
            }
        }

        ## Safety export of inventory_list to csv (in case changes messed up how list is passed back out to report creation)
        $inventory_list | export-csv "inventoryscan-$(get-date -format 'yyyy-MM-dd-hh-mm-ss').csv" -NoTypeInformation -Force
        $missed_items | out-file "misseditems-$(get-date -format 'yyyy-MM-dd-hh-mm-ss').csv"
        $return_obj = [pscustomobject]@{
            misseditems   = $missed_items
            inventorylist = $inventory_list
        }
        
        return $return_obj
    }

    if (test-path $Scanlist -erroraction SilentlyContinue) {
        read-host "scan list detected."
        $scanned_codes = Get-Content $Scanlist

        $results = Get-ScannedItems -scanned_codes $scanned_codes -inventory_list $CURRENT_INVENTORY
        $missed_items = $results.misseditems
        # $written_inventory_list = $results.inventorylist
        # # Write-Host "This is the missed items array: $missed_items"
        # # Write-Host "This is inventory list $written_inventory_list"
        # # Read-Host "The results array and inventory lists should be above this."

        if ($missed_items) {

            $datetimestring = get-date -format 'yyyy-MM-dd-hh-mm-ss'
            "These items were missed during scan at: $datetimestring`r" | Out-File "$env:PSMENU_DIR\inventory\missed_items-$datetimestring.txt"
            $missed_items | Out-File "$env:PSMENU_DIR\inventory\missed_items-$datetimestring.txt" -Append
            Write-Host "Items that were not found in the master list or API lookup have been saved to $env:PSMENU_DIR\inventory\missed_items-$datetimestring.txt"
        
            Invoke-item "$env:PSMENU_DIR\inventory\"
        }
        else {
            Write-Host "All items were found in the master list or API lookup." -Foregroundcolor Green
        
        }
        $CURRENT_INVENTORY = $results.inventorylist
    }
    else {
        # Begin 'scan loop' where user scans items.
        ## First - the scanned code is checked against the master item list, 
        ## If it's not found, the script sends a request to the API URL with scanned code to try to get details.
        while ($true) {

            $user_input = Read-Host "Scan code, or type 'exit' to quit"
            if ($user_input.ToLower() -eq 'exit') {
                break
            }
            $ITEM_FOUND = $false

            # CHECK CURRENT INVENTORY ARRAYLIST
            $CURRENT_INVENTORY | ForEach-Object {
                ## Search upc codes
                write-host "checking $($_.upc), $($_.description)"
                $upctest = $_.upc
                $upctest.gettype().name
                if (($user_input -eq ([string]$($_.upc))) -or ($user_input -eq ([string]$($_.ean)))) {
                    Write-Host "Found match for $user_input in upc/ean columns of current inventory, increasing stock by 1."
                    $player = New-Object System.Media.SoundPlayer
                    $player.SoundLocation = $POSITIVE_BEEP_PATH
                    $player.Load()
                    $player.Play()

                    $matched_item_index = $CURRENT_INVENTORY.IndexOf($_)
                    $matched_item = $CURRENT_INVENTORY[$matched_item_index]
                    Write-Host "Set matched item to: $($matched_item.description)"

                    $CURRENT_INVENTORY | ForEach-Object {
                        if ($matched_item.description -eq $_.description) {
                            $_.stock = [string]$([int]$_.stock + 1)
                            Write-Host "`rIncreased stock of $($_.description) by 1, to: $($_.stock).`n"
                        }
                    }
                    $ITEM_FOUND = $true
                }
            }

            ## Continue to next iteration / scanned item if item was found
            if ($ITEM_FOUND) {
                continue
            }
            ## API LOOKUP
            ## Play 'BAD BEEP'       
            $player = New-Object System.Media.SoundPlayer
            $player.SoundLocation = $NEGATIVE_BEEP_PATH
            $player.Load()
            $player.Play()
            # if reaches this point, then item is not already in the lists so API has to be checked.
            $api_response = Invoke-WebRequest -URI "$API_URL$($user_input)"

            # convert api_response content from json
            $json_response_content = $api_response.content | ConvertFrom-Json
            # make sure response was 'ok'
            if ($json_response_content.code -eq 'OK') {
                Write-Host "API response for $user_input was 'OK', here are the results:" -Foregroundcolor Green
                Write-Host ""
                $menu_options = $json_response_content.items.title | sort
                ## "description","compatible_printers","code","upc","stock","part_num","color","brand","yield","type","comments","ean"
                ## this gets info from first result
                $item_details = $json_response_content.items | where-object { $_.title -eq $($menu_options | select -first 1) }
                $useful_details = $item_details | Select title, description, model, upc, color, brand, ean, dimension, category
                # $useful_details = $item_details | Select ean, title, description, upc, brand, model, color, dimension, category

                $useful_details | Format-List

                Write-Host ""

                # present menu - user can choose between multiple item results (theoretically):

                $chosen_item_name = Menu $menu_options

                # get item object - translate it to new object
                $item_obj = $json_response_content.items | where-object { $_.title -eq $chosen_item_name }

                ## create item object using default / values from the itenm object
                $obj = Create-NewItemObject -Description $chosen_item_name -code $item_obj.model -UPC $item_obj.upc -Part_num $item_obj.model -color $item_obj.color -brand $item_obj.brand -ean $item_obj.ean

                read-host "press enter to continue"
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Adding the object to inventory_csv variable.."
                $CURRENT_INVENTORY.add($obj) | Out-Null

                $CURRENT_INVENTORY
                Read-Host "This is current inventory"

            }
            else {

                Write-Host "API was unable to find matching item for: $user_input."
                $response = Menu @('Scan again?', 'Create item manually')
                if ($response -eq 'Scan again?') {
                    continue
                }
                else {
                    $obj = Create-NewItemObject -UPC $user_input
                    $CURRENT_INVENTORY.add($obj) | Out-Null
                }
            }    
        }
    }
    #########################################################
    ## INVENTORY SPREADSHEET CREATION (end of scanning loop):
    #########################################################
    # script creates a .csv / .xlsx report from CURRENT_INVENTORY arraylist
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Exporting scanned inventory to " -NoNewline
    Write-Host "$outputfile.csv and $outputfile.xlsx" -Foregroundcolor Green
    $CURRENT_INVENTORY | Export-CSV "$outputfile.csv" -NoTypeInformation -Force

    # look for the importexcel powershell module
    $CheckForimportExcel = Get-InstalledModule -Name 'importexcel' -ErrorAction SilentlyContinue
    if (-not $CheckForimportExcel) {
        Install-Module -Name ImportExcel -Force
    }

    $params = @{
        AutoSize             = $true
        TitleBackgroundColor = 'Blue'
        TableName            = "$ScanTitle"
        TableStyle           = 'Medium9' # => Here you can chosse the Style you like the most
        BoldTopRow           = $true
        WorksheetName        = $ScanTitle
        PassThru             = $true
        Path                 = "$OutPutFile.xlsx" # => Define where to save it here!
    }

    $xlsx = $CURRENT_INVENTORY | Export-Excel @params
    $ws = $xlsx.Workbook.Worksheets[$params.Worksheetname]
    $ws.View.ShowGridLines = $false # => This will hide the GridLines on your file
    Close-ExcelPackage $xlsx

    # Explorer.exe $env:PSMENU_DIR\reports\$thedate\$REPORT_DIRECTORY
    try {
        Invoke-Item "$outputfile.xlsx"
    }
    catch {
        Write-Host "Failed to open $outputfile.xlsx, opening .csv in notepad." -Foregroundcolor Yellow
        notepad.exe "$outputfile.csv"
    }
    Read-Host "`nPress [ENTER] to continue."
}
