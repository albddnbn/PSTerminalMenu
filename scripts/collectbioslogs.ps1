param(
    $targetComputer
)

$results = Invoke-Command -ComputerName $targetcomputer -scriptblock {
    $bioslog = Get-ChildItem -Path 'C:\' -filter 'biosupdatelog.txt' -file -erroraction SilentlyContinue
    $bioslog2 = Get-ChildItem -Path 'C:\Temp' -filter 'biosupdatelog.txt' -file -erroraction SilentlyContinue


    if ($bioslog) {
        $bioslog = Get-Content -Path $bioslog.fullname
    }
    if ($bioslog2) {
        $bioslog2 = Get-Content -Path $bioslog2.fullname
    }

    $obj = [pscustomobject]@{
        # ComputerName = $env:COMPUTERNAME
        BiosLog  = $bioslog
        BiosLog2 = $bioslog2
    }
    $obj
} | Select-object * -excludeproperty psshowcomputername, runspaceid

# get unique bios logs:
$unique_bioslogs = $results | Select-Object -ExpandProperty BiosLog -Unique
$unique_bioslogs2 = $results | Select-Object -ExpandProperty BiosLog2 -Unique

$unique_bioslogs | Out-File -FilePath "D:\uniquebioslogs\bioslog.txt"
$unique_bioslogs2 | Out-File -FilePath "D:\uniquebioslogs\bioslog2.txt"
# $iter = 0
# ForEach ($logcontent in $unique_bioslogs) {
#     $logcontent | Out-File -FilePath "D:\uniquebioslogs\bioslog-$iter.txt"
#     $iter += 1
# }

# $iter = 0
# ForEach ($logcontent in $unique_bioslogs2) {
#     $logcontent | Out-File -FilePath "D:\uniquebioslogs\bioslog2-$iter.txt"
#     $iter += 1
# }