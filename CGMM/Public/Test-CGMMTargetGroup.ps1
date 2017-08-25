Function Test-CGMMTargetGroup {
    <#
    .SYNOPSIS
    Run Pester tests against a target group for migration.

    .DESCRIPTION
    Run Pester tests against a target group for migration.  A default Pester script is executed to validate whether the group can be staged successfully.

    .EXAMPLE
    Test-CGMMTargetGroup -Identity $Identity

    Run the default Pester test against an existing target group.
    .EXAMPLE
    Test-CGMMTargetGroup -Identity $Identity -Tag EXOnPrem 
    
    Use predefined Tags to run one or more tests.  Allows you to rerun portions of the test when correcting group configurations.
    .EXAMPLE
    Test-CGMMTargetGroup -Identity $Identity -PassThru 

    The PassThru switch causes Invoke-Pester to produce an output object which can be analyzed by its caller, instead of only sending output to the console.
    .EXAMPLE
    Test-CGMMTargetGroup -Identity $Identity -DomainController $DomainController 

    Ensure on premise queries use a specified domain controller within the Pester test
    .NOTES

    #>
    #requires -Module Pester

    [CmdletBinding()]
    param(
        # Pipeline variable
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity,
        
        [Parameter()]
        [ValidateSet('EXOnline','EXOnPrem','MSOnline')]
        [string[]]$Tag,

        [Parameter()]
        [Switch]$PassThru,
                
        [Parameter()]
        [string]$DomainController
    )

	begin {}
	process	{
        # Use the default pester test path set in the PSM1
        $Script = $DefaultPesterTest

        # Check for Exchange cmdlet availability in On Prem & Exchange Online
        Try {Test-CGMMCmdletAccess -Environment OnPrem,Cloud -ErrorAction Stop}
        Catch {
            $PsCmdlet.ThrowTerminatingError($PSItem)
        }

        # Test for MSOnline access - the only function that uses it, but the Pester tests will skip
        # tests that utilize it if it's not available.
        Try {Get-MsolAccountSku -ErrorAction Stop | Out-Null}
        Catch {
            If ($PSItem -match 'You must call the Connect-MsolService cmdlet before calling any other cmdlets.') {
                Write-Warning 'Domain validation requires MSOnline connectivity, but is optional.  Run Connect-MsolService to avoid skipping those tests.'
            }
        }

        # Set Script Parameters
        $ScriptParameters = @{
            Identity   = $PSBoundParameters.Identity
        }
        If ($PSBoundParameters.DomainController) {
            $ScriptParameters.Add('DomainController',$PSBoundParameters.DomainController)
        }

        # Set Pester Parameters
        $invokePesterSplat = @{
            Script  = @{Path=$Script;Parameters=$ScriptParameters}
        }
        If ($PSBoundParameters.Tag) {
            $invokePesterSplat.Add('Tag',$PSBoundParameters.Tag)
        }
        If ($PSBoundParameters.PassThru) {
            $invokePesterSplat.Add('PassThru',$PSBoundParameters.PassThru)
        }
        Invoke-Pester @invokePesterSplat
    }
	end {}
}