param(
    [Parameter()]
    [string]$ComputerList,
    [Parameter()]
    [string]$RoomName,
    [Parameter()]
    [string]$Master_Computer
)
# if computerlist txt file is provided (hostname on each line), don't need to check for anything else
if ($PSBoundParameters.ContainsKey('ComputerList')) {
    $Computers = Get-Content $ComputerList
}
else {
    if ($PSBoundParameters.ContainsKey('RoomName')) {
        $Computers = Get-ADComputer -Filter { Name -like "$RoomName*" } | Select-Object -ExpandProperty Name
    }
    else {
        $RoomName = Read-Host "Enter the room name (ex: s-a220)"
        try {
            $Computers = Get-ADComputer -Filter { Name -like "$RoomName*" } | Select-Object -ExpandProperty Name
        }
        catch {
            Write-Host "Room not found. Exiting."
            exit
        }
    }
}

if (-not ($PSBoundParameters.ContainsKey('Master_Computer'))) {
    $Master_Computer = $Computers | Where-Object { $_.Name -like "*01" } | Select -Exp Name
}

# copy the ps app deployment folders over to temp dir
Copy-Item -Path "." -Destination "\\$Master_Computer\c$\temp\" -Recurse -Force

Start-Sleep 2
# --------------------------------------------------------------------------------------------------
# ANTHONY Hamilton's script to configure all of the student PCs as servants of the master/teacher PC
Copy-Item -Path "VeyonAddComputers.ps1" -Destination "\\$Master_Computer\c$\temp\Veyon\" -Force

Start-Sleep 5

Invoke-Command -ComputerName $Master_Computer -ScriptBlock {
    Get-ChildItem "C:\TEMP\Veyon\" -Recurse | Unblock-File
    Set-Location "C:\TEMP\Veyon"
    # . .\Deploy-Veyon.ps1
    # . .\VeyonAddComputers.ps1
    # install veyon master
    Powershell.exe -ExecutionPolicy Bypass .\Deploy-Veyon.ps1 -DeploymentType "Install" -DeployMode "Silent" -InstallationType "Teacher"
}

# THEN - install student on all of the classroom pcs
$Student_Computers = $Computers | Where-Object { $_ -notlike "$Master_Computer*" }

# if dtcc.edu isn't in the student computer - add it
# ForEach ($Student_PC in $Student_Computers) {
#     if (-not ($Student_PC.endswith(".dtcc.edu"))) {
#         $Student_Computers[$($Student_Computers.IndexOf($Student_PC))] = "$Student_PC.dtcc.edu"
#     }
# }


ForEach ($Student_PC in $Student_Computers) {

    if (-not ($Student_PC.endswith(".dtcc.edu"))) {
        $Student_PC = "$Student_PC.dtcc.edu"
    }

    Copy-Item -Path "." -Destination "\\$Student_PC\c$\temp\" -Recurse -Force
	write-host "Veyon folder copied to $student_pc"
}

Invoke-Command -ComputerName $Student_PC -ScriptBlock {
	Set-Location "C:\TEMP\Veyon"

	Get-ChildItem ./* -Recurse | Unblock-File
	# . .\Deploy-Veyon.ps1
	# install veyon student

	Powershell.exe -ExecutionPolicy Bypass .\Deploy-Veyon.ps1 -DeploymentType "Install" -DeployMode "Silent" -InstallationType "Student"
}

# remove the temp folder
try {
	Remove-Item -Path "\\$Student_PC\c$\temp\Veyon" -Recurse -Force
}
catch {
	Write-Host "Could not remove temp folder on $Student_PC"
}
# Remove-Item -Path "\\$Student_PC\c$\temp\Veyon" -Recurse -Force
$RoomName = $Master_Computer.Substring(0, $Master_Computer.IndexOf("-", $Master_Computer.IndexOf("-") + 1))
$Computer_count = $Computers.Count

# create the string to add into the script
$scriptstring = @"
`$Student_Computers = @('$($Student_Computers -join "','")')
`$Master_Computer = `'$Master_Computer`'
`$RoomName = `'$RoomName`'
`$veyon = "C:\Program Files\Veyon\veyon-cli"
&`$veyon networkobjects add location `$RoomName
ForEach(`$pc in `$Student_Computers) {		
		`$suffix = "dtcc.edu"

		
		
		`$single = `$pc

		Write-Host "adding a single workstation `$single "

		If ( Test-Connection -BufferSize 32 -Count 1 -ComputerName `$single -Quiet ) {

			Start-Sleep -m 300

			`$IPAddress = ([System.Net.Dns]::GetHostByName(`$single).AddressList[0]).IpAddressToString

			`$MACAddress = Get-WmiObject -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled='True'" -ComputerName `$single | where { `$_.Description -ne "Hyper-V Virtual Ethernet Adapter" } | Select-Object -Expand MACAddress

			echo " `$veyon networkobjects add computer `$single `$IPAddress `$MACAddress `$room "

			&`$veyon networkobjects add computer `$single `$IPAddress `$MACAddress `$RoomName
		}
}
"@
# create the script that needs to be run on the master computer while RDP'd in (invoke-command is generating errors)
$scriptfilename = "RDPThenRunOn-$Master_Computer.ps1"
New-Item -Path $scriptfilename -ItemType "file" -Value $scriptstring -Force

Copy-Item -Path $scriptfilename -Destination \\$Master_Computer\c$\users\public\


Write-Host "Please run $scriptfilename on $Master_Computer to create the room list of PCs you can view." -ForegroundColor Green
Write-Host ""
Write-Host "The script should be located at C:\Users\Public\$scriptfilename."

# test connectivity to all pcs, output list of ones that need config reapplied
# ForEach ($PC in $Computers) {
#     $Test = Test-Connection -ComputerName $PC -Count 1 -Quiet
#     If ($Test -eq $false) {
#         Write-Host "$PC is offline" -ForeGroundColor Red
#         Write-Host "-------------------------------------"
#         Write-Host "Please turn the PC on and then run this command on the instructor/master PC: "
#         Write-Host "C:\Program Files\Veyon\veyon-cli networkobjects add computer <workstation> <ip> <mac> <room>" -ForegroundColor Yellow
#         Write-Host ""
#     }
# }


