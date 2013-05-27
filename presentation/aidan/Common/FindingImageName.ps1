function Find-ImageDescription([Amazon.EC2.AmazonEC2Client]$ec2Client, [String]$imageId)
{
	if ( ($local:ec2Client -eq $null) -or ($local:ec2Client -isnot [Amazon.EC2.AmazonEC2Client]) )
	{
		Write-Error "Error Null or Invalid Client; Expecting Amazon.EC2.AmazonEC2Client but received $local:ec2Client"
		return
	}	
	$describeImagesRequest = New-Object -TypeName Amazon.EC2.Model.DescribeImagesRequest
	$imageIdList = New-Object -TypeName System.Collections.Generic.List[string]
	$imageIdList.Add($imageId)
	$describeImagesRequest.ImageId = $imageIdList
	$describeImageResponse = $ec2Client.DescribeImages($describeImagesRequest)	
	$imageState = $local:describeImageResponse.DescribeImagesResult.Image[0].ImageState
	$imageName = $local:describeImageResponse.DescribeImagesResult.Image[0].Name
	return $describeImageResponse
}