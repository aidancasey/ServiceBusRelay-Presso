# Set up paths
$private:scriptCommonDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $private:scriptCommonDirectory CommonFunctions.ps1)


# Setup webadministration
$iisVersion = Get-ItemProperty "HKLM:\software\microsoft\InetStp";
if ($iisVersion.MajorVersion -eq 7)
{
    if ($iisVersion.MinorVersion -ge 5)
    {
        Import-Module WebAdministration;
    }           
    else
    {
        if (-not (Get-PSSnapIn | Where {$_.Name -eq "WebAdministration";})) 
		{
            Add-PSSnapIn WebAdministration;
        }
    }
}

## CONSTANTS
$defaultWeb = "C:\Webs"

  
##########################################################################
####                   Check if IIS is running                       #####
##########################################################################
function Test-IISRunning([string]$serverName)
{
	if(IsNullOrEmpty $serverName)
	{
		Write-Warning "Server name cannot be null"
		return $False
	}
	
	$service = Get-Service W3SVC -ComputerName $serverName
	if ($service.Status -eq "Running")
	{
		return $True
	}
	else
	{
		return $False
	}	
}

##########################################################################
####                  Check if App pool is running                   #####
##########################################################################
function Test-AppPoolRunning([string]$poolname)
{
	if(IsNullOrEmpty $poolname)
	{
		Write-Warning "AppPool name cannot be null"
		return $False
	}
	
	if(Test-Path IIS:\AppPools\$poolname)
	{
		if($pool.State -eq "Started")
		{
			Return $True
		}
		else
		{
			Return $False
		}
	}
}

##########################################################################
####                         Stop Default website                    #####
##########################################################################
function Stop-DefaultWebSite()
{
	$IsDefaultWebsiteRunning = Test-WebSiteRunning "Default Web Site"
	if($IsDefaultWebsiteRunning)
	{
		Stop-Website "Default Web Site"
	}
}

##########################################################################
####                Check if website is running                      #####
##########################################################################
function Test-WebSiteRunning([string]$websiteName)
{
	if(IsNullOrEmpty $websiteName)
	{
		Write-Warning "Website name cannot be null"
		return $False
	}
	
	if(Test-Path IIS:\Sites\$websiteName)
	{
	    $status = Get-WebsiteState $websiteName
		if($status.Value -eq "Started")
		{
			return $True
		}
		else
		{
			return $False
		}	
	}
	else
	{
		Write-Warning "Website does not exist"
		return $False
	}
}

##########################################################################
####       Create website folder location inside c:\webs             #####
##########################################################################
function New-WebsiteFolder([string]$websiteFolderName)
{
	if(IsNullOrEmpty $websiteFolderName)
	{
		Write-Warning "Folder name cannot be null"
		return
	}
	
	$absoluteWebsiteFolderName = Join-Path $defaultWeb -ChildPath $websiteFolderName
	Create-Folder $absoluteWebsiteFolderName
}

##########################################################################
#### Create web application folder location inside c:\webs\{website} #####
##########################################################################
function New-WebApplicationFolder([string]$websiteName, [string]$webApplicationFolderName)
{
	if(IsNullOrEmpty $websiteName)
	{
		Write-Warning "Website name cannot be null"
		return
	}	
	if(IsNullOrEmpty $webApplicationFolderName)
	{
		Write-Warning "Version name cannot be null"
		return
	}

	$absoluteWebsiteFolderName = Join-Path $defaultWeb -ChildPath $websiteName
	
	if(Test-Path $absoluteWebsiteFolderName)
	{
		$absoluteWebApplicationFolderName = Join-Path $absoluteWebsiteFolderName -ChildPath $webApplicationFolderName
		Create-Folder $absoluteWebApplicationFolderName
	}
}

##########################################################################
####                      Create app pool	                         #####
##########################################################################
function New-AppPool([string]$poolname)
{
	if(IsNullOrEmpty $poolname)
	{
		Write-Warning "AppPool name cannot be null"
		return
	}
	if(!(Test-Path IIS:\AppPools\$poolname))
	{
		New-Item IIS:\AppPools\$poolname		
	}
}

##########################################################################
####             Setup App pool runtime version.				     #####
##########################################################################
function Set-AppPoolRuntime([string]$poolname, [string]$runtime)
{
	if(IsNullOrEmpty $poolname)
	{
		Write-Warning "AppPool name cannot be null"
		return
	}
	
	if(Test-Path IIS:\AppPools\$poolname)
	{
		$pool = Get-Item IIS:\AppPools\$poolname
		$pool.managedRuntimeVersion = $runtime
		$pool | Set-Item
		$pool.Stop()
		$pool.Start()
	}
}

##########################################################################
####                       Create website	                         #####
##########################################################################
function New-WebsiteForProducts([string]$websiteName)
{
	if(IsNullOrEmpty $websiteName)
	{
		Write-Warning "Website name cannot be null"
		return
	}
	if(!(Test-Path IIS:\Sites\$websiteName))
	{
		New-WebSite -Name $websiteName 
	}
}

