Function Convert-CGMMStagingMailContact {
    <#
    .SYNOPSIS
    Converts a staging mail contact into a production named mail contact.

    .DESCRIPTION
    Converts a staging mail contact into a production named mail contact by removing the staging mail contact prefix from relevant mail contact properties.  Some properties such as SamAccountName and DistinguishedName are not able to be changed when renaming an Exchange Online object.  Other properties, such as Name, Alias, DisplayName, and EmailAddresses, that are used in administration and visible to end users will reflect your intended name.

    .EXAMPLE
    Convert-CGMMStagingMailContact -Identity $Identity

    Converts a staged mail contact in Exchange Online.  The Identity field must match a staged mail contact name.

    .EXAMPLE
    Convert-CGMMStagingMailContact -Identity $Identity -HiddenFromAddressListsEnabled $True

    Converts a staged mail contact in Exchange Online and makes the mail contact visible in address lists.  Staged objects are hidden during creation by default.

    .EXAMPLE
    Convert-CGMMStagingMailContact -Identity $Identity -DomainController $DomainController

    Specify a domain controller to aid in making all on premise changes in the same location to avoid AD replication challenges.

    .NOTES

    #>
     [cmdletbinding(SupportsShouldProcess)]
    param(
        # Pipeline variable
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            Try {$_ -match "^$($StagingGroupPrefix)"}
            Catch {
                Throw "The target contact must begin with $($StagingGroupPrefix)."
            }
        })]
        [string]$Identity,

        [Parameter()]
        [Boolean]$HiddenFromAddressListsEnabled,

        [Parameter()]
        [string]$DomainController
    )

	begin {}
	process	{
        Try {
            # Check for Exchange cmdlet availability in On Prem & Exchange Online
            Test-CGMMCmdletAccess -Environment OnPrem -ErrorAction Stop

            $EAPSaved = $Global:ErrorActionPreference
            $Global:ErrorActionPreference = 'Stop'

            # Get the target group
            Write-Verbose "Querying for mail contact $($PSBoundParameters.Identity)"
            $getPremCGMMMailContactSplat = @{
                Identity    = $PSBoundParameters.Identity
                ErrorAction = 'Stop'
            }
            If ($null -ne $PSBoundParameters.DomainController) {
                $getPremCGMMMailContactSplat.Add('DomainController',$PSBoundParameters.DomainController)
            }
            $MailContact = Get-PremCGMMMailContact @getPremCGMMMailContactSplat

            # Validate that the intended rename is available
            $OldGroupName = ($PSBoundParameters.Identity -replace $StagingGroupPrefix)
            $GetDistributionGroupSplat = @{
                Identity    = $OldGroupName
                ErrorAction = 'SilentlyContinue'
            }
            If ($null -ne $PSBoundParameters.DomainController) {
                $GetDistributionGroupSplat.Add('DomainController',$PSBoundParameters.DomainController)
            }
            Write-Verbose "Querying for the intended group name $OldGroupName, which shouldn't exist, for assignment to the contact."
            If ($null -ne (Get-PremCGMMDistributionGroup @GetDistributionGroupSplat)) {
                $ErrorText = "The distribution group {0} must be removed before the staging prefix may be removed from mail contact {1}." -f $GetDistributionGroupSplat['Identity'],$PSBoundParameters.Identity
                Write-Error $ErrorText -ErrorAction Stop
            }

            # Find all properties that were prefixed.
            Write-Verbose "Identifing and processing prefixed properties"
            $PropertiesToProcess = $MailContact.PSObject.Properties |
                Where-Object {$_.value -match $StagingGroupPrefix} |
                Select-Object Name,Value

            # Setup a hash to be used to splat the non-prefixed values
            $SetMailContactSettings = @{}
            ForEach ($Property in $PropertiesToProcess) {
                # Skip over properties that can't or shouldn't be changed
                $SkipProperties = @('DistinguishedName','Identity','LegacyExchangeDN','PrimarySmtpAddress')
                If ($SkipProperties -contains $Property.Name) {continue}

                Switch ($Property.Value.GetType().Name) {
                    string {
                        $ReplacedPrefix = ($Property.Value -replace $StagingGroupPrefix)
                        $SetMailContactSettings.Add($Property.Name,$ReplacedPrefix)
                    }
                    arraylist {
                        $Array = ForEach ($Object in $Property.Value) {
                            $Object -replace $StagingGroupPrefix
                        }
                        $SetMailContactSettings.Add($Property.Name,$Array)
                    }
                    Default {Write-Warning "Property type not accounted for:  $($Property.Name).  Manual intervention required."}
                }

                # Reconstruct the EmailAddresses property to hash the required adds and removes
                # Any non-prefixed addresses that happen to have been assigned will remain unchanged
                If ($Property.Name -eq 'EmailAddresses') {
                    $Removals = $Property.Value | Where-Object {$_ -match $StagingGroupPrefix}
                    $Adds = $SetMailContactSettings['EmailAddresses'] | Where-Object {$Property.Value -notcontains $_}
                    $SetMailContactSettings['EmailAddresses'] = @{Add=$Adds;Remove=$Removals}
                }
            }

            # Avoid the email address policy if it's on
            If ($MailContact.EmailAddressPolicyEnabled -eq $True) {
                Write-Verbose "Temporarily disabling the email address policy"
                $SetMailContactSettings.Add('EmailAddressPolicyEnabled',$False)

                If ($null -ne $SetMailContactSettings['Alias']) {$NewIdentity = $SetMailContactSettings['Alias']}
                Else {$NewIdentity = $MailContact.Alias}
            }

            # Finish up the hash by adding provide parameters.
            $SetMailContactSettings.Add('Identity',$PSBoundParameters.Identity)
            If ($null -ne $PSBoundParameters.HiddenFromAddressListsEnabled) {
                Write-Verbose "Adding HiddenFromAddressListsEnabled with value $($PSBoundParameters.HiddenFromAddressListsEnabled)"
                $SetMailContactSettings.Add(
                    'HiddenFromAddressListsEnabled',$PSBoundParameters.HiddenFromAddressListsEnabled
                    )
            }
            If ($null -ne $PSBoundParameters.DomainController) {
                Write-Verbose "Adding DomainController with value $($PSBoundParameters.DomainController)"
                $SetMailContactSettings.Add('DomainController',$PSBoundParameters.DomainController)
            }

            If ($PSCmdlet.ShouldProcess($Identity,$MyInvocation.MyCommand)) {
                Set-PremCGMMMailContact @SetMailContactSettings
                If ($MailContact.EmailAddressPolicyEnabled -eq $True) {
                    $i = 0
                    Do {
                        Write-Verbose "Waiting for the renamed contact to be available to reenable the email address policy"
                        $i++
                        If ($i -gt 6) {
                            Throw "Timed out waiting for contact $NewIdentity to be available for configuration."
                        }
                        Start-Sleep -Seconds 5
                        $getPremCGMMMailContactSplat = @{
                            Identity    = $NewIdentity
                            ErrorAction = 'Stop'
                        }
                        If ($null -ne $PSBoundParameters.DomainController) {
                            $getPremCGMMMailContactSplat.Add('DomainController',$PSBoundParameters.DomainController)
                        }
                        $NewIdentityReady = Get-PremCGMMMailContact @getPremCGMMMailContactSplat
                    }
                    While ($null -eq $NewIdentityReady)
                    Write-Verbose "Reenabling the email address policy on contact $NewIdentity"
                    $setPremCGMMMailContactSplat = @{
                        Identity                  = $NewIdentity
                        EmailAddressPolicyEnabled = $True
                    }
                    If ($null -ne $PSBoundParameters.DomainController) {
                        $setPremCGMMMailContactSplat.Add('DomainController',$PSBoundParameters.DomainController)
                    }
                    Set-PremCGMMMailContact @setPremCGMMMailContactSplat
                }
            }
        }
        Catch {
            $PsCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {
            $Global:ErrorActionPreference = $EAPSaved
        }
    }
	end {}
}
