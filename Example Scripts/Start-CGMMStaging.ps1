Function Start-CGMMStaging {
    <#
    .SYNOPSIS

    .DESCRIPTION

    .EXAMPLE
    Start-CGMMStaging -Identity $Identity -ExternalEmailAddress $ExternalEmailAddress

	Start the CGMM staging process with mandatory values.  An external email address must be provided for the staging contact such as alias@tenant.mail.onmicrosoft.com.
    .NOTES

    #>
    [cmdletbinding()]
    param(
        # Mandatory parameters
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$ExternalEmailAddress,

		# Optional parameters
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Alias,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$DomainController
    )
	Try {
		# Query target group
		Write-Verbose "Querying $Identity"
		$TargetGroup = Get-CGMMTargetGroup $Identity -ExportSettings -ErrorAction Stop

		# Validate target group can be staged
		# Write-Verbose "Validating $Identity for staging"
		<#
		ForEach ($Object in $TargetGroup.ManagedBy) {
			If ($Object -match 'Workday' -or $Object -match 'Disabled' -or $Object -match 'Messaging and Directory Services') {
				$ErrorText = "{0}'s {1} list contains objects that cannot be migrated.  Staging abandoned." -f $TargetGroup.DistinguishedName,$TargetGroup.ManagedBy
				Write-Error $ErrorText -ErrorAction Stop
			}
		}
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
		$TargetGroup | Set-CGMMStagingGroup -Identity $StagingGroup.Identity -MemberDepartRestriction Closed -RequireSenderAuthenticationEnabled $False -ErrorAction Stop

		# Create staging contact
		Write-Verbose "Creating on premise 'staged' mail contact"
		$NewCGMMStagingMailContactSettings = @{
			Name					= $Identity
			ExternalEmailAddress	= $ExternalEmailAddress
			ErrorAction				= 'Stop'
		}
		If ($PSBoundParameters.Alias) {$NewCGMMStagingMailContactSettings.Add('Alias',$Alias)}
		If ($PSBoundParameters.DomainController) {
			$NewCGMMStagingMailContactSettings.Add('DomainController',$DomainController)
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
			$StagingGroupReady = Get-PremCGMMMailContact $StagingContact.Identity -DomainController $DomainController -ErrorAction SilentlyContinue
		}
		While ($null -eq $StagingGroupReady)
		Write-Verbose "Configuring 'staging' on premise mail contact"
		$TargetGroup | Set-CGMMStagingMailContact $StagingContact.Identity -DomainController $DomainController -ErrorAction Stop

		# To alter the contact primary SMTP to match the previous group config:
		Write-Verbose "Disabling mail contact's email address policy & resetting primary address"
		Set-CGMMStagingMailContact $StagingContact.Identity -PrimarySmtpAddress $StagingGroup.PrimarySmtpAddress -EmailAddressPolicyEnabled $False -DomainController $DomainController -ErrorAction Stop
		Write-Verbose "Enabling mail contact's email address policy"
		Set-CGMMStagingMailContact $StagingContact.Identity -EmailAddressPolicyEnabled $True -DomainController $DomainController -ErrorAction Stop

		# Assign new objects to their respective group memberships (groups the new objects are nested into)
		If ($TargetGroup.MemberOfCloud) {
			Write-Verbose "Updating membership for $($StagingGroup.Identity)"
			Update-CGMMGroupMembershipCloud -Identity $StagingGroup.Identity -Group $TargetGroup.MemberOfCloud -ErrorAction Stop
		}
		If ($TargetGroup.MemberOfOnPrem) {
			Write-Verbose "Updating membership for $($StagingContact.Identity)"
			Update-CGMMGroupMembershipOnPrem -Identity $StagingContact.Identity -Group $TargetGroup.MemberOfOnPrem -DomainController $DomainController -ErrorAction Stop
		}
	}
	Catch {
		$PsCmdlet.ThrowTerminatingError($PSItem)
	}
}