## Set up an AWS connection
## Use $local: to force use of local variable and avoid issues if a global variable have the same name

# Set up paths
$scriptDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $scriptDirectory CommonFunctions.ps1)

Add-Type -Path (Join-Path $scriptDirectory AWSSDK.dll)

# Constants
$DefaultSleepInSeconds = 5
$DefaultNumberOfCallsBeforeTimeout = 48
$ExtendedNumberOfCallsBeforeTimeout = $DefaultNumberOfCallsBeforeTimeout * 2
$MaxLengthInBytes = 5*1024*1024
$RequestTimeoutInMilliseconds = 60*1000*3
$DefaultServerSideEncryptionMethod = [Amazon.S3.Model.ServerSideEncryptionMethod]::AES256
$DefaultS3StorageClass = [Amazon.S3.Model.S3StorageClass]::ReducedRedundancy
$DefaultMaxInstancesToStart = 1
$DefaultMinInstancesToStart = 1
$DefaultInstanceType = [Amazon.EC2.Model.InstanceType]::M1Small	## SQL instances need to be small by default.
$DefaultSecurityGroupId = "default"
$DefaultRegion = "us-west-2"

## parameters that can be utilised in AMI / Instance creation / if not set - supply defaults 
if (IsNullOrEmpty $local:team)			{ 	$team="Devops"	}
if (IsNullOrEmpty $local:Console)		{	$user="Console"	}
if (IsNullOrEmpty $local:projectName)	{	$projectName="Default"	}
if (IsNullOrEmpty $local:instanceLabel)	{	$instanceLabel="PD"	}
if (IsNullOrEmpty $local:buildVersion)	{	$buildVersion="0"	}

## InstanceName and AmiName layout
## Text will be literal apart from the following tags
##  {team}			- name of the team responsible (eg Devops / Assets)
##  {user}			- name of user 
##  {projectname}	- name of the project we are handling
##  {buildversion}	- version number to use
##  {label}			- a label to be incorporated into the name label
##  {datetime}		- current datetime stamp

$DefaultInstanceName="`{team}_GoldInterim_Build{buildversion}_{label}_{datetime}"
$DefaultAmiName="{team}_{projectname}_{label}_Build_{buildversion}_{datetime}"
$DefaultTeamName="{team}\{user}"
$DefaultAMIDescription="Nightly build {datetime}, {buildversion}"

<#
	.SYNOPSIS
	    Substitute named string tokens. 
	.DESCRIPTION
		Uses a pre-defined list of tokens:
			{datetime} 		- current datetime
			{team}			- $team variable
			{user}			- $user variable
			{projectname}	- $projectName
			{buildversion}	- $buildVersion
			{label}			- $instanceLabel
	.PARAMETER stringWithEmbeddedTokens
		String containing a set of pre-defined tokens.  
	.OUTPUTS
		string with token values
	.NOTES
	    Author: Mark Nelson
	    Date:   12/09/2012
#>
function Get-StringFromTokenizedString([String]	$stringWithEmbeddedTokens)
{
	[String]$dateTime = Get-Date -Format yyyyMMddhhmm
	$replaceParametersInString = $stringWithEmbeddedTokens.Replace("{datetime}", $dateTime)
	$replaceParametersInString = $replaceParametersInString.Replace("{team}", $team)
	$replaceParametersInString = $replaceParametersInString.Replace("{user}", $user)
	$replaceParametersInString = $replaceParametersInString.Replace("{projectname}", $projectName)
	$replaceParametersInString = $replaceParametersInString.Replace("{buildversion}", $buildVersion)
	$replaceParametersInString = $replaceParametersInString.Replace("{label}", $instanceLabel)
	return $replaceParametersInString
}




## New-S3Client
## Parameters
## 	$secretKeyID       - is the secret key
## 	$secretAccessKeyID - is the secret access key
function New-S3Client([String]$secretKeyID, [String]$secretAccessKeyID)
{
	Try
	{
		if ((IsNullOrEmpty $local:secretKeyID) -or (IsNullOrEmpty $local:secretAccessKeyID))
		{
			$local:client=[Amazon.AWSClientFactory]::CreateAmazonS3Client()
		}
		else
		{
			$local:client=[Amazon.AWSClientFactory]::CreateAmazonS3Client($local:secretKeyID,$local:secretAccessKeyID)
		}
	}
	Catch
	{
		Write-Error "Failed to create S3 client."
	}
	
	return $local:client
}

## New-Ec2Client
##  Create a new EC2 Client
## Parameters
## 	$secretKeyID       - is the secret key
## 	$secretAccessKeyID - is the secret access key
##  $region			   - is the geographical region used
function New-Ec2Client([String]$secretKeyID, [String]$secretAccessKeyID, [String]$region = $DefaultRegion)
{
	Try
	{
		$config = New-Object -TypeName Amazon.EC2.AmazonEC2Config
		$config.ServiceURL = Get-Ec2ServiceUrl $region
	
		if ((IsNullOrEmpty $local:secretKeyID) -or (IsNullOrEmpty $local:secretAccessKeyID))
		{
			$ec2Client=[Amazon.AWSClientFactory]::CreateAmazonEC2Client($config)
		}
		else
		{
			$ec2Client=[Amazon.AWSClientFactory]::CreateAmazonEC2Client($local:secretKeyID, $local:secretAccessKeyID, $config)
		}
	}
	Catch
	{
		Write-Error "Failed to create EC2 client."
	}
	return $ec2Client
}

## New-CloudFormationClient
##  create a new Cloud Formation Client
## Parameters
## 	$secretKeyID       - is the secret key
## 	$secretAccessKeyID - is the secret access key
##  $region			   - is the geographical region used
function New-CloudFormationClient([String]$secretKeyID, [String]$secretAccessKeyID, [String]$region = $DefaultRegion)
{
	Try
	{
		$config = New-Object -TypeName Amazon.CloudFormation.AmazonCloudFormationConfig
		$config.ServiceURL = Get-CloudFormationServiceUrl $region
	
		if ((IsNullOrEmpty $local:secretKeyID) -or (IsNullOrEmpty $local:secretAccessKeyID))
		{
			$cfClient=[Amazon.AWSClientFactory]::CreateAmazonCloudFormationClient($config)
		}
		else
		{
			$cfClient=[Amazon.AWSClientFactory]::CreateAmazonCloudFormationClient($local:secretKeyID, $local:secretAccessKeyID, $config)
		}
	}
	Catch
	{
		Write-Error "Failed to create Cloud Formation client."
	}
	return $cfClient
}

## New-SnsClient
##  create a new Simple News Service Client
## Parameters
## 	$secretKeyID       - is the secret key
## 	$secretAccessKeyID - is the secret access key
##  $region			   - is the geographical region used
function New-SnsClient([String]$secretKeyID, [String]$secretAccessKeyID, [String]$region = $DefaultRegion)
{
	$config = New-Object -TypeName Amazon.SimpleNotificationService.AmazonSimpleNotificationServiceConfig
	$config.ServiceURL = Get-SnsServiceUrl $region
	
	if ((IsNullOrEmpty $local:secretKeyID) -or (IsNullOrEmpty $local:secretAccessKeyID))
	{
		$snsClient=[Amazon.AWSClientFactory]::CreateAmazonSNSClient($config)
	}
	else
	{
		$snsClient=[Amazon.AWSClientFactory]::CreateAmazonSNSClient($local:secretKeyID, $local:secretAccessKeyID, $config)
	}
	
	return $snsClient
}

## New-SqsClient
##  create a new Simple Query Service Client
## Parameters
## 	$secretKeyID       - is the secret key
## 	$secretAccessKeyID - is the secret access key
##  $region			   - is the geographical region used
function New-SqsClient([String]$secretKeyID, [String]$secretAccessKeyID, [String]$region = $DefaultRegion)
{
	$config = New-Object -TypeName Amazon.SQS.AmazonSQSConfig
	$config.ServiceURL = Get-SqsServiceUrl $region
	
	if ((IsNullOrEmpty $local:secretKeyID) -or (IsNullOrEmpty $local:secretAccessKeyID))
	{
		$sqsClient=[Amazon.AWSClientFactory]::CreateAmazonSQSClient($config)
	}
	else
	{
		$sqsClient=[Amazon.AWSClientFactory]::CreateAmazonSQSClient($local:secretKeyID, $local:secretAccessKeyID, $config)
	}
	
	return $sqsClient
}

## New-RdsClient
##  create a new Relational Database Service Client
## Parameters
## 	$secretKeyID       - is the secret key
## 	$secretAccessKeyID - is the secret access key
##  $region			   - is the geographical region used
function New-RdsClient([String]$secretKeyID, [String]$secretAccessKeyID, [String]$region = $DefaultRegion)
{
	$config = New-Object -TypeName Amazon.RDS.AmazonRDSConfig
	$config.ServiceURL = Get-RelationalDatabaseServiceUrl $region
	
	if ((IsNullOrEmpty $local:secretKeyID) -or (IsNullOrEmpty $local:secretAccessKeyID))
	{
		$rdsClient=[Amazon.AWSClientFactory]::CreateAmazonRDSClient($config)
	}
	else
	{
		$rdsClient=[Amazon.AWSClientFactory]::CreateAmazonRDSClient($local:secretKeyID, $local:secretAccessKeyID, $config)
	}
	
	return $rdsClient
}

## New-ElbClient
##  create a new Elastic Load Balancer Client
## Parameters
## 	$secretKeyID       - is the secret key
## 	$secretAccessKeyID - is the secret access key
##  $region			   - is the geographical region used
function New-ElbClient([String]$secretKeyID, [String]$secretAccessKeyID, [String]$region = $DefaultRegion)
{
	$config = New-Object -TypeName Amazon.ElasticLoadBalancing.AmazonElasticLoadBalancingConfig
	$config.ServiceURL = Get-ElasticLoadBalancingUrl $region
	
	if ((IsNullOrEmpty $local:secretKeyID) -or (IsNullOrEmpty $local:secretAccessKeyID))
	{
		$elbClient=[Amazon.AWSClientFactory]::CreateAmazonElasticLoadBalancingClient($config)
	}
	else
	{
		$elbClient=[Amazon.AWSClientFactory]::CreateAmazonElasticLoadBalancingClient($local:secretKeyID, $local:secretAccessKeyID, $config)
	}
	
	return $elbClient
}

## New-AcwClient
##  create a new Amazon Cloud Watch Client
## Parameters
## 	$secretKeyID       - is the secret key
## 	$secretAccessKeyID - is the secret access key
##  $region			   - is the geographical region used
function New-AcwClient([String]$secretKeyID, [String]$secretAccessKeyID, [String]$region = $DefaultRegion)
{
	$config = New-Object -TypeName Amazon.CloudWatch.AmazonCloudWatchConfig
	$config.ServiceURL = Get-CloudWatchServiceUrl $region
	
	if ((IsNullOrEmpty $local:secretKeyID) -or (IsNullOrEmpty $local:secretAccessKeyID))
	{
		$cwClient=[Amazon.AWSClientFactory]::CreateAmazonCloudWatchClient($config)
	}
	else
	{
		$cwClient=[Amazon.AWSClientFactory]::CreateAmazonCloudWatchClient($local:secretKeyID, $local:secretAccessKeyID, $config)
	}
	
	return $cwClient
}

## New-AsgClient
##  create a new Auto-Scaling group Client
## Parameters
## 	$secretKeyID       - is the secret key
## 	$secretAccessKeyID - is the secret access key
##  $region			   - is the geographical region used
function New-AsgClient([String]$secretKeyID, [String]$secretAccessKeyID, [String]$region = $DefaultRegion)
{
	$config = New-Object -TypeName Amazon.Autoscaling.AmazonAutoScalingConfig
	$config.ServiceURL = Get-AutoScalingGroupUrl $region
	
	if ((IsNullOrEmpty $local:secretKeyID) -or (IsNullOrEmpty $local:secretAccessKeyID))
	{
		$asgClient=[Amazon.AWSClientFactory]::CreateAmazonAutoScalingClient($config)
	}
	else
	{
		$asgClient=[Amazon.AWSClientFactory]::CreateAmazonAutoScalingClient($local:secretKeyID, $local:secretAccessKeyID, $config)
	}
	
	return $asgClient
}

## New-R53Client
##  create a new amazon route 53 Client
## Parameters
## 	$secretKeyID       - is the secret key
## 	$secretAccessKeyID - is the secret access key
##  $region			   - is the geographical region used
function New-R53Client([String]$secretKeyID, [String]$secretAccessKeyID, [String]$region = $DefaultRegion)
{
	$config = New-Object -TypeName Amazon.route53.AmazonRoute53Config
	$config.ServiceURL = "HTTPS://route53.amazonaws.com"
	
	if ((IsNullOrEmpty $local:secretKeyID) -or (IsNullOrEmpty $local:secretAccessKeyID))
	{
		$r53Client=[Amazon.AWSClientFactory]::CreateAmazonRoute53Client($config)
	}
	else
	{
		$r53Client=[Amazon.AWSClientFactory]::CreateAmazonRoute53Client($local:secretKeyID, $local:secretAccessKeyID)
	}
	
	return $r53Client
}

## Get-Ec2ServiceUrl
##  If you just specify the general endpoint (ec2.amazonaws.com), Amazon EC2 
##  directs your request to the us-east-1 endpoint. In order to access EC2 
##  instances in another region the service end point must be configured
## Parameter :
##  $region - the region 
function Get-Ec2ServiceUrl([String]$region)
{
	[String]$value = ""
	switch ($region)
	{
		"eu-west-1"		{$value = "https://ec2.eu-west-1"}		# EU (Ireland) Region
		"sa-east-1"		{$value = "https://ec2.sa-east-1"}		# South America (Sao Paulo) Region
		"us-east-1"		{$value = "https://ec2.us-east-1"}		# US East (Northern Virginia) Region		
		"us-west-2"		{$value = "https://ec2.us-west-2"}		# US West (Oregon) Region
		"us-west-1"		{$value = "https://ec2.us-west-1"}		# US West (Northern California) Region
		"ap-southeast-1"	{$value = "https://ec2.ap-southeast-1"}		# Asia Pacific (Singapore) Region
		"ap-southeast-2"	{$value = "https://ec2.ap-southeast-2"}		# Asia Pacific (Sydney) Region
		"ap-northeast-1"	{$value = "https://ec2.ap-northeast-1"}		# Asia Pacific (Tokyo) Region
		## is it does not match then use us-west-2 as default
		default {$value = "https://ec2.ap-southeast-2"}		
	}
	return $value + ".amazonaws.com"
}

## Get-CloudFormationServiceUrl
##  If you do not specify the endpoint, Amazon EC2 
##  directs your request to the us-east-1 endpoint. In order to access EC2 
##  instances in another region the service end point must be configured
## Parameter :
##  $region - the region 
function Get-CloudFormationServiceUrl([String]$region)
{
	[String]$value = ""
	switch ($region)
	{
		"eu-west-1"		{$value = "https://cloudformation.eu-west-1"}			# EU (Ireland) Region
		"sa-east-1"		{$value = "https://cloudformation.sa-east-1"}			# South America (Sao Paulo) Region
		"us-east-1"		{$value = "https://cloudformation.us-east-1"}			# US East (Northern Virginia) Region		
		"us-west-2"		{$value = "https://cloudformation.us-west-2"}			# US West (Oregon) Region
		"us-west-1"		{$value = "https://cloudformation.us-west-1"}			# US West (Northern California) Region
		"ap-southeast-1"	{$value = "https://cloudformation.ap-southeast-1"}		# Asia Pacific (Singapore) Region
		"ap-southeast-2"	{$value = "https://cloudformation.ap-southeast-2"}		# Asia Pacific (Sydney) Region
		"ap-northeast-1"	{$value = "https://cloudformation.ap-northeast-1"}		# Asia Pacific (Tokyo) Region
		## is it does not match then use Sydney as default
		default {$value = "https://cloudformation.ap-southeast-2"}		
	}
	return $value + ".amazonaws.com"
}

## Get-SnsServiceUrl
##  If you do not specify the endpoint, Amazon EC2 
##  directs your request to the us-east-1 endpoint. In order to access EC2 
##  instances in another region the service end point must be configured
## Parameter :
##  $region - the region 
function Get-SnsServiceUrl([String]$region)
{
	[String]$value = ""
	switch ($region)
	{
		"eu-west-1"		{$value = "https://sns.eu-west-1"}		# EU (Ireland) Region
		"sa-east-1"		{$value = "https://sns.sa-east-1"}		# South America (Sao Paulo) Region
		"us-east-1"		{$value = "https://sns.us-east-1"}		# US East (Northern Virginia) Region		
		"us-west-2"		{$value = "https://sns.us-west-2"}		# US West (Oregon) Region
		"us-west-1"		{$value = "https://sns.us-west-1"}		# US West (Northern California) Region
		"ap-southeast-1"	{$value = "https://sns.ap-southeast-1"}		# Asia Pacific (Singapore) Region
		"ap-southeast-2"	{$value = "https://sns.ap-southeast-2"}		# Asia Pacific (Sydney) Region
		"ap-northeast-1"	{$value = "https://sns.ap-northeast-1"}		# Asia Pacific (Tokyo) Region
		## is it does not match then use Sydney as default
		default {$value = "https://sns.us-west-2"}		
	}
	return $value + ".amazonaws.com"
}

