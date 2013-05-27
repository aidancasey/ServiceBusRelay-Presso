set-psdebug -strict

## Dependencies
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.Sdk.Sfc") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlEnum") | Out-Null

$thisFileName = $MyInvocation.MyCommand.Name

$private:scriptDirectory = Split-Path $MyInvocation.MyCommand.Path 
$private:scriptCommonDirectory = Join-Path -Path (Split-Path -parent $private:scriptDirectory) -ChildPath "Common"
. (Join-Path -Path $private:scriptCommonDirectory -ChildPath "CommonFunctions.ps1")


function Check-IfDatabaseExists([string] $serverName, [string] $databaseName)
{
	$sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($serverName)
	if ($sqlServer.Databases[$databaseName] -ne $null)
	{
		$true
	}
	else
	{
		$false
	}
}

function Check-IfDatabaseExistsUsingServerConnection($sqlServer, [string] $databaseName)
{
	if ($sqlServer.Databases[$databaseName] -ne $null)
	{
		$true
	}
	else
	{
		$false
	}
}

function Create-ServerConnection([string]$serverName, [string]$username, [string]$password)
{
	$serverConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($serverName, $username, $password)
	$sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($serverConnection)
	if ($sqlServer.Version -eq  $null )
	{
		Throw "Can't find the instance $serverName"
	};
	return [Microsoft.SqlServer.Management.Smo.Server] $sqlServer
}

function Create-DatabaseUsingServerConnection([Microsoft.SqlServer.Management.Smo.Server]$sqlServer, [string]$databaseName)
{
	$database = New-Object Microsoft.SqlServer.Management.Smo.Database($sqlServer, $databaseName)
	$database.Create()
}

function Create-Database([string]$serverName, [string]$databaseName)
{
	$sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($serverName)
	$database = New-Object Microsoft.SqlServer.Management.Smo.Database($sqlServer, $databaseName)
	$database.Create()
}

function Create-DbUserUsingServerConnection([Microsoft.SqlServer.Management.Smo.Server]$sqlServer, [string]$databaseName, [string]$username, [string]$login)
{	
	$database = $sqlServer.Databases($databaseName)
	if ($database.Users.Contains($username) -eq $false)
	{
		$user = New-Object Microsoft.SqlServer.Management.Smo.User($database, $username)
		$user.Login = $login
		$user.Create()
	}
}

function Create-SqlLoginUsingServerConnection([Microsoft.SqlServer.Management.Smo.Server]$sqlServer, [string]$databaseName, [string]$loginName, [string]$password)
{	
	Add-Content $log -value "databaseName=$databaseName loginName=$loginName password=$password "
	
	$sqlLoginExists = $sqlServer.Logins.Contains($loginName)
		
	$sqlServer.Logins | foreach { Add-Content "C:\temp\user.txt"  -value $_.Name}
	
	if ($sqlLoginExists -eq $true)
	{
		Add-Content $log -value "$loginName is found and is tobe deleted"
		#Delete existing login and set up a new login
		$sqlServer.Logins[$loginName].Drop();
	}
	
	$sqlLogin = New-Object Microsoft.SqlServer.Management.Smo.Login($sqlServer, $loginName)
	$sqlLogin.LoginType = [Microsoft.SqlServer.Management.Smo.LoginType]::SqlLogin
	$sqlLogin.DefaultDatabase = $databaseName
	$sqlLogin.Create($password)
	Add-Content $log -value "$loginName is recreated with new password"
	$sqlLogin	
}

function Create-SqlLogin([string]$serverName, [string]$databaseName, [string]$username, [string]$password)
{
	$sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($serverName)
	$sqlLoginExists = $sqlServer.Logins.Contains($username)
	
	if ($sqlLoginExists -eq $false)
	{
		$sqlLogin = New-Object Microsoft.SqlServer.Management.Smo.Login($sqlServer, $username)
		$sqlLogin.LoginType = [Microsoft.SqlServer.Management.Smo.LoginType]::SqlLogin
		$sqlLogin.DefaultDatabase = $databaseName
		$sqlLogin.Create($password)
		$sqlLogin
	}
	else 
	{	
		$sqlLogin = $sqlServer.Logins[$username]
		$sqlLogin
	}
}

