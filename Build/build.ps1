<#
.Description
Installs and loads all the required modules for the build.
.Author
Warren F. (RamblingCookieMonster)
#>

[cmdletbinding()]
param ($Task = 'Default')

# Grab nuget bits, install modules, set build variables, start build.
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

# PowerShellGet Work Around
## v1.1.3.2 issue #156 (https://github.com/PowerShell/PowerShellGet/issues/156) impacts this project.
## The work around below will hopefully allow PSGallery deployments to work until a new release is published.
## Edit 2:  AppVeyor returned v1.0.0.1.  Changed code below to try and force 1.1.3.1.
# $PowerShellGetv1131 = Get-Module PowerShellGet -ListAvailable | Where-Object {$_.Version -eq [System.Version]'1.1.3.1'}
# If ($null -eq $PowerShellGetv1131) {
#     Find-Module PowerShellGet -RequiredVersion 1.1.3.1 | Install-Module
# }
Remove-Module PowerShellGet -Force -ErrorAction SilentlyContinue
Find-Module PowerShellGet | Install-Module -Scope CurrentUser
Import-Module -Name PowerShellGet -Force
# Import-Module -Name PowerShellGet -RequiredVersion 1.1.3.1

$Modules = @("Psake", "PSDeploy","BuildHelpers","PSScriptAnalyzer", "Pester","Posh-Git")

ForEach ($Module in $Modules) {
    If (-not (Get-Module -Name $Module -ListAvailable)) {
        Switch ($Module) {
            Pester              {Install-Module $Module -Force -SkipPublisherCheck}
            PSScriptAnalyzer    {Install-Module $Module -Force -SkipPublisherCheck}
            Default             {Install-Module $Module -Force}
        }
    }
    Import-Module $Module
}

$Path = (Resolve-Path $PSScriptRoot\..).Path
Set-BuildEnvironment -Path $Path

Invoke-psake -buildFile $PSScriptRoot\psake.ps1 -taskList $Task -nologo
exit ([int](-not $psake.build_success))