## Get-SqsServiceUrl
##  If you do not specify the endpoint, Amazon SQS 
##  directs your request to the us-east-1 endpoint. In order to access SQS 
##  instances in another region the service end point must be configured
## Parameter :
##  $region - the region 
function Get-SqsServiceUrl([String]$region)
{
	[String]$value = ""
	switch ($region)
	{
		"eu-west-1"			{$value = "https://sqs.eu-west-1"}			# EU (Ireland) Region
		"sa-east-1"			{$value = "https://sqs.sa-east-1"}			# South America (Sao Paulo) Region
		"us-east-1"			{$value = "https://sqs.us-east-1"}			# US East (Northern Virginia) Region		
		"us-west-2"			{$value = "https://sqs.us-west-2"}			# US West (Oregon) Region
		"us-west-1"			{$value = "https://sqs.us-west-1"}			# US West (Northern California) Region
		"ap-southeast-1"	{$value = "https://sqs.ap-southeast-1"}		# Asia Pacific (Singapore) Region
		"ap-southeast-2"	{$value = "https://sqs.ap-southeast-2"}		# Asia Pacific (Sydney) Region
		"ap-northeast-1"	{$value = "https://sqs.ap-northeast-1"}		# Asia Pacific (Tokyo) Region
		## is it does not match then use Sydney as default
		default {$value = "https://sqs.ap-southeast-2"}
	}
	return $value + ".amazonaws.com"
}

## Get-CloudWatchServiceUrl
##  If you do not specify the endpoint, Amazon Cloud Watch 
##  directs your request to the us-east-1 endpoint. In order to access  
##  Cloud Watch in another region the service end point must be configured
## Parameter :
##  $region - the region 
function Get-CloudWatchServiceUrl([String]$region)
{
	[String]$value = ""
	switch ($region)
	{
		"eu-west-1"			{$value = "https://monitoring.eu-west-1"}			# EU (Ireland) Region
		"sa-east-1"			{$value = "https://monitoring.sa-east-1"}			# South America (Sao Paulo) Region
		"us-east-1"			{$value = "https://monitoring.us-east-1"}			# US East (Northern Virginia) Region		
		"us-west-2"			{$value = "https://monitoring.us-west-2"}			# US West (Oregon) Region
		"us-west-1"			{$value = "https://monitoring.us-west-1"}			# US West (Northern California) Region
		"ap-southeast-1"	{$value = "https://monitoring.ap-southeast-1"}		# Asia Pacific (Singapore) Region
		"ap-southeast-2"	{$value = "https://monitoring.ap-southeast-2"}		# Asia Pacific (Sydney) Region
		"ap-northeast-1"	{$value = "https://monitoring.ap-northeast-1"}		# Asia Pacific (Tokyo) Region
		## is it does not match then use Sydney as default
		default {$value = "https://monitoring.ap-southeast-2"}
	}
	return $value + ".amazonaws.com"
}

## Get-S3ServiceUrl
##  in order to acccess S3 buckets in particular regions a different service end point 
##  must be specified, the different end point is critical when uploading to S3
##  by default if region is blank or does not match US-WEST-2 is selected
## Parameters
##	$region - string region
function Get-S3ServiceUrl([String]$region)
{
	[String]$value = ""
	switch ($region)
	{
		"eu-west-1"			{$value = "https://s3-eu-west-1"}			# EU (Ireland) Region
		"sa-east-1"			{$value = "https://s3-sa-east-1"}			# South America (Sao Paulo) Region
		"us-east-1"			{$value = "https://s3"}						# US East (Northern Virginia) Region		
		"us-west-2"			{$value = "http://s3-us-west-2"}			# US West (Oregon) Region
		"us-west-1"			{$value = "https://s3-us-west-1"}			# US West (Northern California) Region
		"ap-southeast-1"	{$value = "https://s3-ap-southeast-1"}		# Asia Pacific (Singapore) Region
		"ap-southeast-2"	{$value = "https://s3-ap-southeast-2"}		# Asia Pacific (Sydney) Region
		"ap-northeast-1"	{$value = "https://s3-ap-northeast-1"}		# Asia Pacific (Tokyo) Region
		## is it does not match then use us-west-2 as default
		default {$value = "https://s3-ap-southeast-2"}
	}
	return $value + ".amazonaws.com"
}

## Get-RelationalDatabaseServiceUrl
##  If you do not specify the endpoint, Amazon Relational Database
##  directs your request to the us-east-1 endpoint. In order to access  
##  RDS in another region the service end point must be configured
##   url to get list: http://docs.aws.amazon.com/general/latest/gr/rande.html
## Parameter :
##  $region - the region 
function Get-RelationalDatabaseServiceUrl([String]$region)
{
	[String]$value = ""
	if ($region)
	{
		$value = "https://rds.$region"
	}
	else
	{
		## is it does not match then use Sydney as default
		$value = "https://rds.ap-southeast-2"
	}
	return $value + ".amazonaws.com"
}

## Get-ElasticLoadBalancingUrl
##  If you do not specify the endpoint, Amazon Load Balancer
##  directs your request to the us-east-1 endpoint. In order to access  
##  ELB in another region the service end point must be configured
## Parameter :
##  $region - the region 
function Get-ElasticLoadBalancingUrl([String]$region)
{
	[String]$value = ""
	if ($region)
	{
		$value = "https://elasticloadbalancing.$region"
	}
	else
	{
		## is it does not match then use Sydney as default
		$value = "https://elasticloadbalancing.ap-southeast-2"
	}
	return $value + ".amazonaws.com"
}

## Get-AutoScalingGroupUrl
##  If you do not specify the endpoint, Amazon scaling group
##  directs your request to the us-east-1 endpoint. In order to access  
##  ASG in another region the service end point must be configured
## Parameter :
##  $region - the region - if none supplied, use Sydney as default
function Get-AutoScalingGroupUrl([String]$region = "ap-southeast-2")
{
	[String]$value = ""
	$value = "https://autoscaling.$region"
	return $value + ".amazonaws.com"
}

## Invoke-StartInstances
## 	this function will start an existing stopped instance of an AMI
## Parameters : 
##  $ec2Client   - Amazon Elastic Cloud Computing client
##  $instanceIds - Array of running instance ids
function Invoke-StartInstances([Amazon.EC2.AmazonEC2Client]$ec2Client, [string[]] $instanceIds)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Host "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received " $local:ec2Client
		return
	}
	$OFS=','
	$local:request = New-Object -TypeName Amazon.EC2.Model.StartInstancesRequest
	$local:request.InstanceId = Get-IdsFromParameterList $local:instanceIds
	
	$response = $ec2Client.StartInstances($local:request)
	return $response
}

## Invoke-SingleInstance
##  Invoke a single instance from and image; uses Invoke-RunInstances
## Parameters : 
##  $ec2Client          - Amazon Elastic Cloud Computing client
##  $imageId            - image Id
##  $keyPairName        - name of the key pair to associate with the image, without a key pair it is not possible to retrive the password
##  $userdata           - commands either powershell, scripts or otherwise to be run on bootstrapping
##  $instanceProfileArn - IAM Profile described as an Amazon Resource Name (ARN) e.g. "arn:aws:iam::587143430827:instance-profile/WebFrontEnd"
function Invoke-SingleInstance([Amazon.EC2.AmazonEC2Client]$ec2Client, [string[]] $imageId, [String]$keyPairName, [String]$userdata, [String]$instanceProfileArn, [String]$instanceType = $DefaultInstanceType, [System.Collections.Generic.List[String]]$securityGroupIdList = "")
{
	$idList = Invoke-RunInstances $ec2Client $imageId $keyPairName $userData $instanceProfileArn $instanceType $DefaultMinInstancesToStart $DefaultMaxInstancesToStart $securityGroupIdList
	Start-Sleep -Seconds 15
	return $idList
}

