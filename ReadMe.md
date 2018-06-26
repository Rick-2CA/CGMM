# Cloud Group Migration Module (CGMM)

The CGMM module was designed to facilitate migrations of on premise Exchange distribution groups to Exchange Online distribution groups.  On premise group settings are staged in Exchange Online with a prefix for values that must be unique.  Upon your review of the staged object the on premise object can be disabled, a sync performed to remove the object from the cloud, and the stage group updated to remove the prefix where it now takes the place as the production group. An on premise mail contact can also be staged and updated for environments that require one.

## Version 1

The first flavor of version 1 published is 1.0.12.57.  There are just minor differences, cleanup type of changes, between 0.0.8.36 and 1.0.12.57.  The numerous minor changes are due to build troubleshooting and do not represent module code changes.

## Requirements

* PowerShell v4
* Requires Exchange Online connectivity.  See [Connect to Exchange Online PowerShell](https://technet.microsoft.com/en-us/library/jj984289(v=exchg.160).aspx).
* Requires Exchange Server connectivity.
* Exchange Server 2010 or newer
* [Pester](https://github.com/pester/Pester) (if installed via the PowerShell Gallery Pester will be automatically installed)

## Installation

The module is available on the [PowerShell Gallery](https://www.powershellgallery.com/packages/cgmm) and can be installed by running:

`Find-Module CGMM | Install-Module`

## Usage

The module requires connectivity to Exchange Server and Exchange Online at the same time.  Due to that the module expects the cmdlets from each resource to be available with specific prefixes.  The remote connections can be setup using `Import-CGMMExchOnline` and `Import-CGMMExchOnPrem` which add prefixes of 'CloudCGMM' and 'PremCGMM' respectively.  When using the module you can choose to write commands using those prefixes or make new connections using the prefixes of your choice.

## Available Commands

    CommandType     Name                                               Version    Source
    -----------     ----                                               -------    ------
    Function        Convert-CGMMStagingGroupCloud                      1.0.12.57   CGMM
    Function        Convert-CGMMStagingMailContact                     1.0.12.57   CGMM
    Function        Get-CGMMTargetGroup                                1.0.12.57   CGMM
    Function        Import-CGMMExchOnline                              1.0.12.57   CGMM
    Function        Import-CGMMExchOnPrem                              1.0.12.57   CGMM
    Function        New-CGMMStagingGroup                               1.0.12.57   CGMM
    Function        New-CGMMStagingMailContact                         1.0.12.57   CGMM
    Function        Set-CGMMStagingGroup                               1.0.12.57   CGMM
    Function        Set-CGMMStagingMailContact                         1.0.12.57   CGMM
    Function        Test-CGMMTargetGroup                               1.0.12.57   CGMM
    Function        Update-CGMMGroupMembershipCloud                    1.0.12.57   CGMM
    Function        Update-CGMMGroupMembershipOnPrem                   1.0.12.57   CGMM

Documentation for each function is available with `Get-Help`.

## Examples

Functions have been shared in the [Example Scripts](https://github.com/Rick-2CA/CGMM/tree/master/ExampleScripts) folder that utilize the CGMM module.  Using the functions allows the following work process:

    Import-CGMMExchOnline -Credential $ExchOnlineCredential
    Import-CGMMExchOnPrem -Credential $ExchOnPremCredential -ExchangeServer $ExchServerName
    Start-CGMMStaging $Identity -ExternalEmailAddress $ExtAddress
    Disable-DistributionGroup $Identity
    Start-ADSyncSyncCycle
    # Need a delay here for the sync so $Identity is no longer available in Exchange Online
    Complete-CGMMConversion "CGMM_$Identity" -HiddenFromAddressListsEnabled $False

AD replication impacts this process as it always has in regards to creating and editing Exchange objects.  Take advantage of the `Domain Controller` parameter available on all functions that work with on premise Exchange.  The `Start` and `Complete` example scripts both have the parameter available.

## Test-CGMMTargetGroup

As of version 0.0.8.36 a command called Test-CGMMTargetGroup exists to perform validation of migration candidates.  The command uses a Pester test included in the module to test various properties of on premise and cloud objects.  When running Test-CGMMTargetGroup you should also connect to MSOnline (`Connect-MsolService`) to validate email address domains exist in Office 365.

## Known Process Issues

Testing of the entire migration process has revealed a few scenarios that so far have proven better to solve outside of the module.  Please keep these scenarios in mind when performing migrations:

* Azure AD Connect may write-back the cloud LegacyExchangeDN to an Exchange disabled object.  If you're disabling and not deleting be sure to clear the proxyaddresses of the object before attempting to run the `Convert-CGMMStagingMailContact` command or move the object out of the sync scope for one sync iteration.
* Mail-enabled security groups may not be removed from Office 365 after being Exchange disabled.  This will cause `Convert-CGMMStagingGroupCloud` to fail.  The recommendation is to move the object out of the sync scope for one sync iteration.  Returning the object to its original OU after it's been removed in Office 365 will not have it recreated in the cloud on the next sync.

## Contributing

The module was written to satisfy the requirements of a specific environment with the motivation of having it work in any environment.

Features in mind for future releases:

* Allow the cmdlet prefixes to be configurable variables.
* Allow migration from on premise distribution groups to cloud unified groups
* Restoration functions to get you back to the original state by use of the export file from `Get-CGMMTargetGroup`

Feature additions are heavily influenced by the needs of my environment and your contributions!
