Function IsDLLFree {
    param(
        [Parameter(Mandatory = $false)]
        [string]$DllToCheckForLock
    )
    # ifd the dll to check argument wasn't proivided
    if (!($PSBoundParameters.ContainsKey('DllToCheckForLock'))) {
        # get the dll to check for lock from the user
        $DllToCheckForLock = Read-Host "Please enter the absolute path/filename to the DLL."
    }

    # The list of DLLs to check for locks by running processes.
    # $DllsToCheckForLocks = "\\s-a228-03\C$\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate\2.2.0.3\PSWindowsUpdate.dll";

    # Assume true, then check all process dependencies
    $result = $true;

    # Iterate through each process and check module dependencies
    foreach ($p in Get-Process) {
        # Iterate through each dll used in a given process
        foreach ($m in Get-Process -Name $p.ProcessName -Module -ErrorAction SilentlyContinue) {
            # Check if dll dependency matches any DLLs in list
            foreach ($dll in $DllToCheckForLock) {
                # Compare the fully-qualified file paths, 
                # if there's a match then a lock exists.
                if ( ($m.FileName.CompareTo($dll) -eq 0) ) {
                    $pName = $p.ProcessName.ToString()
                    Write-Error "$dll is locked by $pName. Stop this service to release this lock on $m1."
                    $result = $false; 
                }
            }
        }
    }

    return $result;
}