## Invoke-RunInstances
##  To spin up a NEW instance of an image
## Parameters : 
##  $ec2Client          - Amazon Elastic Cloud Computing client
##  $imageIds           - array of image Ids
##  $keyPairName        - name of the key pair to associate with the image, without a key pair it is not possible to retrive the password
##  $userdata           - commands either powershell, scripts or otherwise to be run on bootstrapping
##  $instanceProfileArn - IAM Profile described as an Amazon Resource Name (ARN) e.g. "arn:aws:iam::587143430827:instance-profile/WebFrontEnd"
##  $instanceType       - the type of machine instance to start, "t1.micro", "m1.small", "m1.large", "m1.xlarge", "m2.xlarge", "m2.2xlarge", etc
##  $minCount           - minimum number of instances to start
##  $maxCount           - maximum number of instances to start
##  $securityGroupIdList- the security group to place the server(s) into.
function Invoke-RunInstances([Amazon.EC2.AmazonEC2Client]$ec2Client, [string[]] $imageIds, [String]$keyPairName, [String]$userdata, [String]$instanceProfileArn, [String]$instanceType, [int]$minCount, [int]$maxCount, [System.Collections.Generic.List[String]]$securityGroupIdList)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Host "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received " $local:ec2Client		
		return
	}
	$OFS=','
	
	if (IsNullOrEmpty $securityGroupIdList)
	{
		$securityGroupIdList = New-Object -TypeName System.Collections.Generic.List[String]
		$securityGroupIdList.Add($DefaultSecurityGroupId)
	}
	$local:request = New-Object -TypeName Amazon.EC2.Model.RunInstancesRequest
	$local:request.ImageId = Get-IdsFromParameterList $local:imageIds
	$local:request.KeyName = $local:keyPairName
	if (!(IsNullOrEmpty $instanceType))
	{
		$local:request.InstanceType = $instanceType
	}
	else
	{
		$local:request.InstanceType = $DefaultInstanceType
	}
	
	if ($minCount -le 0)
	{
		$local:request.MinCount = $DefaultMinInstancesToStart
	}
	else
	{
		$local:request.MinCount = $minCount
	}
	
	if ($maxCount -le 0)
	{
		$local:request.MaxCount = $DefaultMaxInstancesToStart
	}
	else
	{
		$local:request.MaxCount = $maxCount 
	}
	$local:request.SecurityGroupId = $securityGroupIdList
		
	if (!(IsNullOrEmpty $instanceProfileArn))
	{
		$iamInstanceProfile = New-Object -TypeName Amazon.EC2.Model.IAMInstanceProfile
		$iamInstanceProfile.Arn = $instanceProfileArn
		$local:request.InstanceProfile = $iamInstanceProfile
	}
	
	if (!(IsNullOrEmpty $userData))
	{
		$encoded = Convert-ToBase64 $userdata 
		$local:request.UserData = $encoded
	}

	try
	{

		$response = $ec2Client.RunInstances($local:request)
		
		Write-Host "RunInstanceResult = $($response.RunInstancesResult.Reservation.RunningInstance)"
		$ids = New-Object -TypeName System.Collections.Generic.List[String]
		foreach($instance in $response.RunInstancesResult.Reservation.RunningInstance)
		{
			$ids.Add($instance.InstanceId)		
		}
		return $ids
	}
	Catch [Amazon.EC2.AmazonEC2Exception]
	{
		$exception = $_.Exception
		Switch ($exception.ErrorCode)
		{
			"AuthFailure" {
					Write-FormattedError -exception $exception `
						-errorReason "Invalid ec2Client security token (or insufficient priveledges)." `
						-recommendedAction "check the ec2 secret key and secret access key" 
				}
			"InvalidKeyPair.NotFound" {
					Write-FormattedError -exception $exception `
						-errorReason "keyPairName is invalid or not in correct zone." `
						-recommendedAction "verify the keyPairName are correct" 
				} 
			"InvalidAMIID.Malformed" {
					Write-FormattedError -exception $exception `
						-errorReason "amiImageId is invalid or not in correct zone." `
						-recommendedAction "verify the amiImageIds are correct" 
				}
			"InvalidGroup.NotFound" {
					Write-FormattedError -exception $exception `
						-errorReason "securityGroupIdList is invalid or not in correct zone." `
						-recommendedAction "verify the securityGroupIdList are correct" 
				}
			"InvalidParameterValue" {
					Write-FormattedError -exception $exception `
						-errorReason "One of the supplied parameters may be invalid." `
						-recommendedAction "verify the amiImageIds, keyPairName, instanceType are all valid" 
				}
			"MissingParameter" {
					Write-FormattedError -exception $exception `
						-errorReason "One of the required parameters may be missing or null - this can get misreported by AWS." `
						-recommendedAction "verify the amiImageIds, keyPairName, instanceType are all valid" 
				}
			default {Write-FormattedError -exception $exception}
		}
		$ids = ""
	}
	Catch
	{
		Write-FormattedError -exception $_.Exception `
		$ids = ""
	}
	return $ids
}

## Stop-Instances
##	to stop running Amazon Machine Image instances 
## Parameters : 
##  $ec2Client   - Amazon Elastic Cloud Computing client
##  $instanceIds - Array of running instance ids
function Stop-Instances([Amazon.EC2.AmazonEC2Client]$ec2Client, [string[]] $instanceIds)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Host "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received " $local:ec2Client		
		return
	}
	try
	{
		$local:request = New-Object -TypeName Amazon.EC2.Model.StopInstancesRequest
		$local:request.InstanceId = Get-IdsFromParameterList $local:instanceIds
		$response = $ec2Client.StopInstances($local:request)
	}
	catch
	{
		Write-Host "** Could not stop instance $($local:instanceIds) due to errors"
		Write-FormattedError $_
		$response = $null
	}
	return $response
}

## Reboot-Instances
##	to stop running Amazon Machine Image instances 
## Parameters : Array of running instance ids
function Reboot-Instances([Amazon.EC2.AmazonEC2Client]$ec2Client, [string[]] $instanceIds)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Host "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received " $local:ec2Client		
		return
	}
	$OFS=','
	$local:request = New-Object -TypeName Amazon.EC2.Model.RebootInstancesRequest
	$local:request.InstanceId = Get-IdsFromParameterList $local:instanceIds
	
	$response = $ec2Client.RebootInstances($local:request)
	return $response
}

## Terminate-Instance
##	to delete stopped Amazon Machine Image instances 
## Parameters : 
##  $ec2Client   - Amazon Elastic Cloud Computing client
##  $instanceIds - Array of running instance ids
function Terminate-Instance([Amazon.EC2.AmazonEC2Client]$ec2Client, [String[]] $instanceIds)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Host "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received $local:ec2Client"
		return
	}
	$OFS=','
	$local:request = New-Object -TypeName Amazon.EC2.Model.TerminateInstancesRequest
	$local:request.InstanceId = Get-IdsFromParameterList $local:instanceIds
	
	$response = $ec2Client.TerminateInstances($local:request)
	return $response
}

## New-Image
##  the purpose of this is to create an image from a running or stopped instance.
##  once the image is ready, set the name and other tag metadata
## Parameters :
##  $ec2Client        - Amazon EC2 Client
##  $instanceId       - the instance to create a image from
##  $imageName        - the name of the new Image
##  $imageDescription - the description of the image
##  $buildVersion     - [optional] the build version as passed in from TeamCity
function New-Image([Amazon.EC2.AmazonEC2Client]$ec2Client, [String] $instanceId, [String] $imageName, [String] $imageDescription, [String] $buildVersion, [HashTable] $hashTags)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Host "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received " $local:ec2Client		
		return
	}
	
	$local:request = New-Object -TypeName Amazon.EC2.Model.CreateImageRequest
	$local:request.InstanceId =  $local:instanceId
	$local:request.Name = $local:imageName
	$local:request.Description = $local:imageDescription
	
	$createImageResponse = $ec2Client.CreateImage($request)
	[String[]] $imageIds = @($createImageResponse.CreateImageResult.ImageId)
	
	## ensure that the image is ready before proceeding
	$waitForImageResponse = WaitFor-ImageAvailability $local:ec2Client $imageIds
    
	if (!(IsNullOrEmpty $buildVersion))
	{
		$hashTags.Add("BuildVersion", $buildVersion)
	}
	
    $local:Response = New-Tags $local:ec2Client $imageIds $local:hashTags
	
	return $createImageResponse.CreateImageResult.ImageId
}

## New-Tags
##  function to associate a set of key value pairs to an instance\image, 
##  e.g. Name = MainDBServer; InstanceType = WebServer; Environment = DEV
##  there should be a maximum of 10 key value pairs.  It is assumed that 
##  all the key value pairs match and will be applied to all instances
## Parameters : 
##  $ec2Client   - EC2 Client
##	$resourceIds - comma separated list of running resources (i.e. instances or images)
##  $hashValues  - hashTable of key value pairs
function New-Tags([Amazon.EC2.AmazonEC2Client]$ec2Client, [string[]]$resourceIds, [HashTable]$hashValues)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Host "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received " $local:ec2Client		
		return
	}
	
	## the maximum is 10, but asssume that 1 tag is already taken with Name
	if ($hashValues.Count -gt 9)
	{
		Write-Error "Error Can not have more than 10 Name Value pairs for AMI Tags"
		return
	}
	
	$OFS=','
	$createTagsRequest = New-Object -TypeName Amazon.EC2.Model.CreateTagsRequest
	$createTagsRequest.ResourceId = Get-IdsFromParameterList $resourceIds

	foreach($key in $hashValues.keys)
	{
		$local:tag = New-Object -TypeName Amazon.EC2.Model.Tag		
		$local:tag.Key = $key
		$local:tag.Value = $hashValues[$key]
		
		$response = $createTagsRequest.Tag.Add($tag)
	}
	
	$tagResponse = $ec2Client.CreateTags($createTagsRequest);
	return $tagResponse
}

## New-Stack
##  Create a new cloud formation stack using a cloud formation template
##  You must pass TemplateURL or TemplateBody. If both are passed, only TemplateBody is used.
## Parameters:
##  $cfClient     - cloud formation client
##  $stackName    - name of the stack to be created
##  $templateBody - String containing the cloud formation template body.
##  $templateUrl  - The URL must point to a template located in an S3 bucket in the same region as the stack. 
##  $parameters   - hashtable of key value pairs to be used in the cloud formation template
##  $tags		  - hashtable of tags to apply to ec2 resources
##  $snsTopicArn  - sns arn to notify for stack progress
function New-Stack([Amazon.CloudFormation.AmazonCloudFormationClient] $cfClient, [String] $stackName, [String] $templateBody, [String] $templateUrl, [HashTable] $parameters, [HashTable] $tags, [string[]]$snsTopicArns)
{
	if ( ($local:cfClient -eq $null) -or ($local:cfClient -isnot [Amazon.CloudFormation.AmazonCloudFormationClient]) )
	{
		$message = "Error Null or Invalid Client; Expecting Amazon.CloudFormation.AmazonCloudFormationClient but received  $local:cfClient"
		Write-Host $message -ForegroundColor Red 
		return $message
	}

	if ((IsNullOrEmpty $templateBody) -and (IsNullOrEmpty $templateUrl))
	{
		$message = "Error: No Cloud Formation Template provided."
		Write-Host $message -ForegroundColor Red
		return $message
	}
	
	$createStackRequest = New-Object -TypeName Amazon.CloudFormation.Model.CreateStackRequest
	if (! (IsNullOrEmpty $stackName))
	{
		$createStackRequest.Stackname = $stackName
	}	
	
	if (!(IsNullOrEmpty $templateBody))
	{
		$createStackRequest.TemplateBody = $templateBody
	}
	if (!(IsNullOrEmpty $templateUrl))
	{
		$createStackRequest.TemplateURL = $templateUrl
	}
	
	if ($tags)
	{
		foreach($key in $tags.keys)
		{
			$local:tag = New-Object -TypeName Amazon.CloudFormation.Model.Tag
			$local:tag.key = $key
			$local:tag.value = $tags[$key]
			
			$createStackRequest.Tags.Add($local:tag)
		}
	}
	
	if ($parameters)
	{
		foreach($key in $parameters.keys)
		{
			$local:parameter = New-Object -TypeName Amazon.CloudFormation.Model.Parameter
			$local:parameter.ParameterKey = $key
			$local:parameter.ParameterValue = $parameters[$key]
			
			$createStackRequest.Parameters.Add($local:parameter)
		}
	}
	if ($snsTopicArns)
	{
		
		$createStackRequest.NotificationARNs = $snsTopicArns
	}
	try
	{
		$createStackResponse = $cfClient.CreateStack($createStackRequest)
		
		if ($createStackResponse -ne $null)
	    {      
	        Write-Host "Stacks On Response StackId: $($createStackResponse.CreateStackResult.StackId); RequestId : $($createStackResponse.ResponseMetadata.RequestId)"
			return $createStackResponse.CreateStackResult.StackId
	    }
	}
	Catch [Amazon.CloudFormation.Model.AlreadyExistsException]
	{
		Write-Error $_.Exception.ToString()
		return "Exception: Stack already exists"
	}
	Catch [Amazon.CloudFormation.Model.InsufficientCapabilitiesException]
	{
		Write-Error $_.Exception.ToString()
		return "Exception: Insufficient Capabilities"
	}
	Catch [Amazon.CloudFormation.Model.LimitExceededException]
	{
		Write-Error $_.Exception.ToString()
		return "Exception: Limit Exceeded"
	}
	Catch [Amazon.CloudFormation.AmazonCloudFormationException]
	{
		Write-Error $_.Exception.ToString()
		return "Exception: General Cloud Formation Exception :$_.Exception.ToString()"
	}
}

## Validate-CloudFormationTemplate
##  to validate the cloud formation template
##  You must pass TemplateURL or TemplateBody. If both are passed, only TemplateBody is used.
## Parameters :
##  $cfClient     - cloud formation client
##  $templateBody - String containing the cloud formation template body.
##  $templateUrl  - The URL must point to a template located in an S3 bucket in the same region as the stack.
function Validate-CloudFormationTemplate([Amazon.CloudFormation.AmazonCloudFormationClient]$cfClient, [String] $templateBody, [String] $templateUrl)
{
	if ( ($local:cfClient -eq $null) -or ($local:cfClient -isnot [Amazon.CloudFormation.AmazonCloudFormationClient]) )
	{
		Write-Warning "Error Null or Invalid Client; Expecting Amazon.CloudFormation.AmazonCloudFormationClient but received " $local:cfClient		
		return $false
	}

	if ((IsNullOrEmpty $templateBody) -and (IsNullOrEmpty $templateUrl))
	{
		Write-Warning "No Cloud Formation Template provided."
		return $false
	}

	$validateTemplateRequest = New-Object -TypeName Amazon.CloudFormation.Model.ValidateTemplateRequest
	## NOTE: You must pass TemplateBody or TemplateURL, if both are passed
	##  TemplateBody is used	
	$validateTemplateRequest.TemplateBody = $templateBody
	if (!(IsNullOrEmpty $templateUrl))
	{
		$validateTemplateRequest.TemplateURL = $templateUrl
	}
	try
	{
		$validateTemplateResponse = $cfClient.ValidateTemplate($validateTemplateRequest)
		if ( !(IsNullOrEmpty $validateTemplateResponse))
		{
			return $true
		}
		return $false
	}
	catch
	{
		Write-Error $_
		return $false
	}
	
}

## Set-IpToInstance
##  assign an IP address to an instance
## Parameters : 
##  $ec2Client  - Amazon Elastic Cloud Computing security Token
##  $instanceId - unique identitier for the instance
##  $ipAddress  - ip address to be assigned to the instance
function Set-IpToInstance([Amazon.EC2.AmazonEC2Client]$ec2Client, [String]$instanceId, [String]$ipAddress)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Error "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received $local:ec2Client"
		return
	}
	$local:request = New-Object -TypeName Amazon.EC2.Model.AssociateAddressRequest
	[void]$local:request.WithInstanceId($instanceId)
	[void]$local:request.WithPublicIp($ipAddress) 
	$result = $ec2Client.AssociateAddress($local:request)
	
	if ($result) 
	{ 
		Write-Host "Address $ipAddress assigned to $instanceId successfully."
	}
	else 
	{ 
		Log-Error "Failed to assign $ipAddress to $instanceId."
	}
}

## Find-InstanceByType
##  find a running instance by the key:value pair set in the instance tag
## Parameters :
##  $ec2Client  - an instance of Amazon.EC2.AmazonEC2Client
##  $typeKey    - the name of te key
##  $typeValue  - the value of the key
function Find-InstanceByType([Amazon.EC2.AmazonEC2Client]$ec2Client, [String]$typeKey, [String]$typeValue)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Error "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received $local:ec2Client"
		return
	}
	
	$local:request = New-Object -TypeName Amazon.EC2.Model.DescribeInstancesRequest

	#filter only for Web Servers
	$filterList =  @()
	# Create a new filter to only get servers with a purpose of webserver
	$filter = New-Object -TypeName Amazon.EC2.Model.Filter

	$filter = $filter.WithName("tag:$typeKey")
	$filter = $filter.WithValue($typeValue)
	$filterList += $filter

	# Add the filter to the request
	$local:request = $local:request.WithFilter($filter)
	$response = $ec2Client.DescribeInstances($local:request)
	
	[HashTable]$Return = @{} 

	foreach ($reservation in $response.DescribeInstancesResult.Reservation)
	{  
		## for now there will only be one..
	    foreach($instance in $reservation.RunningInstance)
	    {
			$Return.Ip = $instance.IpAddress
			$Return.InstanceId = $instance.InstanceId
	    }
	}
	$Return
}

## Get-FileFromS3
##  function to download a file from S3 bucket and save to local file location
## Parameters : 
##  $s3Client          - S3 Client
##  $bucketName        - name of the S3 bucket (including folder)
##  $keyName           - name of file to download
##  $destinationFolder - absolute location of the location to store downloaded file
function Get-FileFromS3([Amazon.S3.AmazonS3Client]$s3Client, [String]$s3BucketName, [String]$keyName, [String]$destinationFolder, [String]$destinationFileName)
{
	if ( ($s3Client -eq $null) -or ($s3Client -isnot [Amazon.S3.AmazonS3Client]) )
	{
		Write-Error "S3 Client cannot be null"
		return $false
	}
	
	## if $local:s3BucketName is null or blank
	if (IsNullOrEmpty $s3BucketName)
	{
		Write-Error "S3 Bucket Name cannot be null or empty"
		return $false
	}
	if (IsNullOrEmpty $keyName)
	{
		Write-Error "Key Name cannot be null or empty"
		return $false
	}	

	if (IsNullOrEmpty $destinationFileName)
	{
		$destinationLocation = Join-Path -Path $destinationFolder -ChildPath $keyName
	}
	else
	{
		$destinationLocation = Join-Path -Path $destinationFolder -ChildPath $destinationFileName
	}	
	
	if ($destinationLocation -match "/")
	{
		$destinationLocation = $destinationLocation -replace "/", "`\"
	}
	
	Create-Folder $destinationFolder

	try
	{
		$getObjectRequest = New-Object -TypeName Amazon.S3.Model.GetObjectRequest
		$getObjectRequest.WithBucketName($local:s3BucketName)
		$getObjectRequest.WithKey($local:keyName)

		$response = $s3Client.GetObject($getObjectRequest)
		$response.WriteResponseStreamToFile($destinationLocation)
		
		return $true
	}
	catch
	{
		$errorMessage = "Failed to download file '{0}' from '{1}'. `r`nReason: {2}" -f $fileName, $s3BucketName, $_.Exception.Message
		Write-Error $errorMessage
		return $false
	}
}

## Upload specified file to S3 server
## Parameters : 
##  $s3client       		- is the S3 client and cannot be null
##  $fileName               - is the abolute location of the file to upload and cannot be null
##  $s3BucketName 			- is the S3 bucketname and cannot be null
##  $s3FolderPath 			- is the path on S3 to put the upload file
##  $s3FileName             - is the alternative name of file given when upload and displayed in AWS, if null will be set to $fileNameWithExtension
function Upload-FileToS3([Amazon.S3.AmazonS3Client]$s3client, [String]$fileName, [String]$s3BucketName, [String]$s3FolderPath, [String]$s3FileName)
{
	# Local variables
	$fileInfo = $null
	$actualFileName = $null
	$finalFileKey = $null
	
	
	## $client must not be null and of type Amazon.S3.AmazonS3Client
	if ( ($s3client -eq $null) -or ($s3client -isnot [Amazon.S3.AmazonS3Client]) )
	{
		Write-Error "S3 Client cannot be null"
		return $false
	}
	
	## If $local:s3BucketName is null or blank
	if (IsNullOrEmpty $s3BucketName)
	{
		Write-Error "S3 Bucket Name cannot be null or empty"
		return $false
	}
	
	## Source path and file must be specified
	if ( (IsNullOrEmpty $fileName) -or !(Test-Path $fileName) )
	{
		Write-Error "File does not exist."
		return $false
	}
	## Instantiate FileInfo
	$fileInfo = New-Object -TypeName System.IO.FileInfo $fileName
	
	## set actual filename to be set on S3 bucket
	if(IsNullOrEmpty $s3FileName)
	{		
		## extract actual filename from the absolute path
		$actualFileName = $fileInfo.Name
	}
	else
	{
		## to create a folder need to place the file inside a folder.
		$actualFileName = $s3FileName
	}	
		
	## check if folder path is specified
	if(IsNullOrEmpty $s3FolderPath)
	{
		$finalFileKey = $actualFileName
		Write-Host "Folder path not specifed, default path used instead.: $finalFileKey"
	}
	else
	{
		$finalFileKey = "{0}/{1}" -f $s3FolderPath, $actualFileName
		Write-Host "  Placing file inside a folder by using forward slash: $finalFileKey"
	}
	
	## Upload file to S3 Server
	Try
	{
		## check if file size is greater than 5Mb
		if($fileInfo.Length -ge $MaxLengthInBytes)
		{
			$numberOfParts = $fileInfo.Length / $MaxLengthInBytes + 1
			
			$requestUtility = New-Object -TypeName Amazon.S3.Transfer.TransferUtilityUploadRequest
            $requestUtility.ServerSideEncryptionMethod = $DefaultServerSideEncryptionMethod
            $requestUtility.StorageClass = $DefaultS3StorageClass
			$requestUtility.BucketName = $s3BucketName
            $requestUtility.FilePath = $fileName
            $requestUtility.Key = $finalFileKey
            $requestUtility.Timeout = -1
            $requestUtility.PartSize = $numberOfParts*1024*1024
			
			$transferUtility = New-Object -TypeName Amazon.S3.Transfer.TransferUtility $s3client
			$transferUtility.Upload($requestUtility)
		}
		else
		{
			$request = New-Object -TypeName Amazon.S3.Model.PutObjectRequest
			$request.Timeout = $RequestTimeoutInMilliseconds
			$request.FilePath = $fileName
			$request.BucketName = $s3BucketName
			$request.Key = $finalFileKey
			$request.StorageClass = $DefaultS3StorageClass
			$request.ServerSideEncryptionMethod = $DefaultServerSideEncryptionMethod			
			$s3client.PutObject($request) | Out-Null # PutObject returns xml response./ if not caught it will return itself with method return
		}
		return $true
	}
	Catch
	{
		$errorMessage = "Failed to upload file '{0}' to '{1}'. `r`nReason: {2}" -f $fileName, $s3BucketName, $_.Exception.Message
		Write-Error $errorMessage
		return $false
	}
}

## Get-FileWithFilter
##  this function will allow you to download file(s) given a file pattern
## Parameters :
##  $s3Client    - S3 client 
##  $bucketName  - the name of the S3 bucket to acess
##  $filepattern - file or file pattern to download from S3, e.g. assets.zip; *.ps1
##  $localPath   - location to save the downloaded file(s)
function Get-FileWithFilter([Amazon.S3.AmazonS3Client]$s3Client, [String]$s3BucketName, [String]$filepattern, [String]$localPath)
{
	$result = $false
	## Get a list of all objects in the specified S3 Bucket
	if (IsNullOrEmpty $local:s3BucketName)
	{
		Write-Error "S3 Bucket Name cannot be null or empty"
	}
	else
	{
		$listObjectsRequest = New-Object -TypeName Amazon.S3.Model.ListObjectsRequest
		$listObjectsRequest.BucketName = $local:s3BucketName
		
		$filepattern = $filepattern -Replace("\\","/")
		
		Create-Folder $localPath
			
		try
		{
			$listObjectResponse = $local:s3Client.ListObjects($listObjectsRequest)
			foreach( $s3Object in $listObjectResponse.S3Objects)
			{		
				## download if the size is > 0, i.e. is a file not a folder
				if ($s3Object.Size -gt 0)
				{
					if ( (IsNullOrEmpty $filepattern) -or ($s3Object.Key.ToLower().Contains($filepattern.ToLower()) ))
					{
						Write-Host "downloading file: $local:s3BucketName \ $($s3Object.Key) ==> $localPath"
						Get-FileFromS3 $local:s3Client $local:s3BucketName $s3Object.Key $localPath
						$result = $true
					}
				}
			}
			
		}
		catch [Amazon.S3.AmazonS3Exception]
		{	
			Write-Error $_
		}
	}
	return $result
}


