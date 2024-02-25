function New-CannedResponse {
    <#
    .SYNOPSIS
        Allows user to create a txt/html file, that has variables defined. 
        When the Copy-CannedResponse function is used on this newly created file - it will prompt user for values for any variabels before copying the text to clipboard.

    .DESCRIPTION
        The user will have to enter variables of their own, defined in the text like this: (($variable_name$)).
    
    .PARAMETER FileType
        Allows user to create either a TXT or HTML canned response file. With HTML files - the user will have to click the <> (code) button in OSTicket before pasting in the canned response HTML.
        TXT files can be directly pasted without clicking the <> button.
        Options include: txt, html

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param(
        [string]$FileType
    )
    Write-Host "Canned Response Instructions:"
    Write-Host "-----------------------------"
    Write-Host "Variables are defined like this: " -nonewline -foregroundcolor Yellow
    Write-Host "((`$variable_name_here`$)), Get-CannedResponse will pick them up and prompt you for their values before copying the response content to your clipboard."
    Write-Host "You should be able to use any html tags that work correctly in OSTicket, for ex: <b>text</b> for bold text."
    Write-Host "Enter response content, a blank line will end the input session." -Foregroundcolor Green
    # source: https://stackoverflow.com/questions/36650961/use-read-host-to-enter-multiple-lines / majkinetor
    $response_content = while (1) { read-host | set r; if (!$r) { break }; $r }

    if ($FileType.ToLower() -eq 'html') {

        # create html:
        $html_template = @"
<html>`n
<body>`n

"@
        ForEach ($single_line in $response_content) {
            $html_string = "<p>$single_line</p>`n"
            $html_template += $html_string
        }
        $html_template += @"

</body>`n
</html>
"@
    }
    elseif ($FileType.ToLower() -eq 'txt') {
        # $html_template variable is eventually output to file, so set it to equal just the text content if user chose txt
        $html_template = $response_content
    }
    # write to file - extension will be .html even if its just text content to keep things simple
    do {
        $filename = Read-Host "Enter filename for canned response, no extension needed."
        if ($filename -notlike "*.html") {
            $filename = "$filename.html"
        }
    } until (-not (Test-Path "$env:PSMENU_DIR\canned_responses\$filename" -ErrorAction SilentlyContinue))
    # Set-Content will keep formatting / newlines - Out-File will not as-is
    Set-Content -Path "$env:PSMENU_DIR\canned_responses\$filename" -Value $html_template
    
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ::Canned response file created at canned_responses\$filename" -ForegroundColor Green

    Invoke-Item "$env:PSMENU_DIR\canned_responses\$filename"

}