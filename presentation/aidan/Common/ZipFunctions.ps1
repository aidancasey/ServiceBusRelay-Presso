# REQUIRES -version 2.0

<#
################################################################################################
	.SYNOPSIS
	    Library of compression functions to be used by other routines
	.NOTES
	    Author: DevOps
	    Date:   26/09/2012
		Originally - this used the SharpZipLib assembly, however this was found to be fragile during re-creating the scripts in machine instances
################################################################################################
#>

# Set up paths
$local:scriptCommonDirectory = Split-Path $MyInvocation.MyCommand.Path
$script:zipToolPath = (join-Path $local:scriptCommonDirectory "7za.exe" )






<#
	.SYNOPSIS
	    zip up a directory path to a zip file
	.NOTES
	    Author: Mark Nelson
	    Date:   24/09/2012
#>
function Zip-Files(
	[Parameter(Mandatory=$true)] [string] # name of path to compress. Can contain wildcards (eg *.TXT).
	$sourcePath		
	, [Parameter(Mandatory=$true)][string]  # filename to compress to. 
	$zipFilePathName
)
{
	Try
	{
		Write-Host "$script:zipToolPath a $zipFileName $sourcePath"
		Invoke-Expression "$script:zipToolPath a $zipFilePathName $sourcePath"
	}
	Catch
	{
		Write-Host $_.Exception.Message
		break
	}
	
}
##export-modulemember -function Zip-Files

<#
.SYNOPSIS
    Unpack a zip file.
	
.NOTES
    Author: Prasad Saka
    Date:   21/09/2012
#>
function Unzip-Files
{
	param 
	(
		  [Parameter(Mandatory=$true)] [string] # Name of file to uncompress (including the zip file name).
		  $filePath		
		, [Parameter(Mandatory=$true)] [string] # Location to unpack the files to.
		  $extractPath	
	)
	Try
	{
		Invoke-Expression "$script:zipToolPath x -o$extractPath $filePath" | Out-Null
	}
	Catch 
	{
		Write-Host $_.Exception.Message
		break
	}
	
}
##export-modulemember -function Unzip-Files
