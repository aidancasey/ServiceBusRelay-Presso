## Use $local: to force use of local variable and avoid issues if a global 
##  variable have the same name


if (!(test-path variable:\commonScriptRunLocation)) 
{
	Set-Variable -Name "commonScriptRunLocation" -Option Constant -Value  (Split-Path $MyInvocation.MyCommand.Path)
} # test for EXISTENCE & create

.(Join-Path -Path $commonScriptRunLocation -ChildPath "CommonTypes.ps1")

## Constants
$OS32Bit = "32-Bit"
$OS64Bit = "64-Bit"
$LogName = "Application"

## This function works for windows XP, 2003, 7, 2008
function Get-OSArchitecture
{
	$local:computer = $env:ComputerName
	$local:osArchitecture = $OS32Bit
	if ((Get-WmiObject -Class Win32_OperatingSystem -ComputerName $local:computer -ea 0).OSArchitecture -eq $OS64Bit) 
	{
		$local:osArchitecture = $OS64Bit
	}

	return $local:osArchitecture
}

## Determine if a string is null or empty
function IsNullOrEmpty([String] $value)
{
	return [String]::IsNullOrEmpty($value)
}

## Get-IdsFromParameterList
## 	to convert an array of Ids to a list of Ids
## Parameter : array of Ids
function Get-IdsFromParameterList([String] $paramList)
{
	$idList = New-Object -TypeName System.Collections.Generic.List[String]
	
	[String[]] $paramListArray = $paramList.Split(',')
		
	foreach ($item in $paramListArray) 
	{
		$idList.Add($item.Trim())
	}
	
	,$idList
}

## Create-Folder
##  Creates a folder if it does not exist
## Parameter : 
##  folderName - name of folder to create
function Create-Folder($folderName)
{
	if (!(IsNullOrEmpty $folderName) -and !(Test-Path $folderName))
	{
		Try
		{
			New-Item $folderName -ItemType Directory
		}
	    Catch [system.exception]
		{	
			Write-Error "error while creating '$folderName'  $_"
	        return
	    }  
	}
}

## Delete-Folder
##  Deletes a folder and everyting inside it, if it exists
## Parameter : 
##  folderName - name of folder to create
function Delete-Folder($folderName)
{
	if (!(IsNullOrEmpty $folderName) -and (Test-Path $folderName))
	{
		Remove-Item $folderName -recurse		
		Write-Host "Local directory $logDirectory deleted"
	}	
}

## Get all the files from a specific directory
## Parameters : 
##  $directory     - is the directory to search for the files
##  $filter        - is the filter to narrow the selection option
##  $isRecursive   - is used to search recursively in a folder
function Get-Files( [String]$directory = "$pwd" , [String]$filter, [bool]$isRecursive) 
{ 
	$availableFiles = $null
	
 	if($isRecursive)
	{
  		$availableFiles = Get-ChildItem $directory -Filter $filter -Recurse -Name
	}
	else
	{
		$availableFiles = Get-ChildItem $directory -Filter $filter -Name
	}
  
	return $availableFiles 
	#return $availableFiles | Select-Object mode,name
} 

## Log-Info
##  create an information entry into the event log
## Parameter : message string to be logged
function Log-Info([String]$logSource, [String]$message)
{
	Create-EventLogIfItDoesNotExist $logSource
	Write-EventLog -LogName $LogName -Source $logSource -EntryType Information -EventId 25000 -Message $message
}

## Log-Error
##  create an error entry into the event log
## Parameter : message string to be logged
function Log-Error([String]$logSource, [String]$message)
{
	Create-EventLogIfItDoesNotExist $logSource
	Write-EventLog -LogName $LogName -Source $logSource -EntryType Error -EventId 25000 -Message $message
}

function Create-EventLogIfItDoesNotExist([String]$logSource)
{
	if (![System.Diagnostics.EventLog]::SourceExists($logSource))
	{
		New-EventLog -LogName $LogName -Source $logSource
	}
}

## Convert-ToBase64
##  to convert a string into base 64 encoding
## Parameter :
##  $string - string to be converted
function Convert-ToBase64($string) {
   $bytes  = [System.Text.Encoding]::UTF8.GetBytes($string);
   $encoded = [System.Convert]::ToBase64String($bytes); 

   return $encoded;
}

