$projectRoot = Resolve-Path "$PSScriptRoot\.."
$moduleRoot = Split-Path (Resolve-Path "$projectRoot\*\*.psd1")
$moduleName = Split-Path $moduleRoot -Leaf

$ModuleManifestContent = Get-Content (Join-Path $moduleRoot "$moduleName.psd1")

Describe "Generic Module Tests" -Tag UnitTest {
    # Import Module
    Try {
        ## Unload the module so it's loaded fresh for testing
        Remove-Module $ModuleName -ErrorAction SilentlyContinue
        $ModuleInformation = Import-Module (Join-Path $moduleRoot "$moduleName.psd1") -Force -PassThru -ErrorAction Stop
        It "Module imported successfully" {
            $True | Should Be $True
        }
    }
    Catch {
        It "Module import encountered an error" {
            $True | Should Be $False
        }
    }

    # Evaluate AliasesToExport
    Context AliasesToExport {
        $AliasesToExportString = $ModuleManifestContent | Where-Object {$_ -match 'AliasesToExport'}
        $DeclaredAliases = $AliasesToExportString.Split(',') | 
            ForEach-Object{If ($_ -match '\w+-\w+'){$Matches[0]}}

        It "AliasesToExport should not be a wildcard" {
            $AliasesToExportString -match "\'\*\'" | Should Be $False
        }

        $ExportedAliases = $ModuleInformation.ExportedAliases.Values.Name
        ForEach ($Alias in $DeclaredAliases) {
            It "Alias Should Be Available $Alias " {
                $ExportedAliases -contains $Alias | Should Be $True
            }
        }
    }

    # Evaluate FunctionsToExport
    Context FunctionsToExport {
        $FunctionsToExportString = $ModuleManifestContent | Where-Object {$_ -match 'FunctionsToExport'}
        $DeclaredFunctions = $FunctionsToExportString.Split(',') | 
            ForEach-Object{If ($_ -match '\w+-\w+'){$Matches[0]}}

        It "FunctionsToExport should not be a wildcard" {
            $FunctionsToExportString -match "\'\*\'" | Should Be $False
        }

        $PublishedFunctions = $ModuleInformation.ExportedFunctions.Values.name
        ForEach ($PublicFunction in $DeclaredFunctions) {
            It "Function  Available: $PublicFunction " {
                $PublishedFunctions -contains $PublicFunction | Should Be $True
            }
        }
    }

    # Other Manifest Properties
    Context 'Other Manifest Properties' {
        It "Should contains RootModule"{
            $ModuleInformation.RootModule | Should not BeNullOrEmpty
        }
        It "Should contains Author"{
            $ModuleInformation.Author | Should not BeNullOrEmpty
        }
        It "Should contains Company Name"{
            $ModuleInformation.CompanyName | Should not BeNullOrEmpty
        }
        It "Should contains Description"{
            $ModuleInformation.Description | Should not BeNullOrEmpty
        }
        It "Should contains Copyright"{
            $ModuleInformation.Copyright | Should not BeNullOrEmpty
        }
        It "Should contains License"{
            $ModuleInformation.LicenseURI | Should not BeNullOrEmpty
        }
        It "Should contains a Project Link"{
            $ModuleInformation.ProjectURI | Should not BeNullOrEmpty
        }
        It "Should contains a Tags (For the PSGallery)"{
            $ModuleInformation.Tags.count | Should not BeNullOrEmpty
        }
    }
}