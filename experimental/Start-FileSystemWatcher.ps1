function Start-FileSystemWatcher {
    <#
    .SYNOPSIS
        Uses a FileSystemWatcher object to monitor specified directory for newly created files.
        The $action variable in this function causes the watcher to attempt to open any newly created files, 
        AS SOON AS THEY ARE CREATED.

    .DESCRIPTION
        Uses a FileSystemWatcher object to monitor specified directory for newly created files.
        The $action variable in this function causes the watcher to attempt to open any newly created files, 
        AS SOON AS THEY ARE CREATED.

    .PARAMETER WatchedPath
        The path to the directory to be watched.

    .PARAMETER LogFile
        The path to the log file. If not specified, the default log file will be created at C:\temp\watcher.log.

    .EXAMPLE
        Start-FileSystemWatcher -WatchedPath 'C:\temp\completedjobs' -LogFile 'C:\users\public\watcher.log'
        This will start a watcher for the 'C:\temp\completedjobs' directory and log all events to 'C:\users\public\watcher.log'.

    .NOTES
        ---
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $WatchedPath,
        [Parameter(Mandatory = $false)]
        [string]
        $LogFile = 'C:\temp\watcher.log'
    )
    ## Make sure the logfile exists:
    if (-not (Test-Path $LogFile -ErrorAction SilentlyContinue)) {
        New-Item -Path $LogFile -ItemType File | Out-Null
    }
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Started filesystem watcher for: $WatchedPath." | Out-File -Append -FilePath $LogFile
    ## Configure filesystem watcher for completedjobs directory:
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $WatchedPath
    # $watcher.Filter = "*.txt"
    write-host $WatchedPath
    $watcher.EnableRaisingEvents = $true

    # watcher action
    $action = {
        $path = $Event.SourceEventArgs.FullPath

        ## This will output a statement about the file's creation to terminal
        $name = $Event.SourceEventArgs.Name
        $changeType = $Event.SourceEventArgs.ChangeType
        $timeStamp = $Event.TimeGenerated
        # Write-Host "File $name $changeType at $timeStamp"

        # output to logfile --> May not be able to access the variable inside these {}, we'll see
        "File $name $changeType at $timeStamp" | Out-File -Append -FilePath $LogFile
        Invoke-Item "$path"
    }

    Register-ObjectEvent $watcher 'Created' -Action $action
    
}