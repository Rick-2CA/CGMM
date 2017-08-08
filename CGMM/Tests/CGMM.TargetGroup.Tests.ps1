param (
    $Identity,
    $DomainController
)

Describe "CGMM Exchange On-Premise Tests" -Tag EXOnPrem {
    # Store and set EAP Value
    $EAPSaved = $Global:ErrorActionPreference
    $Global:ErrorActionPreference = 'Stop'

    # Validate Users
    Context 'Validate Members Exist in Exchange On-Premise' {
        $Skip = @{}
        $SkipThisContext = $False

        # Get the 'raw' distribution group properties
        $getPremCGMMDistributionGroupSplat = @{
            Identity    = $Identity
            ErrorAction = 'Stop'
        }
        If ($null -ne $DomainController) {
            $getPremCGMMDistributionGroup.Add('DomainController',$DomainController)
        }
        Try {$DistributionGroup = Get-PremCGMMDistributionGroup @getPremCGMMDistributionGroupSplat}
        Catch {$SkipThisContext = $True}

        It 'Distribution Group Query Successful' {
            $DistributionGroup.Name | Should Be $Identity
        }

        # Check properties that require members to exist in Exchange On-Premise
        $PropertiesToCheck = @(
            'AcceptMessagesOnlyFromSendersOrMembers','BypassModerationOnlyFromSendersOrMembers',
            'GrantSendOnBehalfTo','ManagedBy','ModeratedBy','RejectedSendersSendersOrMembers'
        )
        ForEach ($Property in $PropertiesToCheck) {
            $Skip = @{}
            $PropertyCount = $DistributionGroup.$Property.count
            If ($SkipThisContext -eq $True -or $PropertyCount -eq 0) {
                $Skip = @{Skip = $True}
            }
            It "All $PropertyCount members in property $Property are available in Exchange On-Premise" @Skip {
                $CaughtMembers = $null
                $CaughtMembers = ForEach ($Member in $DistributionGroup.$Property) {
                    $getPremCGMMRecipientSplat = @{
                        Identity = $Member
                    }
                    If ($null -ne $DomainController) {
                        $getPremCGMMDistributionGroup.Add('DomainController',$DomainController)
                    }
                    Try {$null = Get-PremCGMMRecipient @getPremCGMMRecipientSplat}
                    Catch {
                        $Member
                    }
                }
                $CaughtMembers | Should BeNullOrEmpty
            }
        }

        # Look for DistributionGroupMembers that aren't cloud supported recipient types
        $getPremCGMMDistributionGroupMemberSplat = @{
            Identity    = $Identity
            ErrorAction = 'Stop'
        }
        If ($null -ne $DomainController) {
            $getPremCGMMDistributionGroup.Add('DomainController',$DomainController)
        }
        Try {$DistributionGroupMembers = Get-PremCGMMDistributionGroupMember @getPremCGMMDistributionGroupMemberSplat}
        Catch {$SkipThisContext = $True}

        $SupportedRecipientTypes = @(
            'DynamicDistributionGroup','MailContact','MailNonUniversalGroup',
            'MailUniversalDistributionGroup','MailUniversalSecurityGroup',
            'MailUser','PublicFolder','UserMailbox'
        )

        It 'Distribution Group Member Type Should Be Supported In Cloud' @Skip {
            $NotSupported = ForEach ($Member in $DistributionGroupMembers) {
                If ($SupportedRecipientTypes -notcontains $Member.RecipientType) {
                    $Member.Name
                }
            }
            $NotSupported | Should BeNullOrEmpty
        }

        It 'Distribution Group is Synced to Exchange Online' @Skip {
            $CloudGroupQuery = Get-CloudCGMMDistributionGroup -Identity $Identity -ErrorAction Stop
            $CloudGroupQuery.Name | Should Be $Identity
        }
    }
    # Return EAP Value
    $Global:ErrorActionPreference = $EAPSaved
}