##########################################################################
####              Create web application for a website         	     #####
##########################################################################
function New-WebApplicationVersion([string]$websiteName, [string]$webApplicationName)
{
	if(IsNullOrEmpty $websiteName)
	{
		Write-Warning "Website name cannot be null"
		return
	}
	if(IsNullOrEmpty $webApplicationName)
	{
		Write-Warning "WebApplication name cannot be null"
		return
	}
	
	if(Test-Path IIS:\Sites\$websiteName)
	{
		if(!(Test-Path IIS:\Sites\$websiteName\$webApplicationName))
		{
			$iisWebApp = "IIS:\Sites\{0}\{1}" -f $websiteName, $webApplicationName
			
			#NOTE: Setting the physical property is temporaty. 
			#	   Virtual path has to be set later.
			New-Item $iisWebApp -Type Application -PhysicalPath $defaultWeb
		}
	}
}

##########################################################################
####   Create base folder or with custom folder location at c drive	 #####
#### 	Note: 1. If absolute path is not specified then              #####
#### 		     folder is created where this script is executed.    #####
#### 		  2. By default a webs folder is created.                #####
##########################################################################
function New-BaseWebsFolder([string]$folder)
{
	if(IsNullOrEmpty $folder)
	{
		Create-Folder $defaultWeb
	}
	else
	{
		Create-Folder $folder
	}
}

##########################################################################
####             Set web site to virtual directory				     #####
##########################################################################
function Set-WebsiteVirtualDirectory([string]$websiteName, [string]$folderName)
{
	if(IsNullOrEmpty $websiteName)
	{
		Write-Warning "Website name cannot be null"
		return
	}
	if(IsNullOrEmpty $folderName)
	{
		Write-Warning "Virtual Directory name cannot be null"
		return
	}
	
	if(Test-WebSiteRunning $websiteName)
	{
		$websiteFolderName = Join-Path $defaultWeb -ChildPath $folderName
		if(Test-Path $websiteFolderName)
		{
			Set-ItemProperty IIS:\Sites\$websiteName -Name physicalPath -Value  "$websiteFolderName"
		}
	}
}

##########################################################################
####      Set web application to corresponding virtual directory	 #####
##########################################################################
function Set-WebApplicationVirtualDirectory([string]$websiteName, [string]$webAppName, [string]$folderName)
{
	if(IsNullOrEmpty $websiteName)
	{
		Write-Warning "Website name cannot be null"
		return
	}
	if(IsNullOrEmpty $webAppName)
	{
		Write-Warning "WebApplication name cannot be null"
		return
	}
	if(IsNullOrEmpty $folderName)
	{
		Write-Warning "WebApplication folder name cannot be null"
		return
	}
	
	$topLevelSiteName = Split-Path -Parent $websiteName
	if(IsNullOrEmpty $topLevelSiteName)
	{
		$topLevelSiteName = $websiteName
	}	
	
	if(Test-WebSiteRunning $topLevelSiteName)
	{
		$websiteFolderName = Join-Path $defaultWeb -ChildPath $websiteName
		$webApplicationFolderName = Join-Path $websiteFolderName -ChildPath $webAppName
		if(Test-Path $webApplicationFolderName)
		{
			Set-ItemProperty IIS:\Sites\$websiteName\$webAppName -Name physicalPath -Value $webApplicationFolderName
		}
		else
		{
			Write-Warning "Web Application folder does not exist"
		}
	}
}

###########################################################################
####    Set products web application to corresponding app pool       ######
###########################################################################
function Set-WebApplicationAppPool([string]$websiteName, [string]$webAppName, [string]$webAppPoolName)
{
	if(IsNullOrEmpty $websiteName)
	{
		Write-Warning "Website name cannot be null"
		return
	}
	if(IsNullOrEmpty $webAppName)
	{
		Write-Warning "WebApplication name cannot be null"
		return
	}
	if(IsNullOrEmpty $webAppPoolName) 
	{
		Write-Warning "WebApplication AppPool name cannot be null"
		return
	}
	
	if(Test-Path IIS:\Sites\$websiteName)
	{
		if(Test-Path IIS:\Sites\$websiteName\$webAppName)
		{
			$iisWebApp = "IIS:\Sites\{0}\{1}" -f $websiteName, $webAppName
			Set-ItemProperty $iisWebApp -Name ApplicationPool -Value $webAppPoolName
		}
		else
		{
			Write-Warning "Web Application does not exist"
		}
	}
	else
	{
		Write-Warning "Website does not exist"
	}
}

###########################################################################
####                Set website to corresponding app pool            ######
###########################################################################
function Set-WebsiteAppPool([string]$websiteName, [string]$websiteAppPoolName)
{
	if(IsNullOrEmpty $websiteName)
	{
		Write-Warning "Website name cannot be null"
		return
	}
	if(IsNullOrEmpty $websiteAppPoolName)
	{
		Write-Warning "WebApplication AppPool name cannot be null"
		return
	}
	
	if(Test-Path IIS:\Sites\$websiteName)
	{
		$iisWebsite = "IIS:\Sites\{0}" -f $websiteName
		Set-ItemProperty $iisWebsite -Name ApplicationPool -Value $websiteAppPoolName	
	}
	else
	{
		Write-Warning "Website does not exist"
	}
}

##########################################################################
####                Check if application is running                  #####
##########################################################################
#function Test-WebApplicationRunning([string]$url)
#{
#	if($url)
#	{
#	    $status = Get-WebsiteState $url
#		if($status.Value -eq "Started")
#		{
#			return $True
#		}
#		else
#		{
#			return $False
#		}	
#	}
#}