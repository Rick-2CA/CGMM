# Cloud Group Migration Module (CGMM)  
The CGMM module was designed to facilitate migrations of on premise Exchange distribution groups to Exchange Online distribution groups.  On premise group settings are staged in Exchange Online with a prefix for values that must be unique.  Upon your review of the staged object the on premise object can be disabled, a sync performed to remove the object from the cloud, and the stage group updated to remove the prefix where it now takes the place as the production group. An on premise mail contact can also be staged and updated for environments that require one.

## Requirements
* Tested for PowerShell version 4 and above.
* Requires Exchange Online connectivity.  See [Connect to Exchange Online PowerShell](https://technet.microsoft.com/en-us/library/jj984289(v=exchg.160).aspx).
* Requires Exchange Server connectivity.  
* Development completed with Exchange 2010 although it's expected to work through Exchange 2016.

## Installation



## Available Commands  

    CommandType     Name                                               Version    Source
    -----------     ----                                               -------    ------
    Function        Convert-CGMMStagingGroupCloud                      0.0.3.0    CGMM
    Function        Convert-CGMMStagingMailContact                     0.0.3.0    CGMM
    Function        Get-CGMMTargetGroup                                0.0.3.0    CGMM
    Function        Import-CGMMExchOnline                              0.0.3.0    CGMM
    Function        Import-CGMMExchOnPrem                              0.0.3.0    CGMM
    Function        New-CGMMStagingGroup                               0.0.3.0    CGMM
    Function        New-CGMMStagingMailContact                         0.0.3.0    CGMM
    Function        Set-CGMMStagingGroup                               0.0.3.0    CGMM
    Function        Set-CGMMStagingMailContact                         0.0.3.0    CGMM
    Function        Update-CGMMGroupMembershipCloud                    0.0.3.0    CGMM
    Function        Update-CGMMGroupMembershipOnPrem                   0.0.3.0    CGMM


Documentation for each function is available with `Get-Help`.

## Examples
Functions have been shared in the [Example Scripts](https://github.com/Rick-2CA/Cloud-Group-Migration-Module/tree/master/Example%20Scripts) folder that utilize the CGMM module.  Using the functions allows the following work process:

    Start-CGMMStaging $Identity -ExternalEmailAddress $ExtAddress
    Disable-DistributionGroup $Identity
    Start-ADSyncSyncCycle
    Complete-CGMMConversion "CGMM_$Identity" -HiddenFromAddressListsEnabled $False

You should add some validation into `Start-CGMMStaging` and proper timing between the steps listed here into the process, but the example shows how the process could be simplified by using CGMM to write your migration scripts.