## Get-FileNameList
##  this function returns single/list of folders given a folder name pattern
## Parameters :
##  $s3Client    - S3 client 
##  $bucketName  - the name of the S3 bucket to acess
##  $filepattern - folder or folder pattern to download from S3, e.g. 5.4.0.509
function Get-s3FolderNameList([Amazon.S3.AmazonS3Client]$s3Client, [String]$s3BucketName, [String]$namepattern)
{
      $result =  @()
      ## Get a list of all objects in the specified S3 Bucket
      if (IsNullOrEmpty $s3BucketName)
      {
            Write-Error "S3 Bucket Name cannot be null or empty"
      }
      else
      {
            $listObjectsRequest = New-Object -TypeName Amazon.S3.Model.ListObjectsRequest -Property @{
                     BucketName = $s3BucketName ;
                     prefix = $namepattern ;
                }
                        
            try
            {
                  $listObjectResponse = $local:s3Client.ListObjects($listObjectsRequest)
                  $keyname = @()
                  foreach ($item in $listObjectResponse.S3Objects)
                  {
                        $keyname += $($item.key.Substring(0, $item.key.IndexOf("/") ))
                  }
                       
                  $keyname = ($keyname | select -Unique | sort -Descending)
            }
            catch 
            {     
                  Write-Error $_
            }
      }
      return  $keyname
}




## New-SnapshotEC2
##  Create a new snapshot specifying the volume and description
## Parameters :
##  $ec2Client    - an instance of Amazon.EC2.AmazonEC2Client
##  $volumeID     - volume of that needs to be snapshoted
##  $description  - description for the snapshot
function New-SnapshotEC2([Amazon.EC2.AmazonEC2Client]$ec2Client, [String]$volumeID, [String]$description)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Error "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received " $local:ec2Client
		return
	}
	
	$local:request = New-Object Amazon.EC2.Model.CreateSnapshotRequest
	$local:request.VolumeID = $volumeID
	$local:request.Description = $description
	
	$response = $ec2Client.CreateSnapshot($local:request)
	return $response
}

## Delete-SnapshotEC2
##  Delete a snapshot specifying the snashotID
## Parameters :
##  $ec2Client    - an instance of Amazon.EC2.AmazonEC2Client
##  $snapshotID   - snapshotId to be deleted 
function Delete-SnapshotEC2([Amazon.EC2.AmazonEC2Client]$ec2Client, [String]$snapshotID)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Error "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received " $local:ec2Client
		return
	}
	
	$local:request = New-Object Amazon.EC2.Model.DeleteSnapshotRequest
	$local:request.SnapshotId = $snapshotID
	
	$response = $ec2Client.DeleteSnapshot($local:request)
	return $response
}

## New-BootstrapImage
##  this function orchestrates the creation of a golden image from a base image,
##  creating a new instance, boot strapping the instance and finally creating a
##  new Golden Image from the bootstrapped instance.
## Parameters
##  $ec2Client          - Amazon EC2 Client
##  $baseImageId        - the base image to create an instance from
##  $keyPairName        - name of the Key Pair to use to start the instance
##  $instanceProfileArn - the IAM profile
##  $userdata           - user-data to be passed to the instance, e.g. bootstrap instructions
##  $build              - build version information
##  $imageHashTags      - set of name value pairs to add as meta data to the image 
function New-BootstrapImage([Amazon.EC2.AmazonEC2Client]$ec2Client, [String]$baseImageId, [String]$keyPairName, [String]$instanceProfileArn, [String]$userdata, [String]$build, [HashTable]$imageHashTags, [String]$instanceType, [System.Collections.Generic.List[String]]$securityGroupIdList)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Error "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received $local:ec2Client"
		return
	}
	if (IsNullOrEmpty $instanceType)
	{
		$instanceType = $DefaultInstanceType
	}
	
	## prepare the tags on the instance
	$buildVersion=$build
	Write-Host "Setting instance Tag metadata"
	$hashTags = @{"Name" = (Get-StringFromTokenizedString($DefaultInstanceName))}
	$hashTags.Add("Team", (Get-StringFromTokenizedString($DefaultTeamName)))
	$hashTags.Add("Environment", "BUILD")
	$hashTags.Add("BootType", "RunInstance")
	$hashTags.Add("Build", $build)
	
	## create a new running instance from the base image
	Write-Host "Creating new instance from base image"
	$invokedInstanceId = Invoke-SingleInstance $local:ec2Client $baseImageId $keyPairName $userdata $instanceProfileArn $instanceType $securityGroupIdList
	
	## set the tags on the instance
	$local:tagResponse = New-Tags $ec2Client $invokedInstanceId $local:instanceHashTags
	
	## check if the instance is ready to use
	Write-Host "waiting for the instance to be available before proceeding..."
	$waitInstanceResponse = WaitFor-InstanceAvailability $local:ec2Client $invokedInstanceId
		
	## Stop the instance
	Write-Host "Stopping the newly creating instance before creating image"
	$stopInstanceResponse = Stop-Instances $local:ec2Client $invokedInstanceId
	
	## Wait for the instance to stop
	Write-Host "Waiting for the instance to stop"	
	$waitStopInstanceResponse = WaitFor-InstanceStopped $local:ec2Client $invokedInstanceId
	
	## create an image from the instance and when it is available, set the 'Tag' Metadata	
	Write-Host "Creating a new image from stopped instance"
	$imageName = Get-StringFromTokenizedString($DefaultAmiName)
	$imageDescription = Get-StringFromTokenizedString($DefaultAMIDescription)
	
	if ($imageHashTags.Contains("Name"))
	{
		$imageHashTags["Name"] = $imageName
	}
	else
	{
		$imageHashTags.Add("Name", $imageName)
	}
	$imageDescription = "Nightly Build $dateTime, $build"
	$imageHashTags.Add("Description", $imageDescription)
	$dateTime = Get-Date -Format u
	$imageHashTags.Add("CreateDate", $dateTime)
	$newImageId = New-Image $ec2Client $invokedInstanceId $imageName $imageDescription $build $imageHashTags
	Write-Host "newImageId=$newImageId"
	
	## terminate the instance create (i.e. delete the instance from the list; aka clean up)
	Write-Host "Deleting newly created instance - clean up process."
	$terminateResponse = Terminate-Instance $ec2Client $invokedInstanceId

	Write-Host "New Golden Image Id $newImageId"
	return $newImageId
}

## New-BootstrapImage
##  this function orchestrates the creation of a new base image from an AWS image,
##  creating a new instance, boot strapping the instance and finally creating a
##  new base Image from the bootstrapped instance.
## Parameters
##  $ec2Client          - Amazon EC2 Client
##  $baseImageId        - the base image to create an instance from
##  $keyPairName        - name of the Key Pair to use to start the instance
##  $instanceProfileArn - the IAM profile
##  $userdata           - user-data to be passed to the instance, e.g. bootstrap instructions
##  $imageHashTags      - set of name value pairs to add as meta data to the image 
function New-BaseImage([Amazon.EC2.AmazonEC2Client]$ec2Client, [String]$baseImageId, [String]$keyPairName, [String]$instanceProfileArn, [String]$userdata, [HashTable]$imageHashTags)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Error "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received $local:ec2Client"
		return
	}
	## create a new running instance from the base image
	Write-Host "Creating new instance from base image"
	$invokedInstanceId = Invoke-SingleInstance $local:ec2Client $baseImageId $keyPairName $userdata $instanceProfileArn
	
	## check if the instance is ready to use
	Write-Host "waiting for the instance to be available before proceeding..."
	$waitInstanceResponse = WaitFor-InstanceAvailability $local:ec2Client $invokedInstanceId
		
	## try to set the tags on the instance before it shutsdown
	Write-Host "Setting instance Tag metadata"
	[String]$dateTime = Get-Date -Format yyyyMMddhhmm
	[HashTable]$local:hashTags = @{"Name"=[String]::Format("DailyBuild_{0}", $dateTime); "Environment"="BUILD"; "BootType" = "RunInstance"; }
	$local:tagResponse = New-Tags $ec2Client $invokedInstanceId $local:hashTags
		
	## Wait for the instance to stop - should stop after it has been sysprep'd
	Write-Host "Waiting for the instance to stop"	
	$waitStopInstanceResponse = WaitFor-InstanceStopped $local:ec2Client $invokedInstanceId
	
	## create an image from the instance and when it is available, set the 'Tag' Metadata	
	Write-Host "Creating a new image from stopped instance"
	$imageName = [String]::Format("BaseImage_{0}",$dateTime)
	
	if ($imageHashTags.Contains("Name"))
	{
		$imageHashTags["Name"] = $imageName
	}
	else
	{
		$imageHashTags.Add("Name", $imageName)
	}
	$imageDescription = "Base Image Build $dateTime"
	$imageHashTags.Add("Description", $imageDescription)
	$dateTime = Get-Date -Format u
	$imageHashTags.Add("CreateDate", $dateTime)
	$newImageId = New-Image $ec2Client $invokedInstanceId $imageName $imageDescription $dateTime $imageHashTags
	Write-Host "newImageId=$newImageId"
	
	## terminate the instance create (i.e. delete the instance from the list; aka clean up)
	Write-Host "Deleting newly created instance - clean up process."
	$terminateResponse = Terminate-Instance $ec2Client $invokedInstanceId

	Write-Host "New Base Image Id $newImageId"
	return $newImageId
}

## WaitFor-ImageAvailability
##  get information about the image, and check that the image is available and ready to be used
## Parameters:
##  $ec2Client - Amazon EC2 Client
##  $imageId   - the unique Id of the image
function WaitFor-ImageAvailability([Amazon.EC2.AmazonEC2Client]$ec2Client, [String]$imageId)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Error "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received $local:ec2Client"
		return
	}	
	$local:counter = 0
	$local:response = Get-ImageDescription $ec2Client $imageId

	$DefaultNumberOfCallsBeforeTimeoutForImage = $DefaultNumberOfCallsBeforeTimeout * 4
	
	while($local:response.DescribeImagesResult.Image[0].ImageState -ne "available" -and $local:counter -le $DefaultNumberOfCallsBeforeTimeoutForImage)
	{
        if ($local:response.DescribeImagesResult.Image[0].ImageState -eq "available")
        { 
			return $true
            $local:counter = $DefaultNumberOfCallsBeforeTimeoutForImage + 1;
        }
		Start-sleep -Seconds $DefaultSleepInSeconds
		$local:response = Get-ImageDescription $local:ec2Client $imageId
		$local:counter = $local:counter + 1
	}
	if ($local:response.DescribeImagesResult.Image[0].ImageState -ne "available")
	{
		return $false
	}
	return $true
}

## Get-ImageDescription
##  get information about the image, e.g. if it is avaiable, i.e. ready to be used
## Parameters:
##  $ec2Client - Amazon EC2 Client
##  $imageId   - the unique Id of the image 
function Get-ImageDescription([Amazon.EC2.AmazonEC2Client]$ec2Client, [String]$imageId)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Error "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received $local:ec2Client"
		return
	}	
	$describeImagesRequest = New-Object -TypeName Amazon.EC2.Model.DescribeImagesRequest
	$imageIdList = New-Object -TypeName System.Collections.Generic.List[String]
	$imageIdList.Add($imageId)
	$describeImagesRequest.ImageId = $imageIdList
	$describeImageResponse = $ec2Client.DescribeImages($describeImagesRequest)	
	return $describeImageResponse
}

## Get-InstanceStatusDescription
##  Get the meta data about the status of the instance, e.g. status
## Parameters:
##  $ec2Client   - Amazon EC2 Client
##  $instanceIds - an array of instance Id
function Get-InstanceStatusDescription([Amazon.EC2.AmazonEC2Client]$ec2Client, [String[]] $instanceIds)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Error "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received $local:ec2Client"
		return
	}	
	$describeInstanceStatusRequest = New-Object -TypeName Amazon.EC2.Model.DescribeInstanceStatusRequest
	if (! (IsNullOrEmpty $instanceIds))
	{
		$describeInstanceStatusRequest.InstanceId = Get-IdsFromParameterList $instanceIds
	}
	$describeInstanceStatusResponse = $ec2Client.DescribeInstanceStatus($describeInstanceStatusRequest)
	return $describeInstanceStatusResponse
}

## Get-InstanceDescription
##  et the metadata about the instance
## Parameters:
##  $ec2Client   - Amazon EC2 Client
##  $instanceIds - an array of instance Id
function Get-InstanceDescription([Amazon.EC2.AmazonEC2Client]$ec2Client, [String[]] $instanceIds)
{
	$describeInstancesRequest = New-Object -TypeName Amazon.EC2.Model.DescribeInstancesRequest
	if (! (IsNullOrEmpty $instanceIds))
	{
		$describeInstancesRequest.InstanceId = Get-IdsFromParameterList $instanceIds
	}
	$response = $ec2Client.DescribeInstances($describeInstancesRequest)
	return $response
}

## Get-InstanceDnsName
##  the purpose of this function is to be able to get the dns name of the instance
function Get-InstanceDnsName([Amazon.EC2.AmazonEC2Client]$ec2Client, [String]$instanceId)
{
# convert id into list 
	$instanceIds = New-Object -TypeName System.Collections.Generic.List[String]
	$instanceIds.Add[$instanceId]
	$response = Get-InstanceDescription $ec2Client $instanceIds
	if (response.IsSetDescribeInstancesResult -and response.DescribeInstancesResult.IsSetReservation -and response.DescribeInstancesResult.Reservation[0].IsSetRunningInstance)
    {
        return response.DescribeInstancesResult.Reservation[0].RunningInstance[0].PrivateDnsName
    }
	return ""
}


## Get-VolumeDescription
##  get the metadata about each volume id, e.g. size, if it is in use, if attached, etc
## Parameters:
##  $ec2Client - Amazon EC2 Client
##  $volumeIds - an array of volume Ids
function Get-VolumeDescription([Amazon.EC2.AmazonEC2Client] $ec2Client, [String[]] $volumeIds)
{
	$describeVolumeRequest = New-Object -TypeName Amazon.EC2.Model.DescribeVolumesRequest
	if (! (IsNullOrEmpty $volumeIds))
	{
		$describeVolumeRequest.VolumeId = Get-IdsFromParameterList $volumeIds
	}
	$volumesResponse = $ec2Client.DescribeVolumes($describeVolumeRequest)
	return $volumesResponse
}

## WaitFor-InstanceAvailability
##  get information about the instance, and check that the instance is available and ready to be used
## Parameters:
##  $ec2Client - Amazon EC2 Client
##  $imageId   - the unique Id of the image
function WaitFor-InstanceAvailability([Amazon.EC2.AmazonEC2Client]$ec2Client, [String]$instanceId)
{
	[Bool]$result = $true ;
	[Array]$allowedStatus = @("pending", "stopped");
	$result =  WaitFor-InstanceState -ec2Client $ec2Client -awsInstanceId $instanceId -successfulStatus "running" -allowedStatus $allowedStatus -counterTimeout $ExtendedNumberOfCallsBeforeTimeout
	if ($result)
	{
		$result = Waitfor-InstanceHealthChecksPassed -ec2Client $ec2Client -awsInstanceId $instanceId -counterTimeout 100
	}
	return $result
}

<#
	.SYNOPSIS
	    Get information about the instance, and check that the instance has stopped
	.PARAMETER ec2Client
		Amazon Elastic Cloud Computing security Token
	.PARAMETER instanceId
		instance ID to check state
    .OUTPUTS
    	True - success / false - timeout (or unexpected state)
	.NOTES
	    Author: Mark Nelson 
	    Date:   06/10/2012
#>
function WaitFor-InstanceStopped([Amazon.EC2.AmazonEC2Client]$ec2Client, [String]$instanceId)
{
	[array]$allowedStatus = @("stopping", "running");
	return WaitFor-InstanceState -ec2Client $ec2Client -awsInstanceId $instanceId -successfulStatus "stopped" -allowedStatus $allowedStatus -counterTimeout $ExtendedNumberOfCallsBeforeTimeout
}

## New-CloudFormationTemplate
##  Creates Cloud Formation (CF) script as a text file with hard coded AMI ID of Golden Image and Version.
## Parameters get must be the first lineboots or else will result in parameter not found error
##  $cfClient         - 
##  $sourceCfTemplate - specifies the source path and filename for the cloud formation template with specific markers, which need to be replaced
##  $destinationPath  - specifies the destination path for the new cloud formation script
##  $templateCFOut    - the generated cloud formation template with replaced token markers
##  $hashReplacerTags - hash table containing token to be replaced and the value replacing the token
function New-CloudFormationTemplate([Amazon.CloudFormation.AmazonCloudFormationClient] $cfClient, [String] $sourceCfTemplate, [String] $destinationPath, [String] $templateCFOut, [HashTable] $hashReplacerTags)
{
	##Start point
	Write-Host "Start changing the template with replacing the hash keys for hash values in the template text file"

	## the hash contain any key pair
	if (($hashReplacerTags -eq $null) -or ($hashReplacerTags.Count -lt 1))
	{
		Write-Error "Invalid hash table"
		return $false
	}
	
	## check that the source file exists
	if (!(Test-Path $sourceCfTemplate))
	{
		Write-Error "Source cloud formation template file, $sourceCfTemplate, does not exist"
		return $false
	}
	
	##Check that the destination folder exists, if not create it
	if (!(Test-Path $destinationPath))
	{
		New-Item $destinationPath -ItemType Directory
	}
	
	try
	{
		## Read file from source path
		[String[]]$templateContents = [IO.File]::ReadAllLines($sourceCfTemplate)

		##Check if input template is valid
		$isValidCF = Validate-CloudFormationTemplate $cfClient $templateContents ""
		if(! $isValidCF)
		{
			Write-Error "CloudFormation template is invalid."
			return $false
		}
		
		##Replacing the markers in the text file
		$templateContents = Replace-TokenInString $templateContents $hashReplacerTags
		
		##Check if template is valid
		$isValidCF = Validate-CloudFormationTemplate $cfClient $templateContents ""
		if(! $isValidCF)
		{
			Write-Error "CloudFormation template is invalid."
			return $false
		}
		
		$destinationFileName = Join-Path -Path $destinationPath -ChildPath $templateCFOut
	
		## Write the template to destination, overwrite contents if it already exists
		[IO.File]::WriteAllLines($destinationFileName, $templateContents)
		
		return $true
	}
	catch
	{
		## Print error and return false
		Write-Error $_
		return $false
	}
	return
}

