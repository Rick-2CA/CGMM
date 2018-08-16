Function Get-CGMMTargetGroup {
    <#
    .SYNOPSIS
    Collects data from a distribution group for usage in a migration

    .DESCRIPTION
    Collects data from an on premise distribution group and queries Exchange Online for cloud group membership.  The data can be referenced or piped into other cmdlets during the migration process.  Settings may also be exported in Json format.

    .EXAMPLE
    Get-CGMMTargetGroup -Identity $Identity

    Return distribution group properties along with custom properties that are relevant to migrating a distribution group into Exchange Online.  Use Get-Help Get-CGMMTargetGroup -Full to view the notes for more information.
    .EXAMPLE
    Get-CGMMTargetGroup -Identity $Identity -ViewEntireForest

    Query a distribution group and ensure the entire forest is viewable.  Not required if you specified the setting with Import-CGMMExchOnPrem.
    .EXAMPLE
    Get-CGMMTargetGroup -Identity $Identity -ExportSettings

    Query a distribution group and export the settings.  The file exported will be named with the identity name provided in Json format in the console path the cmdlet is executed from.
    .NOTES
    Custom properties are created in the output data to facilitate the creation of a cloud object.  The properties are created in reference to on premise properties that utilize distinguished names to identify objects.  The new properties identify the same objects via primary SMTP addresses valid in Exchange Online.

    Other custom properties include LegacyExchangeDNCloud (applied to the new cloud group as an X500 address), MembersOfCloud (cloud groups the queried group is a member of), MembersOfOnPrem (on premise groups the queried group is a member of), Members (the queried group's membership list).

    The custom objects include:
        AcceptMessagesOnlyFromSmtpAddresses
        BypassModerationOnlyFromSmtpAddresses
        GrantSendOnBehalfToSmtpAddresses
        LegacyExchangeDNCloud
        ManagedBySmtpAddresses
        MemberOfCloud
        MemberOfOnPrem
        Members
        ModeratedBySmtpAddresses
        RejectedSendersSmtpAddresses

    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity,

        [Parameter()]
        [string]$DomainController,

        [Parameter()]
        [Switch]$ViewEntireForest,

        [Parameter()]
        [Switch]$ExportSettings
    )

	begin {}
	process	{
        # Check for Exchange cmdlet availability in On Prem & Exchange Online
        Try {Test-CGMMCmdletAccess -Environment OnPrem,Cloud -ErrorAction Stop}
        Catch {
            $PsCmdlet.ThrowTerminatingError($PSItem)
        }

        $EAPSaved = $Global:ErrorActionPreference
        $Global:ErrorActionPreference = 'Stop'
        # Confirm entire forest is viewable
        If ($ViewEntireForest) {
            If ((Get-PremCGMMADServerSettings | Select-Object -ExpandProperty ViewEntireForest) -eq $False) {
                Try {
                    Set-PremCGMMADServerSettings -ViewEntireForest $True
                    Write-Verbose "ViewEntireForest set to `$True"
                }
                Catch {
                    $Global:ErrorActionPreference = $EAPSaved
                    $PsCmdlet.ThrowTerminatingError($PSItem)
                }
            }
        }

        Try {
            # Collect group details and membership list
            Write-Verbose "Querying distribution group identity $Identity"
            $getPremCGMMDistributionGroupSplat = @{
                Identity    = $Identity
                ErrorAction = 'Stop'
            }
            If ($PSBoundParameters.$DomainController) {
                $getPremCGMMDistributionGroupSplat.Add('DomainController',$DomainController)
            }
            [object]$GroupObject = Get-PremCGMMDistributionGroup @getPremCGMMDistributionGroupSplat
            Write-Verbose "Querying distribution group members for identity $($GroupObject.Identity)"
            [array]$GroupMembers = Get-PremCGMMDistributionGroupMember $GroupObject.Identity -ErrorAction Stop

            # AcceptMessagesOnlyFromSendersOrMembers
            Write-Verbose "Querying AcceptMessagesOnlyFromSendersOrMembers smtp addresses"
            [array]$AcceptMessagesOnlyFromSmtpAddresses = ForEach ($AcceptedSender in $GroupObject.AcceptMessagesOnlyFromSendersOrMembers) {
                Get-PremCGMMRecipient -Identity $AcceptedSender | Select-Object -Expand PrimarySmtpAddress
            }
            $GroupObject | Add-Member -MemberType NoteProperty -Name AcceptMessagesOnlyFromSmtpAddresses -Value $AcceptMessagesOnlyFromSmtpAddresses

            # BypassModerationOnlyFromSendersOrMembers
            Write-Verbose "Querying BypassModerationOnlyFromSendersOrMembers smtp addresses"
            [array]$BypassModerationOnlyFromSmtpAddresses = ForEach ($BypassSender in $GroupObject.BypassModerationOnlyFromSendersOrMembers) {
                Get-PremCGMMRecipient -Identity $BypassSender | Select-Object -Expand PrimarySmtpAddress
            }
            $GroupObject | Add-Member -MemberType NoteProperty -Name BypassModerationOnlyFromSmtpAddresses -Value $BypassModerationOnlyFromSmtpAddresses

            # GrantSendOnBehalfTo
            Write-Verbose "Querying GrantSendOnBehalfTo smtp addresses"
            [array]$GrantSendOnBehalfToSmtpAddresses = ForEach ($BypassSender in $GroupObject.GrantSendOnBehalfTo) {
                Get-PremCGMMRecipient -Identity $BypassSender | Select-Object -Expand PrimarySmtpAddress
            }
            $GroupObject | Add-Member -MemberType NoteProperty -Name GrantSendOnBehalfToSmtpAddresses -Value $GrantSendOnBehalfToSmtpAddresses

            # ManagedBy
            Write-Verbose "Querying managers' smtp addresses"
            [array]$ManagedBySmtpAddresses = ForEach ($Manager in $GroupObject.ManagedBy) {
                Get-PremCGMMRecipient -Identity $Manager | Select-Object -Expand PrimarySmtpAddress
            }
            $GroupObject | Add-Member -MemberType NoteProperty -Name ManagedBySmtpAddresses -Value $ManagedBySmtpAddresses

            # MemberOf Cloud  (Parent Groups of our target object)
            Write-Verbose "Querying MemberOf Cloud"
            # ***Get-DistributionGroupMember is a private function*** The function doesn't require a prefix as with Exchange cmdlets
            $MemberOfCloud = Get-CGMMDistributionGroupMembership $GroupObject.PrimarySmtpAddress -Cloud -ErrorAction Stop
            $GroupObject | Add-Member -MemberType NoteProperty -Name MemberOfCloud -Value $MemberOfCloud

            # MemberOf On Premise (Parent Groups of our target object)
            Write-Verbose "Querying MemberOf On Premise"
            # ***Get-DistributionGroupMember is a private function*** The function doesn't require a prefix as with Exchange cmdlets
            $MemberOfOnPrem = Get-CGMMDistributionGroupMembership $GroupObject.Identity -ErrorAction Stop
            $GroupObject | Add-Member -MemberType NoteProperty -Name MemberOfOnPrem -Value $MemberOfOnPrem

            # Members
            Write-Verbose "Querying members' smtp addresses"
            [array]$Members = ForEach ($GroupMember in $GroupMembers) {
                If ($GroupMember.PrimarySmtpAddress) {$GroupMember.PrimarySmtpAddress}
            }
            $GroupObject | Add-Member -MemberType NoteProperty -Name Members -Value $Members

            # ModeratedBy
            Write-Verbose "Querying ModeratedBy smtp addresses"
            [array]$ModeratedBySmtpAddresses = ForEach ($ModeratedBy in $GroupObject.ModeratedBy) {
                Get-PremCGMMRecipient -Identity $ModeratedBy | Select-Object -Expand PrimarySmtpAddress
            }
            $GroupObject | Add-Member -MemberType NoteProperty -Name ModeratedBySmtpAddresses -Value $ModeratedBySmtpAddresses

            # RejectMessagesFrom
            Write-Verbose "Querying RejectMessagesFrom smtp addresses"
            [array]$RejectedSendersSmtpAddresses = ForEach ($RejectedSender in $GroupObject.RejectMessagesFrom) {
                Get-PremCGMMRecipient -Identity $RejectedSender | Select-Object -Expand PrimarySmtpAddress
            }
            $GroupObject | Add-Member -MemberType NoteProperty -Name RejectedSendersSmtpAddresses -Value $RejectedSendersSmtpAddresses

            # Exchange Online Legacy DistinguishedName (if it was previously synced to Office 365)
            Write-Verbose "Querying Cloud Legacy DistinguishedName"
            $LegacyExchangeDNCloud =  Get-CloudCGMMDistributionGroup $GroupObject.PrimarySmtpAddress -ErrorAction Stop |
                Select-Object -ExpandProperty LegacyExchangeDN
            $GroupObject | Add-Member -MemberType NoteProperty -Name LegacyExchangeDNCloud -Value $LegacyExchangeDNCloud

            # Remove parameters with null/empty values
            # Get-DistributionList displays properties that or null or empty.  Set-DistributionList doesn't accept
            # pipeline input and therefore isn't impacted by the null or empty values.  In the module we're doing a
            # Get | Set that ends up sending the results of Get-DistributionList to Set-Distribution list so we
            # need to find and remove the null or empty values.
            $ExcludeProperties = ForEach ($PropertyName in $GroupObject.PSObject.Properties.Name) {
                $Property = $GroupObject.$PropertyName
                If ($Property.count -eq 0 -or [string]::IsNullOrEmpty($Property)) {
                    $PropertyName
                }
            }
            $GroupObject = $GroupObject | Select-Object -Property * -ExcludeProperty $ExcludeProperties

            If ($PSBoundParameters.ExportSettings) {
                Try {
                    Write-Verbose "Converting object data to Json and exporting to $Identity.xml"
                    $GroupObject | ConvertTo-Json | Out-File "$Identity.json"
                }
                Catch {Write-Warning $PSItem}
            }

            # Console Output
            $GroupObject
        } # End Try
        Catch {
            $PsCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {
            $Global:ErrorActionPreference = $EAPSaved
        }
    } # End Process
	end {}
}
