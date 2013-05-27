# Set up paths
$private:scriptCommonDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $private:scriptCommonDirectory IIS_Utility_Functions.ps1)

##########################################################################
####                    Setup IIS for products                       #####
##########################################################################
function Set-IISProducts($systemName, $siteName, $productName, $siteAppPoolName, 
					     $productAppVersionName, $productAppPoolVersionName)
{
	#####################################################
		
	
	# Check if default web site is running if so stop
	Stop-DefaultWebSite

	# Create webs virtual directory for deployment
	New-BaseWebsFolder 
	
	#####################################################

	# Create and set website pool with version
	New-AppPool $siteAppPoolName
	Set-AppPoolRuntime $siteAppPoolName v4.0

	# Create top level website
	New-WebsiteForProducts $siteName

	# Create top level virtual directory
	New-WebsiteFolder $siteName
	
	# Set top level website to virual directory
	Set-WebsiteVirtualDirectory $siteName $siteName

	# Set top level website to AppPool
	Set-WebsiteAppPool $siteName $siteAppPoolName
	
	# Create product webapp version
	New-WebApplicationVersion $siteName $productName 

	# Create product version directory
	New-WebApplicationFolder $siteName $productName 
	
	# Set product webapp to virtual directory
	Set-WebApplicationVirtualDirectory $siteName $productName $productAppVersionName

	# Set product webapp to AppPool
	Set-WebApplicationAppPool $siteName $productName $siteAppPoolName	
	
	# Test WebSite is running		
	$websiteStatus = Test-WebSiteRunning $siteName
	if($websiteStatus)
	{
		#####################################################
		
		$productApplication = "{0}\{1}" -f $siteName, $productName

		# Create product webapp version
		New-WebApplicationVersion $productApplication $productAppVersionName

		# Create product version directory
		New-WebApplicationFolder $productApplication $productAppVersionName

		# Create and set product web app pool with version
		New-AppPool $productAppPoolVersionName
		Set-AppPoolRuntime $productAppPoolVersionName v4.0

		# Set product webapp to virtual directory
		Set-WebApplicationVirtualDirectory $productApplication $productAppVersionName $productAppVersionName

		# Set product webapp to AppPool
		Set-WebApplicationAppPool $productApplication $productAppVersionName $productAppPoolVersionName
		
#			# Test WebApplication is running
#			# TODO: Need to find a way to test if an application is running
#			
#			######################################################
	}
	else
	{
		$message = "Website: {0} is not running" -f $productName
		Write-Warning $message
	}
		
	
	
	
}