## Convert-FromBase64
##  decode a string that has been base64 encoded
## Parameter :
##  $string - base64 string to be converted
function Convert-FromBase64($string) {
   $bytes  = [System.Convert]::FromBase64String($string);
   $decoded = [System.Text.Encoding]::UTF8.GetString($bytes); 

   return $decoded;
}

## Replace-TokenInString
##  replace tokens in a string array and return the replaced contents
## Parameter : 
##  $source           - string array containing tokens to be replaced
##	$hashReplacerTags - hash table for replacement
function Replace-TokenInString([String[]] $source, [Hashtable] $hashReplacerTags)
{
	Try
	{
		$lines = $source
		for($i = 0; $i -le $local:lines.length ; $i++)
		{
			$line = $local:lines[$i]
			foreach($replacer in $hashReplacerTags.Keys)
			{
				if($line -match $replacer )
				{
					$line = $line -replace $replacer, $hashReplacerTags[$replacer]
				}
			}
			$fileout = $fileout+$line+"`n"
		}
		return $fileout
	}
	Catch
	{
		Write-Error "Failed to replace tokens in file. $_.Exception.ToString()"		
	}
	return ""
}

function Check-IfWindowsAccountExists([String]$hostname, [String]$username)
{
	$adsi = [adsi] "WinNT://$hostname"
	
	$allUsers = ($adsi.PSBase.Children |
			    Where-Object {$_.psBase.SchemaClassName -eq "User"} |
			    Select-Object -expand Name)

	$userFound = $allUsers -contains $username

	if ($userFound -eq $true)
	{
		$true
	}
	else
	{
	    $false
	}
}

function Create-WindowsAccount ([String]$hostname, [String]$username, [String]$password) {   
	$adsi = [adsi] "WinNT://$hostname"  
   	$user = $adsi.Create("User", $username)
   	$user.SetPassword($password)   
   	$user.SetInfo()   
}

function Create-DomainAccount ([String]$domainName, [String]$networkName, [String]$username, [String]$password)
{
	if ([String]::IsNullOrEmpty($networkName))
	{
		$networkName="local"
	}
	$objOU=[ADSI]"LDAP://DC=$domainName,DC=$networkName"
	$objUser=$objOU.Create("user","CN=$username")
	$objUser.Put("sAMAccountName","$username")
	$objUser.SetInfo()
	$objUser.psbase.properties
	$objUser | get-member
	$objUser.SetPassword("$password")
	$objUser.psbase.InvokeSet("AccountDisabled",$false)
	$objUser.SetInfo()
}

function Get-WindowsService([String]$serviceName)
{
	$local:service = Get-WmiObject win32_service -Filter "name='$serviceName'"
	return $local:service
}

function Get-WindowsServiceStatus([String]$serviceName)
{
	$local:service = Get-WindowsService $serviceName
	$local:service.State
}

function Wait-UntilServiceIsStopped([String]$serviceName)
{
	$local:service = Get-WindowsService $serviceName
	Wait-Event ($local:service.State -eq 'Stopped') -Timeout 30
}

function Wait-UntilServiceIsStarted([String]$serviceName)
{
	$local:service = Get-WindowsService $serviceName
	Wait-Event ($local:service.State -eq 'Started') -Timeout 30
}

function Set-WebConfigSqlConnectionString([String]$configfile, [String]$connectionString, [bool]$backup = $true)
{	
	$webConfigPath = (Resolve-Path $configfile).Path 
	$configfileName = [System.IO.Path]::GetFileNameWithoutExtension($configfile)
	$configExtension = [System.IO.Path]::GetExtension($configfile)
	$folder = $webConfigPath.SubString(0, $webConfigPath.Length - $configfileName.Length - $configExtension.Length)
		
	$currentDate = (get-date).tostring("yyyymmdd-hhmmss")
	$backupFile = Join-Path -Path $folder -ChildPath $configfileName 
	$backupFile = $backupFile + "_$currentDate" + $configExtension

	# Get the content of the config file and cast it to XML and save a backup copy labeled .bak
	$xml = [xml](get-content $webConfigPath)
	
	if (! [String]::IsNullOrEmpty($connectionString))
	{
		#save a backup copy if requested
		if ($backup) {$xml.Save($backupFile)}
		$root = $xml.get_DocumentElement();
		$root.connectionStrings.add.connectionString = $connectionString
		# Save it
		$xml.Save($webConfigPath)
	}
}

