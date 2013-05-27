$bootstrapFolder = "C:\Deploy" 
#region Logging
New-Item $bootstrapFolder -Type Directory

$LogFile = "$bootstrapfolder\userdata.log"
Function WL						
{
  #Write-Log - purpose: to log events so we have an audit-trail in the instance
   Param ([string]$logstring)
   $logstring = (Get-Date -UFormat "%Y/%m/%d %T") + " " + $logstring
   Add-content $Logfile -value $logstring
   Write-Host $logstring		          # output for interactive user
}
#endregion Logging
WL "Begin Userdata"
#region InstallAWStools
$tempFolder = "C:\temp"
New-Item $tempFolder -Type Directory

$AwsSdkUri = "http://sdk-for-net.amazonwebservices.com/latest/AWSToolsAndSDKForNet.msi"
$AwsSdkMsiFileName = "AWSToolsAndSDKForNet.msi"

WL "Downloading AWSTools"
$targetLocation = Join-Path -Path $tempFolder -ChildPath $AwsSdkMsiFileName
$webclient = New-Object System.Net.WebClient
$webclient.DownloadFile($AwsSdkUri, $targetLocation)
if (!(Test-Path  $targetLocation))
{
	WL "SDK not downloaded successfully"
}
else
{
	WL "Installing AWS Tools"
	Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $targetLocation  /norestart /quiet /passive " -Wait -NoNewWindow
	$AwsSdkLib = "C:\Program Files (x86)\AWS SDK for .NET\bin\AWSSDK.dll"
	Add-Type -Path $AwsSdkLib
	WL "Installed AWS Tools" 
}
WL "Completed Userdata"
#endregion InstallAWStools
