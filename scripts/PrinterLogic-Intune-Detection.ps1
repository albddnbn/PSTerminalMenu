$folders = @("Program Files", "Program Files (x86)")
foreach ($folder in $folders) {
    $result = Get-ChildItem -Path "C:\$folder" -Filter "PrinterInstallerClient.exe" -Recurse -ErrorAction SilentlyContinue | Select -ExpandProperty FullName
    if ($result) {
        write-output "$result found"
        exit 0
    }
}
exit 1