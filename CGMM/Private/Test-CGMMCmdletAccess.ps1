Function Test-CGMMCmdletAccess {
    <#
    .SYNOPSIS

    .DESCRIPTION

    .EXAMPLE
    Test-CGMMCmdletAccess -Environment OnPrem,Cloud

    .EXAMPLE

    .NOTES

    #>
    [cmdletbinding()]
    param(
        # Pipeline variable
        [Parameter(Mandatory)]
        [ValidateSet('OnPrem','Cloud')]
        [string[]]$Environment
    )

	begin {}
	process	{
		Try {
            $TerminateValue = 0
            ForEach ($Object in $Environment) {
                Switch ($Object) {
                    OnPrem  {
                        Write-Verbose "Setting OnPrem variables"
                        $CmdletPrefix = $PremCmdletPrefix
                        $Option = 1
                    }
                    Cloud   {
                        Write-Verbose "Setting Cloud variables"
                        $CmdletPrefix = $CloudCmdletPrefix
                        $Option = 2
                    }
                }

                Try {
                    Write-Verbose "Searching for command Get-$($CmdletPrefix)DistributionGroup"
                    $null = Get-Command "Get-$($CmdletPrefix)DistributionGroup" -ErrorAction Stop
                    
                    Write-Verbose "Searching for command Get-$($CmdletPrefix)Recipient"
                    $null = Get-Command "Get-$($CmdletPrefix)Recipient" -ErrorAction Stop
                }
                Catch {
                    $TerminateValue = $TerminateValue + $Option
                }
            }

            $Option1Error = "This cmdlet requires access to On Premise Exchange cmdlets made available by running Import-CGMMExchOnPrem with your credentials.  Please connect to Exchange and try again."
            $Option2Error = "This cmdlet requires access to Exchange Online cmdlets made available by running Import-CGMMExchOnline with your credentials.  Please connect to Exchange Online and try again."
            $Option3Error = "This cmdlet requires access to Exchange & Exchange Online cmdlets made available by running Import-CGMMExchOnPrem & Import-CGMMExchOnline respectively with your credentials.  Please connect to both Exchange & Exchange Online and try again."

            Switch ($TerminateValue) {
                1 {Write-Error $Option1Error}
                2 {Write-Error $Option2Error}
                3 {Write-Error $Option3Error}
                Default {}
            }
        }
        Catch {
            $PsCmdlet.ThrowTerminatingError($PSItem)
        }
    }
	end {}
}        