
# Set up paths
$scriptDirectory = Split-Path $MyInvocation.MyCommand.Path
# Reference the SharpZipLib assembly here
Add-Type -Path (Join-Path $scriptDirectory ICSharpCode.SharpZipLib.dll)

## Zip-Files
##  zip up the contents of a directory to a zip file.
## Parameters : 
## 	$sourcePath     - directory / folder to compress
## 	$zipFilename    - filename of compressed contents
function Zip-Files([String]$sourcePath, [String]$zipFilename, [String]$extMatch="")
{
   $zip = New-Object ICSharpCode.SharpZipLib.Zip.FastZip
   $zip.CreateZip($zipFilename, $sourcePath, $true, $extMatch)
} 

## Unzip-Files
##  unzip the contents of a file to specified directory
## Parameters :
## 	 $zipFilename     - name of file to uncompress
##   $destinationPath - location to extract contents
function Unzip-Files([String]$zipFilename, [String]$destinationPath)
{ 
   $zip = New-Object ICSharpCode.SharpZipLib.Zip.FastZip
   $zip.ExtractZip($zipFilename, $destinationPath, $null)
} 

