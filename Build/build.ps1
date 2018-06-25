<#
.Description
Installs and loads all the required modules for the build.
.Author
Warren F. (RamblingCookieMonster)
#>

[cmdletbinding()]
param ($Task = 'Default')

# Grab NuGet bits
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

# Update PowerShellGet & PackageManagement modules.  Required to update the modules without loading them first
# (update themselves) because PackageManagement will keep using the version first loaded.
$ManualModuleInstalls = @{
    'PowerShellGet' = '1.6.5'
    'PackageManagement' = '1.1.7.2'
}
$ManualModuleKeys = $ManualModuleInstalls.Keys

ForEach ($ManualModuleKey in $ManualModuleKeys) {

    $ModuleName = $ManualModuleKey
    $ModuleVersion = $ManualModuleInstalls[$ManualModuleKey]

    # If the current version is less than the specified version update it
    If (((Get-Module $ModuleName -ListAvailable)[0].Version) -lt $ModuleVersion) {
        $File         = 'https://www.powershellgallery.com/api/v2/package/{0}/{1}' -f $ModuleName, $ModuleVersion
        $ModulePath   = '\{0}\{1}\' -f $ModuleName, $ModuleVersion
        $TempFilePath = '{0}\PSGalleryFix{1}{2}.{3}.zip' -f $env:TEMP, $ModulePath, $ModuleName, $ModuleVersion
        $ExpandPath   = '{0}\WindowsPowerShell\Modules{1}' -f $env:ProgramFiles, $ModulePath

        $null = New-Item -Path $env:TEMP\PSGalleryFix\$ModulePath -ItemType Directory -Force
        Invoke-WebRequest -Uri $File -UseBasicParsing -OutFile $TempFilePath
        Expand-Archive -Path $TempFilePath -DestinationPath $ExpandPath -Force
        Remove-Item -Path $TempFilePath
    }
}

Remove-Module PowerShellGet,PackageManagement -Force
Import-Module -Name PowerShellGet -Force
Import-PackageProvider -Name PowerShellGet -Force -RequiredVersion $ManualModuleInstalls['PowerShellGet']

# Install build dependency modules
$Modules = @("Psake","PSDeploy","BuildHelpers","Pester","Posh-Git","PSScriptAnalyzer")

ForEach ($Module in $Modules) {
    If (-not (Get-Module -Name $Module -ListAvailable)) {
        Switch ($Module) {
            Pester              {Write-Warning "$Module, Pester";PowerShellGet\Install-Module $Module -Force -SkipPublisherCheck}
            Default             {Write-Warning "$Module, Default";PowerShellGet\Install-Module $Module -Force}
        }
    }

    Try {
        Write-Warning "Importing $Module"
        Import-Module $Module -Force -ErrorAction Stop
    }
    Catch {
        If ($Module -eq 'PSScriptAnalyzer') {
            Write-Warning 'Attempting PSScriptAnalyzer install a second time'
            Try {
                Get-Module $Module -ListAvailable
                Install-Module $Module -Force -ErrorAction Stop -SkipPublisherCheck
                Start-Sleep -Seconds 5
                Import-Module $Module -Force -ErrorAction Stop
            }
            Catch {
                $PSCmdlet.ThrowTerminatingError($PSItem)
            }
        }
        Write-Error $PSItem
        Write-Host "Starting hour long sleep"
        Start-Sleep -Seconds 3600
        Exit
    }
}

$Path = (Resolve-Path $PSScriptRoot\..).Path
Set-BuildEnvironment -Path $Path

Invoke-psake -buildFile $PSScriptRoot\psake.ps1 -taskList $Task -nologo
exit ([int](-not $psake.build_success))
