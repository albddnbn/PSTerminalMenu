Function Install-GenericMSI {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$targetComputer,
        [Parameter(Mandatory = $true)]
        [string]$installer_path
    )
    # copy installer to target computer public folder
    $filename = Split-Path $installer_path -Leaf
    $target_installer_path = "\\$targetComputer\c$\temp\"
    Copy-Item -Path $installer_path -Destination $target_installer_path -Force
    # if installer_path is an .exe file
    # if ($filename -like "*.exe") {
    #     $arguments = "/S /norestart"
    #     $process = Start-Process -FilePath $installerPath -ArgumentList $arguments -PassThru -Wait
    #     $exitCode = $process.ExitCode
    # } elseif ($filename -like "*.msi") {
    $installation_result = Invoke-Command -ComputerName $targetComputer -ScriptBlock {
        $result = (Start-Process "msiexec.exe" -ArgumentList "/i `"C:\temp\$using:filename`" /qn" -Wait -Passthru).ExitCode
        $result
    }
    # get just the filename from the msi path
    Write-Host "$filename installation on $targetComputer completed."
    Write-Host "$filename exit code: $installation_result"
    #}
}