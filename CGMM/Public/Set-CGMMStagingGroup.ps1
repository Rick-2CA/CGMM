Function Set-CGMMStagingGroup {
    <#
    .SYNOPSIS
	Sets properties on a staged Exchange Online distribution group.

    .DESCRIPTION
	Sets properties on a staged Exchange Online distribution group.  A prefix is applied to properties that require unique values.  Groups are hidden from address lists if HiddenFromAddressListsEnabled is not explicitly set to $False.  Parameters include nearly every parameter used with Set-DistributionGroup in Exchange Online.  Some parameters may require you to call Set-DistributionGroup from outside this module to properly apply.

	Most parameters utilize ValueFromPipelineByPropertyName.  The most value comes from using Get-CGMMTargetGroup to pipe its custom properties when configuring a staged group.

    .EXAMPLE
    Set-CGMMStagingGroup -Identity $Identity

    .EXAMPLE
	Get-CGMMTargetGroup $OnPremiseDLIdentity | Set-CGMMStagingGroup -Identity $StagingGroupIdentity

	Pipe the on premise distribution group's settings into the new staging group.
    .NOTES

    #>
    [cmdletbinding(SupportsShouldProcess)]
    param(
        # Mandatory Parameters
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            Try {$_ -match "^$($StagingGroupPrefix)"}
            Catch {
                Throw "The target group must begin with $($StagingGroupPrefix)."
            }
        })]
        [string]$Identity,

		# Optional Parameters
		[Parameter()]
		[array]$AcceptMessagesOnlyFrom,

        [Parameter()]
		[array]$AcceptMessagesOnlyFromDLMembers,

		[Parameter()]
		[array]$AcceptMessagesOnlyFromSendersOrMembers,

        [Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Alias,

		[Parameter()]
		[array]$BypassModerationFromSendersOrMembers,
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[Boolean]$BypassNestedModerationEnabled, 
		
		[Parameter()]
		[System.Management.Automation.SwitchParameter]$BypassSecurityGroupManagerCheck, 
		
		[Parameter()]
		[Boolean]$CreateDTMFMap, 
		
        [Parameter()]
		[string]$DisplayName,
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string[]]$EmailAddresses, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string]$ExtensionCustomAttribute1, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string]$ExtensionCustomAttribute2, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string]$ExtensionCustomAttribute3, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string]$ExtensionCustomAttribute4, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string]$ExtensionCustomAttribute5, 
		
		[Parameter()]
		[string[]]$GrantSendOnBehalfTo, 
		
		[Parameter()]
		[Boolean]$HiddenFromAddressListsEnabled=$True, 
		
		[Parameter()]
		[System.Management.Automation.SwitchParameter]$IgnoreNamingPolicy, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string]$MailTip, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string[]]$MailTipTranslations, 
		
		[Parameter()]
		[string[]]$ManagedBy, 
		
		[Parameter()]
		[ValidateSet('Open','Closed')]
		[string]$MemberDepartRestriction, 
		
		[Parameter()]
		[ValidateSet('Open','Closed','ApprovalRequired')]
		[string]$MemberJoinRestriction, 
		
		[Parameter()]
		[string[]]$ModeratedBy, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[Boolean]$ModerationEnabled, 

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$PrimarySmtpAddress,
		
		[Parameter()]
		[string[]]$RejectMessagesFrom, 
		
		[Parameter()]
		[string[]]$RejectMessagesFromDLMembers, 
		
		[Parameter()]
		[string[]]$RejectMessagesFromSendersOrMembers, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[Boolean]$ReportToManagerEnabled, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[Boolean]$ReportToOriginatorEnabled, 
		
		[Parameter()]
		[Boolean]$RequireSenderAuthenticationEnabled, 
		
		[Parameter()]
		[switch]$RoomList, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[ValidateSet('Always','Internal','Never')]
		[string]$SendModerationNotifications, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[Boolean]$SendOofMessageToOriginatorEnabled, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string]$SimpleDisplayName, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string[]]$UMDtmfMap, 
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string]$WindowsEmailAddress,

		# CGMM Custom Attributes
		
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string[]]$AcceptMessagesOnlyFromSmtpAddresses,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string[]]$GrantSendOnBehalfToSmtpAddresses,

		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string]$LegacyExchangeDNCloud,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string[]]$ManagedBySmtpAddresses,

		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string[]]$ManagersSmtpAddresses,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string[]]$ModeratedBySmtpAddresses,

		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string[]]$RejectSendersSmtpAddresses,

		# Default property from Get-DistributionGroup that isn't default for Set-DistributionGroup
		[Parameter(ValueFromPipelineByPropertyName = $True)]
		[string]$LegacyExchangeDN
    )

	begin {}
	process	{
		# Check for Exchange cmdlet availability in On Prem & Exchange Online
        Try {Test-CGMMCmdletAccess -Environment Cloud -ErrorAction Stop}
        Catch {
            $PsCmdlet.ThrowTerminatingError($PSItem)
        }

		# Get the current primary smtp address to see if a former primary needs added as a secondary
		$EAPSaved = $Global:ErrorActionPreference
        $Global:ErrorActionPreference = 'Stop'
		Write-Verbose "Searching for cloud distribution group $Identity"
		Try {
			$DistGroupCurrentState = Get-CloudCGMMDistributionGroup $Identity | Select-Object PrimarySMTPAddress,EmailAddresses
		}
		Catch {
			$Global:ErrorActionPreference = $EAPSaved
			$PsCmdlet.ThrowTerminatingError($PSItem)
		}
		$Global:ErrorActionPreference = $EAPSaved

		# Check for and apply prefix to optional fields
		Write-Verbose "Applying the prefix '$StagingGroupPrefix' to properties that must be unique."
		$OptionalParameters = @('Name','Alias','DisplayName','PrimarySMTPAddress','SimpleDisplayName','WindowsEmailAddress')
		ForEach ($Parameter in $OptionalParameters) {
			If ($PSBoundParameters.$Parameter) {
				$PSBoundParameters.$Parameter = $StagingGroupPrefix + $PSBoundParameters.$Parameter
			}
		}

		# Update the EmailAddresses to include the prefix
		If ($PSBoundParameters.EmailAddresses) {
			Write-Verbose "Processing email addresses and applying the prefix '$StagingGroupPrefix'"
			# Normalize the case sensitivity of X500.  Office 365 defaults to uppercase and this script
			# sets the case to uppercase when adding legacy Exchange DNs.  Other versions of Exchange, at
			# least Exchange 2010, returns the value in lowercase.  Required when doing 
			# `$NewAddressCollection | Select-Object -Unique` below.
			[array]$PSBoundParameters.EmailAddresses = $PSBoundParameters.EmailAddresses -replace "^x500:","X500:"
			# Create an array containing each address with the prefix added
			[array]$PrefixedEmailAddresses = ForEach ($Address in $PSBoundParameters.EmailAddresses) {
				# Prefix X400 addresses that aren't prefixed.  X400s require specific formatting
				If ($Address -match 'X400' -and $Address -notmatch ";S=$StagingGroupPrefix") {
					$Address -replace ';S=',";S=$StagingGroupPrefix"
				}
				# Prefix other addresses with a type (smtp:,X500:,etc.) that aren't already prefixed
				ElseIf ($Address -match ':' -and $Address -notmatch ":$($StagingGroupPrefix)") {
					$Address -replace ":",":$($StagingGroupPrefix)"
				}
				# Prefix addresses without a type that aren't already prefixed
				ElseIf ($Address -notmatch "^$($StagingGroupPrefix)"-and $Address -notmatch ":" ) {
					$Address.Insert(0,$StagingGroupPrefix)
				}
				# Capture already prefixed addresses
				Else {$Address}
			}
			
			If ($PrefixedEmailAddresses) {
				# Force EmailAddresses to only add secondaries
				[array]$PrefixedEmailAddresses = $PrefixedEmailAddresses -replace "^SMTP:","smtp:"
			}
			$Address = $Null
		}

		# Update the EmailAddresses to include both legacy Exchange DNs with the prefix
		$AddressingParameters = @('LegacyExchangeDNCloud','LegacyExchangeDN')
		[array]$PrefixedLegacyDNs = ForEach ($Parameter in $AddressingParameters) {
			If ($PSBoundParameters.$Parameter) {
				If ($($PSBoundParameters.$Parameter) -notmatch "^$($StagingGroupPrefix)") {
					"X500:$($StagingGroupPrefix)$($PSBoundParameters.$Parameter)"
				}
				[void]$PSBoundParameters.Remove($Parameter)
			}
		}

		# Create an array list out of the new addresses.
		$NewAddressCollection = New-Object System.Collections.ArrayList
		If ($PrefixedEmailAddresses) {
			[void]$NewAddressCollection.AddRange($PrefixedEmailAddresses)
		}
		If ($PrefixedLegacyDNs) {
			[void]$NewAddressCollection.AddRange($PrefixedLegacyDNs)
		}

		# If new addresses exist only add addresses that don't already exist
		If ($NewAddressCollection.count -gt 0) {
			# Ensure $NewAddressCollection does not contain duplicates
			$NewAddressCollection = $NewAddressCollection | Select-Object -Unique
			# Get the current status minus address type.  This is used to ensure we don't try to add 
			# an SMTP and smtp version of an address.
			$CurrentStateTypeLess = $DistGroupCurrentState.EmailAddresses -replace "^.*:"
			[array]$SecondariesToAdd = ForEach ($NewAddress in $NewAddressCollection) {
				If ($CurrentStateTypeLess -notcontains $NewAddress.Split(':')[1]){
					$NewAddress
				}
			}
			
			# Combine the addresses that don't exist to the current list and apply them back to 
			# $PSBoundParameters.EmailAddresses so they may be splatted.
			If ($SecondariesToAdd) {
				[void]$DistGroupCurrentState.EmailAddresses.AddRange($SecondariesToAdd)
			}
			$PSBoundParameters.EmailAddresses = $DistGroupCurrentState.EmailAddresses
		}

		# Reassign parameters.  On premise properties that use distinguished name won't work in the cloud, but
		# the property names are the same.  The code segment below takes a custom properties populated by
		# Get-CGMMTargetGroup and reassigns their values to the property expected by the New-DistributionGroup
		# parameters.
		Write-Verbose "Reassigning custom properties to Exchange Online properties."
		$ReassignedParameters = @(
			@{'AcceptMessagesOnlyFromSendersOrMembers'	= 'AcceptMessagesOnlyFromSmtpAddresses'}
			@{'BypassModerationFromSendersOrMembers'	= 'BypassModerationOnlyFromSmtpAddresses'}
			@{'GrantSendOnBehalfTo' 					= 'GrantSendOnBehalfToSmtpAddresses'}
			@{'ManagedBy'								= 'ManagedBySmtpAddresses'},
			@{'ModeratedBy'								= 'ModeratedBySmtpAddresses'}
			@{'RejectMessagesFromSendersOrMembers'		= 'RejectSendersSmtpAddresses'}
		)
		ForEach ($Parameter in $ReassignedParameters) {
			$AssignTo = $($Parameter.Keys)
			$AssignFrom = $($Parameter.Values)

			# If the custom 'AssignFrom' property has a value rewrite the 'AssignTo' property Exchange cmdlet expects
			If ($PSBoundParameters.$AssignFrom) {
				Write-Verbose "Adding $AssignFrom to $AssignTo"
				$PSBoundParameters.Add($AssignTo,$($PSBoundParameters.$AssignFrom))
			}
			# Remove the custom property - it won't be expected by the Exchange cmdlet
			[void]$PSBoundparameters.Remove($AssignFrom)
		}

		# HiddenFromAddressListsEnabled
		If (-not $PSBoundParameters.HiddenFromAddressListsEnabled) {
			$PSBoundParameters.HiddenFromAddressListsEnabled = $HiddenFromAddressListsEnabled
		}

		# Prefixed call of New-DistributionGroup (Exchange Online version) with -WhatIf support
		If ($PSCmdlet.ShouldProcess($Identity,$MyInvocation.MyCommand)) {
			$EAPSaved = $Global:ErrorActionPreference
			$Global:ErrorActionPreference = 'Stop'
			Try {
				Set-CloudCGMMDistributionGroup @PSBoundParameters
			}
			Catch {
				$PsCmdlet.ThrowTerminatingError($PSItem)
			}
			Finally {
				$Global:ErrorActionPreference = $EAPSaved
			}
		}
    }
	end {}
}