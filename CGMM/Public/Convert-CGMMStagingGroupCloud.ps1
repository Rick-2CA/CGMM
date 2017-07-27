Function Convert-CGMMStagingGroupCloud {
    <#
    .SYNOPSIS
    Converts a staging group into a production named group.

    .DESCRIPTION
    Converts a staging group into a production named group by removing the staging group prefix from relevant group properties.  Some properties such as SamAccountName and DistinguishedName are not able to be changed when renaming an Exchange Online object.  Other properties, such as Name, Alias, DisplayName, and EmailAddresses, that are used in administration and visible to end users will reflect your intended name.

    .EXAMPLE
    Convert-CGMMStagingGroupCloud -Identity $Identity

    Converts a staged distribution group in Exchange Online.  The Identity field must match a staged group name.
    .EXAMPLE
    Convert-CGMMStagingGroupCloud -Identity $Identity -HiddenFromAddressListsEnabled $True

    Converts a staged distribution group in Exchange Online and makes the group visible in address lists.  Staged objects are hidden during creation by default.
    .EXAMPLE
    Convert-CGMMStagingGroupCloud -Identity $Identity -IgnoreNamingPolicy

    Converting a staging group causes a rename action which is subjected to naming policies.  Use -IgnoreNamingPolicy to bypass the policy if required.
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
                Throw "The target group must begin with $($StagingGroupPrefix)."
            }
        })]
        [string]$Identity,

        [Parameter()]
		[Boolean]$HiddenFromAddressListsEnabled,

        [Parameter()]
		[switch]$IgnoreNamingPolicy
    )

	begin {}
	process	{
        Try {
            # Check for Exchange cmdlet availability in On Prem & Exchange Online
            Test-CGMMCmdletAccess -Environment Cloud -ErrorAction Stop
            
            $EAPSaved = $Global:ErrorActionPreference
            $Global:ErrorActionPreference = 'Stop'

            # Get the target group
            Write-Verbose "Querying for distribution group $($PSBoundParameters.Identity)"
            $Group = Get-CloudCGMMDistributionGroup -Identity $PSBoundParameters.Identity -ErrorAction Stop

            # Validate that the intended rename is available
            $OldGroupName = ($PSBoundParameters.Identity -replace $StagingGroupPrefix)
            $GetDistributionGroupSettings = @{
                Identity    = $OldGroupName
                ErrorAction = 'SilentlyContinue'
            }
            Write-Verbose "Querying for the intended group name $($OldGroupName), which shouldn't exist."
            If (Get-CloudCGMMDistributionGroup @GetDistributionGroupSettings) {
                $ErrorText = "The distribution group {0} must be removed before the staging prefix may be removed from {1}." -f $GetDistributionGroupSettings.Identity,$PSBoundParameters.Identity 
                Write-Error $ErrorText -ErrorAction Stop
            }

            # Find all properties that were prefixed.
            Write-Verbose "Identifing and processing prefixed properties"
            $PropertiesToProcess = $Group.PSObject.Properties | 
                Where-Object {$_.value -match $StagingGroupPrefix} | 
                Select-Object Name,Value

            # Setup a hash to be used to splat the non-prefixed values
            $SetDistributionGroupSettings = @{}
            ForEach ($Property in $PropertiesToProcess) {
                # Skip over properties that can't or shouldn't be changed
                $SkipProperties = @('DistinguishedName','Id','Identity','LegacyExchangeDN','PrimarySmtpAddress','SamAccountName')
                If ($SkipProperties -contains $Property.Name) {continue}

                Switch ($Property.Value.GetType().Name) {
                    string {
                        $ReplacedPrefix = ($Property.Value -replace $StagingGroupPrefix)
                        $SetDistributionGroupSettings.Add($Property.Name,$ReplacedPrefix)
                    }
                    arraylist {
                        $Array = ForEach ($Object in $Property.Value) {
                            $Object -replace $StagingGroupPrefix
                        }
                        $SetDistributionGroupSettings.Add($Property.Name,$Array)
                    }
                    Default {Write-Warning "Property type not accounted for:  $($Property.Name).  Manual intervention required."}
                }
                
                # Reconstruct the EmailAddresses property to hash the required adds and removes
                # Any non-prefixed addresses that happen to have been assigned will remain unchanged
                If ($Property.Name -eq 'EmailAddresses') {
                    $Removals = $Property.Value | Where-Object {$_ -match $StagingGroupPrefix}
                    $Adds = $SetDistributionGroupSettings['EmailAddresses'] | Where-Object {$Property.Value -notcontains $_}
                    $SetDistributionGroupSettings['EmailAddresses'] = @{Add=$Adds;Remove=$Removals}
                }
            }

            # Finish up the hash by adding providing parameters.
            $SetDistributionGroupSettings.Add('Identity',$PSBoundParameters.Identity)
            If ($PSBoundParameters.IgnoreNamingPolicy) {$SetDistributionGroupSettings.Add('IgnoreNamingPolicy',$True)}
            If ($null -ne $PSBoundParameters.HiddenFromAddressListsEnabled) {
                $SetDistributionGroupSettings.Add(
                    'HiddenFromAddressListsEnabled',$PSBoundParameters.HiddenFromAddressListsEnabled
                )
            }

            If ($PSCmdlet.ShouldProcess($Identity,$MyInvocation.MyCommand)) {
                Set-CloudCGMMDistributionGroup @SetDistributionGroupSettings
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