function Get-ConnectionString([String] $dbServer, [String]$catalog, [String]$username, [String]$password, [Bool] $useIntegratedSecurity=$FALSE, [Bool]$encryptConnection=$FALSE)
{
	[String] $connectionString = "Data Source=$dbServer;Initial Catalog=$catalog;"
	
	if ($encryptConnection)
	{
		$connectionString += "encrypt=true;"
	}
	if ($useIntegratedSecurity)
	{
		$connectionString += "Trusted_Connection=True";
	}
	else
	{
		$connectionString += "Persist Security Info=True;User ID=$username;Password=$password;"
	}

	return $connectionString
}

<#
	.SYNOPSIS
	    Reads the contents of all files of a particular type in a sub-directory
	.PARAMETER FilePath
		name of filepath to get filecontents for
	.OUTPUTS
		Contents of the files
#>
Function Get-MultipleLogFileContents {
	Param 
	(
		[Parameter(Mandatory=$true)][String]$FilePath
	)
	$cr = "`n"
	[String]$contentsPrefix = "$cr  "
	[String]$result = ""
	foreach( $fileName in Get-ChildItem -Path $FilePath -Include "*.Log" -recurse ) 
	{ 
		$result = $result + "** Begin $($fileName.Name)$cr" 
		$result = $result + "----------------------------------------$contentsPrefix"
	    $result = $result + [String](Get-Content $fileName | out-string).Replace("$cr", "$contentsPrefix")
		$result = $result + "$cr----------------------------------------$cr"
		$result = $result + "** End $($fileName.Name)$cr"
	}         

	return $result
}

<#
	.SYNOPSIS
	    Open a Remote Desktop Terminal Session
	.PARAMETER server
		Address / Server to connect to
	.PARAMETER user
		Username credentials to use
	.PARAMETER pass
		Password credentials to use
	.PARAMETER waitPeriod
		sleep period after setting RDC (before calling) and cleanup after activating
	.OUTPUTS
		None
#>
function Start-RDCSession([String]$server, [String]$user, [String]$pass, [Int]$waitPeriod = 6)
{
  Write-Host "- saving RDP credential" -ForegroundColor Blue
  cmdkey /delete:TERMSRV/$server
  cmdkey /delete:TERMSRV/$server /user:[Environment]::UserDomainName\[Environment]::UserName
  cmdkey /generic:TERMSRV/$server /user:$user /pass:$pass
  Write-Host "- opening RDP" -ForegroundColor Blue
  mstsc /v:$server
  ## Cleanup - need to wait as otherwise credentials are wiped prior to Remote Desktop intialisation completing
  Wait-Event -Timeout $waitPeriod
  cmdkey /delete:TERMSRV/$server
}

<#
	.SYNOPSIS
	    Write a formatted error message out.
	.OUTPUTS
		None
#>
function Write-FormattedError
{
	param 
	(
		[String]					# Error message to log
			$message
		, [Exception]				# Exception to log (contains more than just text)
			$exception
		, [String] 					# Reason for the error occurring
			$errorReason			
		, [String] 					# actions to take to correct the issue
			$recommendedAction
	)

	$formattedError = $message 
	if (! (IsNullOrEmpty $exception))
	{
		$formattedError = ("{0}`n ErrorCode: {1}`n Message: {2}" -f $formattedError, $exception.ErrorCode, $exception.Message)
	}
	if (! (IsNullOrEmpty $errorReason))
	{
		$formattedError = ("{0}`n Reason: {1}" -f $formattedError, $errorReason)
	}
	if (! (IsNullOrEmpty $recommendedAction))
	{
		$formattedError = ("{0}`n RecommendedAction: {1}" -f $formattedError, $recommendedAction)
	}
	$formattedError = ("{0}`n StackTrace: {1}" -f $formattedError, $StackTrace)
	Write-Error $formattedError
}

<#
	.SYNOPSIS
	    Modify a string to be XML safe
