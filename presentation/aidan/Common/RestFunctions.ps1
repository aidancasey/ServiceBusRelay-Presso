<#


	.NOTE
		see: https://bitbucket.org/thompsonson/powershellmodulerepository/
#>

#region setupPathsAndConstants
$scriptCommonDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $scriptCommonDirectory -ChildPath CommonFunctions.ps1)
#endRegion setupPathsAndConstants



<#
	.SYNOPSIS
	    pads the URL with / if this is not in string. 
    .OUTPUTS
    	fixed URL string. 
#>
Function Fix-Url ([String]$url) {
    if($url.EndsWith('/') -Or $url.EndsWith('\')) {
        return $url
    }
    return "$url/"
}

<#
	.SYNOPSIS
	    Carry credentials to be used in other REST interface
    .OUTPUTS
    	Network credentials object. 
	.NOTE
		This leaves password in clear. A more robust method should be used!
		#TODO: what happens for non-domain?
#>
function Create-RestCredentials{
    [CmdletBinding()]
  PARAM (
        [String][Parameter(Mandatory=$true)]
        	$username,
        [String][Parameter(Mandatory=$true)]
        	$password,
        [String]
        	$domain
  )
  	if ( IsNullOrEmpty($domain ))
	{
    	$creds = New-Object System.Net.NetworkCredential($username,$password)  
	}
	else
	{
    	$creds = New-Object System.Net.NetworkCredential($username,$password,$domain)  
	}
    return $creds
}

<#
	.SYNOPSIS
	    simple Rest requester to obtain data
    .OUTPUTS
    	3 output formats: 
					default - XML object
					-JSON
	.NOTE
		This leaves password in clear. A more robust method should be used!
#>
function Request-Rest{
    
    [CmdletBinding()]
  PARAM (
        [String][Parameter(Mandatory=$true)]				# REST URL to obtain data from
        	$URL,
        [System.Net.NetworkCredential][Parameter(Mandatory=$true)]	# Credentials - use Create-RestCredentials to get this
         	$credentials,
        [String][Parameter(Mandatory=$false)]				# Optional string to supply to the rest service 
        	$UserAgent = "PowerShell API Client",
        [Switch][Parameter(Mandatory=$false)]				# output result data in JSON format
         	$JSON,
        [Switch][Parameter(Mandatory=$false)]				# output result data as RAW string
        	$Raw
  )
    #Create a URI instance since the HttpWebRequest.Create Method will escape the URL by default.   
    $URL = Fix-Url $Url
    $URI = New-Object System.Uri($URL,$true)   
    #Create a request object using the URI   
    $request = [System.Net.HttpWebRequest]::Create($URI)   
    #Build up a nice User Agent   
    $request.UserAgent = $(   
        "{0} (PowerShell {1}; .NET CLR {2}; {3})" -f $UserAgent, $(if($Host.Version){$Host.Version}else{"1.0"}),  
        [Environment]::Version,  
        [Environment]::OSVersion.ToString().Replace("Microsoft Windows ", "Win")  
        )
    $request.Credentials = $credentials
    
    if ($PSBoundParameters.ContainsKey('JSON'))
    {
        $request.Accept = "application/json"
    }
            
    try
    {
        [System.Net.HttpWebResponse] $response = [System.Net.HttpWebResponse] $request.GetResponse()
    }
    catch
    {
         Throw "Exception occurred in $($MyInvocation.MyCommand): `n$($_.Exception.Message)"
    }
    
    $reader = [IO.StreamReader] $response.GetResponseStream()  
    if (($PSBoundParameters.ContainsKey('JSON')) -or ($PSBoundParameters.ContainsKey('Raw')))
    {
        $output = $reader.ReadToEnd()  
    }
    else
    {
        [xml]$output = $reader.ReadToEnd()  
    }
    
    $reader.Close()  
    Write-Output $output  
    $response.Close()
}