function Publish-SnsTopic($snsClient, [String]$snsArn, [String]$subject, [String]$message)
{
	$publishTopicRequest = New-Object -TypeName Amazon.SimpleNotificationService.Model.PublishRequest
	$publishTopicRequest = $publishTopicRequest.WithTopicArn($snsArn).WithSubject($subject).WithMessage($message)
	$snsClient.Publish($publishTopicRequest)
}

function Get-SqsMessages($sqsClient, [String]$queueUrl)
{
	$receiveMessageRequest = New-Object -TypeName Amazon.SQS.Model.ReceiveMessageRequest
	$receiveMessageRequest = $receiveMessageRequest.WithQueueUrl($queueUrl)
	$receiveMessageResponse = $sqsClient.ReceiveMessage($receiveMessageRequest)
	$currentMessages = $receiveMessageResponse.ReceiveMessageResult.Message
	return ,$currentMessages
}

function Delete-SqsMessages($sqsClient, [String]$queueUrl, $messages)
{
	$deleteMessageBatchEntries = New-Object -TypeName System.Collections.Generic.List[Amazon.SQS.Model.DeleteMessageBatchRequestEntry]
	
	foreach ($message in $messages)
	{
		$deleteMessageBatchEntry = New-Object -TypeName Amazon.SQS.Model.DeleteMessageBatchRequestEntry
		$deleteMessageBatchEntry.Id = $message.MessageId
		$deleteMessageBatchEntry.ReceiptHandle = $message.ReceiptHandle
		$deleteMessageBatchEntries.Add($deleteMessageBatchEntry)
	}
	
	$deleteMessageBatchRequest = New-Object -TypeName Amazon.SQS.Model.DeleteMessageBatchRequest
	$deleteMessageBatchRequest = $deleteMessageBatchRequest.WithQueueUrl($queueUrl).WithEntries($deleteMessageBatchEntries.ToArray())
	$sqsClient.DeleteMessageBatch($deleteMessageBatchRequest)
}

## TODO: Use Convert-FromJson once we've moved to PowerShell v3
function Get-SqsMessageBody($sqsMessage)
{
	$messageBody = $sqsMessage.Body.Split(',')[4].Split(':')[1] #Poor man's JSON parsing :)
	return $messageBody
}

<#
	.SYNOPSIS
	    Get the generated password for an instance, based on the security key-pair
    .OUTPUTS
    	Returns Decrypted password
	.NOTES
		TODO: Merge with 'Get-PasswordData'
#>
function Get-PasswordData($ec2Client, $instanceId, $secretKey)
{
	$getPasswordDataRequest = New-Object -TypeName Amazon.Ec2.Model.GetPasswordDataRequest
	$getPasswordDataRequest.InstanceId = $instanceId
	$response = $ec2Client.GetPasswordData($getPasswordDataRequest)
	
	if (response.GetPasswordDataResult.PasswordData.IsSetData)
    {
	    $result = $response.GetPasswordDataResult.GetDecryptedPassword($secretKey)
    }
	return $result
}

<#
	.SYNOPSIS
	    Get the generated password for an instance, based on the security key-pair
    .OUTPUTS
    	Returns Decrypted password
	.NOTES
		TODO: Merge with 'Get-PasswordData'
#>
Function Get-InstancePasswordEc2 
{
    Param 
	(
        [Parameter(Mandatory=$false)][Alias('client')][Alias('c')][Amazon.EC2.AmazonEC2Client] # Amazon Elastic Cloud Computing security Token. (if not supplied, will use the current session credentials)
			$ec2Client = (. New-Ec2Client)
        , [Alias('i')][Alias('id')][String] # a running or stopped amazon machine instance
			$InstanceId
		, [Parameter(Mandatory=$true)][Alias('p')][String]				# A private key file(.PEM) that belongs to the security keypair associated with the instance. Or contents of the file.
			$PemFile
		, [Bool]
			$doReportErrors = $true
    )
	try
	{	
		$local:ec2PasswordDataRequest = New-Object -TypeName Amazon.EC2.Model.GetPasswordDataRequest
		$local:ec2PasswordDataResponse =  New-Object -TypeName Amazon.EC2.Model.GetPasswordDataResponse
		$local:ec2PasswordDataResult =  New-Object -TypeName Amazon.EC2.Model.GetPasswordDataResult 
		$local:ec2PasswordDataRequest.InstanceId = Get-IdsFromParameterList $InstanceId
		$local:ec2PasswordDataResponse = $ec2Client.GetPasswordData($local:ec2PasswordDataRequest)
		$local:ec2PasswordDataResult = $local:ec2PasswordDataResponse.GetPasswordDataResult
		if ($PemFile -like  "*.PEM")
		{
			$keyPairFileData = (Get-Content $PemFile | out-string)		
		}
		else
		{
			$keyPairFileData = $PemFile
		}
		$instancePassword = $local:ec2PasswordDataResult.GetDecryptedPassword($keyPairFileData) 
	}
	catch
	{
		$exception = $_.Exception
		if ($($exception) -like "*Bad Length.*")
		{
			if ($doReportErrors)
			{
				Write-FormattedError -exception $exception `
					-errorReason "Instance not fully available yet for signing in." `
					-recommendedAction "Wait for a few minutes and attempt to get the password again" 
			}
		}
		else
		{
			Write-FormattedError -exception $exception
		}
		$instancePassword = ""
	}
	return $instancePassword
}

<#
	.SYNOPSIS
	    Look for text in particular tags for images
    .OUTPUTS
    	Returns AMIImageId(s)
#>
function Find-ImageByTag
{
	param(
		  [Amazon.EC2.AmazonEC2Client]	# Amazon Elastic Cloud Computing Security Token.
			$ec2Client  = (. New-Ec2Client)							
		, [String]						# Tag to look for
			$tagName = "Name"
		, [String]						# String to search for
			$tagTextToFind
		, [Bool]						# is the string a wildcard
			$doWildCardSearch = $true	
		, [Bool]						# With similar names - pick out the latest based on the tag looked for (in alphabetical order
			$doFindHighest = $false
	)
	[String]$foundOn = "tag"
	[array]$amiImageIds = @();
	if ($doWildCardSearch)
	{	
		$tagTextToFind = "*{0}*" -f $tagTextToFind
	}
	$ec2Filter = New-Object -TypeName Amazon.EC2.Model.Filter -Property @{
 	 	WithName = 'tag:' + $tagName
	    WithValue = $tagTextToFind
	 } 
	$describeImagesRequest = New-Object -TypeName Amazon.EC2.Model.DescribeImagesRequest -Property @{
		WithFilter = $ec2Filter
	 }
	$describeImagesResult =  $ec2Client.DescribeImages($describeImagesRequest)
	if ($describeImagesResult.DescribeImagesResult.Image.Count -eq 0) ## if no items returned - try description field
	{
		$foundOn = "description"
		$ec2Filter = New-Object -TypeName Amazon.EC2.Model.Filter -Property @{
	 	 	WithName = 'description'
		    WithValue = $tagTextToFind
		 } 
		$describeImagesRequest = New-Object -TypeName Amazon.EC2.Model.DescribeImagesRequest -Property @{
			WithFilter = $ec2Filter
		 }
		$describeImagesResult =  $ec2Client.DescribeImages($describeImagesRequest)
	}
	if ($describeImagesResult.DescribeImagesResult.Image.Count -eq 0) ## if no items returned - try Image Name field
	{
		$foundOn = "name"
		$ec2Filter = New-Object -TypeName Amazon.EC2.Model.Filter -Property @{
	 	 	WithName = 'name'
		    WithValue = $tagTextToFind
		 } 
		$describeImagesRequest = New-Object -TypeName Amazon.EC2.Model.DescribeImagesRequest -Property @{
			WithFilter = $ec2Filter
		 }
		$describeImagesResult =  $ec2Client.DescribeImages($describeImagesRequest)
	}
	## Obtain list of filtered images
	$label=""
	
	Foreach ($item in $describeImagesResult.DescribeImagesResult.Image)
	{
		if ($doFindHighest)
		{
			switch ($foundOn)
			{
				"tag" {	
						$checkValue =($item.Tag | Where-Object { $_.Key -eq "$tagName" }).Value
						#$item.SelectSingleNode("/Tag/item[@key='$tagName']")
						if ($label -lt $checkValue) 
							{
								$label = $checkValue
								$amiImageId = $item.ImageID
							}
					}
				"description" {
						if ($label -lt $item.Description) 
							{
								$label = $item.Description
								$amiImageId = $item.ImageID
							}
					}
				"name" { 
						if ($label -lt $item.Name) 
							{
								$label = $item.Name
								$amiImageId = $item.ImageID
							}
					}
			}
		}
		else
		{
			$amiImageIds += $item.ImageID
		}
	}
	if ($doFindHighest)
	{
		$amiImageIds = @($amiImageId)
	}
	return $amiImageIds
}

<#
	.SYNOPSIS
	    gets id or AMIimage name or description. 
    .OUTPUTS
    	ImageId
#>
function Get-ImageIdFromNameOrId
{
	param(
		[Amazon.EC2.AmazonEC2Client]			# Amazon Elastic Cloud Computing Security Token.
			$ec2Client  = (. New-Ec2Client)
		, [Parameter(Mandatory=$true)][String]	# Passed in AMIID or Name/Description
			$amiNameOrId
		, [Bool]								# Allow multiple instances to be returned
			$doAllowMultipleResults = $false		
		)
	## Detect if passed-in variable is name or ID
	if (! ( $amiNameOrId.StartsWith("ami-") ))
	{
		if ($doAllowMultipleResults)
		{	
			$amiBaseImage = Find-ImageByTag -ec2Client $ec2Client -tagTextToFind $amiNameOrId 
		}
		else
		{	
			$amiBaseImage = Find-ImageByTag -ec2Client $ec2Client -tagTextToFind $amiNameOrId -doFindHighest $true
		}
		if (IsNullOrEmpty($amiBaseImage))
		{
			Write-Host "Unable to find an image including: $amiNameOrId"
			$amiBaseImageId = ""
		}
		else
		{
			if ( ($amiBaseImage.Count -gt 1) -and ( $doAllowMultipleResults -eq $false) )
			{
				Write-Host "More than 1 image matched the criteria you supplied. Using 1st entry. List: $amiBaseImage"
				$amiBaseImageId = $amiBaseImage[0]
			}
			else
			{
				$amiBaseImageId = $amiBaseImage
			}
		}
	}
	else
	{
		$amiBaseImageId = $amiNameOrId
	}
	return $amiBaseImageId
}

<#
	.SYNOPSIS
	    Look for text in particular tags for instance
    .OUTPUTS
    	Returns awsInstanceId(s)
	.NOTES
		TODO: Merge with 'Find-InstanceByType' 
#>
function Find-InstanceByTag
{
	param(
		  [Amazon.EC2.AmazonEC2Client]			# Amazon Elastic Cloud Computing Security Token.
			$ec2Client  = (. New-Ec2Client)							
		, [String]								# Tag to look for
			$tagName = "Name"
		, [Parameter(Mandatory=$true)][String]	# String to search for
			$tagTextToFind
		, [Bool]								# is the string a wildcard
			$doWildCardSearch = $true	
		, [ValidateSet("","Running","Stopped")][String]	# State that instance is in
			$instanceState
		, [Bool]								# Ignore any instances in the terminated state
			$doIgnoreTerminated = $true
	)
	
	[array]$instanceIds = @();
	if ($doWildCardSearch)
	{	
		$tagTextToFind = "*{0}*" -f $tagTextToFind
	}
	$ec2Filter = New-Object -TypeName Amazon.EC2.Model.Filter -Property @{
 	 	WithName = 'tag:' + $tagName
	    WithValue = $tagTextToFind
	 } 
	$describeInstancesRequest = New-Object -TypeName Amazon.EC2.Model.DescribeInstancesRequest	-Property @{
		WithFilter = $ec2Filter
	 }
	$describeInstancesResult =  $ec2Client.DescribeInstances($describeInstancesRequest)

	# Obtain list of filtered instances
	Foreach ($item in $describeInstancesResult.DescribeInstancesResult.Reservation)
	{
		$itemState = $item.RunningInstance.Item(0).InstanceState.Name ;
		if (!($doIgnoreTerminated -and ($itemState -eq "terminated")))
		{
			if (($itemState -eq $instanceState) -or ($instanceState -eq ""))
			{
				$instanceIds += $item.RunningInstance.Item(0).InstanceId
			}
		}
	}
	return $instanceIds
}

<#
	.SYNOPSIS
	    gets id from instance name or description. 
    .OUTPUTS
    	ImageId
#>
function Get-InstanceIdFromNameOrId
{
	param(
		[Amazon.EC2.AmazonEC2Client]			# Amazon Elastic Cloud Computing security token.
			$ec2Client  = (. New-Ec2Client)
		, [Parameter(Mandatory=$true)][String]	# Passed in instanceID or Name/Description
			$instanceNameOrId
		, [Bool]								# Allow multiple instances to be returned
			$doAllowMultipleResults = $false
		)
	## Detect if passed-in variable is name or ID
	if (! ( $instanceNameOrId.StartsWith("i-") ))
	{
		$instanceIds = Find-InstanceByTag -ec2Client $ec2Client -tagTextToFind $instanceNameOrId 
		if (IsNullOrEmpty($instanceIds))
		{
			Write-Host "Unable to find an instance including: $instanceNameOrId"
			$instanceId = ""
		}
		else
		{
			if ( ($instanceIds.Count -gt 1) -and ( $doAllowMultipleResults -eq $false) )
			{
				Write-Host "More than 1 image matched the criteria you supplied. Using 1st entry. List: $instanceIds"
				$instanceId = $instanceIds[0]
			}
			else
			{
				$instanceId = $instanceIds
			}
		}
	}
	else
	{
		$instanceId = $instanceNameOrId
	}
	return $instanceId
}

<#
	.SYNOPSIS
	    Terminate stack 
    .OUTPUTS
    	True - success / false
#>
function Terminate-Stack
{
	param(	
		[Amazon.CloudFormation.AmazonCloudFormationClient]	# Amazon Cloud Formation Security Token
			$cfClient
		, [String]											# name of the cloud formation stack 
			$stackName
	)
	$request =  New-Object -TypeName Amazon.CloudFormation.Model.DeleteStackRequest -Property @{
		withStackName = $stackName 
	}
	$result = $cfClient.DeleteStack( $request )
}

<#
	.SYNOPSIS
	    Get event log from stack 
    .OUTPUTS
    	array containing log of events
#>
function Get-StackEventLog
{
	param(	
		[Amazon.CloudFormation.AmazonCloudFormationClient]	# Amazon Cloud Formation Security Token
			$cfClient
		, [String]											# name of the cloud formation stack 
			$stackName
	)
	$describeStacksRequest =  New-Object -TypeName Amazon.CloudFormation.Model.DescribeStackEventsRequest -Property @{
		withStackName = $stackName 
	}
	
	$array = @()
	$stackEvents = $cfClient.DescribeStackEvents($describeStacksRequest)
	foreach ($event in $stackEvents.DescribeStackEventsResult.StackEvents)
	{
		$obj = New-Object PSObject
        $obj | Add-Member -MemberType NoteProperty -Name "EventId" -Value $($event.eventId)
        $obj | Add-Member -MemberType NoteProperty -Name "TimeStamp" -Value $($event.timestamp)
        $obj | Add-Member -MemberType NoteProperty -Name "ResourceStatus" -Value $($event.ResourceStatus)
        $obj | Add-Member -MemberType NoteProperty -Name "LogicalResourceId" -Value $($event.LogicalResourceId)
        $obj | Add-Member -MemberType NoteProperty -Name "PhysicalResourceId" -Value $($event.PhysicalResourceId)
        $obj | Add-Member -MemberType NoteProperty -Name "ResourceStatusReason" -Value $($event.ResourceStatusReason)
        $array += $obj
	}
	$array =  ($array | sort-object -property TimeStamp, EventId -Unique )
	return $array
}

<#
	.SYNOPSIS
	    Get list of stacks that match the name
    .OUTPUTS
    	array containing list of stacknames that match
