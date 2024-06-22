<#
function that will run any of the dism install scripts instead of having them separated into different functions
the only different between them is the item that's being installed
#>
Function Install-DismItem {
    param (
        # [Parameter(Mandatory=$true)]
        # [ValidateSet("Hyper-V", "IIS", "RSAT", "WDS")]
        [string]$InstallItem
    )
    # check if they have PS-Menu module
    if (Get-Module -Name PS-Menu -ListAvailable) {
        # if they do, import it
        Import-Module PS-Menu -Force
    }
    else {
        # if they don't, install it
        Install-Module PS-Menu -Scope CurrentUser -Force
        # and import it
        Import-Module PS-Menu -Force
    }

    # array that holds all possible installation items
    $InstallItems = @{
        "notepad"     = "Microsoft.Windows.Notepad~~~~0.0.1.0";
        "WIN+SHIFT+S" = "Windows.Client.ShellComponents~~~~0.0.1.0"; 
        "rsat"        = "Rsat.activedirectory.DS-LDS.Tools~~~~0.0.1.0", "Rsat.GroupPolicy.Management.tools~~~~0.0.1.0", "rsat.wsus.tools~~~~0.0.1.0";
        "ISE"         = "microsoft.windows.powershell.ise~~~~0.0.1.0";
        "MS Paint"    = "Microsoft.Windows.MSPaint~~~~0.0.1.0";
        ".Net 3.5"    = "NetFx3";
    }
    # if the installitem paramtere is bound
    if ($InstallItem -eq "") {
        # ask the user
        Write-Host "What would you like to install?"
        $InstallItem = menu @($InstallItems.Keys)
    }
    elseif ($PSBoundParameters.ContainsKey('InstallItem')) {
        # switch statement to run the correct function
        if ($InstallItems.Keys -notcontains $InstallItem) {
            Write-Host "Invalid install item" -ForegroundColor Red
            Write-Host "Valid installation items include: "
            Write-Host $InstallItems
            # exit
            Exit
        }
    }
    else {
        # ask the user
        Write-Host "What would you like to install?"
        $InstallItem = menu $InstallItems.Keys

    }
    Set-Itemproperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'UseWUServer' -value '0'
    Restart-Service -Name 'wuauserv'

    $install_string = $InstallItems[$InstallItem]
    # check if install string is an array or arraylist
    if ($install_string -is [array] -or $install_string.GetType().Name -eq "ArrayList") {
        # if it is, loop through it
        foreach ($item in $install_string) {
            # and install each item
            DISM /online /Add-Capability /CapabilityName:$item
        }
    }
    elseif ($install_string -eq "NetFx3") {
        DISM /online /Enable-Feature /FeatureName:$install_string /All
    }
    else {
        # if it's not, install it
        DISM /online /Add-Capability /CapabilityName:$install_string
    }
    Set-Itemproperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'UseWUServer' -value '1'
    
    Restart-Service -Name 'wuauserv'
    Stop-Process -Name explorer -Force
    Start-Process explorer
}