function Create-DatabaseRoleUsingServerConnection($sqlServer, [string]$databaseName, [string]$username, [string]$loginName, [string[]]$roleNames)
{
	Add-Content $log -value "databaseName=$databaseName username=$username loginName=$loginName roleNames=$roleNames"
	$database = $sqlServer.Databases[$databaseName]
	if ($database.Users.Contains($username) -eq $true)
	{
		Add-Content $log -value "$databaseName contains $username it is to be deleted"
		#if user exists then deletes the user and then set up the user again
		$database.Users[$username].Drop();
	}
	
	$newUser = New-Object Microsoft.SqlServer.Management.Smo.User($database, $username)
	$newUser.Login = $loginName
	$newUser.DefaultSchema = "dbo"
	$newUser.Create()
	Add-Content $log -value "$username is created and relinked with login $loginName"
	
	foreach ($roleName in $roleNames)
	{	
		if ($database.Roles.Contains($roleName) -eq $false)
		{			
			$newRole = New-Object Microsoft.SqlServer.Management.Smo.DatabaseRole($database, $roleName)
			$newRole.Create()
	 		$permissionSet = New-Object Microsoft.SqlServer.Management.Smo.DatabasePermissionSet([Microsoft.SqlServer.Management.Smo.DatabasePermission]::Execute)
			$database.Grant($permissionSet, $roleName)		
			$newRole.AddMember($username);
		}
		$role = $database.Roles[$roleName]
		
		if ($role.EnumMembers().Contains($username) -eq $false)
		{
			Add-Content $log -value "role=$role  linked with $username"
			$role.AddMember($username);
		}
	
	}
}

function Assign-SqlLoginToDatabaseUsingServerConnection($sqlServer, [Microsoft.SqlServer.Management.Smo.Login]$sqlLogin, [string]$serverName, [string]$databaseName, [string[]]$sqlRoles)
{	
	$database = $sqlServer.Databases[$databaseName]
	$sqlUserExists = $database.Users.Contains($sqlLogin.Name)
	
	if ($sqlUserExists -eq $false)
	{
		$sqlUser = New-Object Microsoft.SqlServer.Management.Smo.User($database, $sqlLogin.Name);
		$sqlUser.UserType = [Microsoft.SqlServer.Management.Smo.UserType]::SqlLogin
		$sqlUser.Login = $sqlLogin.Name
		$sqlUser.Create()
		
		if ($sqlRoles.Count -lt 1)
		{
			$sqlRoles = @("db_datareader", "db_datawriter")
		}
		foreach($role in $sqlRoles)
		{
			$sqlUser.AddToRole($role)
		}
		$sqlUser.Alter()
	}
}

function Assign-SqlLoginToDatabase([Microsoft.SqlServer.Management.Smo.Login]$sqlLogin, [string]$serverName, [string]$databaseName, [string[]]$sqlRoles)
{
	$sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($serverName)
	$database = $sqlServer.Databases[$databaseName]
	$sqlUserExists = $database.Users.Contains($sqlLogin.Name)
	
	if ($sqlUserExists -eq $false)
	{
		$sqlUser = New-Object Microsoft.SqlServer.Management.Smo.User($database, $sqlLogin.Name);
		$sqlUser.UserType = [Microsoft.SqlServer.Management.Smo.UserType]::SqlLogin
		$sqlUser.Login = $sqlLogin.Name
		$sqlUser.Create()
		
		if ($sqlRoles.Count -lt 1)
		{
			$sqlRoles = @("db_datareader", "db_datawriter")
		}
		foreach($role in $sqlRoles)
		{
			$sqlUser.AddToRole($role)
		}
		$sqlUser.Alter()
	}
}

# the following function uses a trusted database connection 
function Invoke-DatabaseUpgradeScript($upgraderPath, $dbServerName, $databaseName)
{
	Try
	{
		Write-Host "UpgradePath = $upgraderPath"
		Start-Process -FilePath "$upgraderPath" -ArgumentList " -C -S$dbServerName -D$databaseName -A " -Wait -NoNewWindow  
	}
	Catch
	{
		Log-Error $thisFileName "Error executing database upgrade script"
		Log-Error $thisFileName $_.Exception.Message
		Write-Host $_.Exception.Message
		break
	}
	
	Log-Info $thisFileName "Successfully applied database upgrade script"
}

