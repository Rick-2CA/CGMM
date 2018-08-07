param (
    $Identity,
    $DomainController
)

# Define skip variable.  It can be toggled to True upon failures to skip some tests
$Skip = $False

# Get the 'raw' distribution group properties
$getPremCGMMDistributionGroupSplat = @{
    Identity    = $Identity
    ErrorAction = 'Stop'
}
If ($null -ne $DomainController) {
    $getPremCGMMDistributionGroupSplat.Add('DomainController',$DomainController)
}
Try {$DistributionGroup = Get-PremCGMMDistributionGroup @getPremCGMMDistributionGroupSplat}
Catch {$Skip = $True}

Describe "CGMM Exchange On-Premise Tests" -Tag EXOnPrem {
    # Store and set EAP Value
    $EAPSaved = $Global:ErrorActionPreference
    $Global:ErrorActionPreference = 'Stop'

    Context 'Distribution Group Configuration' {
        It 'Distribution group found on premise' {
            $getPremCGMMDistributionGroupSplat = @{
                Identity    = $Identity
                ErrorAction = 'Stop'
            }
            If ($null -ne $DomainController) {
                $getPremCGMMDistributionGroupSplat.Add('DomainController',$DomainController)
            }
            {Get-PremCGMMDistributionGroup @getPremCGMMDistributionGroupSplat} | Should -Not -Throw
        }

        It 'Distribution group is not a member of another on premise group' {
            $getGroupSplat = @{
                ResultSize = 'Unlimited'
                Filter     = "Members -eq '$($DistributionGroup.Identity)'"
            }
            $MemberOf = (Get-PremCGMMGroup @getGroupSplat).Name
            $MemberOf | Should -BeNullOrEmpty
        }

        # Only run this test if MemberJoinRestriction is ApprovalRequired or the describe skip trigger is True
        $MJRSkip = ($DistributionGroup.MemberJoinRestriction -ne 'ApprovalRequired' -or $Skip -eq $True)
        It 'MemberJoinRestriction is set to ApprovalRequired and a manager is set in ManagedBy' -Skip:$MJRSkip {
            $DistributionGroup.ManagedBy | Should -Not -BeNullOrEmpty
        }

        It 'Alias does not contain spaces' -Skip:$Skip {
            $DistributionGroup.Alias | Should -Not -Match " "
        }

        It 'Alias does not have a period followed by another period' -Skip:$Skip {
            $DistributionGroup.Alias | Should -Not -Match "\.\."
        }
    }

    # Validate Users
    Context 'Validate Properties Have Exchange Objects As Members' {
        # Check properties that require members to exist in Exchange On-Premise
        $PropertiesToCheck = @(
            'AcceptMessagesOnlyFromSendersOrMembers','BypassModerationOnlyFromSendersOrMembers',
            'GrantSendOnBehalfTo','ManagedBy','ModeratedBy','RejectedSendersSendersOrMembers'
        )
        ForEach ($Property in $PropertiesToCheck) {
            $PropertyCount = $DistributionGroup.$Property.count
            $PropertySkip = ($Skip -eq $True -or $PropertyCount -eq 0)
            It "All $PropertyCount members in property $Property are available in Exchange On-Premise" -Skip:$PropertySkip {
                $CaughtMembers = $null
                # Catch members that error.  They'll show up in the failed test results
                $CaughtMembers = ForEach ($Member in $DistributionGroup.$Property) {
                    $getPremCGMMRecipientSplat = @{
                        Identity = $Member
                    }
                    If ($null -ne $DomainController) {
                        $getPremCGMMRecipientSplat.Add('DomainController',$DomainController)
                    }
                    Try {$null = Get-PremCGMMRecipient @getPremCGMMRecipientSplat}
                    Catch {
                        $Member
                    }
                }
                $CaughtMembers | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Validate Exchange Online Compatibility' {
        # Look for DistributionGroupMembers that aren't cloud supported recipient types
        $getPremCGMMDistributionGroupMemberSplat = @{
            Identity    = $Identity
            ErrorAction = 'Stop'
        }
        If ($null -ne $DomainController) {
            $getPremCGMMDistributionGroupMemberSplat.Add('DomainController',$DomainController)
        }
        Try {$DistributionGroupMembers = Get-PremCGMMDistributionGroupMember @getPremCGMMDistributionGroupMemberSplat}
        Catch {$Skip = $True}

        $SupportedRecipientTypes = @(
            'DynamicDistributionGroup','MailContact','MailNonUniversalGroup',
            'MailUniversalDistributionGroup','MailUniversalSecurityGroup',
            'MailUser','PublicFolder','UserMailbox'
        )

        It 'Distribution Group Members RecipientType Should Be Supported In Cloud' -Skip:$Skip {
            $NotSupported = ForEach ($Member in $DistributionGroupMembers) {
                If ($SupportedRecipientTypes -notcontains $Member.RecipientType) {
                    $Member.Name
                }
            }
            $NotSupported | Should -BeNullOrEmpty
        }

        It 'Distribution Group is Synced to Exchange Online (PrimarySMTPAddress Matches)' -Skip:$Skip {
            $CloudGroupQuery = Get-CloudCGMMDistributionGroup -Identity $Identity -ErrorAction Stop
            $CloudGroupQuery.PrimarySMTPAddress | Should -Be $DistributionGroup.PrimarySMTPAddress
        }
    }
    # Return EAP Value
    $Global:ErrorActionPreference = $EAPSaved
}

Describe "CGMM MSOnline Tests" -Tag MSOnline {
    # Store and set EAP Value
    $EAPSaved = $Global:ErrorActionPreference
    $Global:ErrorActionPreference = 'Stop'

    $Skip = ($null -eq $DistributionGroup)

    # Return EAP Value
    $Global:ErrorActionPreference = $EAPSaved

    # Get a list of MsolDomains from MSOnline
    Try {
        [array]$MsolDomains = Get-MsolDomain -ErrorAction Stop | Select-Object -Expand Name
    }
    Catch {$Skip = $True}

    Context 'MSOnline' {
        # Show tests regarding the MSOnline query
        It "MSOnline Successfully Queried" -Skip:$Skip {
            # This test should never fail.  It'll succeed or skip.
            $Skip | Should -Not -Be $True
        }

        It "Found $($MsolDomains.count) MsolDomains" -Skip:$Skip {
            $MSolDomains | Should -Not -BeNullOrEmpty
        }
    }

    Context 'MSOnline Email Domain Validation' {
        # Confirm the group was found & has addresses
        It 'Distribution Group EmailAddresses Property Has Addresses' -Skip:$Skip {
            $DistributionGroup.EmailAddresses | Should -Not -BeNullOrEmpty
        }

        # Validate all assigned SMTP addresses are valid Msol domains
        [array]$SMTPAddresses = $DistributionGroup.EmailAddresses | Where-Object {$_ -match '^SMTP:'}
        [array]$Domains = ForEach ($Address in $SMTPAddresses) {
            $Address.Split("@")[1]
        }
        [array]$UniqueDomains = $Domains | Select-Object -Unique
        ForEach ($UniqueDomain in $UniqueDomains) {
            It "Domain $UniqueDomain Exists in MSOnline" -Skip:$Skip {
                $MsolDomains -contains $UniqueDomain | Should -Be $True
            }
        }
    }
}

Describe "CGMM Exchange Online Tests" -Tag EXOnline {
    # Store and set EAP Value
    $EAPSaved = $Global:ErrorActionPreference
    $Global:ErrorActionPreference = 'Stop'

    # Query for the CGMMTargetGroup.
    $getCGMMTargetGroupSplat = @{
        Identity            = $Identity
        DomainController    = $DomainController
        ErrorAction         = 'Stop'
    }
    Try {$GroupObject = Get-CGMMTargetGroup @getCGMMTargetGroupSplat}
    Catch {$Skip = $True}

    # Validate Users
    Context 'Validate Members Exist in Exchange Online' {
        It "Get-CGMMTargetGroup successfully queries" {
            $getCGMMTargetGroupSplat.ErrorAction = 'Continue'
            {$GroupObject = Get-CGMMTargetGroup @getCGMMTargetGroupSplat} | Should -Not -Throw
        }

        # Check properties that require members to exist in Exchange Online
        $PropertiesToCheck = @(
            'AcceptMessagesOnlyFromSmtpAddresses','BypassModerationOnlyFromSmtpAddresses',
            'GrantSendOnBehalfToSmtpAddresses','ManagedBySmtpAddresses',
            'Members','ModeratedBySmtpAddresses','RejectedSendersSmtpAddresses'
        )
        ForEach ($Property in $PropertiesToCheck) {
            # Save the Skip value to reset
            $PropertySkip = $False
            $PropertyCount = $GroupObject.$Property.count
            $PropertySkip = ($Skip -eq $True -or $PropertyCount -eq 0)
            It "All $PropertyCount members in property $Property are available in Exchange Online" -Skip:$PropertySkip {
                $CaughtMembers = $null
                $CaughtMembers = ForEach ($Member in $GroupObject.$Property) {
                    Try {$null = Get-CloudCGMMRecipient $Member}
                    Catch {
                        $Member
                    }
                }
                $CaughtMembers | Should -BeNullOrEmpty
            }
        }
    }

    # Return EAP Value
    $Global:ErrorActionPreference = $EAPSaved
}
