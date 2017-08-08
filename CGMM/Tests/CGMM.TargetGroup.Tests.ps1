Describe "CGMM MSOnline Tests" -Tag MSOnline {
    # Perform tests that utilize MSOnline
    Context MSOnline {
        # Test Connectivity By Storing Msol Domains
        Try {
            $MsolDomains = Get-MsolDomain -ErrorAction Stop | Select-Object -Expand Name
            It "MSOnline Domains Exist" {
                $MsolDomains | Should not BeNullOrEmpty 
            }
            $Skip = @{}
        }
        Catch {
            It "Connect-MsolService Executed" {
                $False | Should Be $True
            }
            $Skip = @{Skip = $True}
        }

        # Validate all assigned SMTP addresses are valid Msol domains
        [array]$SMTPAddresses = $GroupObject.EmailAddresses | Where-Object {$_ -match '^SMTP:'}
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

    Context 'Validate access to Exchange Online' {
        It 'Cloud CGMM Cmdlet Access Does Not Throw Error' {
            {Test-CGMMCmdletAccess -Environment Cloud} | Should Not Throw
        }
    }

    # Validate Users
    Context 'Validate Members Exist in Exchange Online'{
        $Skip = @{}
        $SkipThisContext = $False

        # Perform a query to see if connectivity exists.  We don't want warnings or errors for this query
        $getCloudCGMMRecipientSplat = @{
            ResultSize = 1
            WarningAction = 'SilentlyContinue'
            ErrorAction = 'SilentlyContinue'
        }
        If ($null -eq (Get-CloudCGMMRecipient @getCloudCGMMRecipientSplat)) {
            $SkipThisContext = $True
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