#>
function Find-StackByName
{
	param (
		[Amazon.CloudFormation.AmazonCloudFormationClient]	# Amazon Cloud Formation Security Token
			$cfClient
		, [String]											# name of the cloud formation stack (allows partial matches)
			$nameToFind
	)
	$nameToFind = "*{0}*" -f $nameToFind
	$result = @()
	$resultList = $cfClient.ListStacks()
	foreach ($item in $resultList.ListStacksResult.StackSummaries)
	{
		if ($item.StackStatus -ne "DELETE_COMPLETE")
		{
			if ($item.StackName -like $nameToFind)
			{
				$result += $item.StackName
			}
		}
	}
	return $result
}

<#
	.SYNOPSIS
	    Get the output list from a CloudFormation Stack
    .OUTPUTS
    	array containing log of outputs
#>
function Get-StackOutputList
{
	param(
		[Amazon.CloudFormation.AmazonCloudFormationClient]	# Amazon Cloud Formation Security Token
			$cfClient
		, [String]											# name of the cloud formation stack 
			$stackName
	)
	Try
	{
		$describeStacksRequest = New-Object -TypeName Amazon.CloudFormation.Model.DescribeStacksRequest -Property @{
			withStackName = $stackName
		}
		$response = $cfClient.DescribeStacks($describeStacksRequest)
		$result = $true
	}
	catch
	{
		Write-Host "failed to read the stack output.`n $_.Exception."
		$result = $false
	}
	
	$array = @()
	if ($result)
	{
		foreach ($output in $response.DescribeStacksResult.Stacks.item(0).Outputs)
		{
			$obj = New-Object PSObject
	        $obj | Add-Member -MemberType NoteProperty -Name "OutputKey" -Value $($output.OutputKey)
	        $obj | Add-Member -MemberType NoteProperty -Name "OutputValue" -Value $($output.OutputValue)
	        $obj | Add-Member -MemberType NoteProperty -Name "Description" -Value $($output.Description)
	        $array += $obj
		}
		$array =  ($array | sort-object -property OutputKey -Unique )
	}
	return $array
}

<#
	.SYNOPSIS
	    Get the resource list from a CloudFormation Stack
    .OUTPUTS
    	array containing log of resources
#>
function Get-StackResourceList
{
	param(
		[Amazon.CloudFormation.AmazonCloudFormationClient]	# Amazon Cloud Formation Security Token
			$cfClient
		, [String]											# name of the cloud formation stack 
			$stackName
		, [String] [ValidateSet("","CREATE_COMPLETE","DELETE_COMPLETE")]
			$stackStatus = ""
	)
	$local:request = New-Object -TypeName Amazon.CloudFormation.Model.ListStackResourcesRequest -Property @{
		withStackName = $stackName
	}
	$response = $cfClient.listStackResources($local:request)
	$array = @()
	foreach ($resource in $response.ListStackResourcesResult.StackResourceSummaries)
	{
		if ($resource.ResourceStatus -Match $stackStatus)
		{
			$obj = New-Object PSObject
	        $obj | Add-Member -MemberType NoteProperty -Name "LogicalResourceId" -Value $($resource.LogicalResourceId)
	        $obj | Add-Member -MemberType NoteProperty -Name "PhysicalResourceId" -Value $($resource.PhysicalResourceId)
	        $obj | Add-Member -MemberType NoteProperty -Name "ResourceType" -Value $($resource.ResourceType)
	        $obj | Add-Member -MemberType NoteProperty -Name "ResourceStatus" -Value $($resource.ResourceStatus)
	        $obj | Add-Member -MemberType NoteProperty -Name "ResourceStatusReason" -Value $($resource.ResourceStatusReason)
	        $array += $obj
		}
	}
	$array =  ($array | sort-object -property PhysicalResourceId -Unique )
	return $array
}

<#
	.SYNOPSIS
	    Check that a cloud stack is in the desired state
    .OUTPUTS
    	True - success / false - timeout (or unexpected state)
#>
function WaitFor-StackState
{
	param 
	(
		[Amazon.CloudFormation.AmazonCloudFormationClient]	# Amazon Cloud Formation Security Token
			$cfClient
		, [String] 											# Name of stack we are waiting for
			$stackName
		, [String]											# Desired end state for success
			$successfulStatus
		, [array]											# Allowed transition states 
			$allowedStatus
		, [array]											# Failure states 
			$failedStatus
		, [int] 											# Number of loops to try before exiting 
			$counterTimeout = $DefaultNumberOfCallsBeforeTimeout
	)
	[bool]$result = $false
	
	## Wait for status to be set
	while( ($counterTimeout -ge 0) )
	{
		$describeStacksRequest = New-Object -TypeName Amazon.CloudFormation.Model.DescribeStacksRequest -Property @{
			withStackName = $stackName
		}
		try
		{
			$response = $cfClient.DescribeStacks($describeStacksRequest)
		}
		catch
		{
			if ($successfulStatus -ne ".")
			{
				Write-Host "The stack: " -NoNewline -ForegroundColor Blue
				Write-Host "$stackName" -NoNewline -ForegroundColor DarkBlue
				Write-Host " does not exist." -ForegroundColor Blue
			}
			$result = $true
			break ;
		}
		
		$runningInstance = $response.DescribeStacksResult.Stacks.item(0) #Get metadata about specific running instance
		$currentStatus = $runningInstance.StackStatus ;
		if ( $successfulStatus -eq $currentStatus )
		{
			$result = $true ;
			break ;
		}
		if (($failedStatus -contains $currentStatus ))
		{
			Write-Host $allowedStatus.count
			Write-Host "Failed status: '$currentStatus' found while waiting for $successfulStatus" -ForegroundColor DarkRed
			break ;
		}
		
		if (!($allowedStatus -contains $currentStatus ) -and ($successfulStatus -ne $currentStatus ))
		{
			Write-Host $allowedStatus.count
			Write-Error "Unexpected status: '$currentStatus' found while waiting for $successfulStatus"
			break ;
		}
		Start-sleep -Seconds $DefaultSleepInSeconds ;
		$counterTimeout-- ;
	}
	if ($counterTimeout -le 0)
	{
		Write-Host " Timeout occurred while waiting for stack."
	}
	return $result ; 
}

<#
	.SYNOPSIS
	    Check that a cloud stack has been deleted
    .OUTPUTS
    	True - success / false - timeout (or unexpected state)
#>
function WaitFor-StackDeleted
{
	param 
	(
		[Amazon.CloudFormation.AmazonCloudFormationClient] 	# Cloud Formation security Token
		  	$cfClient
		, [String]											# name of the cloud formation stack 
			$stackName
		, [int] 											# Number of loops to try before exiting 
			$counterTimeout = $DefaultNumberOfCallsBeforeTimeout
	)
	[Array] $allowedStatus = @("DELETE_IN_PROGRESS")	
	$successfulStatus = "."
	return WaitFor-StackState $cfClient $stackName -successfulStatus $successfulStatus -allowedStatus $allowedStatus -counterTimeout $counterTimeout 
}

<#
	.SYNOPSIS
	    Check that a cloud stack has been created
    .OUTPUTS
    	True - success / false - timeout (or unexpected state)
#>
function WaitFor-StackCreated
{
	param 
	(
		[Amazon.CloudFormation.AmazonCloudFormationClient] 	# Cloud Formation security Token
		  	$cfClient
		, [String]											# name of the cloud formation stack 
			$stackName
		, [int] 											# Number of loops to try before exiting 
			$counterTimeout = $DefaultNumberOfCallsBeforeTimeout
	)
	[Array] $allowedStatus = @("CREATE_IN_PROGRESS")
	[Array] $failedStatus = @("ROLLBACK_IN_PROGRESS","ROLLBACK_COMPLETE")
	$successfulStatus = "CREATE_COMPLETE"
	return WaitFor-StackState $cfClient $stackName -successfulStatus $successfulStatus -allowedStatus $allowedStatus -failedStatus $failedStatus -counterTimeout $counterTimeout
}

<#
	.SYNOPSIS
	    Terminate and wait for stack and write out log
    .OUTPUTS
    	True - success / false
#>
function Terminate-StackWaitAndOutputLog
{
	param(	
		[Amazon.CloudFormation.AmazonCloudFormationClient]	# Amazon Cloud Formation Security Token
			$cfClient
		, [String]											# name of the cloud formation stack 
			$stackName
		, [int] 											# Number of loops to try before exiting 
			$counterTimeout = $DefaultNumberOfCallsBeforeTimeout
	)
	$result = $true
	[Array] $matchedStacks = Find-StackByName $cfClient $stackName
	if ($matchedStacks.Count -gt 0)
	{
		Write-Host "Dump the existing stack log for: $stackName"
		Get-StackEventLog $cfClient $stackName | Select TimeStamp, ResourceStatus, LogicalResourceId, ResourceStatusReason | ft -Wrap | out-host
		
		Write-Host "Terminate the existing stack: $stackName"
		Terminate-Stack $cfClient $stackName
		if (!(WaitFor-StackDeleted -cfClient $cfClient -stackName $stackName -counterTimeout $counterTimeout))
		{
			Write-Host "There is a problem deleting the stack. You may need to manually investigate"
			$result = $false
		}
	}
	return $result
}

<#
	.SYNOPSIS
	    Get the console output of the instance (including stdout from userdata)
    .OUTPUTS
    	output of the instance console
#>
function Get-EC2InstanceConsoleOutput
{
	param(
		[Amazon.EC2.AmazonEC2Client]	# Amazon Elastic Cloud Computing Security Token.
			$ec2Client
		, [String]						# instance Id to get the log from 
			$instanceId
	)
	$getConsoleOutputRequest = New-Object -TypeName Amazon.EC2.Model.GetConsoleOutputRequest -Property @{
			withInstanceId = $instanceId
		}
	$response = $ec2Client.GetConsoleOutput( $getConsoleOutputRequest )
	$timestamp = $response.GetConsoleOutputResult.ConsoleOutput.TimeStamp
	$result = Convert-FromBase64 $($response.GetConsoleOutputResult.ConsoleOutput.Output)
	return $result
}

<#
	.SYNOPSIS
	    Create a basic log function for use in the Userdata of an instance. Usage: LU "Text" 
    .OUTPUTS
    	String to add into the top of userdata section of the script. 
	.NOTE
		Since this was written we have used a simplified inline function called: WL
#>
function Log-UserdataFunction
{
	param (
		[String] 
			$filename = "C:\Deploy\userdata.log"
		)
	$result = "Function LU ([Parameter(Position=0, ValueFromPipeline=`$true, ValueFromPipelineByPropertyName=`$true)][String]`$logstring	, [Switch]`$clearFile = `$false)
	{
		if (`$clearFile -eq `$true) {Remove-Item $filename}
		`$logstring = (Get-Date -UFormat `"%Y/%m/%d %T`") + `" `" + `$logstring
		Add-content $filename -value `$logstring -force -PassThru
	}
	"
	return $result
}

<#
	.SYNOPSIS
	    This function will change the instance capabilities of an existing instance
		Note: If instance is currently running - will need to be stopped prior to change
#>
function Set-InstanceTypeOfExistingInstance
{
	param (
		[Parameter(Mandatory=$true)][Amazon.EC2.AmazonEC2Client] 	# Amazon Elastic Cloud Computing security token.
		  	$ec2Client 
		, [string[]] 				 								# Array of stopped instance ids.
		  	$instanceIds
		, [String]													# Size of instance
			$instanceType
	)

	if (! (IsNullOrEmpty $instanceType))
	{
		foreach ($awsInstanceId in $local:instanceIds)
		{
			$local:response = Get-InstanceDescription $local:ec2Client $awsInstanceId
			$runningInstance = $local:response.DescribeInstancesResult.Reservation.Item(0).RunningInstance.Item(0) #Get metadata about specific running instance
			$currentStatus = $runningInstance.InstanceState.Name ;
			$currentInstanceType = $runningInstance.InstanceType ;
			if ( $currentInstanceType -ne $instanceType )
			{
				if ( $currentStatus -eq "running" )
				{
					Stop-Instances $ec2Client $awsInstanceId
					WaitFor-InstanceStopped $ec2Client $awsInstanceId
				}
				$local:request = New-Object -TypeName Amazon.EC2.Model.ModifyInstanceAttributeRequest -Property @{
					InstanceId = $awsInstanceId
				}
				$local:request.Attribute = "instanceType"
				$local:request.Value = $instanceType
				
				$ec2Client.ModifyInstanceAttribute($local:request)
			}
		}
	}
}

<#
	.SYNOPSIS
	    this function will allow you to delete file(s) given a file pattern
#>
function Delete-FilesFromS3
{
	param 
	(
		[Parameter(Mandatory=$true)][Amazon.S3.AmazonS3Client] 	# Amazon Simple Storage Service (s3) Security Token
			$s3client
		, [Parameter(Mandatory=$true)][String] 					# The Amazon Simple Storage service bucket used for file transfer
			$s3BucketName
		, [string[]] 				# file or file pattern to delete in S3, e.g. assets\*.zip; *.ps1
			$filePatternSetToDelete = ""
	)
	
	$listObjectsRequest = New-Object -TypeName Amazon.S3.Model.ListObjectsRequest
	$listObjectsRequest.BucketName = $local:s3BucketName

	try
	{
		$listObjectResponse = $local:s3client.ListObjects($listObjectsRequest)
		foreach ($filePatternToDelete in $filePatternSetToDelete)
		{
			$filePatternToDelete = $filePatternToDelete.Replace("`\","/")
		
			foreach( $s3Object in $listObjectResponse.S3Objects)
			{		
				if ($s3Object.Size -gt 0)
				{
					if ( (IsNullOrEmpty $filePatternToDelete) -or ($s3Object.Key.ToLower().Contains($filePatternToDelete.ToLower()) ))
					{
						Write-Host "removing file from Bucket: $local:s3BucketName ==> $($s3Object.Key)"
						$deleteObjectRequest = New-Object -TypeName Amazon.S3.Model.DeleteObjectRequest 
						$deleteObjectRequest.bucketName = $local:s3BucketName
						$deleteObjectRequest.Key = $s3Object.Key
						[void] $s3client.deleteObject( $deleteObjectRequest);
					}
				}
			}
		}
	}
	catch [Amazon.S3.AmazonS3Exception]
	{	
		Write-Error $_
	}
}

<#
	.SYNOPSIS
	    this function orchestrates part 1 of the creation of a golden image from a base image,
		 creating a new instance and boot strapping the instance. 
    .OUTPUTS
    	Returns Instance Id
#>
function New-InstanceCreationForGoldenImage
{
	param 
	(
		  [Amazon.EC2.AmazonEC2Client]   		# Amazon Elastic Cloud Computing Security Token.
		  	$ec2Client = (. New-Ec2Client)		
		, [Parameter(Mandatory=$true)] [String] # Amazon Machine Image Id to base the Golden Image on
			$amiBaseImage
		, [String]	# name of the key pair to associate with the instance
			$keyPairName	
		, [String] 								# IAM Profile Role described as an Amazon Resource Name (ARN) 
			$iamInstanceProfileArn	 		 
		, [String]								# commands either powershell, scripts or otherwise to be run when the instance is created
			$userdata			
		, [String]								# The instance machine-processor size/type to create
			$instanceType = $DefaultInstanceType	 
		, [System.Collections.Generic.List[String]]	# Security group permissions that the instance can operate in.
			$securityGroupIdList 
		, [String]								# build version information
			$build				 
	)

	$response = $true
	## prepare the tags on the instance
	$buildVersion=$build
	Write-Host "Setting instance Tag metadata"
	$instanceHashTags = @{"Name" = (Get-StringFromTokenizedString($DefaultInstanceName))}
	$instanceHashTags.Add("Team", (Get-StringFromTokenizedString($DefaultTeamName)))
	$instanceHashTags.Add("Environment", "BUILD")
	$instanceHashTags.Add("BootType", "RunInstance")
	$instanceHashTags.Add("Build", $build)

	## create a new running instance from the base image
	Write-Host "Creating new instance from base image"	
	$invokedInstanceId = Invoke-SingleInstance $local:ec2Client $amiBaseImage $keyPairName $userdata $iamInstanceProfileArn $instanceType $securityGroupIdList
	if (! (IsNullOrEmpty $invokedInstanceId))
	{
		## set the tags on the instance
		$local:tagResponse = New-Tags $ec2Client $invokedInstanceId $local:instanceHashTags

		## check if the instance is ready to use
		Write-Host "waiting for the instance to be available before proceeding..."
		$waitInstanceResponse = WaitFor-InstanceAvailability $local:ec2Client $invokedInstanceId
	}
	if ($waitInstanceResponse -eq $false)
	{
		return ""
	}
	else
	{
		return $invokedInstanceId
	}
}

<#
	.SYNOPSIS
	    this function orchestrates part 2 of the creation of a golden image from a base image,
		 creating a new Golden Image from the bootstrapped instance. 
    .OUTPUTS
    	Returns Instance Id
