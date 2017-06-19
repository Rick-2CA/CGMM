Function Import-CGMMExchOnPrem {
    <#
    .SYNOPSIS
	Connects to on premise Exchange with a specific prefix

    .DESCRIPTION
	Connects to on premise Exchange with a specific prefix used by the module to interact with the service.

    .EXAMPLE
    Import-CGMMExchOnPrem -Credential $Credential -ExchangeServer $ExchangeServer

	Connect to a specified on premise Exchange server using the specified credentials.
    .EXAMPLE
	Import-CGMMExchOnPrem -Credential $Credential -ExchangeServer $ExchangeServer -ViewEntireForest

	Connect to a specified on premise Exchange server using the specified credentials and configures the setting to view the entire forest.
    .NOTES

    #>

	[CmdletBinding()]
	Param(
		[parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[System.Management.Automation.CredentialAttribute()]
		$Credential,

		[parameter(Mandatory)]
		[string]$ExchangeServer,

		[parameter()]
		[switch]$ViewEntireForest
	)

	Begin {}
	
	Process {
		$Prefix = $PremCmdletPrefix

		# New-PSSession
		$SessionParameters = @{
			'Name'					= $SessionName 
			'ConfigurationName'		= 'Microsoft.Exchange(CGMM)'
			'ConnectionUri'			= "http://$($ExchangeServer)/Powershell/?SerializationLevel=Full"
			'Credential'			= $Credential
			'Authentication'		= 'Kerberos'
		}
		Try {$Session = New-PSSession @SessionParameters -ErrorAction Stop}
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
		Try {Import-Module @ModuleParameters -DisableNameChecking -Global -ErrorAction Stop}
		Catch {
			$PsCmdlet.ThrowTerminatingError($PSItem)
		}
		
		# Set-ADServerSettings to view the entire forest
		If ($ViewEntireForest) {
			$ADServerSettings = Get-Command "Set-$($Prefix)ADServerSettings"
			If ($ADServerSettings) {
				& $ADServerSettings -ViewEntireForest $True
			}
		}
	}
	
	End {}
}