Describe "CGMM MSOnline Tests" -Tag MSOnline {
    # Store and set EAP Value
    $EAPSaved = $Global:ErrorActionPreference
    $Global:ErrorActionPreference = 'Stop'

    # Query the distribution group for the EmailAddresses property
    $getPremCGMMDistributionGroupSplat = @{
        Identity    = $Identity
        ErrorAction = 'Stop'
    }
    If ($null -ne $DomainController) {
        $getPremCGMMDistributionGroup.Add('DomainController',$DomainController)
    }
    Try {$EmailAddresses = Get-PremCGMMDistributionGroup @getPremCGMMDistributionGroupSplat | Select-Object -ExpandProperty EmailAddresses}
    Catch {}

    # Return EAP Value
    $Global:ErrorActionPreference = $EAPSaved

    Context MSOnline {
        # Get a list of MsolDomains from MSOnline
        $Skip = @{}
        If ($null -eq $EmailAddresses) {
            $Skip = @{Skip = $True}
        }
        Try {
            [array]$MsolDomains = Get-MsolDomain -ErrorAction Stop | Select-Object -Expand Name
        }
        Catch {$Skip = @{Skip = $True}}

        # Show tests regarding the MSOnline query
        It "MSOnline Successfully Queried" {
            $Skip.Skip | Should Not Be $True
        }

        It "Found $($MsolDomains.count) MsolDomains" @Skip {
            $MSolDomains | Should Not BeNullOrEmpty
        }

        # Validate all assigned SMTP addresses are valid Msol domains
        [array]$SMTPAddresses = $EmailAddresses | Where-Object {$_ -match '^SMTP:'}
        [array]$Domains = ForEach ($Address in $SMTPAddresses) {
            $Address.Split("@")[1]
        }
        [array]$UniqueDomains = $Domains | Select-Object -Unique
        ForEach ($UniqueDomain in $UniqueDomains) {
            It "Domain $UniqueDomain Exists in MSOnline" @Skip {
                $MsolDomains -contains $UniqueDomain | Should Be $True
            }
        }
    }
}

Describe "CGMM Exchange Online Tests" -Tag EXOnline {
    # Store and set EAP Value
    $EAPSaved = $Global:ErrorActionPreference
    $Global:ErrorActionPreference = 'Stop'

    # Validate Users
    Context 'Validate Members Exist in Exchange Online' {
        $Skip = @{}
        $SkipThisContext = $False

        Try {
            $GroupObject = Get-CGMMTargetGroup -Identity $Identity -DomainController $DomainController
        }
        Catch {$SkipThisContext = $True}

        It "Get-CGMMTargetGroup successfully queries" {
            $GroupObject | Should Not BeNullOrEmpty
        }

        # Check properties that require members to exist in Exchange Online
        $PropertiesToCheck = @(
            'AcceptMessagesOnlyFromSmtpAddresses','BypassModerationOnlyFromSmtpAddresses',
            'GrantSendOnBehalfToSmtpAddresses','ManagedBySmtpAddresses',
            'Members','ModeratedBySmtpAddresses','RejectedSendersSmtpAddresses'
        )
        ForEach ($Property in $PropertiesToCheck) {
            $PropertyCount = $GroupObject.$Property.count
            If ($SkipThisContext -eq $True -or $PropertyCount -eq 0) {
                $Skip = @{Skip = $True}
            }
            It "All $PropertyCount members in property $Property are available in Exchange Online" @Skip {
                $CaughtMembers = $null
                $CaughtMembers = ForEach ($Member in $GroupObject.$Property) {
                    Try {$null = Get-CloudCGMMRecipient $Member}
                    Catch {
                        $Member
                    }
                }
                $CaughtMembers | Should BeNullOrEmpty
            }
            $Skip = @{}
        }
    }

    # Return EAP Value
    $Global:ErrorActionPreference = $EAPSaved
}