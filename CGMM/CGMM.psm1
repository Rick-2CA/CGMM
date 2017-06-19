#Requires -Version 3
[cmdletbinding()]
param()

Write-Verbose $PSScriptRoot

Write-Verbose "Creating Variables"
New-Variable StagingGroupPrefix -Value 'CGMM_' -Scope Script
New-Variable PremCmdletPrefix -Value 'PremCGMM' -Scope Script
New-Variable CloudCmdletPrefix -Value 'CloudCGMM' -Scope Script

Write-Verbose 'Import everything in sub folders folder'
ForEach ($Folder in @('Private','Public'))
{
    $Root = Join-Path -Path $PSScriptRoot -ChildPath $Folder
    If (Test-Path -Path $Root) {
        Write-Verbose "processing folder $Root"
        $Files = Get-ChildItem -Path $Root -Filter *.ps1 -Recurse

        # Dot source each file
        $Files | Where-Object{ $_.name -NotLike '*.Tests.ps1'} | 
            ForEach-Object {Write-Verbose $_.basename; . $_.FullName}
    }
}

Export-ModuleMember -Function (Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1").BaseName