#>
function New-ImageCreationFromInstanceForGoldenImage
{
	param
	(
		  [Amazon.EC2.AmazonEC2Client]   		# Amazon Elastic Cloud Computing security Token
		  	$ec2Client = (. New-Ec2Client)		
		, [String] 								# An AWS instance to create the image from
			$awsInstanceId
		, [String]								# build version information
			$build				 
		, [HashTable]							# set of name value pairs to add as meta data to the image 
			$imageHashTags		 
	)
	## Create the Tag metadata
	$imageName = Get-StringFromTokenizedString($DefaultAmiName)
	$imageDescription = Get-StringFromTokenizedString($DefaultAMIDescription)
	## imageHashTags are supplied by the calling routine
	$imageHashTags.Add("Name", $imageName)
	$imageHashTags.Add("Description", $imageDescription)
	$dateTime = Get-Date -Format u
	$imageHashTags.Add("CreateDate", $dateTime)	
	
	## Stop the instance
	Write-Host "Stopping the newly creating instance before creating image"
	$stopInstanceResponse = Stop-Instances $local:ec2Client $awsInstanceId
	if (! (IsNullOrEmpty $stopInstanceResponse))
	{
		## Wait for the instance to stop
		Write-Host "Waiting for the instance to stop"	
		$waitStopInstanceResponse = WaitFor-InstanceStopped $local:ec2Client $awsInstanceId
		
		## create an image from the instance and when it is available, set the 'Tag' Metadata	
		Write-Host "Creating a new image from stopped instance"	
		$newImageId = New-Image $ec2Client $awsInstanceId $imageName $imageDescription $build $imageHashTags
		if (!( IsNullOrEmpty $newImageId))
		{
			## terminate the instance create (i.e. delete the instance from the list; aka clean up)
			Write-Host "Deleting newly created instance - clean up process."
			$terminateResponse = Terminate-Instance $ec2Client $awsInstanceId
			
			Write-Host "New Golden Image Id: $newImageId"
		}
		else
		{
			Write-FormattedError "Issue creating image from instance. Instanceid: $awsInstanceId left in stopped state for debugging"
		}
	}

	return $newImageId
}

<#
	.SYNOPSIS
	    Add Account sharing permission to an AMI image.
    .OUTPUTS
    	Returns Instance Id
#>
function Add-AccountPermissionToImage
{
	param
	(
		  [Amazon.EC2.AmazonEC2Client]   		# Amazon Elastic Cloud Computing security Token
		  	$ec2Client = (. New-Ec2Client)		
		, [Parameter(Mandatory=$true)] [String]	# Amazon Machine Image Id to base the Golden Image on
			$amiBaseImage	
		, [String[]]							# AWS Account Number to allow image to be shared with
			$awsAccountNumber
	)
	$request = New-Object -TypeName Amazon.EC2.Model.ModifyImageAttributeRequest -Property @{
		ImageId =  $amiBaseImage
		WithAttribute = "launchPermission"
		WithOperationType = "add"
	}
	$request.UserId = $awsAccountNumber
	$response = (!( IsNullOrEmpty($ec2Client.ModifyImageAttribute($request)) ))
	return $response
}

<#
	.SYNOPSIS
	    Get log files generated by golden image creation
    .OUTPUTS
    	Contents of the log files
#>
function Get-LogFilesFromS3
{
	param (
		  [Amazon.S3.AmazonS3Client]		# Amazon Simple Storage Service (s3) Security Token
			$s3Client							
		, [String]							# The Amazon Simple Storage service bucket used for file transfer
			$s3BucketName
		, [String]							# is the path on S3 to fetch the file(s) from
			$s3FolderName
	)
	[String]$logFileContents="" 
	 
	if (IsNullOrEmpty $local:scriptCommonDirectory)
	{ 
		$logDirectory = Join-Path -Path $(get-location) -ChildPath $s3BucketName 
	}
	else
	{
		$logDirectory = Join-Path $scriptCommonDirectory $s3BucketName
	}
	
##	Write-Host "Downloading Logs"
	if ((Get-FileWithFilter $s3Client $s3BucketName  $s3FolderName  $logDirectory))
	{
		Write-Host "Get logs from $s3BucketName . $s3FolderName ==> $logDirectory"
	
		Write-Host "Remove Logs from S3"
		Delete-FilesFromS3 $s3Client $s3BucketName $s3FolderName
		
		Write-Host "Read logfiles in"
		$logFileContents = (Get-MultipleLogFileContents $logDirectory)
		
		Delete-Folder $logDirectory 		
	}
	else
	{	
		Write-Host "Unable to obtain log details"
		$logFileContents = "" 
	}
	return ($logFileContents)
}

<#
	.SYNOPSIS
	    Wait for the log files to get generated
    .OUTPUTS
    	Contents of the log files
#>
function WaitFor-LogFilesFromS3
{
	param (
		[Amazon.S3.AmazonS3Client]	# Amazon Simple Storage Service (s3) Security Token
			$s3Client
		, [String]					# The Amazon Simple Storage service bucket used for file transfer
			$s3BucketName
		, [String]					# is the path on S3 to fetch the file(s) from
			$s3FolderName
	)
	$loopCounter = $DefaultNumberOfCallsBeforeTimeout
	$logFileContents = ""
	While ( ( $loopCounter -ge 0) -and ( $logFileContents -eq "" ) )
	{
		$loopCounter-- ;
		Start-Sleep -Seconds $DefaultSleepInSeconds ; ## Wait for logs to finish writing to the bucket
		
		Write-Host ("Attempting to retrieve logs - Try: {0} of {1}" -f ($DefaultNumberOfCallsBeforeTimeout-$loopCounter), $DefaultNumberOfCallsBeforeTimeout ) ;
		$logFileContents = [String](Get-LogFilesFromS3 $s3Client $s3BucketName $s3FolderName)
	}
	return $logFileContents
}

<#
	.SYNOPSIS
	    get information about the instance, and check that the instance is in the desired state
    .OUTPUTS
    	True - success / false - timeout (or unexpected state)
#>
function WaitFor-InstanceState
{
	param 
	(
		  [Amazon.EC2.AmazonEC2Client]   		# Amazon Elastic Cloud Computing Security Token.
		  	$ec2Client = (. New-Ec2Client)		
		, [String] 								# An AWS instance to create the image from
			$awsInstanceId
		, [String]								# Desired end state for success
			$successfulStatus
		, [array]								# Allowed transition states 
			$allowedStatus
		, [int] 								# Number of loops to try before exiting 
			$counterTimeout = $DefaultNumberOfCallsBeforeTimeout
	)
	[bool]$result = $false
	
	## Wait for status to be set
	while( ($counterTimeout -ge 0) )
	{
		$local:response = Get-InstanceDescription $local:ec2Client $awsInstanceId
		$runningInstance = $local:response.DescribeInstancesResult.Reservation.Item(0).RunningInstance.Item(0) #Get metadata about specific running instance
		$currentStatus = $runningInstance.InstanceState.Name ;
		if ( $successfulStatus -eq $currentStatus )
		{
			$result = $true ;
			break ;
		}
		if (!($allowedStatus -contains $currentStatus ) -and ($successfulStatus -ne $currentStatus ))
		{
			Write-Host $allowedStatus.count
			Write-Error "Unexpected status: '$currentStatus' found while waiting for $successfulStatus"
			break ;
		}
		Start-sleep -Seconds $DefaultSleepInSeconds ;
		$counterTimeout-- ;
	}
	return $result ; 
}

<#
	.SYNOPSIS
	    Wait for a timeout or for healthchecks to be passed
    .OUTPUTS
    	True - success / false - timeout (or unexpected state)
