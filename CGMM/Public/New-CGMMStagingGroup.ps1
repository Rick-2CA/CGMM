Function New-CGMMStagingGroup {
    <#
    .SYNOPSIS
	Creates a new Exchange Online distribution group staged with prefixed property values.

    .DESCRIPTION
	Creates a new Exchange Online distribution group staged with prefixed property values.  The prefixed properties are name properties or properties that are required to be unique in Exchange.  This allows you to confirm the copying of an existing on premise group before removing the group to be replaced by a cloud version.

    .EXAMPLE
    New-CGMMStagingGroup -Name $Name -Alias $Alias -DisplayName $DisplayName -PrimarySmtpAddress $PrimarySmtpAddress

	Mandatory parameters to create a staged group.  Each of the mandatory parameter values will be updated with the module's prefix when creating the new distribution group.

    .EXAMPLE
	Get-CGMMTargetGroup $TargetGroup | New-CGMMStagingGroup

	Use the settings from an on premise group to create the cloud distribution group.

	.EXAMPLE
	Get-CGMMTargetGroup $TargetGroup | New-CGMM-StagingGroup -Name $NewName -Alias $NewAlias -DisplayName $NewDisplayName -PrimarySmtpAddress $NewPrimarySmtpAddress

	Use the settings from an on premise group to create the cloud distribution group, but override the pipeline values with paramter values.  This method may be used to rename a group during migration.  Renaming the group in transition can impact follow up functions in the migration process!  Be sure to pass the property identity.
    .NOTES

    #>
    [cmdletbinding(SupportsShouldProcess)]
    param(
		# Mandatory parameters
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
		[ValidateNotNullOrEmpty()]
		[string]$Alias,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
		[string]$DisplayName,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
		[ValidateNotNullOrEmpty()]
		[string]$PrimarySmtpAddress,

		# Optional Parameters
		# Cloud migrations assume distribution group.  This field is mandatory for New-DistributionGroup, but 
		# optional in this context since it's all we wish to accept in the cloud.
		[Parameter()]
		[ValidateSet('Distribution','Security')]
		[string]$GroupType='Distribution',

        [Parameter()]
		[switch]$IgnoreNamingPolicy,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		$ManagedBySmtpAddresses,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		$MemberDepartRestriction,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		$MemberJoinRestriction,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		$Members,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		$ModeratedBySmtpAddresses,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		$ModerationEnabled,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		$Notes,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		$RequireSenderAuthenticationEnabled,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		$SendModerationNotifications
    )

	begin {}
	process	{
        # Check for Exchange cmdlet availability in On Prem & Exchange Online
        Try {Test-CGMMCmdletAccess -Environment Cloud -ErrorAction Stop}
        Catch {
            $PsCmdlet.ThrowTerminatingError($PSItem)
        }

		# Apply prefix to mandatory fields
		$MandatoryParameters = @('Name','Alias','DisplayName','PrimarySMTPAddress')
		ForEach ($Parameter in $MandatoryParameters) {
			$PSBoundParameters.$Parameter = $StagingGroupPrefix + $PSBoundParameters.$Parameter
		}

		# Check for and apply prefix to optional fields
		<#
		$OptionalParameters = @()
		ForEach ($Parameter in $OptionalParameters) {
			If ($PSBoundParameters.$Parameter) {
				$PSBoundParameters.$Parameter = $StagingGroupPrefix + $PSBoundParameters.$Parameter
			}
		}
		#>

		# Reassign parameters.  On premise properties that use distinguished name won't work in the cloud, but
		# the property names are the same.  The code segment below takes a custom properties populated by
		# Get-CGMMTargetGroup and reassigns their values to the property expected by the New-DistributionGroup
		# parameters.
		$ReassignedParameters = @(
			@{'ManagedBy'='ManagedBySmtpAddresses'},
			@{'ModeratedBy'='ModeratedBySmtpAddresses'}
		)
		ForEach ($Parameter in $ReassignedParameters) {
			$AssignTo = $($Parameter.Keys)
			$AssignFrom = $($Parameter.Values)

			# If the custom 'AssignFrom' property has a value rewrite the 'AssignTo' property Exchange cmdlet expects
			# If the custom property is null the 'AssignTo' property should be too and no action is required.
			If ($null -ne $PSBoundParameters.$AssignFrom) {
				$PSBoundParameters.Add($AssignTo,$($PSBoundParameters.$AssignFrom))
			}
			# Remove the custom property - it won't be expected by the Exchange cmdlet
			[void]$PSBoundparameters.Remove($AssignFrom)
		}
		# Prefixed call of New-DistributionGroup (Exchange Online version)
		If ($PSCmdlet.ShouldProcess($Name,$MyInvocation.MyCommand)) {
			Try {
				New-CloudCGMMDistributionGroup @PSBoundParameters
			}
			Catch {
				$PsCmdlet.ThrowTerminatingError($PSItem)
			}
			
		}
    }
	end {}
}