function Invoke-DatabaseUpgradeScriptUsingUsername([string]$upgraderPath, [string]$dbServerName, [string]$databaseName, [string]$username, [string]$password)
{
	try
	{
		Write-Host "UpgradePath = $upgraderPath"
		if ([string]::IsNullOrEmpty($upgraderPath) -eq $false)
		{
			Start-Process -FilePath "$upgraderPath" -ArgumentList " -C -S`"$dbServerName`" -D`"$databaseName`" -U`"$username`" -P`"$password`" " -Wait -NoNewWindow  
		}
	}
	catch
	{
		Log-Error $thisFileName "Error executing database upgrade script"
		Log-Error $thisFileName $_.Exception.Message
		Write-Host $_.Exception.Message
	}
}

function Check-DatabaseMirroringEnabled($serverName, $databaseName)
{
	$sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($serverName)
	$database = New-Object Microsoft.SqlServer.Management.Smo.Database($sqlServer, $databaseName)
	return $database.IsMirroringEnabled
}

function Invoke-SqlScriptFromFile([string] $server, [string]$catalog, [string]$scriptName)
{
	if ([string]::IsNullOrEmpty($server))
	{
		$server="localhost" ;
	}
	$arguments = "-S $server -i $scriptName -W -h-1" ;
	if (!([string]::IsNullOrEmpty($catalog)))
	{
		$arguments += " -d $catalog" ;
	}

	Add-Content $log -value "Invoke-SqlScriptFromFile - arguments=$arguments "
	try
	{
		return (Start-ProcessAndWait -FilePath "sqlcmd.exe" -ArgumentList $arguments )
	}
	Catch
	{
		Log-Error $thisFileName "Error running sqlcmd with $arguments"
		Log-Error $thisFileName $_.Exception.Message
		Write-Host $_.Exception.Message
	}
#	Start-Process -FilePath "osql.exe" -ArgumentList "-i $scriptName -S $server -E $database" -Wait -NoNewWindow
}

function Invoke-SqlScript([string] $server, [string]$catalog, [string]$username, [string]$password, [string]$sqlScript, [string]$scriptFile)
{
	if ([string]::IsNullOrEmpty($server))
	{
		break ;
	}
	if ([string]::IsNullOrEmpty($catalog))
	{
		break ;
	}

	$arguments = " -S $server -d $catalog -W -h-1"
	if ([string]::IsNullOrEmpty($username))
	{
		$arguments += " -E " ;
	}
	else
	{
		$arguments += " -U $username -P $password " ;
	}
	if ([string]::IsNullOrEmpty($sqlScript))
	{
		$arguments += " -i `"$scriptFile`" " ;
	}
	else
	{
		$arguments += " -Q ""$sqlScript"" "	;
	}
	
	Add-Content $log -value "Invoke-SqlScript - arguments=$arguments "
	try
	{
		return (Start-ProcessAndWait -FilePath "sqlcmd.exe" -ArgumentList $arguments )
	}
	Catch
	{
		Log-Error $thisFileName "Error running sqlcmd with $arguments"
		Log-Error $thisFileName $_.Exception.Message
		Write-Host $_.Exception.Message
	}
}

<#
	.SYNOPSIS
	    List all the tables in a particular database
    .OUTPUTS
    	True / False - depending on success of the operation
#>
function List-TablesInDatabase
{
	param (
		[Microsoft.SqlServer.Management.Smo.Server]
			$sqlServer
		, [String]
			$database
	)
	Try
	{
		$db = $sqlServer.Databases[$Database];
		if ($db.name -ne $Database) {Throw "Can't find the database '$Database' in $sqlServer"};
		$Table = @() ;	
		foreach ($myTable in $db.Tables)
		{
			$table += $myTable.Name
		}
		return ( ($table) -join "," )
	}
	Catch
	{
		Log-Error $thisFileName "Error listing tables for $Database"
		Log-Error $thisFileName $_.Exception.Message
		Write-Host $_.Exception.Message
	}
}

<#
	.SYNOPSIS
	    Exports the database structure for the chosen db.
    .OUTPUTS
    	True / False - depending on success of the operation
#>
function Copy-StructureFromDatabaseToFile
{
	param (
			[Microsoft.SqlServer.Management.Smo.Server] # Token with server connection
				$sqlServer
			, [String]			# the database to create the structure from
				$Database
			, [String]			# local directory to save build-scripts to
				$FilePath
	)
	$db = $sqlServer.Databases[$Database] 
	if ($db.name -ne $Database)
	{
		Throw "Can't find the database '$Database' in $sqlServer"
	};
	# Create the Database root directory if it doesn't exist
	Create-Folder "$FilePath"
	$Filename = "$($FilePath)\$($Database)_Structure.sql"
	
	$CreationScriptOptions = new-object ("Microsoft.SqlServer.Management.Smo.ScriptingOptions") 
	$CreationScriptOptions.ExtendedProperties		= $true; # yes, we want these
	$CreationScriptOptions.DRIAll 					= $true; # and all the constraints 
	$CreationScriptOptions.Indexes					= $true; # Yup, these would be nice
	$CreationScriptOptions.Triggers					= $true; # This should be included when scripting a database
	$CreationScriptOptions.ScriptBatchTerminator 	= $true; # this only goes to the file
	$CreationScriptOptions.IncludeHeaders 			= $true; # of course
	$CreationScriptOptions.ToFileOnly 				= $true; # no need of string output as well
	$CreationScriptOptions.IncludeIfNotExists 		= $true; # not necessary but it means the script can be more versatile
#	$CreationScriptOptions.IncludeDatabaseRoleMemberships = $true;
	$CreationScriptOptions.Filename =  $Filename ; 
	$transfer = new-object ("Microsoft.SqlServer.Management.Smo.Transfer") $db ;

	$transfer.options = $CreationScriptOptions ; # tell the transfer object of our preferences
	$transfer.ScriptTransfer() ;
}

<#
	.SYNOPSIS
	    Exports the database data for the chosen db.
    .OUTPUTS
    	True / False - depending on success of the operation
#>
function Copy-DataFromDatabaseToFile
{
	param (
			[Microsoft.SqlServer.Management.Smo.Server] # Token with server connection
				$sqlServer
			, [String]			# the database to create the structure from
				$Database
			, [String]			# local directory to save build-scripts to
				$FilePath
			, [String]			# list of tables to gather data for - leave blank for all tables
				$TableList = ""
	)

	# Create the Database root directory if it doesn't exist
	Create-Folder "$FilePath"
	$Filename = "$($FilePath)\$($Database)_data.sql"

	$scripter = new-object ('Microsoft.SqlServer.Management.Smo.Scripter') $sqlServer
	$scripter.Options.ScriptSchema 			= $False; # no we're not scripting the schema
	$scripter.Options.ScriptData 			= $true; # but we're scripting the data
	$scripter.Options.NoCommandTerminator 	= $true; # don't worry about ; at end
	$scripter.Options.FileName 				= $Filename #writing out the data to file
	$scripter.Options.ToFileOnly 			= $true #who wants it on the screen?
	$ServerUrn = $sqlServer.Urn #we need this to construct our URNs.

	if (!$TableList)	# Get a list of all tables if they are not supplied.
	{
		$TableList = List-TablesInDatabase -sqlServer $sqlServer -database $database
	}

	#so we just construct the URNs of the objects we want to script
	$UrnsToScript = New-Object Microsoft.SqlServer.Management.Smo.UrnCollection
	$Table=@()
	foreach ($tablepath in $TableList -split ',')
	{
		$Tuple = "" | Select Database, Schema, Table ;
		$TableName = $tablepath.Trim() -split '.',0,'SimpleMatch' ;
	    switch ($TableName.count)
		{ 
			1 { $Tuple.database=$database; $Tuple.Schema='dbo'; $Tuple.Table=$tablename[0];  break}
			2 { $Tuple.database=$database; $Tuple.Schema=$tablename[0]; $Tuple.Table=$tablename[1];  break}
			3 { $Tuple.database=$tablename[0]; $Tuple.Schema=$tablename[1]; $Tuple.Table=$tablename[2];  break}
			default {throw 'too many dots in the tablename'}
	  	}
		$Urn = "$ServerUrn/Database[@Name='$($tuple.database)']/Table[@Name='$($tuple.table)' and @Schema='$($tuple.schema)']"; 
		$UrnsToScript.Add($Urn) 
	}

	#and script them
	$scripter.EnumScript($UrnsToScript) #Simple eh?
	
}
