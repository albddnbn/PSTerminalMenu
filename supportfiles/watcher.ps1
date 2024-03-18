param(
    $watchedpath
)
Write-Host "Watching $watchedpath"
## Configure filesystem watcher for completedjobs directory:
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $watchedpath
# $watcher.Filter = "*.txt"
write-host $watchedpath
$watcher.EnableRaisingEvents = $true

# watcher action
$action = {
    $path = $Event.SourceEventArgs.FullPath
    $name = $Event.SourceEventArgs.Name
    $changeType = $Event.SourceEventArgs.ChangeType
    $timeStamp = $Event.TimeGenerated
    Write-Host "File $name $changeType at $timeStamp"
    # $watcher.EnableRaisingEvents = $false
    # $watcher.Dispose()
    # $watcher = $null
    Invoke-Item "$path"
}

Register-ObjectEvent $watcher 'Created' -Action $action
