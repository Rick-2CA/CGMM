# Cloud Group Migration Module (CGMM)  
The CGMM module was designed to facilitate migrations of on premise Exchange distribution groups to Exchange Online distribution groups.  On premise group settings are staged in Exchange Online with a prefix for values that must be unique.  Upon your review of the staged object the on premise object can be disabled, a sync performed to remove the object from the cloud, and the stage group updated to remove the prefix where it now takes the place as the production group. An on premise mail contact can also be staged and updated for environments that require one.

## Requirements
* PowerShell v4
* Requires Exchange Online connectivity.  See [Connect to Exchange Online PowerShell](https://technet.microsoft.com/en-us/library/jj984289(v=exchg.160).aspx).
* Requires Exchange Server connectivity.  
* Exchange Server 2010 or newer

## Installation
Details pending....

## Usage
The module requires connectivity to Exchange Server and Exchange Online at the same time.  Due to that the module expects the cmdlets from each resource to be available with specific prefixes.  The remote connections can be setup using `Import-CGMMExchOnline` and `Import-CGMMExchOnPrem` which add prefixes of 'CloudCGMM' and 'PremCGMM' respectively.  When using the module you can choose to write commands using those prefixes or make new connections using the prefixes of your choice.

## Available Commands  

    CommandType     Name                                               Version    Source
    -----------     ----                                               -------    ------
    Function        Convert-CGMMStagingGroupCloud                      0.0.1.0    CGMM
    Function        Convert-CGMMStagingMailContact                     0.0.1.0    CGMM
    Function        Get-CGMMTargetGroup                                0.0.1.0    CGMM
    Function        Import-CGMMExchOnline                              0.0.1.0    CGMM
    Function        Import-CGMMExchOnPrem                              0.0.1.0    CGMM
    Function        New-CGMMStagingGroup                               0.0.1.0    CGMM
    Function        New-CGMMStagingMailContact                         0.0.1.0    CGMM
    Function        Set-CGMMStagingGroup                               0.0.1.0    CGMM
    Function        Set-CGMMStagingMailContact                         0.0.1.0    CGMM
    Function        Update-CGMMGroupMembershipCloud                    0.0.1.0    CGMM
    Function        Update-CGMMGroupMembershipOnPrem                   0.0.1.0    CGMM

Documentation for each function is available with `Get-Help`.

## Examples
Functions have been shared in the [Example Scripts](https://github.com/Rick-2CA/Cloud-Group-Migration-Module/tree/master/Example%20Scripts) folder that utilize the CGMM module.  Using the functions allows the following work process:

    Start-CGMMStaging $Identity -ExternalEmailAddress $ExtAddress
    Disable-DistributionGroup $Identity
    Start-ADSyncSyncCycle
    Complete-CGMMConversion "CGMM_$Identity" -HiddenFromAddressListsEnabled $False

You should add some validation into `Start-CGMMStaging` and proper timing between the steps listed here into the process, but the example shows how the process could be simplified by using CGMM to write your migration scripts.

## Contributing
The module was written to satisfy the requirements of a specific environment with the motivation of having it work in any environment.  

Features in mind for future releases:
* Allow the cmdlet prefixes to be configurable variables.
* Allow migration from on premise distribution groups to cloud unified groups
* Restoration functions to get you back to the original state by use of the export file from `Get-CGMMTargetGroup`

Feature additions are heavily influenced by the needs of my environment and your contributions!