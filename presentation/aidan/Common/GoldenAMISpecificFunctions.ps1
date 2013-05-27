
# Set up paths
$private:scriptDirectory = Split-Path $MyInvocation.MyCommand.Path
$private:scriptCleanupDirectory = Join-Path -Path (Split-Path -parent $private:scriptDirectory) -ChildPath "Cleanup"

. (Join-Path $private:scriptDirectory AwsCommonFunctions.ps1)
. (Join-Path -Path $private:scriptCleanupDirectory -ChildPath "AddAMIsMasterXML.ps1")


function Transfer-FileFromS3
{
	param (
		[String] 
			$filename = "C:\Deploy\userdata.log"
		)
	$result = "Function X32file (`$s3Bucket,`$s3File,`$outputFile)
	{
		`$s3client = [Amazon.AWSClientFactory]::CreateAmazonS3Client() ;
		`$getObjectRequest = New-Object -TypeName Amazon.S3.Model.GetObjectRequest -Property @{
			BucketName = `$s3Bucket ;
			Key = `$s3File ;
		}
		Remove-Item -Force -path `$outputFile;
		`$response = `$s3client.GetObject(`$getObjectRequest);
		`$response.WriteResponseStreamToFile(`$outputFile);
		`$s3client.dispose | out-null;
		Write-Output `$('Tranferred ',`$s3Bucket,':',`$s3File,' -> ',`$outputFile);
	}
	"
	return $result
}

<#
		.SYNOPSIS
			Prepares user data, specific to account type

		.DESCRIPTION
			A detailed description of the function.

		.PARAMETER  Name
			The description of the ParameterA parameter.
		
		.INPUTS
			AWSAccountType	

		.OUTPUTS
			System.String

		.NOTES
			Additional information about the function go here.

	#>	
function Get-Userdata {	
	[OutputType([System.string])]
	param(
		[Parameter(Position=0, Mandatory=$true)]		
		[AWSAccountType]
		$accountType
		,[string]
		$masterFile
		,[string]
		$product
		,[string]
		$site
		,[string]
		$s3BucketName
		,[string]
		$s3LogFolderName
		,[string]
		$filePathList
		,[string]
		$initStatement
		,[string]
		$buildVersion
		, [string]
		$cloudwatchConfigFilePath
	)
	try {
	
		$copyFileFroms3 = Transfer-FileFromS3
		$userdataFunction = Log-UserdataFunction
		
		switch ($accountType)
		{
		
		"Dev"
			{
			return	Get-UserdataFromDev -masterFile $masterFile -product $product -site $site -s3BucketName $s3BucketName -s3LogFolderName $s3LogFolderName `
				-filePathList $filePathList -initStatement $initStatement -buildVersion $buildVersion 		
			}
		"PreProd"
			{
			return	Get-UserdataFromPreProd -s3BucketName $s3BucketName -s3LogFolderName $s3LogFolderName -cloudwatchConfigFilePath $cloudwatchConfigFilePath				
			}
		"Production"
			{
			return	Get-UserdataFromProd -s3BucketName $s3BucketName -s3LogFolderName $s3LogFolderName -cloudwatchConfigFilePath $cloudwatchConfigFilePath				
			}
		}
		
	}
	catch {
		throw
	}
}

<#
		.SYNOPSIS
			Prepares user data, for dev account AMI

		.DESCRIPTION
			A detailed description of the function.

		.PARAMETER  Name
			The description of the ParameterA parameter.
		
		.INPUTS
			AWSAccountType	

		.OUTPUTS
			System.String

		.NOTES
			Additional information about the function go here.

	#>
