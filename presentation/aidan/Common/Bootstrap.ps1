## Set up an AWS connection
## Use $local: to force use of local variable and avoid issues if a global variable have the same name
param([string]$bucketName, [string]$localPath)

## Set up paths
$scriptDirectory = Split-Path $MyInvocation.MyCommand.Path
## this is the default location if the AWS SDK has been installed
$awsSdkLib = "C:\Program Files (x86)\AWS SDK for .NET\bin\AWSSDK.dll"
if (Test-Path $awsSdkLib)
{
	Add-Type -Path $awsSdkLib
}
else
{
	Add-Type -Path (Join-Path $scriptDirectory AWSSDK.dll)
}

$log = Join-Path $scriptDirectory -ChildPath 'bootstrap.log'
$message = Get-Date -Format u
Add-Content $log -value "BootStrap Start - $message"
if ([string]::IsNullOrEmpty($localPath))
{
	$localPath = "C:\Tools"
}

## Get-FileFromS3
##  function to download a file from S3 bucket and save to local file location
## Parameters : 
##  $s3Client          - S3 Client
##  $bucketName        - name of the S3 bucket (including folder)
##  $keyName           - name of file to download
##  $destinationFolder - absolute location of the location to store downloaded file
function Get-FileFromS3($s3Client, [string] $s3BucketName, [string] $keyName, [string] $destinationFolder)
{
	if ( ($local:s3Client -eq $null) -or ($local:s3Client -isnot [Amazon.S3.AmazonS3Client]) )
	{
		Write-Error "Error : Null or Invalid Client; Expecting Amazon.S3.AmazonS3Client but received $local:s3Client"
		return
	}
	
	## if $local:s3BucketName is null or blank
	if ([String]::IsNullOrEmpty( $local:s3BucketName))
	{
		Write-Error "S3 Bucket Name cannot be null or empty"
		return
	}
	if ([String]::IsNullOrEmpty($local:keyName ))
	{
		Write-Error "Key Name cannot be null or empty"
		return
	}	
	
	$destinationLocation = Join-Path -Path $destinationFolder -ChildPath $keyName
	
	## Check that the destination exists, create otherwise
	if (!(Test-Path $destinationFolder))
	{
		New-Item $destinationFolder -ItemType Directory
	}

	$getObjectRequest = New-Object -TypeName Amazon.S3.Model.GetObjectRequest
	[void]$getObjectRequest.WithBucketName($local:s3BucketName)
	[void]$getObjectRequest.WithKey($local:keyName)

	$response = $client.GetObject($getObjectRequest)
	$response.WriteResponseStreamToFile($destinationLocation)
}

## Get a list of all objects in the specified S3 Bucket
if ([String]::IsNullOrEmpty( $local:bucketName))
{
	Add-Content $log -value "S3 Bucket Name cannot be null or empty"
	return
}

## Create S3 Client
try
{
	$client = [Amazon.AWSClientFactory]::CreateAmazonS3Client()
}
Catch
{
	Write-Error $_
	Add-Content $log -value $_
	return
}

## creating List Object Request
Add-Content $log -value "Creating List Object Request"
$listObjectsRequest = New-Object -TypeName Amazon.S3.Model.ListObjectsRequest
$listObjectsRequest.WithBucketName($bucketName);
try
{
	$listObjectResponse = $client.ListObjects($listObjectsRequest)
	Add-Content $log -value "Downloading ..."
	foreach( $s3Object in $listObjectResponse.S3Objects)
	{		
		## download if the size is > 0, i.e. is a file not a folder		
		if ($s3Object.Size -gt 0)
		{	
			Add-Content $log -value $s3Object.Key
			Get-FileFromS3 $client $bucketName $s3Object.Key $localPath
		}
	}
}
catch [Amazon.S3.AmazonS3Exception]
{	
	Write-Error $_
	Add-Content $log -value $_
}
finally
{
	$client.Dispose()
}
$message = Get-Date -Format u
Add-Content $log -value "Bootstrap Completed - $message"
