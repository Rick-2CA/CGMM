Function Test-CGMMTargetGroup {
    <#
    .SYNOPSIS
    Run Pester tests against a target group for migration.

    .DESCRIPTION
    Run Pester tests against a target group for migration.  Accepts a group name or a group object (from Get-CGMMTargetGroup or the contents of an export from Get-CGMMTargetGroup).  A default script is executed if a Pester script is not defined with the Script parameter.

    .EXAMPLE
    Test-CGMMTargetGroup -Identity $Identity

    Run the default Pester test against an existing target group.  This method will run Get-CGMMTargetGroup to find the identity.
    .EXAMPLE
    Test-CGMMTargetGroup -Identity $Identity -DomainController $DomainController 
    
    Run the default Pester script specifying a domain controller for the Get-CGMMTargetGroup query.
    .EXAMPLE
    Test-CGMMTargetGroup -CGMMTargetGroupObject $CGMMTargetGroupObject -Tag MSOnline,EXOnline

    Run the default Pester script with specified tags.  Tags can be run to test specifc groups of tests.    
    .EXAMPLE
    Test-CGMMTargetGroup -CGMMTargetGroupObject $CGMMTargetGroupObject -Script $Script

    Run specified Pester script(s) against the CGMMTargetGroupObject.
    .NOTES

    #>
    #requires -Module Pester

    [CmdletBinding(DefaultParameterSetName="Identity")]
    param(
        # Pipeline variable
        [Parameter(ParameterSetName='Identity',Mandatory=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity,

        [Parameter(ParameterSetName='CGMMTargetGroupObject',Mandatory=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [object]$CGMMTargetGroupObject,
        
        [Parameter(ParameterSetName='Identity')]
        [Parameter(ParameterSetName='CGMMTargetGroupObject')]
        [ValidateNotNullOrEmpty()]
        [object[]]$Script=$DefaultPesterTest,
        
        [Parameter(ParameterSetName='Identity')]
        [Parameter(ParameterSetName='CGMMTargetGroupObject')]
        [string[]]$TestName,
        
        [Parameter(ParameterSetName='Identity')]
        [Parameter(ParameterSetName='CGMMTargetGroupObject')]
        [string[]]$Tag,

        [Parameter(ParameterSetName='Identity')]
        [Parameter(ParameterSetName='CGMMTargetGroupObject')]
        [Switch]$PassThru,
                
        [Parameter(ParameterSetName='Identity')]
        [string]$DomainController
    )

	begin {}
	process	{
        # Use the identity to create a group object to run Pester against
		If ($PsCmdlet.ParameterSetName -eq 'Identity') {
            Try {
                $SavedErrorActionPreference = $Global:ErrorActionPreference
                $Global:ErrorActionPreference = 'Stop'

                # Splat for Get-CGMMTargetGroup
                $getCGMMTargetGroupSplat = @{
                    Identity = $Identity
                    ErrorAction = 'Stop'
                }

                # Validate the Domain Controller
                If ($PSBoundParameters.DomainController) {
                    Write-Verbose "Validating domain controller $DomainController with Test-Connection"
                    Test-Connection $DomainController -Count 2 -ErrorAction Stop | Out-Null
                    $getCGMMTargetGroupSplat.Add('DomainController',$DomainController)
                }

                # Query target group
                Write-Verbose "Querying $Identity"
                $GroupObject = Get-CGMMTargetGroup @getCGMMTargetGroupSplat
            }
            Catch {
                $PsCmdlet.ThrowTerminatingError($PSItem)
            }
            Finally {
                $Global:ErrorActionPreference = $SavedErrorActionPreference
            }
        }

        # If GroupObject wasn't queried grab the CGMMTargetGroupObject
        If ($null -eq $GroupObject -and $PSBoundParameters.CGMMTargetGroupObject) {
            $GroupObject = $PSBoundParameters.CGMMTargetGroupObject
        }

        $invokePester = @{
            Script  = @{Path = $Script; Parameters = @{GroupObject = $GroupObject}}
        }
        If ($PSBoundParameters.TestName) {
            $invokePester.Add('TestName',$PSBoundParameters.TestName)
        }
        If ($PSBoundParameters.Tag) {
            $invokePester.Add('Tag',$PSBoundParameters.Tag)
        }
        If ($PSBoundParameters.PassThru) {
            $invokePester.Add('PassThru',$PSBoundParameters.PassThru)
        }
        Invoke-Pester @invokePester
    }
	end {}
}

<#
Test-CGMMTargetGroup will need to be custom for the module.  It'll run two stages:
    * Prem Tests
    * Cloud Tests

The Prem tests will ensure that Get-CGMMTargetGroup's Get-PremCGMM* calls are validated
The Cloud tests will ensure that Get-CGMMTargetGroup's Get-CloudCGMM* calls are validated
    Also tests MSOnline domains

The function will not allow other tests.  Users will have to write and call their own tests for Invoke-Pester
The function will not accept objects in leiu of Identity.
The function should still accept tags, which can now use ValidateSet, and PassThru

# Tests
Get-PremCGMMDistributionGroup
Get-PremCGMMDistributionGroupMember
Get-CGMMDistributionGroupMembership $GroupObject.PrimarySmtpAddress (OnPrem)
Get-CGMMDistributionGroupMembership $GroupObject.PrimarySmtpAddress -Cloud
ForEach ($User in $Group.AcceptMessagesOnlyFrom) {Try {$null = Get-PremCGMMRecipient $User -ErrorAction Stop}Catch {$User}}
Get-CloudCGMMDistributionGroup

#>