$ModulePathToFind = Read-Host "Enter absolute path to .dll"   
$KillIt           = $false

foreach ($p in Get-Process)
{
    foreach ($m in $p.modules)
    {
        if ( $m.FileName -match $ModulePathToFind)
        {
            write-host "Found:" $m.FileName "in" $p.Name "ID:" $p.id

            if ($KillIt)
            {
                write-host "In 'Kill' mode."
                Stop-Process -Id $p.id -Force
            }
            else
            {
                write-host "Not in 'Kill' mode."
            }
        }
    }
}