#>
function Waitfor-InstanceHealthChecksPassed
{
	param 
	(
		  [Amazon.EC2.AmazonEC2Client]   		# Amazon Elastic Cloud Computing security Token
		  	$ec2Client = (. New-Ec2Client)		
		, [String] 								# An AWS instance to create the image from
			$awsInstanceId
		, [int] 								# Number of loops to try before exiting 
			$counterTimeout = $DefaultNumberOfCallsBeforeTimeout
	)
	[bool]$result = $false ;
	while ( $counterTimeout -ge 0)
	{
		$local:response = Get-InstanceStatusDescription $local:ec2Client $awsInstanceId
		if (($local:response.DescribeInstanceStatusResult.InstanceStatus[0].SystemStatusDetail.Status -eq "ok")`
			-and ($local:response.DescribeInstanceStatusResult.InstanceStatus[0].InstanceStatusDetail.Status -eq "ok"))
		{
			$result = $true ;
			break ;
		}
		Start-sleep -Seconds $DefaultSleepInSeconds ;
		$counterTimeout-- ;
	}
	return $result
}

<#
	.SYNOPSIS
	    Obtain login information about an AWS instance, and optionally - login via Remote Desktop
    .OUTPUTS
    	Returns true / false
#>
function Get-InstanceLoginInformation
{
	param (
		[Amazon.EC2.AmazonEC2Client] 								# Amazon Elastic Cloud Computing Security Token.
			$ec2Client = (. New-Ec2Client)
		, [Parameter(Mandatory=$true)][String]  					# a list of instances to perform operations on
			$instanceId
		, [Parameter(Mandatory=$true)][String]						# filename containing PGP signature
			$keyPairFileName
		, [Bool]													# Set to true to autostart the RDC
			$AllowAutoStartRDC = $false
		, [Int]														# Number of times to attempt getting connection before failing: Default=0
			$retryCount = 0
			
	)
	
	## login to remote desktop
	$result = $true
	[Bool]$logErrors = ($retryCount -eq 0)
		
	$instanceMetaData = Get-InstanceDescription $ec2Client $instanceId
	try 
	{
		$runningInstance = $instanceMetaData.DescribeInstancesResult.Reservation.Item(0).RunningInstance.Item(0) #Get metadata about specific running instance
		if ($runningInstance.InstanceState.Name -eq "running")
		{
			$loginAddress = $runningInstance.PublicDNSName
			$instanceUserName = "Administrator"		
			Write-Host "Instance is left running for debugging"
			## obtaining instance password
			if (! (IsNullOrEmpty $keyPairFileName))
			{
				do
				{
					$instancePassword = Get-InstancePasswordEc2 $ec2Client $instanceId $keyPairFileName -doReportErrors $logErrors			
					if (! (IsNullOrEmpty($instancePassword) ))
					{
						break;
					}
					sleep -Seconds 15	# Wait as signon might be delayed
					$retryCount -- ;
				} while ($retryCount -gt 0)
				
				Write-Host "Instance ID: $instanceId"
				Write-Host "Public DNS Name: $loginAddress"
				Write-Host "RDC UserName:	 $instanceUserName"
			
				if ($instancePassword -ne "")
				{
					Write-Host "RDC Password:	 $instancePassword"
					if ($AllowAutoStartRDC -eq $true)
					{
						Start-RDCSession $loginAddress $instanceUserName $instancePassword
					}
				}
				else
				{
					Write-Host "*** Unfortunately - unable to obtain a password currently"
					$result = $false
				}
			}
			else
			{
				Write-Host "pem file is not valid or is empty"
				$result = $false
			}			
		}
		else
		{
			Write-Error "Instance is not in an expected state"
			$result = $false
		}
	}
	catch 
	{	
		Write-Host "Something is wrong with the temporary instance"
		Write-FormattedError $_
		$result = $false
	}
	return $result
}

<#
	.SYNOPSIS
	    See if an EIP is associated with an existing instance
    .OUTPUTS
    	Returns awsInstanceId(s) if assigned, or null
#>
function Get-InstanceAssociatedWithIP
{
	Param(
		  [Amazon.EC2.AmazonEC2Client]			# Amazon Elastic Cloud Computing Security Token.
			$ec2Client 
		, [String]								# Elastic IP address to check
			$ipAddress
	)
	$local:request = New-Object -TypeName Amazon.EC2.Model.DescribeAddressesRequest  -Property @{ WithPublicIp = $ipAddress }
	try {
	    $response = $ec2Client.DescribeAddresses($local:request)
		$result = $($response.DescribeAddressesResponse.DescribeAddressesResult.Address.InstanceId)
	} 
	catch {
	    Write-Host "Failed to validate EIP $ipAddress, ensure that it is allocated and associated with your account.  Aborting." -ForegroundColor Blue
	    $result = $null
	}
	return $result
}

<#
	.SYNOPSIS
	    Remove EIP address from an instance.
    .OUTPUTS
    	Returns True / False
#>
function Set-IpToUnattached
{
	param(
		[Amazon.EC2.AmazonEC2Client]	# Amazon Elastic Cloud Computing security Token
			$ec2Client
		, [String]						# ip address to be assigned to the instance
			$ipAddress					
	)
	$result = $true
	try {
		$local:request = New-Object -TypeName Amazon.EC2.Model.DisassociateAddressRequest -Property @{	WithPublicIp = $ipAddress }
		$ec2Client.DisassociateAddress($local:request)
	}
	catch {
	    Write-Host "Failed to validate EIP $ipAddress, ensure that it is allocated and associated with your account.  Aborting." -ForegroundColor Blue
		$result = $false
	}
	return $result
}

<#
	.SYNOPSIS
	    Get list of RDS Snapshots that match the name
    .OUTPUTS
    	array containing list of Snapshots that match
#>
function Find-SnapshotRDSByName
{
	param (
		[Amazon.RDS.AmazonRDSClient]					# Amazon Relational Database Service Token
			$rdsClient
		, [String]										# name of the RDS snapshot (allows partial matches)
			$nameToFind
		, [String]										# name of the DB instance to match on
			$dbInstanceName			
		, [Bool]										# is the string a wildcard
			$doWildCardSearch = $false	
		, [Bool]										# return the most recent match only
			$doReturnLatestVersion = $false	
		, [Bool]										# default to list of names / allow all details (only relevant for wildcard)
			$doReturnAllDetails = $false
	)
	#TODO: have return latest flag
	$result = @()
	
	$local:request = New-Object -TypeName Amazon.RDS.Model.DescribeDBSnapshotsRequest 
	if ($doWildCardSearch)
	{
		$marker=""
		$searchName = "*{0}*" -f $nameToFind
		$instanceName = "*{0}*" -f $dbInstanceName
		$local:request.dbInstanceIdentifier =""
		$local:request.dbSnapshotIdentifier =""
		$local:request.MaxRecords = 20 ;

		Do
		{
			$local:request.Marker = $marker ;
			
			$resultList = $rdsClient.DescribeDBSnapshots($local:request) ;
			$marker = $resultList.DescribeDBSnapshotsResult.marker
			foreach ($item in $resultList.DescribeDBSnapshotsResult.DBSnapshots)
			{
				if ($item.DBSnapshotIdentifier -like $searchName)
				{
					if ($item.DBInstanceIdentifier -like $instanceName)
					{
						if (!$doReturnLatestVersion)
						{
							# return ALL matching items
							if ($doReturnAllDetails)
							{
								$obj = New-Object PSObject
	        					$obj | Add-Member -MemberType NoteProperty -Name "DBSnapshotIdentifier" -Value $($item.DBSnapshotIdentifier)
	        					$obj | Add-Member -MemberType NoteProperty -Name "DBInstanceIdentifier" -Value $($item.DBInstanceIdentifier)
	        					$obj | Add-Member -MemberType NoteProperty -Name "SnapshotType" -Value $($item.SnapshotType)
	        					$obj | Add-Member -MemberType NoteProperty -Name "Status" -Value $($item.Status)
	        					$obj | Add-Member -MemberType NoteProperty -Name "SnapshotCreateTime" -Value $($item.SnapshotCreateTime)
								$result += $obj
							}
							else
							{
								$result += $item.DBSnapshotIdentifier
							}
						}
						else
						{
							# return LATEST matching item
							if ((!$latestDate) -or ($latestDate -lt $item.SnapshotCreateTime))
							{
								$latestDate = $item.SnapshotCreateTime ;
								$result = $item.DBSnapshotIdentifier ;
							}
						}
					}
				}
			}
		}
		Until (! $marker )
		# look for Marker
	}
	else
	{
		if ($nameToFind)
		{
			try
			{
				$local:request.dbSnapshotIdentifier = $nameToFind ;
				$resultList = $rdsClient.DescribeDBSnapshots($local:request) ;
				foreach ($item in $resultList.DescribeDBSnapshotsResult.DBSnapshots)
				{
					if (!$doReturnLatestVersion)
					{
						Write-Host found "RDS snapshot: $($item.DBSnapshotIdentifier) was created: $($item.SnapshotCreateTime)"
						$result += $item.DBSnapshotIdentifier
					}
					else
					{
						# return LATEST matching item
						if ((!$latestDate) -or ($latestDate -lt $item.SnapshotCreateTime))
						{
							$latestDate = $item.SnapshotCreateTime ;
							$result = $item.DBSnapshotIdentifier ;
						}
					}					
				}
			}
			catch
			{
				# unable to locate snapshot
				Write-Host "RDS Snapshot not found: $nameToFind" -ForegroundColor Blue
			}
		}
	}
	return $result
}


<#
	.SYNOPSIS
	    Get list of RDS Snapshots that match the type
    .OUTPUTS
    	array containing list of Snapshots that match
#>
function Find-SnapshotRDSByType
{
	param (
		[Amazon.RDS.AmazonRDSClient]					# Amazon Relational Database Service Token
			$rdsClient
		, [String]										# name of the RDS snapshot (allows partial matches)
			$snapshotType		
	)
	
	$local:request = New-Object -TypeName Amazon.RDS.Model.DescribeDBSnapshotsRequest 
	if (!(IsNullOrEmpty $snapshotType))
	{
		$local:request.SnapshotType =$snapshotType
	}
	
	
	$resultList = $rdsClient.DescribeDBSnapshots($local:request) ;	
	return $resultList.DescribeDBSnapshotsResult.DBSnapshots;
}

<#
	.SYNOPSIS
	    Create an RDS snapshot (backup) of a database.
    .OUTPUTS
    	True / False - depending on success of the operation
#>
function New-SnapshotRDS()
{
	param (
		[Amazon.RDS.AmazonRDSClient]					# Amazon Relational Database Service Token
			$rdsClient
		, [String]										# Name of RDS instance to snapshot
			$rdsInstanceName
		, [String]										# Name to call the RDS snapshot
			$rdsSnapshotName
	)
	try {
	
		$local:request = New-Object -TypeName Amazon.RDS.Model.CreateDBSnapshotRequest -Property @{
				dBInstanceIdentifier = $rdsInstanceName ;
				dBSnapshotIdentifier = $rdsSnapshotName
			}
		$response = $rdsClient.createDBSnapshot($local:request)
		$result = $true
	}
	catch {
		Write-Host "Failed to create RDS snapshot. Ensure that rds instance: $rdsInstanceName is valid, and snapshot: $rdsSnapshotName is valid and not in use.`n $_.Exception."
		$result = $false
	}
	return $result
}

<#
	.SYNOPSIS
	    Copy an existing RDS snapshot (backup) of a database.
    .OUTPUTS
    	True / False - depending on success of the operation
#>
function Copy-SnapshotRDS()
{
	param (
		[Amazon.RDS.AmazonRDSClient]					# Amazon Relational Database Service Token
			$rdsClient
		, [String]										# Name of the existing RDS snapshot
			$rdsSnapshotNameExisting
		, [String]										# Name to call the new RDS snapshot
			$rdsSnapshotNameNew
	)
	try {
	
		$local:request = New-Object -TypeName Amazon.RDS.Model.CopyDBSnapshotRequest -Property @{
			SourceDBSnapshotIdentifier = $rdsSnapshotNameExisting ;
			TargetDBSnapshotIdentifier = $rdsSnapshotNameNew ;
		}
		$response = $rdsClient.CopyDBSnapshot($local:request)
		$result = $true
	}
	catch {
		Write-Host "Failed to copy RDS snapshot. Ensure that rds instance: $rdsSnapshotNameExisting exists, and RDS instanceId: $rdsSnapshotNameNew is valid and does not exist.`n $_.Exception."
		 
		$result = $false
	}
	return $result
}

<#
	.SYNOPSIS
	    Delete an RDS snapshot (backup) of a database.
    .OUTPUTS
    	True / False - depending on success of the operation
#>
function Delete-SnapshotRDS()
{
	param (
		[Amazon.RDS.AmazonRDSClient]					# Amazon Relational Database Service Token
			$rdsClient
		, [String]										# Name of the RDS snapshot
			$rdsSnapshotName
	)
	try {
	
		$local:request = New-Object -TypeName Amazon.RDS.Model.DeleteDBSnapshotRequest -Property @{
				dBSnapshotIdentifier = $rdsSnapshotName
			}
		$response = $rdsClient.deleteDBSnapshot($local:request)
		$result = $true
	}
	catch {
		Write-Host "Failed to delete RDS snapshot. Ensure that rds snapshot: $rdsSnapshotName is a valid name"
		$result = $false
	}
	return $result
}

<#
	.SYNOPSIS
	    Rename an existing RDS snapshot (backup) of a database.
    .OUTPUTS
    	True / False - depending on success of the operation
#>
function Rename-SnapshotRDS()
{
	param (
		[Amazon.RDS.AmazonRDSClient]					# Amazon Relational Database Service Token
			$rdsClient
		, [String]										# Name of the existing RDS snapshot
			$rdsSnapshotNameExisting
		, [String]										# Name to call the new RDS snapshot
			$rdsSnapshotNameNew
	)
	$result = Copy-SnapshotRDS -rdsClient $rdsClient -rdsSnapshotNameExisting $rdsSnapshotNameExisting -rdsSnapshotNameNew $rdsSnapshotNameNew
	if ($result) 
	{
		$result = Delete-SnapshotRDS -rdsClient $rdsClient -rdsSnapshotName $rdsSnapshotNameExisting
	}
	return $result
}

<#
	.SYNOPSIS
	    Restore a RDS snapshot to an RDS instance.
    .OUTPUTS
    	True / False - depending on success of the operation
#>
function Restore-SnapshotRDSToDBInstance()
{
	param (
		[Amazon.RDS.AmazonRDSClient]					# Amazon Relational Database Service Token
			$rdsClient
		, [String]										# Name of the RDS snapshot to restore
			$rdsSnapshotName
		, [String]										# RDS instance to create with the restore (must not already exist)
			$rdsInstanceName
	)
	try {
	
		$local:request = New-Object -TypeName Amazon.RDS.Model.RestoreDBInstanceFromDBSnapshotRequest -Property @{
				dBSnapshotIdentifier = $rdsSnapshotName ;
				dBInstanceIdentifier = $rdsInstanceName
			}
		$response = $rdsClient.RestoreDBInstanceFromDBSnapshot($local:request)
		$result = $true
	}
	catch {
		Write-Host "Failed to restore RDS snapshot. Ensure that rds snapshot: $rdsSnapshotName is valid and exists, and DBInstance: $rdsInstanceName is valid and does not exist."
		$result = $false
	}
	return $result
}

<#
	.SYNOPSIS
	    Delete an RDS instance of a database.
    .OUTPUTS
    	True / False - depending on success of the operation
#>
function Delete-RDSInstance()
{
	param (
		[Amazon.RDS.AmazonRDSClient]					# Amazon Relational Database Service Token
			$rdsClient
		, [String]										# Name of the RDS instance
			$rdsInstanceName
		, [String]										# Optional - Name to save snapshot as.
			$rdsSnapshotName
	)
	try {
	
		$local:request = New-Object -TypeName Amazon.RDS.Model.DeleteDBInstanceRequest -Property @{
				DBInstanceIdentifier = $rdsInstanceName
			}
		if ($rdsSnapshotName)
		{
			$local:request.FinalDBSnapshotIdentifier = $rdsSnapshotName
			$local:request.SkipFinalSnapshot = $false
		}
			
		$response = $rdsClient.deleteDBInstance($local:request)
		$result = $true
	}
	catch {
		Write-Host "Failed to delete RDS instance. Ensure that rds instance: $rdsInstanceName is valid, and Snapshot: $rdsSnapshotName is valid and does not exist"
		$result = $false
	}
	return $result
}

<#
	.SYNOPSIS
	    Delete an Elastic Load Balancer.
    .OUTPUTS
    	True / False - depending on success of the operation
#>
function Delete-ElasticLoadBalancer()
{
	param (
		[Amazon.ElasticLoadBalancing.AmazonElasticLoadBalancingClient]		# Elastic Load Balancing security Token
			$elbClient
		, [String]															# name of physical ID of load balancer
			$instanceId
	)
	try {
		$local:request = New-Object -TypeName Amazon.ElasticLoadBalancing.Model.DeleteLoadBalancerRequest -Property @{
				loadBalancerName = $instanceId
			}
		$response = $elbClient.deleteLoadBalancer($local:request)
		$result = $true
	}
	catch {
		Write-Host "Failed to delete Load Balancer instance. Ensure that ELB instance: $instanceId exists and is in the same security context.`n $_.Exception."
		$result = $false
	}
	return $result
}



<#
	.SYNOPSIS
	    Collects correct AWS account related details
	.PARAMETER accountType
		account type for whom details would be returned
	.OUTPUTS
		hashtable containing account related details
#>
function Get-AWSDetailsByAccountType()
{
	param(
		[AWSAccountType]
			$accountType
		, [Parameter(Mandatory=$true)] 
			[String]
			$region
	)
	
	[hashtable] $AWSDetailsDevOregon = @{
								"keyPairName"="DevopsKeyPair_West";
								"Ec2SecurityGroup" = "sg-5cd8446c";
								"snstopic" = "arn:aws:sns:us-west-2:587143430827:DevopsStackNotification";
								"snsalarmtopic" = "arn:aws:sns:us-west-2:587143430827:DevopsStackAlarm"
								}
	[hashtable] $AWSDetailsDevSydney = @{
								"keyPairName"="DevopsKeyPair_southeast";
								"Ec2SecurityGroup" = "sg-de77eee4";
								"snstopic" = "arn:aws:sns:ap-southeast-2:587143430827:DevopsStackNotification";
								"snsalarmtopic" = "arn:aws:sns:ap-southeast-2:587143430827:DevopsStackAlarm"
								}
	[hashtable] $AWSDetailsDevRegion = @{"us-west-2"=$AWSDetailsDevOregon; "ap-southeast-2"=$AWSDetailsDevSydney;}								
	
	[hashtable] $AWSDetailsDev = @{
								"S3ScriptLocation"="powershell-scripts"; 
								"S3DeploymentLocation"="assetsdeploy"; 
								"S3GoldenImageLocation"="devopsdeploy"; 
								"HostedZone" ="addevcloudservices.com.au"; 
								"keyPairName" = $AWSDetailsDevRegion.get_Item($region).keyPairName; 
								"amiNameLookup" = "Devops_Assets_Web_Build_";
								"BaseAMIName" = "Devops_Web_Base_Image";
								"snstopic" = $AWSDetailsDevRegion.get_Item($region).snstopic; 
								"snsalarmtopic" = $AWSDetailsDevRegion.get_Item($region).snsalarmtopic;
								"Ec2SecurityGroup" = $AWSDetailsDevRegion.get_Item($region).Ec2SecurityGroup; 
								"DefaultInstanceType" = "t1.micro";
								"InstanceProfileArn" = "arn:aws:iam::587143430827:instance-profile/Devops_Bootstrap";
								"CloudwatchFileName" = "";
								"SharedAccountNumbers" = "194610482393";
								"Region" = $AWSDetailsDevRegion
								}
								
	
	[hashtable] $AWSDetailsPreProdOregon = @{
								"keyPairName"="PreProduction_West2";
								"Ec2SecurityGroup" = "sg-b22db782";
								"snstopic" = "arn:aws:sns:us-west-2:194610482393:DevopsStackNotification";
								"snsalarmtopic" = "arn:aws:sns:us-west-2:194610482393:DevopsStackAlarm"
								}
	[hashtable] $AWSDetailsPreProdSydney = @{
								"keyPairName"="PreProduction_southeast2";
								"Ec2SecurityGroup" = "sg-e86bf2d2"
								"snstopic" = "arn:aws:sns:ap-southeast-2:194610482393:DevopsStackNotification";
								"snsalarmtopic" = "arn:aws:sns:ap-southeast-2:194610482393:DevopsStackAlarm"
								}
	[hashtable] $AWSDetailsPreProdRegion = @{"us-west-2"=$AWSDetailsPreProdOregon; "ap-southeast-2"=$AWSDetailsPreProdSydney;}	
	
	[hashtable] $AWSDetailsPreProd = @{
								"S3ScriptLocation"="myobdeploy-preprod"; 
								"S3DeploymentLocation"="assetstage"; 
								"S3GoldenImageLocation"="assetstage";								
								"HostedZone" ="adppcloudservices.com.au"; 
								"keyPairName" = $AWSDetailsPreProdRegion.get_Item($region).keyPairName; 
								"amiNameLookup" = "PreProd_Assets_Web_Build_";
								"BaseAMIName" = "Devops_Assets_Web_Build_BuildNumber";
								"snstopic" = $AWSDetailsPreProdRegion.get_Item($region).snstopic;			
								"snsalarmtopic" = $AWSDetailsPreProdRegion.get_Item($region).snsalarmtopic;
								"Ec2SecurityGroup" = $AWSDetailsPreProdRegion.get_Item($region).Ec2SecurityGroup;
								"DefaultInstanceType" = "t1.micro";
								"InstanceProfileArn" = "arn:aws:iam::194610482393:instance-profile/WebFrontEnd"
								"CloudwatchFileName" = "Bootstrap/ec2cloudwatch.conf"
								"SharedAccountNumbers" = "085593993164"
								"Region" = $AWSDetailsPreProdRegion
								}
	# Note: this is in Sydney
	
	[hashtable] $AWSDetailsProdSydney = @{
								"keyPairName"="Production_SouthEast2";
								"Ec2SecurityGroup" = "sg-2879e012"
								}
	[hashtable] $AWSDetailsProdRegion = @{"ap-southeast-2"=$AWSDetailsProdSydney;}	
	
	[hashtable] $AWSDetailsProduction = @{
								"S3ScriptLocation"="myobdeploy-prod"; 
								"S3DeploymentLocation"="assetstage-prod"; 
								"S3GoldenImageLocation"="assetstage-prod";
								"HostedZone" ="adcloudservices.com.au"; 
								"keyPairName" = $AWSDetailsProdRegion.get_Item($region).keyPairName;  
								"amiNameLookup" = "Production_Assets_Web_Build_";
								"BaseAMIName" = "PreProd_Assets_Web_Build_BuildNumber";
								"snstopic" = "arn:aws:sns:ap-southeast-2:085593993164:DevopsStackNotification";			
								"snsalarmtopic" = "arn:aws:sns:ap-southeast-2:085593993164:DevopsStackAlarm";
								"Ec2SecurityGroup" = $AWSDetailsProdRegion.get_Item($region).Ec2SecurityGroup;
								"DefaultInstanceType" = "t1.micro";
								"InstanceProfileArn" = "arn:aws:iam::085593993164:instance-profile/WebFrontEnd";
								"CloudwatchFileName" = "Bootstrap/ec2cloudwatch.conf";
								"Region" = $AWSDetailsProdRegion
								}
								
	[hashtable] $AWSDetails = @{"Dev"=$AWSDetailsDev; "PreProd"=$AWSDetailsPreProd; "Production"=$AWSDetailsProduction; }	
	[hashtable] $response = @{}
	if ($AWSDetails.ContainsKey($accountType.ToString()))
	{
		$response = $AWSDetails.get_Item($accountType.ToString())
	}
	return $response
		
}


<#
	.SYNOPSIS
	    returns STS and collab service details for individual stack type
	.PARAMETER stackType
		stack type for whom details would be returned
	.OUTPUTS
		string containing security related details
#>
function Get-STSAndCollabServiceDetails()
{
	param(
		[string]
			$stackType		
	)
	
	[string] $response = [string]::Empty
	
	switch ($stackType)
	{
		{($_ -eq "QA") -or ($_ -eq "QAAutomation")}
		{
			$response = "-frameworkSecurityDetails `\`"authenticationServer=https://secure.myob.com/oauth2/v1/`\n
								authorizationServer=https://collabmaintenance.myob.com/ProcessFileUserMaintenance.svc`\n
								clientId=AccountantsFramework`\n
								clientSecret=Za70QYW49oTN7aTrAZ7C`\n
								devKey=qr3z9bcdrhfpqk3hj4smvme2`\n
								scopes=Assets`\`""
		}
		{($_ -eq "Build") -or ($_ -eq "QAPerformance")}		
		{
			$response = "-frameworkSecurityDetails `\`"authenticationServer=https://test.secure.myob.com/oauth2/v1/`\n
								authorizationServer=http://autstbizsit01.myobtest.net/MYOBCollab_Services/MYOB_BizTalk_CollabServices_Orchestrations_ProcessFileUserMaintenance_CollaborationMaintenancePort.svc`\n
								clientId=MyobAssetsClient`\n
								clientSecret=z2nJ9300GItfG31`\n
								devKey=gyjrntkz2df6sbsyqq3b7z8w`\n
								scopes=Assets`\`""
		}
		
	}
	
	return $response
		
}


<#
	.SYNOPSIS
	    Validates a snapshot exists in an amazon region
	.PARAMETER snapshotName
		Snapshot name to be validated
	.OUTPUTS
		Boolean indication of the validation result
#>
function Validate-SnapshotName()
{
	param(
		[ValidateNotNullOrEmpty()]
		[string]
			$snapshotName, 
		[string]
			$awsSecretKeyID
		, [string]
			$awsSecretAccessKeyID
		, [string]
			$awsRegion
	)
			
	$rdsClient = New-rdsClient -secretKeyID $awsSecretKeyID -secretAccessKeyID $awsSecretAccessKeyID -region $awsRegion
	$snapshot = Find-SnapshotRDSByName -rdsClient $rdsClient -nameToFind $snapshotName -doWildCardSearch $false
	$rdsClient.Dispose | Out-Null
	if ($snapshot)
	{
		return $true		
	}	
	
	return $false
	
}