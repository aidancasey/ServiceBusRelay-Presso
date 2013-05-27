try
{
	[reflection.assembly]::GetAssembly([type]"TeamcityBuildStatus") | Out-Null 
}
catch  [system.exception]
{
	Add-Type -TypeDefinition @"
   // declaring enum to describe teamcity output possibilities
   public enum TeamcityBuildStatus
   {
      SUCCESS,
	  FAILURE
   }
"@
}

try
{
	[reflection.assembly]::GetAssembly([type]"AWSAccountType") | Out-Null 
}
catch  [system.exception]
{
	Add-Type -TypeDefinition @"
   // declaring enum to describe AWS account types
   public enum AWSAccountType
   {
      Dev,
	  PreProd,
	  Production
   }
"@
}


try
{
	[reflection.assembly]::GetAssembly([type]"OnlineVersionStatus") | Out-Null 
}
catch  [system.exception]
{
	Add-Type -TypeDefinition @"
   // declaring enum to describe applicable Online version status of a specific version
   public enum OnlineVersionStatus
   {
      current,
	  live,
	  deprecated,
	  keep,
	  superseeded
   }
"@
}