function Get-UserdataFromDev {		
	[OutputType([System.string])]
	param(
		[Parameter(Position=0, Mandatory=$true)]		
		[string]
		$masterFile
		, [Parameter(Position=1, Mandatory=$true)]		
		[string]
		$product
		, [Parameter(Position=2, Mandatory=$true)]		
		[string]
		$site
		, [Parameter(Position=3, Mandatory=$true)]		
		[string]
		$s3BucketName
		, [Parameter(Position=4, Mandatory=$true)]		
		[string]
		$s3LogFolderName
		, [Parameter(Position=5, Mandatory=$true)]		
		[string]
		$filePathList
		, [Parameter(Position=6, Mandatory=$true)]		
		[string]
		$initStatement
		, [Parameter(Position=7, Mandatory=$true)]		
		[string]
		$buildVersion
	)
	try {
	
		$currentOnlineVersionDetails = Find-XMLFileToAddAMI -productName $product -masterFile $masterFile
		
		$filepath = Split-Path $masterFile
		
		#prepare multiple version web app 	
		$initInput = [string]::Format("{0}={1}", $currentOnlineVersionDetails.onlineVersion, $buildVersion)#	V2=5.4.0.561"
		
		$xmldata = [xml]((Get-Content $masterFile))
		
		$productDetails = $xmldata.goldenami.product | Where-Object { $_.name -eq "$product" }
		
		$otherRunningVersions = $productDetails.onlineversion | Where-Object { $_.version -ne $currentOnlineVersionDetails.onlineVersion -and $_.onlineversionstatus -ne [OnlineVersionStatus]::deprecated}
		
		if (! (IsNullOrEmpty $otherRunningVersions))
		{
		
			$otherRunningVersions | foreach { 
				$versionFile = Join-Path $filepath $_.file
				$xmldata = [xml]((Get-Content $versionFile))
				$currentRunningVersion = $xmldata.goldenami.ami | where { $_.onlineversionstatus -eq [OnlineVersionStatus]::current -or  $_.onlineversionstatus -eq [OnlineVersionStatus]::live}
				$initInput = [string]::Format( "{0}{1}{2}={3}", 
												$initInput, 
												"`n", 
												$currentRunningVersion.onlineversion, 
												$currentRunningVersion.buildNumber) 
				}
			
		}
		
		$userData = "<powershell>
					Remove-Item -Force 'c:\Deploy' -include *.log
					C:\Deploy\Bootstrap.ps1 -bucketName '$s3BucketName' -filepathList @('$filePathList') | Out-File C:\Deploy\DownloadFiles.log
					C:\Deploy\ResetInstanceConfig.ps1 | Out-File C:\Deploy\DownloadFiles.log
					$initStatement -versionDetails `"$initInput`" | Out-File C:\Deploy\init.log
					C:\Tools\AssetsWeb\changewebsite.ps1 -websiteToUse $site | Out-File C:\Deploy\changewebsite.log
					C:\Deploy\TransferLogsToBucket.ps1 -s3BucketName '$s3BucketName' -s3Folder '$s3LogFolderName' -logFilePath 'C:\Deploy\'
					C:\Deploy\SetNewRelicLabel.ps1 -productName 'Assets' -version 'v1' -build $buildVersion | Out-File C:\Deploy\SetNewRelicLabel.log
					
					</powershell>"
	return $userData
		
	}
	catch {
		throw
	}
}

<#
		.SYNOPSIS
			Prepares user data, for dev account AMI

		.DESCRIPTION
			A detailed description of the function.

		.PARAMETER  Name
			The description of the ParameterA parameter.
		
		.INPUTS
			AWSAccountType	

		.OUTPUTS
			System.String

		.NOTES
			Additional information about the function go here.

	#>	
function Get-UserdataFromPreProd {	
	[OutputType([System.string])]
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[string]
		$s3BucketName 
		, [Parameter(Position=2, Mandatory=$true)]		
		[string]
		$s3LogFolderName 		
		, [Parameter(Position=3, Mandatory=$true)]		
		[string]
		$cloudwatchConfigFilePath
	)
	try {			
		
		$userData = "<powershell>
					Add-Type -Path C:\Tools\Common\AWSSDK.dll
					$userdataFunction
					LU 'Userdata Script started' -clearfile
					Remove-Item -Force 'c:\Deploy' -include *.log -exclude 'userdata.log'
					LU 'Transferring new authentication key'
					$copyFileFroms3
					X32file -s3Bucket '$s3BucketName' -s3File '$cloudwatchConfigFilePath' -outputFile 'c:\Deploy\ec2cloudwatch.conf' | LU
					LU 'Reset Instance'
					C:\Deploy\ResetInstanceConfig.ps1 | LU
					LU 'Final step - Transfer logs to bucket'
					C:\Deploy\TransferLogsToBucket.ps1 -s3BucketName '$s3BucketName' -s3Folder '$s3LogFolderName' -logFilePath 'C:\Deploy\'
					LU 'Userdata script completed'
					</powershell>"
	return $userData
		
	}
	catch {
		throw
	}
}

