$appnames = get-content stanton-mdt-apps.txt
foreach ($name in $appnames) {
    # get rid of any spaces in the name
    $name = $name -replace ' ', ''
    # create a folder for the app using the name
    # copy-item ./default-stuff ./$name -recurse

    # delete everything inside the $name folder
    remove-item ./$name/* -recurse
}

