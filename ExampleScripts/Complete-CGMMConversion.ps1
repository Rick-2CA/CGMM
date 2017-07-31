Function Complete-CGMMConversion {
    <#
    .SYNOPSIS
    An example of how to utilize the CGMM module to automate the conversion of a staging group to production.

    .DESCRIPTION
    An example of how to utilize the CGMM module to automate the conversion of a staging group and its on premise staging contact.  It's recommended to specify a domain controller that's in the same site as Exchange.  This step should come after removing the migration target from Exchange (on premise as well as the synced copy in the cloud).

    .EXAMPLE
    Complete-CGMMConversion -Identity $Identity -HiddenFromAddressListsEnabled $False -DomainController $DomainController

    Convert the on premise mail contact and cloud distribution group from staging to production and unhide the objects in the GAL.

    .NOTES

    #>
    [cmdletbinding()]
    param(
        # Pipeline variable
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            Try {$_ -match "^$($StagingGroupPrefix)"}
            Catch {
                Throw "The target identity must begin with $($StagingGroupPrefix)."
            }
        })]
        [string]$Identity,

        [Parameter()]
		[Boolean]$HiddenFromAddressListsEnabled,

        [Parameter()]
		[Switch]$IgnoreNamingPolicy,
        
        [Parameter()]
        [string]$DomainController
    )

	begin {}
	process	{
        $SavedErrorActionPreference = $Global:ErrorActionPreference
        $Global:ErrorActionPreference = 'Stop'
        Try {
            $convertCGMMStagingMailContact = @{
                Identity    = $Identity
            }
            If ($null -ne $PSBoundParameters.HiddenFromAddressListsEnabled) {
                $convertCGMMStagingMailContact.Add('HiddenFromAddressListsEnabled',$PSBoundParameters.HiddenFromAddressListsEnabled)
            }
            If ($null -ne $PSBoundParameters.DomainController) {
                $convertCGMMStagingMailContact.Add('DomainController',$PSBoundParameters.DomainController)
            }
            Write-Verbose "Converting mail contact $($PSBoundParameters.Identity)"
            Convert-CGMMStagingMailContact @convertCGMMStagingMailContact

            $convertCGMMStagingGroupCloud = @{
                Identity    = $Identity
            }
            If ($null -ne $PSBoundParameters.HiddenFromAddressListsEnabled) {
                $convertCGMMStagingGroupCloud.Add('HiddenFromAddressListsEnabled',$PSBoundParameters.HiddenFromAddressListsEnabled)
            }
            If ($null -ne $PSBoundParameters.IgnoreNamingPolicy) {
                $convertCGMMStagingGroupCloud.Add('IgnoreNamingPolicy',$True)
            }
            Write-Verbose "Converting cloud distribution group $($PSBoundParameters.Identity)"
            Convert-CGMMStagingGroupCloud @convertCGMMStagingGroupCloud
        }
        Catch {
		$PsCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {
            $Global:ErrorActionPreference = $SavedErrorActionPreference
        }
    }
	end {}
}