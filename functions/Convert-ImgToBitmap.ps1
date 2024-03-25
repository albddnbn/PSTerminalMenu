Function Convert-ImgToBitmap {
    <#
    .SYNOPSIS
        Uses the Get-Image and Convert-ToBitmap functions from: https://github.com/dwj7738/PowershellModules/tree/master/PSImageTools to convert specified image to bitmap.
    
    .DESCRIPTION
        Get-Image: https://github.com/dwj7738/PowershellModules/blob/master/PSImageTools/Get-Image.ps1
        Convert-ToBitmap: https://github.com/dwj7738/PowershellModules/blob/master/PSImageTools/ConvertTo-Bitmap.ps1
    
    .EXAMPLE
        Convert-ImgToBitmap -ImagePath 'C:\Users\user\Downloads\image.jpg'
    
    .NOTES
        Author: albddnbn (Alex B.)
        Project Site: https://github.com/albddnbn/PSTerminalMenu
    #>

    param(
        [Parameter(Mandatory = $true)]
        [string]$ImagePath
    )
    function Get-Image {
        <#
        .Synopsis
            Gets information about images.
    
        .Description
            Get-Image gets an object that represents each image file. 
            The object has many properties and methods that you can use to edit images in Windows PowerShell. 
    
        .Notes
            Get-Image uses Wia.ImageFile, a Windows Image Acquisition COM object to get image data.
            Then it uses the Add-Member cmdlet to add note properties and script methods to the object. 
    
            The Resize script method uses the Add-ScaleFilter function. It has the following syntax:
            Resize ($width, $height, [switch]$DoNotPreserveAspectRation). 
            Width and Height can be specified in pixels or percentages. 
            For a description of these parameters, type "get-help Add-ScaleFilter –par *".
    
            The Crop script method uses the uses the Add-CropFilter function. It has the following syntax:
            Crop ([Double]$left, [Double]$top, [Double]$right, [Double]$bottom).
            All dimensions are measured in pixels.
            For a description of these parameters, type "get-help Add-CropFilter –par *".
    
            The FlipVertical, FlipHorizontal, RotateClockwise and RotateCounterClockwise script methods use the Add-RotateFlipFilter function.
            For a description of these parameters, type "get-help Add-RotateFlipFilter –par *".
    
        .Parameter File
            [Required] Specifies the image files. Enter the path and file name of an image file, such as $home\pictures\MyPhoto.jpg.
            You can also pipe one or more image files to Get-Image, such as those from Get-Item or Get-Childitem (dir). 
    
        .Example
            Get-Image –file C:\myPics\MyPhoto.jpg
    
        .Example
            Get-ChildItem $home\Pictures -Recurse | Get-Image        
    
        .Example
            (Get-Image –file C:\myPics\MyPhoto.jpg).resize(80, 120)
    
        .Example
            # Crops 8 pixels from the top of the image.
            $CatPhoto = Get-Image –file $home\Pictures\Cat.jpg
            $CatPhoto.crop(0,8,0,0)
    
        .Example
            $CatPhoto = Get-Image –file $home\Pictures\Cat.jpg
            $CatPhoto.flipvertical()
    
        .Example
            dir $home\pictures\Vacation*.jpg | get-image | format-table fullname, horizontalResolution, PixelDepth –autosize
    
        .Link
            "Image Manipulation in PowerShell": http://blogs.msdn.com/powershell/archive/2009/03/31/image-manipulation-in-powershell.aspx
        .Link
            Add-CropFilter
        .Link
            Add-ScaleFilter
        .Link
            Add-RotateFlipFilter
        .Link
            Get-ImageProperties
        #>
        param(    
            [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
            [Alias('FullName')]
            [string]$file)
        
        process {
            $realItem = Get-Item $file -ErrorAction SilentlyContinue     
            if (-not $realItem) { return }
            $image = New-Object -ComObject Wia.ImageFile        
            try {        
                $image.LoadFile($realItem.FullName)
                $image | 
                Add-Member NoteProperty FullName $realItem.FullName -PassThru | 
                Add-Member ScriptMethod Resize {
                    param($width, $height, [switch]$DoNotPreserveAspectRatio)                    
                    $image = New-Object -ComObject Wia.ImageFile
                    $image.LoadFile($this.FullName)
                    $filter = Add-ScaleFilter @psBoundParameters -passThru -image $image
                    $image = $image | Set-ImageFilter -filter $filter -passThru
                    Remove-Item $this.Fullname
                    $image.SaveFile($this.FullName)                    
                } -PassThru | 
                Add-Member ScriptMethod Crop {
                    param([Double]$left, [Double]$top, [Double]$right, [Double]$bottom)
                    $image = New-Object -ComObject Wia.ImageFile
                    $image.LoadFile($this.FullName)
                    $filter = Add-CropFilter @psBoundParameters -passThru -image $image
                    $image = $image | Set-ImageFilter -filter $filter -passThru
                    Remove-Item $this.Fullname
                    $image.SaveFile($this.FullName)                    
                } -PassThru | 
                Add-Member ScriptMethod FlipVertical {
                    $image = New-Object -ComObject Wia.ImageFile
                    $image.LoadFile($this.FullName)
                    $filter = Add-RotateFlipFilter -flipVertical -passThru 
                    $image = $image | Set-ImageFilter -filter $filter -passThru
                    Remove-Item $this.Fullname
                    $image.SaveFile($this.FullName)                    
                } -PassThru | 
                Add-Member ScriptMethod FlipHorizontal {
                    $image = New-Object -ComObject Wia.ImageFile
                    $image.LoadFile($this.FullName)
                    $filter = Add-RotateFlipFilter -flipHorizontal -passThru 
                    $image = $image | Set-ImageFilter -filter $filter -passThru
                    Remove-Item $this.Fullname
                    $image.SaveFile($this.FullName)                    
                } -PassThru |
                Add-Member ScriptMethod RotateClockwise {
                    $image = New-Object -ComObject Wia.ImageFile
                    $image.LoadFile($this.FullName)
                    $filter = Add-RotateFlipFilter -angle 90 -passThru 
                    $image = $image | Set-ImageFilter -filter $filter -passThru
                    Remove-Item $this.Fullname
                    $image.SaveFile($this.FullName)                    
                } -PassThru |
                Add-Member ScriptMethod RotateCounterClockwise {
                    $image = New-Object -ComObject Wia.ImageFile
                    $image.LoadFile($this.FullName)
                    $filter = Add-RotateFlipFilter -angle 270 -passThru 
                    $image = $image | Set-ImageFilter -filter $filter -passThru
                    Remove-Item $this.Fullname
                    $image.SaveFile($this.FullName)                    
                } -PassThru 
                    
            }
            catch {
                Write-Verbose $_
            }
        }    
    }
    function ConvertTo-Bitmap {
        <#
        .Synopsis
        Converts an image to a bitmap (.bmp) file.
    
        .Description
        The ConvertTo-Bitmap function converts image files to .bmp file format.
        You can specify the desired image quality on a scale of 1 to 100.
    
        ConvertTo-Bitmap takes only COM-based image objects of the type that Get-Image returns.
        To use this function, use the Get-Image function to create image objects for the image files, 
        then submit the image objects to ConvertTo-Bitmap.
    
        The converted files have the same name and location as the original files but with a .bmp file name extension. 
        If a file with the same name already exists in the location, ConvertTo-Bitmap declares an error. 
    
        .Parameter Image
        Specifies the image objects to convert.
        The objects must be of the type that the Get-Image function returns.
        Enter a variable that contains the image objects or a command that gets the image objects, such as a Get-Image command.
        This parameter is optional, but if you do not include it, ConvertTo-Bitmap has no effect.
    
        .Parameter Quality
        A number from 1 to 100 that indicates the desired quality of the .bmp file.
        The default is 100, which represents the best possible quality.
    
        .Parameter HideProgress
        Hides the progress bar.
    
        .Parameter Remove
        Deletes the original file. By default, both the original file and new .bmp file are saved. 
    
        .Notes
        ConvertTo-Bitmap uses the Windows Image Acquisition (WIA) Layer to convert files.
    
        .Link
        "Image Manipulation in PowerShell": http://blogs.msdn.com/powershell/archive/2009/03/31/image-manipulation-in-powershell.aspx
    
        .Link
        "ImageProcess object": http://msdn.microsoft.com/en-us/library/ms630507(VS.85).aspx
    
        .Link 
        Get-Image
    
        .Link
        ConvertTo-JPEG
    
        .Example
        Get-Image .\MyPhoto.png | ConvertTo-Bitmap
    
        .Example
        # Deletes the original BMP files.
        dir .\*.jpg | get-image | ConvertTo-Bitmap –quality 100 –remove -hideProgress
    
        .Example
        $photos = dir $home\Pictures\Vacation\* -recurse –include *.jpg, *.png, *.gif
        $photos | get-image | ConvertTo-Bitmap
        #>
        param(
            [Parameter(ValueFromPipeline = $true)]    
            $Image,
        
            [ValidateRange(1, 100)]
            [int]$Quality = 100,
        
            [switch]$HideProgress,
        
            [switch]$Remove
        )
        process {
            if (-not $image.Loadfile -and 
                -not $image.Fullname) { return }
            $realItem = Get-Item -ErrorAction SilentlyContinue $image.FullName
            if (-not $realItem) { return }
            if (".bmp" -ne $realItem.Extension) {
                $noExtension = $realItem.FullName.Substring(0, 
                    $realItem.FullName.Length - $realItem.Extension.Length)
                $process = New-Object -ComObject Wia.ImageProcess
                $convertFilter = $process.FilterInfos.Item("Convert").FilterId
                $process.Filters.Add($convertFilter)
                $process.Filters.Item(1).Properties.Item("Quality") = $quality
                $process.Filters.Item(1).Properties.Item("FormatID") = "{B96B3CAB-0728-11D3-9D7B-0000F81EF32E}"
                $newImg = $process.Apply($image.PSObject.BaseObject)
                $newImg.SaveFile("$noExtension.bmp")
                if (-not $hideProgress) {
                    Write-Progress "Converting Image" $realItem.Fullname
                }
                if ($remove) {
                    $realItem | Remove-Item
                }
            }
        
        }
    }

    if (Test-Path $ImagePath -ErrorAction SilentlyContinue) {

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Successfully tested path at $ImagePath, attempting to convert to bitmap."

        Get-Image $ImagePath | ConvertTo-Bitmap

    }
    else {
            
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] :: Path at $ImagePath does not exist, please check the path and try again." -ForegroundColor Red
    }

}