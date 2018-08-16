Function Set-CGMMStagingMailContact {
    <#
    .SYNOPSIS
	Sets properties on a staged on premise Exchange mail contact.

    .DESCRIPTION
	Sets properties on a staged on premise Exchange mail contact.  A prefix is applied to properties that require unique values.  Mail contacts are hidden from address lists if HiddenFromAddressListsEnabled is not explicitly set to $False.  Parameters include nearly every parameter used with Set-MailContact in Exchange.  Some parameters may require you to call Set-MailContact from outside this module to properly apply.

	The number of parameters that use ValueFromPipelineByPropertyName is limited.  Use Get-Help Set-CGMMStagingMailContact -Full to view the notes for more information.

    .EXAMPLE
    Set-CGMMStagingMailContact -Identity $Identity

    .EXAMPLE
	Get-CGMMTargetGroup $OnPremiseDLIdentity | Set-CGMMStagingMailContact -Identity $StagingMailContactIdentity

	Pipe the on premise distribution group's settings into the new mail contact.

	.EXAMPLE
    Set-CGMMStagingMailContact -Identity $Identity -Group $Groups -DomainController $DomainController

    Specify a domain controller to aid in making all on premise changes in the same location to avoid AD replication challenges.

    .NOTES
	ValueFromPipelineByPropertyName is supported for the following parameters:
		EmailAddresses
		SimpleDisplayName
		WindowsEmailAddress
		LegacyExchangeDN

    #>
    [cmdletbinding(SupportsShouldProcess)]
    param(
        # Mandatory parameters
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity,

        # Optional parameters
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

        [Parameter()]
        [Boolean]$BypassNestedModerationEnabled,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]$BypassSecurityGroupManagerCheck,

        [Parameter()]
        [Boolean]$CreateDTMFMap,

        [Parameter()]
        [string]$CustomAttribute1,

        [Parameter()]
        [string]$CustomAttribute2,

        [Parameter()]
        [string]$CustomAttribute3,

        [Parameter()]
        [string]$CustomAttribute4,

        [Parameter()]
        [string]$CustomAttribute5,

        [Parameter()]
        [string]$CustomAttribute6,

        [Parameter()]
        [string]$CustomAttribute7,

        [Parameter()]
        [string]$CustomAttribute8,

        [Parameter()]
        [string]$CustomAttribute9,

        [Parameter()]
        [string]$CustomAttribute10,

        [Parameter()]
        [string]$CustomAttribute11,

        [Parameter()]
        [string]$CustomAttribute12,

        [Parameter()]
        [string]$CustomAttribute13,

        [Parameter()]
        [string]$CustomAttribute14,

        [Parameter()]
        [string]$CustomAttribute15,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DisplayName,

        [Parameter()]
        [string]$DomainController,

        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$EmailAddresses,

        [Parameter()]
        [Boolean]$EmailAddressPolicyEnabled,

        [Parameter()]
        [string]$ExtensionCustomAttribute1,

        [Parameter()]
        [string]$ExtensionCustomAttribute2,

        [Parameter()]
        [string]$ExtensionCustomAttribute3,

        [Parameter()]
        [string]$ExtensionCustomAttribute4,

        [Parameter()]
        [string]$ExtensionCustomAttribute5,

        [Parameter()]
        [string]$ExternalEmailAddress,

        [Parameter()]
        [string[]]$GrantSendOnBehalfTo,

        [Parameter()]
        [Boolean]$HiddenFromAddressListsEnabled = $True,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]$IgnoreDefaultScope,

        [Parameter()]
        [ValidateSet('BinHex', 'UuEncode', 'AppleSingle', 'AppleDouble')]
        [string]$MacAttachmentFormat,

        [Parameter()]
        [string]$MailTip,

        [Parameter()]
        [string[]]$MailTipTranslations,

        [Parameter()]
        [string]$MaxReceiveSize,

        [Parameter()]
        [object]$MaxRecipientPerMessage,

        [Parameter()]
        [string]$MaxSendSize,

        [Parameter()]
        [ValidateSet('Text', 'Html', 'TextAndHtml')]
        [string]$MessageBodyFormat,

        [Parameter()]
        [ValidateSet('Text', 'Mime')]
        [string]$MessageFormat,

        [Parameter()]
        [string[]]$ModeratedBy,

        [Parameter()]
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

        [Parameter()]
        [System.Management.Automation.SwitchParameter]$RemovePicture,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]$RemoveSpokenName,

        [Parameter()]
        [Boolean]$RequireSenderAuthenticationEnabled,

        [Parameter()]
        [string]$SecondaryAddress,

        [Parameter()]
        [string]$SecondaryDialPlan,

        [Parameter()]
        [ValidateSet('Always', 'Internal', 'Never')]
        [string]$SendModerationNotifications,

        [Parameter()]
        [Boolean]$SendOofMessageToOriginatorEnabled,

        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string]$SimpleDisplayName,

        [Parameter()]
        [string[]]$UMDtmfMap,

        [Parameter()]
        [ValidateSet('Always', 'Never', 'UseDefaultSettings')]
        [string]$UseMapiRichTextFormat,

        [Parameter()]
        [Boolean]$UsePreferMessageFormat,

        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string]$WindowsEmailAddress,

        # Default property from Get-DistributionGroup that isn't default for Set-DistributionGroup
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string]$LegacyExchangeDN
    )

    begin {}
    process	{
        # Check for Exchange cmdlet availability in On Prem & Exchange Online
        Try {Test-CGMMCmdletAccess -Environment OnPrem -ErrorAction Stop}
        Catch {
            $PsCmdlet.ThrowTerminatingError($PSItem)
        }

        # Get the current primary smtp address to see if a former primary needs added as a secondary
        $EAPSaved = $Global:ErrorActionPreference
        $Global:ErrorActionPreference = 'Stop'
        Write-Verbose "Searching for cloud distribution group $Identity"
        Try {
            $MailContactSettings = @{
                Identity = $Identity
            }
            If ($PSBoundParameters.DomainController) {$MailContactSettings.Add('DomainController', $PSBoundParameters.DomainController)}
            $MailContactCurrentState = Get-PremCGMMMailContact @MailContactSettings | Select-Object PrimarySMTPAddress, EmailAddresses
        }
        Catch {
            $Global:ErrorActionPreference = $EAPSaved
            $PsCmdlet.ThrowTerminatingError($PSItem)
        }
        $Global:ErrorActionPreference = $EAPSaved

        # Check for and apply prefix to optional fields
        Write-Verbose "Applying the prefix '$StagingGroupPrefix' to properties that must be unique."
        $OptionalParameters = @('Name', 'Alias', 'DisplayName', 'PrimarySMTPAddress', 'SimpleDisplayName', 'WindowsEmailAddress')
        ForEach ($Parameter in $OptionalParameters) {
            If ($PSBoundParameters.$Parameter) {
                # Just in case someone offers the prefix up voluntarily...
                If ($($PSBoundParameters.$Parameter) -notmatch "^$($StagingGroupPrefix)") {
                    $PSBoundParameters.$Parameter = $StagingGroupPrefix + $PSBoundParameters.$Parameter
                }
            }
        }

        # Update the EmailAddresses to include the prefix
        If ($PSBoundParameters.EmailAddresses) {
            Write-Verbose "Processing email addresses and applying the prefix '$StagingGroupPrefix'"
            # Normalize the case sensitivity of X500.  Office 365 defaults to uppercase and this script
            # sets the case to uppercase when adding legacy Exchange DNs.  Other versions of Exchange, at
            # least Exchange 2010, returns the value in lowercase.  Required when doing
            # `$NewAddressCollection | Select-Object -Unique` below.
            [array]$PSBoundParameters.EmailAddresses = $PSBoundParameters.EmailAddresses -replace "^x500:", "X500:"
            # Create an array containing each address with the prefix added
            [array]$PrefixedEmailAddresses = ForEach ($Address in $PSBoundParameters.EmailAddresses) {
                # Prefix X400 addresses that aren't prefixed.  X400s require specific formatting
                If ($Address -match 'X400' -and $Address -notmatch ";S=$StagingGroupPrefix") {
                    $Address -replace ';S=', ";S=$StagingGroupPrefix"
                }
                # Prefix the addresses with a type (smtp:,X500:) that aren't already prefixed
                ElseIf ($Address -match ':' -and $Address -notmatch ":$($StagingGroupPrefix)") {
                    $Address -replace ":", ":$($StagingGroupPrefix)"
                }
                # Prefix addresses without a type that aren't already prefixed
                ElseIf ($Address -notmatch "^$($StagingGroupPrefix)" -and $Address -notmatch ":" ) {
                    $Address.Insert(0, $StagingGroupPrefix)
                }
                # Capture already prefixed addresses
                Else {$Address}
            }
            # Force EmailAddresses to only add secondaries
            [array]$PrefixedEmailAddresses = $PrefixedEmailAddresses -replace "^SMTP:", "smtp:"
            $Address = $Null
        }

        # Update the LegacyExchangeDN to include the prefix
        $AddressingParameters = @('LegacyExchangeDN')
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
            $CurrentStateTypeLess = $MailContactCurrentState.EmailAddresses -replace "^.*:"
            [array]$SecondariesToAdd = ForEach ($NewAddress in $NewAddressCollection) {
                If ($CurrentStateTypeLess -notcontains $NewAddress.Split(':')[1]) {
                    $NewAddress
                }
            }

            # Combine the addresses that don't exist to the current list and apply them back to
            # $PSBoundParameters.EmailAddresses so they may be splatted.
            [void]$MailContactCurrentState.EmailAddresses.AddRange($SecondariesToAdd)
            $PSBoundParameters.EmailAddresses = $MailContactCurrentState.EmailAddresses
        }

        # HiddenFromAddressListsEnabled - Force the default value if it wasn't specified
        If (-not $PSBoundParameters.HiddenFromAddressListsEnabled) {
            $PSBoundParameters.HiddenFromAddressListsEnabled = $HiddenFromAddressListsEnabled
        }

        # Prefixed call of New-DistributionGroup (Exchange Online version) with -WhatIf support
        If ($PSCmdlet.ShouldProcess($Identity, $MyInvocation.MyCommand)) {
            Try {
                Set-PremCGMMMailContact @PSBoundParameters
            }
            Catch {
                $PsCmdlet.ThrowTerminatingError($PSItem)
            }
        }
    }
    end {}
}