#>
function Convert-SafeXml([String] $value)
{
	return (((($value -replace "<","&gt;") -replace ">", "&lt;") -replace "&", "&amp;") -replace """", "&quot;") 
}

<#
.SYNOPSIS
Outputs random strings.

.DESCRIPTION
Outputs one or more random strings containing specified types of characters.

.PARAMETER Length
Specifies the length of the output string(s). The default value is 8. You cannot specify a value less than 4.

.PARAMETER LowerCase
Specifies that the string must contain lowercase ASCII characters (default). Specify -LowerCase:$false if you do not want the random string(s) to contain lowercase ASCII characters.

.PARAMETER UpperCase
Specifies that the string must contain upercase ASCII characters.

.PARAMETER Numbers
Specifies that the string must contain number characters (0 through 9).

.PARAMETER Symbols
Specifies that the string must contain typewriter symbol characters.

.PARAMETER Count
Specifies the number of random strings to output.

.EXAMPLE
PS C:\> Get-RandomString
Outputs a string containing 8 random lowercase ASCII characters.

.EXAMPLE
PS C:\> Get-RandomString -Length 14 -Count 5
Outputs 5 random strings containing 14 lowercase ASCII characters each.

.EXAMPLE
PS C:\> Get-RandomString -UpperCase -LowerCase -Numbers -Count 10
Outputs 10 random 8-character strings containing uppercase, lowercase, and numbers.

.EXAMPLE
PS C:\> Get-RandomString -Length 32 -LowerCase:$false -Numbers -Symbols -Count 20
Outputs 20 random 32-character strings containing numbers and typewriter symbols.

.EXAMPLE
PS C:\> Get-RandomString -Length 4 -LowerCase:$false -Numbers -Count 15
Outputs 15 random 4-character strings containing only numbers.
#>
function Get-RandomString([UInt32] $Length=8, [Switch] $LowerCase=$TRUE, [Switch] $UpperCase,  [Switch] $Numbers,  [Switch] $Symbols,  [Uint32] $Count=1)
{
	if ($Length -lt 4) {
	  throw "-Length must specify a value greater than 3"
	}

	if (-not ($LowerCase -or $UpperCase -or $Numbers -or $Symbols)) {
	  throw "You must specify one of: -LowerCase -UpperCase -Numbers -Symbols"
	}

	# Specifies bitmap values for character sets selected.
	$CHARSET_LOWER = 1
	$CHARSET_UPPER = 2
	$CHARSET_NUMBER = 4
	$CHARSET_SYMBOL = 8

	# Creates character arrays for the different character classes,
	# based on ASCII character values.
	$charsLower = 97..122 | foreach-object { [Char] $_ }
	$charsUpper = 65..90 | foreach-object { [Char] $_ }
	$charsNumber = 48..57 | foreach-object { [Char] $_ }
	$charsSymbol = 35,36,42,43,44,45,46,47,58,59,61,63,64,91,92,93,95,123,125,126 | foreach-object { [Char] $_ }

	# Contains the array of characters to use.
	$charList = @()
	# Contains bitmap of the character sets selected.
	$charSets = 0
	if ($LowerCase) {
	  $charList += $charsLower
	  $charSets = $charSets -bor $CHARSET_LOWER
	}
	if ($UpperCase) {
	  $charList += $charsUpper
	  $charSets = $charSets -bor $CHARSET_UPPER
	}
	if ($Numbers) {
	  $charList += $charsNumber
	  $charSets = $charSets -bor $CHARSET_NUMBER
	}
	if ($Symbols) {
	  $charList += $charsSymbol
	  $charSets = $charSets -bor $CHARSET_SYMBOL
	}

	1..$Count | foreach-object {
	  # Loops until the string contains at least
	  # one character from each character class.
	  do {
	    # No character classes matched yet.
	    $flags = 0
	    $output = ""
	    # Create output string containing random characters.
	    1..$Length | foreach-object {
	      $output += $charList[(get-random -maximum $charList.Length)]
	    }
	    # Check if character classes match.
	    if ($LowerCase) {
	      if (test-stringcontents $output $charsLower) {
	        $flags = $flags -bor $CHARSET_LOWER
	      }
	    }
	    if ($UpperCase) {
	      if (test-stringcontents $output $charsUpper) {
	        $flags = $flags -bor $CHARSET_UPPER
	      }
	    }
	    if ($Numbers) {
	      if (test-stringcontents $output $charsNumber) {
	        $flags = $flags -bor $CHARSET_NUMBER
	      }
	    }
	    if ($Symbols) {
	      if (test-stringcontents $output $charsSymbol) {
	        $flags = $flags -bor $CHARSET_SYMBOL
	      }
	    }
	  }
	  until ($flags -eq $charSets)
	  # Output the string.
	  $output
	}
}
# Returns True if the string contains at least one character
# from the array, or False otherwise.
function test-stringcontents([String] $test, [Char[]] $chars) {
  foreach ($char in $test.ToCharArray()) {
    if ($chars -ccontains $char) { return $TRUE }
  }
  return $FALSE
}

<#
	.SYNOPSIS
	    Checks the web output for communication. Used for asset web-page connectivity
    .OUTPUTS
    	True / False
#>
function Test-WebChannel 
{
	param(
		[String]
			$PathToCheck
		, [String]
			$errorMsgToUse = "There was an issue connecting to Route53 or the web-servers."
		, [Int]
			$timeoutInSeconds = 90
	)
	$wc = new-object System.Net.WebClient;
	$result = $false;
	$timeout = (Get-Date).addseconds($timeoutInSeconds);
	Write-Host "Attempting to request info from server: `"$PathToCheck`""
	
	Do 
	{	
		$currentDate = Get-Date
		Try
		{
			$eipString = $wc.DownloadString("$PathToCheck")
			if ($eipString)
			{
				Write-Host "server request returned the following: $eipString"
				$result = $true
			}
			else
			{
				Write-Host "server request is valid - but did not return any information"
			}
		}
		Catch
		{
			if ($timeout -ge $currentDate)
			{
				sleep 5 ;
			}
		}
	}
	While ( (!$result) -and ($timeout -ge $currentDate))
	if (!$result)
	{
		Write-Host $errorMsgToUse -ForegroundColor Red
	}

	
	$wc.Dispose | Out-Null
	return $result;
}


<#
	.SYNOPSIS
	    Writes build status to teamcity
#>
function Write-TeamcityBuildStatus
{
	param(
		[TeamcityBuildStatus]
			$buildStatus		
	)
	
	Write-Host "##teamcity[buildStatus status='$buildStatus']"
	
}


<#
	.SYNOPSIS
	    Create a basic log function for use in the Userdata of an instance. Usage: LU "Text" 
    .OUTPUTS
    	String to add into the top of userdata section of the script. 
	.NOTE
		Since this was written we have used a simplified inline function called: WL
#>
function Log-Data
{
	param (
		[String] 
			$filename = "C:\Deploy\userdata.log"
		)
	$result = "Function LU ([Parameter(Position=0, ValueFromPipeline=`$true, ValueFromPipelineByPropertyName=`$true)][String]`$logstring	, [Switch]`$clearFile = `$false)
	{
		if (`$clearFile -eq `$true) {Remove-Item $filename}
		`$logstring = (Get-Date -UFormat `"%Y/%m/%d %T`") + `" `" + `$logstring
		write-host	`"`$logstring`"		
		Add-Content -Path ""$filename"" -Value `"`$logstring`"
	}
	"
	return $result
}

<#
	.SYNOPSIS
	    Wrapper for start process. moves stdout into return string. Will wait for process to return.
    .OUTPUTS
    	Response from 
#>
function Start-ProcessAndWait
{
    param (
         [String]
            $FilePath = $(Throw "An executable must be specified")
        ,[String]
            $argumentList
    )
    $processFile = "processoutput.txt"

    Remove-Item $processFile ;
	if (IsNullOrEmpty $argumentList)
	{
		Start-Process -FilePath $FilePath -Wait -NoNewWindow -RedirectStandardOutput $processFile
	}
	else
	{
    	Start-Process -FilePath $FilePath -ArgumentList $argumentList -Wait -NoNewWindow -RedirectStandardOutput $processFile
	}
    $result = [IO.File]::ReadAllText($processFile) ;

    return $result ;
}


