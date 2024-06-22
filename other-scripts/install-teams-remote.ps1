# install team on remote while user logged in:
Function Get-Teams {
    [CmdletBinding()]
    param(
        [String]$Target
    )
    $Target = Read-Host "Enter target: "
    # copy installer to remote target
    $dest = '\\' + $Target + '\c$\users\public\Teams_windows.msi'
    copy-item -path C:\Users\Public\Teams_windows_x64.msi -destination $dest
    invoke-command -computername $Target -scriptblock {
        # run installation and save result exit code to variable
        $result = (Start-Process "msiexec" -ArgumentList "/i C:\Users\Public\Teams_windows_x64.msi ALLUSERS=1" -Wait -Passthru).ExitCode
    }
    if ($result -eq 0) {
        Write-Host "Successful installation!"
    }
    else {
        Write-Host "Possibly unsuccessful installation..."
    }
}