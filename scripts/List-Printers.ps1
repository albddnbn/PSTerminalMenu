<#
.SYNOPSIS
    Checks for user logged into computer - if there is one, the script lists any connected printers using the win32_printer CIM class.
    It creates a PSCustomObject that has 'Username', 'DefaultPrinter', and 'ConnectedPrinters' properties.
    'ConnectedPrinters' is a comma-separated string/list of printer names that user is connected to.
#>

# Everything will stay null, if there is no user logged in
$obj = [PScustomObject]@{
    Username          = (get-process -name 'explorer' -includeusername -erroraction silentlycontinue).username
    DefaultPrinter    = $null
    ConnectedPrinters = $null
}

# Only need to check for connected printers if a user is logged in.
if ($obj.Username) {
    # get connected printers:
    $printers = get-ciminstance -class win32_printer | select name, Default
    $obj.DefaultPrinter = $printers | where-object { $_.default } | select -exp name

    ForEach ($single_printer in $printers) {
        if (-not $printer.default) {
            # make sure its not a 'OneNote' printer, or Microsoft Printer to PDF.
            if (($single_printer.name -notin ('Microsoft Print to PDF', 'Fax')) -and ($single_printer.name -notlike "*OneNote *")) {
                $obj.ConnectedPrinters = "$($obj.ConnectedPrinters), $($single_printer.name)"
            }
        }
    }
}

return $obj