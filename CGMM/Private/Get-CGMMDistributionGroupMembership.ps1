<#
    .NOTES
        Sourced from the Mark Kraus (https://get-powershellblog.blogspot.com/) at https://www.reddit.com/r/PowerShell/comments/59ebur/o365_user_groups_and_recursive_groups.  This version has been modified for the requirements of the module.
#>

function Get-CGMMDistributionGroupMembership {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True
        )]
        [string[]]$Identity,
        [switch]$Recurse,
        [string[]]$Processed,
        [switch]$Cloud
    )
    begin{
        if(-not $processed){
            $Processed = @()
        }
    }    
    process {
        foreach ($CurIdentity in $Identity){
            if(-not $PSCmdlet.ShouldProcess($CurIdentity)){
                continue
            }
            Write-Verbose "Looking up memberships for '$CurIdentity'."
            try{
                If ($Cloud) {
                    $Recipient = Get-CloudCGMMRecipient -Identity $CurIdentity -ErrorAction Stop
                }
                Else {$Recipient = Get-PremCGMMRecipient -Identity $CurIdentity -ErrorAction Stop}
            }
            catch {
                $ErrorMessage = $_.exception.message
                $Message = "Unable to find recipient '{0}': {1}" -f $CurIdentity, $ErrorMessage
                Write-Error $Message
                continue
            }
            Write-Verbose "Adding '$($Recipient.PrimarySmtpAddress)' to processed list"
            $Processed += $Recipient.PrimarySmtpAddress
            $Results = @()
            $Filter = {members -eq "{0}"} -f $Recipient.DistinguishedName
            If ($Cloud) {
                Write-Verbose "Looking up cloud recipients"
                $CloudRecipients = Get-CloudCGMMRecipient -ResultSize Unlimited -filter $Filter | 
                    Select-Object -ExpandProperty PrimarySmtpAddress |  
                    Where-Object {$_ -notin $Processed}

                Write-Verbose "Filter out cloud recipients that are DirSynced"
                $Recipients = ForEach ($GroupPrimarySmtpAddress in $CloudRecipients) {
                    Get-CloudCGMMDistributionGroup $GroupPrimarySmtpAddress | 
                    Where-Object {$_.IsDirSynced -eq $False} |
                    Select-Object -ExpandProperty PrimarySmtpAddress
                }
            }
            Else {
                Write-Verbose "Looking up on prem recipients"
                $Recipients = Get-PremCGMMRecipient -ResultSize Unlimited -filter $Filter | 
                    Select-Object -ExpandProperty PrimarySmtpAddress |  
                    Where-Object {$_ -notin $Processed}
            }
            
            ForEach ($Recipient in $Recipients) {
                #Send the current result to the pipe and at it to the $Results so it can later be recursed
                $Recipient
                $Results += $Recipient
            }
            
            if(-not $Recurse){
                continue
            }
            #Trying to do this in a pipeline screws things up, so need to do it one at a time... :(
            Foreach($Result in $Results){
                Write-Verbose "Recursing for '$($Result.PrimarySmtpAddress)'."
                Get-CGMMDistributionGroupMembership -Identity $Result.PrimarySmtpAddress -Recurse -Processed $Processed
                Write-Verbose "Done recursing for '$($Result.PrimarySmtpAddress)'."
            }#End Foreach result
        } #End Foreach Identity
    } #End Process
} #End Function