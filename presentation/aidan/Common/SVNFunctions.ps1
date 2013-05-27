<#
.SYNOPSIS
Launches TortoiseSVN with the given command.
Do the commit/update based on the command.
List of supported commands can be found at:
http://tortoisesvn.net/docs/release/TortoiseSVN_en/tsvn-automation.html
#>

param([string]$command = "commit", [string]$path, [string]$comments)

function Svn-Functions
(
	[string]$command = "update"
	, [string]$path
	, [string]$comments
)
{
	if($command.ToUpper() -eq "COMMIT" -and ($path))
	{
		svn $command $path -m $comments
	}
	if($command.ToUpper() -eq "UPDATE" -and ($path))
	{
		svn $command $path
	}
	if($command.ToUpper() -eq "UNLOCK" -and ($path))
	{
		svn $command $path
	}
	if($command.ToUpper() -eq "LOCK" -and ($path))
	{
		svn $command -m $comments --force $path
	}
	if($command.ToUpper() -eq "ADD" -and ($path))
	{
		svn $command $path
	}
}

Svn-Functions "$command" "$path" "$comments"