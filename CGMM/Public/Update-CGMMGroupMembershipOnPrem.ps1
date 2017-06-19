Function Update-CGMMGroupMembershipOnPrem {
    <#
    .SYNOPSIS
    Update on premise distribution group membership with the migrated group's new mail contact.

    .DESCRIPTION
    Update on premise distribution group membership with the migrated group's new mail contact.  

    .EXAMPLE
    Update-CGMMGroupMembershipOnPrem -Identity $Identity -Group $Groups

    Specify the identity of the staged cloud mail contact that should be added as a member of one or more on premise distribution groups.

    .EXAMPLE
    Get-CGMMTargetGroup $OnPremiseDLIdentity | Update-CGMMGroupMembershipOnPrem -Identity $StagingMailContactIdentity

    The Group parameter has an alias of 'MemberOfOnPrem' provided by the Get-CGMMTargetGroup function.  If 'MemberOfOnPrem' has a value it can be piped into Update-CGMMGroupMembershipOnPrem.

    .EXAMPLE
    Update-CGMMGroupMembershipOnPrem -Identity $Identity -Group $Groups -BypassSecurityGroupManagerCheck

    Bypass the security group manager check to make membership changes to a group.

    .EXAMPLE
    Update-CGMMGroupMembershipOnPrem -Identity $Identity -Group $Groups -DomainController $DomainController

    Specify a domain controller to aid in making all on premise changes in the same location to avoid AD replication challenges.

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
        [Alias('MemberOfOnPrem')]
        [string[]]$Group,
        
        # Optional parameters
        [Parameter()]
        [switch]$BypassSecurityGroupManagerCheck,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DomainController
    )

	begin {}
	process	{
        # Check for Exchange cmdlet availability in On Prem & Exchange Online
        Try {Test-CGMMCmdletAccess -Environment OnPrem -ErrorAction Stop}
        Catch {
            $PsCmdlet.ThrowTerminatingError($PSItem)
        }
		
		ForEach ($Object in $Group) {
            $AddDistributionGroupMember = @{
                Identity    = $Object
                Member      = $Identity
            }
            If ($PSBoundParameters.DomainController) {$AddDistributionGroupMember.Add('DomainController',$PSBoundParameters.DomainController)}
            If ($PSBoundParameters.BypassSecurityGroupManagerCheck) {$AddDistributionGroupMember.Add('BypassSecurityGroupManagerCheck',$True)}

            If ($PSCmdlet.ShouldProcess($Object,$MyInvocation.MyCommand)) {
                Add-PremCGMMDistributionGroupMember @AddDistributionGroupMember
            }
        }
    }
	end {}
}
	
	
		