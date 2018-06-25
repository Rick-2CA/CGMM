<#
.Description
Installs and loads all the required modules for the build.
.Author
Warren F. (RamblingCookieMonster)
#>

[cmdletbinding()]
param ($Task = 'Default')

Write-Warning 'Get-Module'
Get-Module
Write-Warning '-------------------------------'
Write-Warning '-------------------------------'
Write-Warning '-------------------------------'

# Grab nuget bits, install modules, set build variables, start build.
Write-Warning 'Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null'
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

# PowerShellGet Work Around

# Write-Warning 'Install-Module PowerShellGet'
# Find-Module PowerShellGet | Install-Module -Force -SkipPublisherCheck
# Write-Warning 'Remove-Module PowerShellGet,PackageManagement'
# Remove-Module PowerShellGet,PackageManagement -Force
# Write-Warning 'Import-Module -Name PowerShellGet -Force'
# Import-Module -Name PowerShellGet -Force

$modulename = 'PowerShellGet'
$ModuleVersion = '1.6.5'

$file = 'https://www.powershellgallery.com/api/v2/package/{0}/{1}' -f $ModuleName,$ModuleVersion
$ModulePath = ('\{0}\{1}\' -f $ModuleName, $ModuleVersion)
$tempfilepath = ('{0}\PSGalleryFix{1}{2}.{3}.zip' -f $env:TEMP, $ModulePath, $ModuleName, $ModuleVersion)
$null = New-Item -Path $env:TEMP\PSGalleryFix\$ModulePath -ItemType Directory -Force
Invoke-WebRequest -Uri $file -UseBasicParsing -OutFile $tempfilepath
$ExpandPath = ('{0}\WindowsPowerShell\Modules{1}' -f $env:ProgramFiles, $ModulePath)
Expand-Archive -Path $tempfilepath -DestinationPath $ExpandPath -Force
Remove-Item -Path $tempfilepath

$modulename = 'PackageManagement'
$ModuleVersion = '1.1.7.2'

$file = 'https://www.powershellgallery.com/api/v2/package/{0}/{1}' -f $ModuleName,$ModuleVersion
$ModulePath = ('\{0}\{1}\' -f $ModuleName, $ModuleVersion)
$tempfilepath = ('{0}\PSGalleryFix{1}{2}.{3}.zip' -f $env:TEMP, $ModulePath, $ModuleName, $ModuleVersion)
$null = New-Item -Path $env:TEMP\PSGalleryFix\$ModulePath -ItemType Directory -Force
Invoke-WebRequest -Uri $file -UseBasicParsing -OutFile $tempfilepath
$ExpandPath = ('{0}\WindowsPowerShell\Modules{1}' -f $env:ProgramFiles, $ModulePath)
Expand-Archive -Path $tempfilepath -DestinationPath $ExpandPath -Force
Remove-Item -Path $tempfilepath

Remove-Module PowerShellGet,PackageManagement -Force
Import-Module -Name PowerShellGet -Force
Import-PackageProvider -Name PowerShellGet -Force -RequiredVersion 1.6.5

Write-Warning 'Get-Module'
Get-Module
Write-Warning '-------------------------------'
Write-Warning '-------------------------------'
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
