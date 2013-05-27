<#
	.SYNOPSIS
	    Add the AMI in XML file
		Keep backup of old values
		
	.NOTES
	    Author: Surya Prasad Saka 
	    Date:   15/11/2012
#>

$private:scriptDirectory = Split-Path $MyInvocation.MyCommand.Path
$private:scriptBuildAdminDirectory = Join-Path -Path (Split-Path -parent $private:scriptDirectory) -ChildPath "BuildAdmin"
. (Join-Path $private:scriptDirectory "SVNFunctions.ps1")

function Create-XML()
{
$xml = @'
<?xml version="1.0" encoding="utf-8"?>
<goldenami>
<product name="Assets">
    <currentversion>v1</currentversion>
</product>
<product name="Devops">
    <currentversion>v1</currentversion>
</product>
<ami>
<id>Ami Id</id>
<name>Ami Name</name>
<buildNumber>BuildNumber</buildNumber>
<status>Status</status>
<onlineversion>OnlineVersion</onlineversion>
<onlineversionstatus>OnlineVersionStatus</onlineversionstatus>
<product>Product</product>
</ami>
</goldenami>
'@

return $xml
}

function Add-AMI
	(
		[String]							# Golden AMI Id
			$ami_Id 
		, [String]							# Golden AMI Name
			$ami_Name
		, [String]							# Status of AMI
			$status
		, [String]							# Build number
			$buildNumber
		, [String]							# Online Version
			$onlineVersion
		, [String]							# Online Version Status
			$onlineVersionStatus
		, [String]							# Product name
			$productName
		, [String]							# Path where file exists
			$filePath
		, [String]							# File name to update the AMIs
			$fileName
	)
{	
	$file = Join-Path $filepath $fileName
	## Check that the destination exists, create otherwise
	if (!(Test-Path $filepath))
	{
		New-Item $filepath -ItemType Directory
	}
	else
	{
		if (!(Test-Path $file))
		{
			Create-XML | Out-File $file
			Svn-Functions "add" "$file" "Adding"
		}
	}

	## Load XML from file:	
	$xmldata = [xml]((Get-Content $file))
	## Getting current version of AMIs.
	$product = $xmldata.goldenami.product | Where-Object { $_.name -match $productName } 

	## If current version matches then only update earlier AMIs with onlineversionstatus = "superseeded".
	if($product.currentversion -match $onlineVersion)
	{
		$ami = $xmldata.goldenami.ami |
		Where-Object { $_.onlineVersionStatus -match "current" -and $_.onlineVersionStatus -notmatch "live" -and $_.onlineVersion -match $onlineVersion -and $_.product -match $productName}
		$ami.onlineVersionStatus = "superseeded"
	}
	
	$xmldata.goldenami.ami
	
	# Create new node:
	$newamiid = $local:xmldata.CreateElement("ami")
	$newamiid.set_InnerXML("<id>$ami_Id</id><name>$ami_Name</name><buildNumber>$buildNumber</buildNumber><status>$status</status><onlineversion>$onlineVersion</onlineversion><onlineversionstatus>$onlineVersionStatus</onlineversionstatus><product>$productName</product>")
	# Write nodes in XML:
	$local:xmldata.goldenami.AppendChild($newamiid)
	# Check result:
	$local:xmldata.goldenami.ami

	$local:xmldata.Save($file)
	
	#Tortoise SVN functions to commit and unlock the file.
	Svn-Functions "commit" "$file" "Commiting new file created"
}
