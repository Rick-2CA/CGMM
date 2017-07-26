Function Update-CGMMGroupMembershipCloud {
    <#
    .SYNOPSIS
    Update other cloud distribution group membership with the migrated group's new cloud object.

    .DESCRIPTION
    Update other cloud distribution group membership with the migrated group's new cloud object.  

    .EXAMPLE
    Update-CGMMGroupMemberShipCloud -Identity $Identity -Group $Groups

    Specify the identity of the staged cloud distribution group that should be added as a member of one or more cloud distribution groups.

    .EXAMPLE
    Get-CGMMTargetGroup $OnPremiseDLIdentity | Update-CGMMGroupMemberShipCloud -Identity $StagingGroupIdentity

    The Group parameter has an alias of 'MemberOfCloud' provided by the Get-CGMMTargetGroup function.  If 'MemberOfCloud' has a value it can be piped into Update-CGMMGroupMemberShipCloud.

    .EXAMPLE
    Update-CGMMGroupMemberShipCloud -Identity $Identity -Group $Groups -BypassSecurityGroupManagerCheck

    Bypass the security group manager check to make membership changes to a group.

    .NOTES

    #>
    [cmdletbinding(SupportsShouldProcess)]
    param(
        # Mandatory parameters
        # No pipeline support for identity.  The object that should have the group membership
        # should have the old group's identity, not the new group's which should be specified
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity, 
        
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('MemberOfCloud')]
        [string[]]$Group,
        
        # Optional parameters
        [Parameter()]
        [switch]$BypassSecurityGroupManagerCheck
    )

	begin {}
	process	{
        # Check for Exchange cmdlet availability in On Prem & Exchange Online
        Try {Test-CGMMCmdletAccess -Environment Cloud -ErrorAction Stop}
        Catch {
            $PsCmdlet.ThrowTerminatingError($PSItem)
        }
		
		ForEach ($Object in $Group) {
            $AddDistributionGroupMember = @{
                Identity    = $Object
                Member      = $Identity
            }
            If ($BypassSecurityGroupManagerCheck) {$AddDistributionGroupMember.Add('BypassSecurityGroupManagerCheck',$True)}

            If ($PSCmdlet.ShouldProcess($Object,$MyInvocation.MyCommand)) {
                $EAPSaved = $Global:ErrorActionPreference
                $Global:ErrorActionPreference = 'Stop'
                Try {
                    Add-CloudCGMMDistributionGroupMember @AddDistributionGroupMember
                }
                Catch {
                    $PsCmdlet.ThrowTerminatingError($PSItem)
                }
                Finally {
                    $Global:ErrorActionPreference = $EAPSaved
                }
            }
        }
    }
	end {}
}