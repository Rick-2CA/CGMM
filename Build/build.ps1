<#
.Description
Installs and loads all the required modules for the build.
.Author
Warren F. (RamblingCookieMonster)
#>

[cmdletbinding()]
param ($Task = 'Default')

# Grab nuget bits, install modules, set build variables, start build.
Write-Warning 'Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null'
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

# PowerShellGet Work Around

Write-Warning 'Install-Module PowerShellGet'
Find-Module PowerShellGet | Install-Module -Force -SkipPublisherCheck
Write-Warning 'Remove-Module PowerShellGet,PackageManagement'
Remove-Module PowerShellGet,PackageManagement -Force
Write-Warning 'Import-Module -Name PowerShellGet -Force'
Import-Module -Name PowerShellGet -Force

Write-Warning 'Get-Module'
Get-Module
Write-Warning '-------------------------------'
$Modules = @("Psake", "PSDeploy","BuildHelpers","PSScriptAnalyzer", "Pester","Posh-Git")

ForEach ($Module in $Modules) {
    If (-not (Get-Module -Name $Module -ListAvailable)) {
        Switch ($Module) {
            Pester              {PowerShellGet\Install-Module $Module -Force -SkipPublisherCheck}
            Default             {PowerShellGet\Install-Module $Module -Force}
        }
    }
    Import-Module $Module
}

$Path = (Resolve-Path $PSScriptRoot\..).Path
Set-BuildEnvironment -Path $Path

Invoke-psake -buildFile $PSScriptRoot\psake.ps1 -taskList $Task -nologo
exit ([int](-not $psake.build_success))