<#
		.SYNOPSIS
			Prepares user data, for dev account AMI

		.DESCRIPTION
			A detailed description of the function.

		.PARAMETER  Name
			The description of the ParameterA parameter.
		
		.INPUTS
			AWSAccountType	

		.OUTPUTS
			System.String

		.NOTES
			Additional information about the function go here.

	#>	
function Get-UserdataFromProd {	
	[OutputType([System.string])]
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[string]
		$s3BucketName 
		, [Parameter(Position=2, Mandatory=$true)]		
		[string]
		$s3LogFolderName 		
		, [Parameter(Position=3, Mandatory=$true)]		
		[string]
		$cloudwatchConfigFilePath
	)
	try {			
		
		$userData = "<powershell>
					Add-Type -Path C:\Tools\Common\AWSSDK.dll
					$userdataFunction
					LU 'Userdata Script started' -clearfile
					Remove-Item -Force 'c:\Deploy' -include *.log -exclude 'userdata.log'
					LU 'Transferring new authentication key'
					$copyFileFroms3
					X32file -s3Bucket '$s3BucketName' -s3File '$cloudwatchConfigFilePath' -outputFile 'c:\Deploy\ec2cloudwatch.conf' | LU
					LU 'Reset Instance'
					C:\Deploy\ResetInstanceConfig.ps1 | LU
					LU 'Final step - Transfer logs to bucket'
					C:\Deploy\TransferLogsToBucket.ps1 -s3BucketName '$s3BucketName' -s3Folder '$s3LogFolderName' -logFilePath 'C:\Deploy\'
					LU 'Userdata script completed'
					</powershell>"
	return $userData
		
	}
	catch {
		throw
	}
}


<#
		.SYNOPSIS
			Record (insert-update) ami detail to the correct versioned AMIList file		

	#>	
function Record-AMIDetailToAMIList {		
	param(
		[AWSAccountType]
		$accountType
		,[ValidateNotNullOrEmpty()]
		[System.String]
		$goldenImageId		
		,[ValidateNotNull()]
		[System.String]
		$imageName
		,[ValidateNotNull()]
		[System.String]
		$buildVersion
		,[ValidateNotNull()]
		[System.String]
		$onlineVersion
		,[ValidateNotNull()]
		[System.String]
		$productName
		,[ValidateNotNull()]
		[System.String]
		$amiListFilePath
		,[ValidateNotNull()]
		[System.String]
		$amiListFileName
		,[System.String]
		$copyPath
	)
	try {
	
		$amiStatus = "available"
		
		switch ($accountType)
		{		
			"Dev"
			{
				$onlineVersionStatus = [OnlineVersionStatus]::current.ToString()
			
				Add-AMIToList -ami_Id $goldenImageId -ami_Name $imageName -status $amiStatus -buildNumber $buildVersion -onlineVersion $onlineVersion -onlineVersionStatus $onlineVersionStatus -productName `
				$productName -filePath $amiListFilePath -fileName $amiListFileName
			}
			"PreProd"
			{
				$onlineVersionStatus = [OnlineVersionStatus]::keep.ToString()
			
				Add-AMIToList -ami_Id $goldenImageId -ami_Name $imageName -status $amiStatus -buildNumber $buildVersion -onlineVersion $onlineVersion -onlineVersionStatus $onlineVersionStatus -productName `
				$productName -filePath $amiListFilePath -fileName $amiListFileName
			}
			"Production"
			{
				$onlineVersionStatus = [OnlineVersionStatus]::live.ToString()
			
#				Add-AMIToList -ami_Id $goldenImageId -ami_Name $imageName -status $amiStatus -buildNumber $buildVersion -onlineVersion $onlineVersion -onlineVersionStatus $onlineVersionStatus -productName `
#				$productName -filePath $amiListFilePath -fileName $amiListFileName
				
				$private:scriptParentDirectory = Split-Path $commonScriptRunLocation
				$private:scriptTeamcityDirectory = Join-Path -Path ($scriptParentDirectory) -ChildPath "TeamCity"
				$private:scriptUpdateAMIFile = Join-Path -Path $private:scriptTeamcityDirectory -ChildPath "UpdateAMICurrentVersionAndLiveVersion.ps1"
				
				invoke-expression -Command "$private:scriptUpdateAMIFile -Version '$onlineVersion' -productName '$productName' -copyPath '$copyPath' -onlineVersionStatus '$onlineVersionStatus'"
			}
		}
	}
	catch {
		throw
	}
}


function Get-CurrentPath {
	return $MyInvocation.MyCommand.Path
}