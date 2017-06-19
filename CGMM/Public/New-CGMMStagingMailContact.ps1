Function New-CGMMStagingMailContact {
    <#
    .SYNOPSIS
	Creates a new on premise Exchange mail contact staged with prefixed property values.

    .DESCRIPTION
	Creates a new on premise Exchange mail contact staged with prefixed property values.  The prefixed properties are name properties or properties that are required to be unique in Exchange.  This allows you to confirm settings based on an existing on premise group before removing the group to be replaced by the mail contact.

    .EXAMPLE
    New-CGMMStagingMailContact -Name $Name -ExternalEmailAddress $ExternalEmailAddress

	Mandatory parameters to create a staged mail contact.  Each of the mandatory parameter values will be updated with the module's prefix when creating the new mail contact.  Additionally the alias and displayname will be prefixed based off the name parameter if not specified.

    .EXAMPLE
	New-CGMMStagingMailContact -Name $Name -ExternalEmailAddress $ExternalEmailAddress -Alias $Alias -Displayname $DisplayName -DomainController $DomainControllerFQDN -OrganizationalUnit $OU

	Create a staged mail contact with prefixed name, external email address, alias, and displayname with a specified domain controller and organizational unit for your on premise directory services.

    .EXAMPLE
    New-CGMMStagingMailContact -Name $Name -ExternalEmailAddress $ExternalEmailAddress -DomainController $DomainController

    Specify a domain controller to aid in making all on premise changes in the same location to avoid AD replication challenges.

    .NOTES

    #>
    [cmdletbinding(SupportsShouldProcess)]
    param(
		# Mandatory parameters
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$ExternalEmailAddress,

		# Optional Parameters
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Alias,

        [Parameter()]
		[string]$DisplayName,

        [Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$DomainController,

        [Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$OrganizationalUnit
    )

	begin {}
	process	{
        # Check for Exchange cmdlet availability in On Prem & Exchange Online
        Try {Test-CGMMCmdletAccess -Environment OnPrem -ErrorAction Stop}
        Catch {
            $PsCmdlet.ThrowTerminatingError($PSItem)
        }
				
		# Apply prefix to mandatory fields
		Write-Verbose "Applying prefix to mandatory fields"
		$MandatoryParameters = @('Name','ExternalEmailAddress')
		ForEach ($Parameter in $MandatoryParameters) {
			# Just in case someone offers the prefix up voluntarily...
			If ($Parameter -notmatch "^$($StagingGroupPrefix)") {
				$PSBoundParameters.$Parameter = $StagingGroupPrefix + $PSBoundParameters.$Parameter
			}
		}

		# Check for and apply prefix to optional fields
		Write-Verbose "Applying prefix to optional fields"
		$OptionalParameters = @('Alias','DisplayName')
		ForEach ($Parameter in $OptionalParameters) {
			If ($PSBoundParameters.$Parameter) {
				If ($Parameter -notmatch "^$($StagingGroupPrefix)") {
					Write-Verbose "Parameter found"
					$PSBoundParameters.$Parameter = $StagingGroupPrefix + $PSBoundParameters.$Parameter
				}
			}
			ElseIf ($Parameter -eq 'Alias') {
				$NewAlias = $PSBoundParameters.Name.Replace(" ","")
				Write-Warning "The alias for $($PSBoundParameters.Name) has been set based on the 'Name' parameter to $NewAlias.  Please confirm the value to avoid issues with email address assignment."
				$PSBoundParameters.$Parameter = $NewAlias
			}
			Else {
				$PSBoundParameters.$Parameter = $PSBoundParameters.Name
			}
		}

		# Prefixed call of New-DistributionGroup (Exchange Online version)
		If ($PSCmdlet.ShouldProcess($Name,$MyInvocation.MyCommand)) {
			Try {
				New-PremCGMMMailContact @PSBoundParameters
			}
			Catch {
				$PsCmdlet.ThrowTerminatingError($PSItem)
			}
		}
    }
	end {}
}