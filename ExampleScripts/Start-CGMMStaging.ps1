Function Start-CGMMStaging {
    <#
    .SYNOPSIS
	An example of how to utilize the CGMM module to automate the staging of a group to migrate.  

	.DESCRIPTION
	An example of how to utilize the CGMM module to automate the staging of a group and its on premise contact.  It's recommended to specify a domain controller that's in the same site as Exchange.  The external email address is used on the new contact and should correspond with the routing address previously assigned to the group you're migrating.  The assumption is that the group is already synced to the cloud.  If that assumption is false you should manually add the routing address in your process.

    .EXAMPLE
    Start-CGMMStaging -Identity $Identity -ExternalEmailAddress $ExternalEmailAddress

	Start the CGMM staging process with mandatory values.  An external email address must be provided for the staging contact such as alias@tenant.mail.onmicrosoft.com.  
    .NOTES

	#>
	#requires -Module CGMM
    [cmdletbinding()]
    param(
        # Mandatory parameters
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$ExternalEmailAddress,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$DomainController,

		# Optional parameters
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Alias,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ContactOU
	)
	
	$SavedErrorActionPreference = $Global:ErrorActionPreference
    $Global:ErrorActionPreference = 'Stop'
	Try {
		# Validate the Domain Controller
		Write-Verbose "Validating domain controller $DomainController with Test-Connection"
		Test-Connection $DomainController -Count 2 -ErrorAction Stop | Out-Null

		# Query target group
		Write-Verbose "Querying $Identity"
		$TargetGroup = Get-CGMMTargetGroup $Identity -ExportSettings -ErrorAction Stop

		# Validate target group can be staged
		# Write-Verbose "Validating $Identity for staging"
		<#
		Insert validation tests here:
			* Do you need to stop if local addresses are present?
			* Do you need to stop if a member of ManagedBy or Members is disabled or in an OU for terminated accounts?
			* Do you need to stop if there are no members?

			This is where you'd customize to your environment with validation rules
		#>

		# Create staging group
		Write-Verbose "Creating 'staging' cloud group"
		$StagingGroup = $TargetGroup | New-CGMMStagingGroup -IgnoreNamingPolicy -ErrorAction Stop

		# Set staging group once confirmed available
		Write-Verbose "StagingGroup Identity:  $($StagingGroup.Identity)"
		$i = 0
		Do {
			Write-Verbose "Waiting for the new cloud group to be available"
			$i++
			If ($i -gt 6) {Throw "Timed out waiting for $($StagingGroup.Identity) to be available for configuration. "}
			Start-Sleep -Seconds 5  
			$StagingGroupReady = Get-CloudCGMMDistributionGroup $StagingGroup.Identity -ErrorAction SilentlyContinue
		}
		While ($null -eq $StagingGroupReady)
		Write-Verbose "Configuring 'staging' cloud group"
		$setCGMMStagingGroupSplat = @{
		    Identity = $StagingGroup.Identity
		    MemberDepartRestriction = 'Closed'
		    RequireSenderAuthenticationEnabled = $False
		    ErrorAction = 'Stop'
		}
		$TargetGroup | Set-CGMMStagingGroup @setCGMMStagingGroupSplat

		# Create staging contact
		Write-Verbose "Creating on premise 'staged' mail contact"
		$NewCGMMStagingMailContactSettings = @{
			Name					= $TargetGroup.Name
			Alias					= $TargetGroup.Alias
			ExternalEmailAddress	= $ExternalEmailAddress
			ErrorAction				= 'Stop'
		}
		If ($PSBoundParameters.Alias) {$NewCGMMStagingMailContactSettings.Add('Alias',$Alias)}
		If ($PSBoundParameters.DomainController) {
			$NewCGMMStagingMailContactSettings.Add('DomainController',$DomainController)
		}
		If ($PSBoundParameters.ContactOU) {
			$NewCGMMStagingMailContactSettings.Add('OrganizationalUnit',$ContactOU)
		}
		$StagingContact = New-CGMMStagingMailContact @NewCGMMStagingMailContactSettings

		# Configure staging contact when confirmed available
		Write-Verbose "StagingContact Identity:  $($StagingContact.Identity)"
		$i = 0
		Do {
			Write-Verbose "Waiting for the new on premise mail contact to be available"
			$i++
			If ($i -gt 6) {Throw "Timed out waiting for $($StagingContact.Identity) to be available for configuration."}
			Start-Sleep -Seconds 5  
			$getPremCGMMMailContactSplat = @{
				Identity = $StagingContact.Identity
				DomainController = $DomainController
				ErrorAction = 'SilentlyContinue'
			}
			$StagingGroupReady = Get-PremCGMMMailContact @getPremCGMMMailContactSplat
		}
		While ($null -eq $StagingGroupReady)
		Write-Verbose "Configuring 'staging' on premise mail contact"
		$setCGMMStagingMailContactSplat = @{
		    Identity = $StagingContact.Identity
			DomainController = $DomainController
			ErrorAction = 'Stop'
		}
		$TargetGroup | Set-CGMMStagingMailContact @setCGMMStagingMailContactSplat

		# To alter the contact primary SMTP to match the previous group config:
		Write-Verbose "Disabling mail contact's email address policy & resetting primary address"
		$setCGMMStagingMailContactSplat = @{
			Identity = $StagingContact.Identity
			PrimarySmtpAddress = $StagingGroup.PrimarySmtpAddress
			EmailAddressPolicyEnabled = $False
			DomainController = $DomainController
			ErrorAction = 'Stop'
		}
		Set-CGMMStagingMailContact @setCGMMStagingMailContactSplat
		Write-Verbose "Enabling mail contact's email address policy"
		$setCGMMStagingMailContactSplat = @{
		    Identity = $StagingContact.Identity
		    DomainController = $DomainController
			EmailAddressPolicyEnabled = $True
			ErrorAction = 'Stop'
		}
		Set-CGMMStagingMailContact @setCGMMStagingMailContactSplat

		# Assign new objects to their respective group memberships (groups the new objects are nested into)
		If ($TargetGroup.MemberOfCloud) {
			Write-Verbose "Updating membership for $($StagingGroup.Identity)"
			$updateCGMMGroupMembershipCloudSplat = @{
				Group = $TargetGroup.MemberOfCloud
				Identity = $StagingGroup.Identity
				ErrorAction = 'Stop'    
			}
			Update-CGMMGroupMembershipCloud @updateCGMMGroupMembershipCloudSplat
		}
		If ($TargetGroup.MemberOfOnPrem) {
			Write-Verbose "Updating membership for $($StagingContact.Identity)"
			$updateCGMMGroupMembershipOnPremSplat = @{
				Identity = $StagingContact.Identity
				Group = $TargetGroup.MemberOfOnPrem
				DomainController = $DomainController
			    ErrorAction = 'Stop'
			}
			Update-CGMMGroupMembershipOnPrem @updateCGMMGroupMembershipOnPremSplat
		}
	}
	Catch {
		Write-Error $PSItem -ErrorAction Stop
	}
	Finally {
		$Global:ErrorActionPreference = $SavedErrorActionPreference
	}
}