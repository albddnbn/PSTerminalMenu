$THISPC = hostname
$HERE = (Get-Item -Path ".\").FullName
$OUTTIE = $HERE + "\" + $THISPC + ".html"

Function SoftwareInvent  
{
param(
[Parameter(valuefrompipeline=$true)][string]$Computers)        
begin {}                
    Process  
        {
        $computer = [ADSI]("WinNT://" + $Computers + ",computer")
        $pingResult = Test-Connection -ComputerName $Computers -Count 2 -Quiet        
        if ($pingResult)
            {
            Write-Host -ForegroundColor Green "Performing Inventory de Software on your computer"$Computers
            $Base = New-Object PSObject;
            $Base | Add-Member Noteproperty Computer -Value $Null;
            $Base | Add-Member Noteproperty Software -Value $Null;
            $Base | Add-Member Noteproperty Manufacture -Value $Null;
            $Base | Add-Member Noteproperty InstallDate -Value $Null;
            $Base | Add-Member Noteproperty EstimatedSize -Value $Null;
            $Base | Add-Member Noteproperty Version -Value $Null;
            $Base | Add-Member Noteproperty Wow6432Node -Value $Null;
            $Results =  New-Object System.Collections.Generic.List[System.Object];
                ForEach ($ComputerName in $Computers)
                {
                $Registry = $Null;
                Try{$Registry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$ComputerName);}
                Catch
                    {    
                    Write-Host -ForegroundColor Yellow "Cannot connect to the registry of the computer"$Computers "Start the remote registry service on the same"      
                    }
                    If ($Registry){
                        $UninstallKeys = $Null;
                        $SubKey = $Null;
                        $UninstallKeys = $Registry.OpenSubKey("Software\Microsoft\Windows\CurrentVersion\Uninstall",$False);
                        $UninstallKeys.GetSubKeyNames()|%{
                            $SubKey = $UninstallKeys.OpenSubKey($_,$False);
                            $DisplayName = $SubKey.GetValue("DisplayName");
                            If ($DisplayName.Length -gt 0){
                                $Entry = $Base | Select-Object *
                                $Entry.Computer = $ComputerName;
                                $Entry.Software = $DisplayName.Trim();  
                                $Entry.Manufacture = $SubKey.GetValue("Publisher");  
                                [ref]$ParsedInstallDate = Get-Date
                                If ([DateTime]::TryParseExact($SubKey.GetValue("InstallDate"),"yyyyMMdd",$Null,[System.Globalization.DateTimeStyles]::None,$ParsedInstallDate)){                    
                                $Entry.InstallDate = $ParsedInstallDate.Value
                                }
                                $Entry.EstimatedSize = [Math]::Round($SubKey.GetValue("EstimatedSize")/1KB,1);
                                $Entry.Version = $SubKey.GetValue("DisplayVersion");
                                [Void]$Results.Add($Entry);
                            }
                        }
                            If ([IntPtr]::Size -eq 8){
                            $UninstallKeysWow6432Node = $Null;
                            $SubKeyWow6432Node = $Null;
                            $UninstallKeysWow6432Node = $Registry.OpenSubKey("Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",$False);
                                If ($UninstallKeysWow6432Node) {
                                    $UninstallKeysWow6432Node.GetSubKeyNames()|%{
                                    $SubKeyWow6432Node = $UninstallKeysWow6432Node.OpenSubKey($_,$False);
                                    $DisplayName = $SubKeyWow6432Node.GetValue("DisplayName");
                                    If ($DisplayName.Length -gt 0){
                                        $Entry = $Base | Select-Object *
                                        $Entry.Computer = $ComputerName;
                                        $Entry.Software = $DisplayName.Trim();  
                                        $Entry.Manufacture = $SubKeyWow6432Node.GetValue("Publisher");  
                                        [ref]$ParsedInstallDate = Get-Date
                                        If ([DateTime]::TryParseExact($SubKeyWow6432Node.GetValue("InstallDate"),"yyyyMMdd",$Null,[System.Globalization.DateTimeStyles]::None,$ParsedInstallDate)){                      
                                        $Entry.InstallDate = $ParsedInstallDate.Value
                                        }
                                        $Entry.EstimatedSize = [Math]::Round($SubKeyWow6432Node.GetValue("EstimatedSize")/1KB,1);
                                        $Entry.Version = $SubKeyWow6432Node.GetValue("DisplayVersion");
                                        $Entry.Wow6432Node = $True;
                                        [Void]$Results.Add($Entry);
                                        }
                                    }
                                }
                            }
                    }
                }
                $Results
                }    
            else
                {        
                Write-host -ForegroundColor Red "Connection failure with the computer" $Computers        
                }
        }
end {}      
}

echo $HERE
echo $THISPC
echo $OUTTIE

$a = "<style>"
$a = $a + "BODY{background-color:#E6E8FA;}"
$a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$a = $a + "TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:#236B8E}"
$a = $a + "TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:#C0C0C0}"
$a = $a + "</style>"
Write-Host "Initiating Software inventory" -ForegroundColor Yellow
#Get-Content Computers.txt | SoftwareInvent | Select-Object Computer, Software, Manufacture, Version | ConvertTo-HTML -head $a | Out-File $OUTTIE | Set-Content -Encoding UTF8  
get-content env:computername | SoftwareInvent | Select-Object Computer, Software, Manufacture, Version | ConvertTo-HTML -head $a | Out-File $OUTTIE | Set-Content -Encoding UTF8  
write-Host "Inventory successfully held" -ForegroundColor Yellow