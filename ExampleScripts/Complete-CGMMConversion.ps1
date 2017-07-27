Function Complete-CGMMConversion {
    <#
    .SYNOPSIS

    .DESCRIPTION

    .EXAMPLE
    Complete-CGMMConversion -Identity $Identity -HiddenFromAddressListsEnabled $False

    .EXAMPLE

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
            $CmdletParameters = @{
                Identity    = $Identity
            }
            If ($null -ne $PSBoundParameters.HiddenFromAddressListsEnabled) {
                $CmdletParameters.Add('HiddenFromAddressListsEnabled',$PSBoundParameters.HiddenFromAddressListsEnabled)
            }
            If ($null -ne $PSBoundParameters.DomainController) {
                $CmdletParameters.Add('DomainController',$PSBoundParameters.DomainController)
            }
            Write-Verbose "Converting mail contact $($PSBoundParameters.Identity)"
            Convert-CGMMStagingMailContact @CmdletParameters

            If ($null -ne $PSBoundParameters.IgnoreNamingPolicy) {
                $CmdletParameters.Add('IgnoreNamingPolicy',$True)
            }
            Write-Verbose "Converting cloud distribution group $($PSBoundParameters.Identity)"
            Convert-CGMMStagingGroupCloud @CmdletParameters
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