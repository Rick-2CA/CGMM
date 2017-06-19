Function Import-CGMMExchOnline {
    <#
    .SYNOPSIS
	Connects to Exchange Online with a specific prefix

    .DESCRIPTION
	Connects to Exchange Online with a specific prefix used by the module to interact with the service.

    .EXAMPLE
    Import-CGMMExchOnline -Credential $Credential

	Connect to Exchange Online using the specified credentials.
    .NOTES

    #>

	[CmdletBinding()]
	Param(
		[parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[System.Management.Automation.CredentialAttribute()]
		$Credential
	)

	Begin {}
	
	Process {
		$Prefix = $CloudCmdletPrefix
		# New-PSSession
		$SessionParameters = @{
			'Name'					= $SessionName
			'ConfigurationName'		= 'Microsoft.Exchange(CGMM)'
			'ConnectionUri'			= 'https://outlook.office365.com/powershell-liveid/'
			'Credential'			= $Credential
			'Authentication'		= 'Basic'
		}
		Try {$Session = New-PSSession @SessionParameters -AllowRedirection -ErrorAction Stop}
		Catch {
			$PsCmdlet.ThrowTerminatingError($PSItem)
		}
		 
		# Import-PSSession
		$PSSessionParameters = @{
			'Session'	= $Session	
		}
		If ($Prefix) {$PSSessionParameters.Add("Prefix",$Prefix)}
		Try {$ModuleInfo = Import-PSSession @PSSessionParameters -AllowClobber -DisableNameChecking -ErrorAction Stop}
		Catch {
			$PsCmdlet.ThrowTerminatingError($PSItem)
		}
		
		# Import-Module
		$ModuleParameters = @{
			'ModuleInfo'	= $ModuleInfo	
		}
		If ($Prefix) {$ModuleParameters.Add("Prefix",$Prefix)}
		Try {
			Import-Module @ModuleParameters -DisableNameChecking -Global -ErrorAction Stop
		}
		Catch {
			$PsCmdlet.ThrowTerminatingError($PSItem)
		}
	}
	
	End {}
}