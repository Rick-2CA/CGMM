# PSake makes variables declared here available in other scriptblocks
# Init some things
Properties {
    # Find the build folder based on build system
    $ProjectRoot = $ENV:BHProjectPath
    If (-not $ProjectRoot)
    {
        $ProjectRoot = $PSScriptRoot
    }

    $Timestamp = Get-date -uformat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
    $TestFile = "TestResults_PS$PSVersion`_$TimeStamp.xml"
    $Lines = '----------------------------------------------------------------------'

    $Verbose = @{}
    If ( $ENV:BHCommitMessage -match "!verbose" )
    {
        $Verbose = @{Verbose = $True}
    }
}

Task Default -Depends Deploy

Task Init {
    $Lines
    Set-Location $ProjectRoot
    "Build System Details:"
    Get-Item ENV:BH* | Format-List
    "`n"
}

Task UnitTests -Depends Init {
    $Lines
    'Running quick unit tests to fail early if there is an error'
    $TestResults = Invoke-Pester -Path $ProjectRoot\Tests\*unit* -PassThru -Tag UnitTest
    
    If ($TestResults.FailedCount -gt 0) {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}

Task Test -Depends UnitTests {
    $Lines
    "`n`tSTATUS: Testing with PowerShell $PSVersion"

    # Gather test results. Store them in a variable and file
    $TestResults = Invoke-Pester -Path $ProjectRoot\Tests -PassThru -OutputFormat NUnitXml -OutputFile "$ProjectRoot\$TestFile" -Tag Test

    # In Appveyor?  Upload our tests! #Abstract this into a function?
    If ( $ENV:BHBuildSystem -eq 'AppVeyor' ) {
        [XML]$Content = Get-Content "$ProjectRoot\$TestFile"
        $Content.'test-results'.'test-suite'.type = "Powershell"
        $Content.Save( "$ProjectRoot\$TestFile" )

        "Uploading $ProjectRoot\$TestFile to AppVeyor"
        "JobID: $env:APPVEYOR_JOB_ID"
        (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path "$ProjectRoot\$TestFile"))
    }

    Remove-Item "$ProjectRoot\$TestFile" -Force -ErrorAction SilentlyContinue

    # Failed tests?
    # Need to tell psake or it will proceed to the deployment. Danger!
    If ($TestResults.FailedCount -gt 0) {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}

Task Build -Depends Test {
    $Lines

    $Functions = Get-ChildItem "$env:BHModulePath\Public\*.ps1" | 
        Where-Object { $_.name -notmatch 'Tests'} |
        Select-Object -ExpandProperty basename      

    # Load the module, read the exported functions, update the psd1 FunctionsToExport
    Set-ModuleFunctions -Name $env:BHPSModuleManifest -FunctionsToExport $functions

    # Bump the module version
    ## Get the module version from both the module manifest and the PS Gallery (if it exists)
    $ManifestVersion = [version](Get-Metadata -Path $env:BHPSModuleManifest)
    $GalleryVersion = [version](Get-NextPSGalleryVersion -Name $env:BHProjectName)
    ## If the manifest version is lower than the gallery use the gallery version
    If ($ManifestVersion -lt $GalleryVersion) {
        $Script:Version = $GalleryVersion
    }
    Else {
        $Script:Version = $ManifestVersion
    }
    ## If deploying use Step-Version to increment the 'build' number
    If ($ENV:BHCommitMessage -match '!deploy') {
        $Script:Version = [version](Step-Version ($ManifestVersion))
    }
    ## Always increment the 'revision' number with BHBuildNumber
    $Script:Version = [version]::New($Version.Major, $Version.Minor, $Version.Build, $env:BHBuildNumber)
    Write-Host "Using version: $Version"
        
    Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ModuleVersion -Value $Version
}

Task Deploy -Depends Build {
    $Lines

    If ($ENV:APPVEYOR_PULL_REQUEST_NUMBER -gt 0) {
        Write-Warning -Message "Skipping version increment and publish for pull request #$env:APPVEYOR_PULL_REQUEST_NUMBER"
    }
    # GitHub & PSGallery Deployment
    ElseIf ($ENV:BHBuildSystem -ne 'Unknown' -and $ENV:BHBranchName -eq "master") {
        # Publish To GitHub
        $EAPSaved = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        Try {
            # Set up a path to the git.exe cmd, import posh-git to give us control over git, and then push changes to GitHub
            # Note that "update version" is included in the appveyor.yml file's "skip a build" regex to avoid a loop
            Write-Host "Log:  Location $(Get-Location)"
            Write-Host 'Log:  git checkout master'
            git checkout master
            Write-Host "Log:  git add all"
            git add --all
            Write-Host 'Log:  git status'
            git status
            Write-Host "Log:  git commit -s -m "Update version to $Version""
            git commit -s -m "Update version to $Version"
            Write-Host 'Log:  git push origin master'
            git push origin master
            Write-Host "Module version $Version published to GitHub." -ForegroundColor Cyan
        }
        Catch {
            Write-Warning "Publishing update $Version to GitHub failed."
            Throw $_
        }
        $ErrorActionPreference = $EAPSaved

        # Publish to PSGallery
        If ($ENV:BHCommitMessage -match '!deploy') {
            $Params = @{
                Path = $ProjectRoot
                Force = $True
                Verbose = $True
            }

            # Searches for .PSDeploy.ps1 files in the current and nested paths, and invokes their deployment
            Write-Host "Invoking PSDeploy" -ForegroundColor Cyan
            Invoke-PSDeploy @Params
        }
        Else {
            "Skipping PS Gallery deployment: To deploy, ensure that...`n" + 
            "`t* You are in a known build system (Current: $ENV:BHBuildSystem)`n" + 
            "`t* You are committing to the master branch (Current: $ENV:BHBranchName) `n" + 
            "`t* Your commit message includes !deploy (Current: $ENV:BHCommitMessage)"
        }
    }
    Else
    {
        "Skipping GitHub & PSGallery deployment: To deploy, ensure that...`n" + 
        "`t* You are in a known build system (Current: $ENV:BHBuildSystem)`n" + 
        "`t* You are committing to the master branch (Current: $ENV:BHBranchName) `n" + 
        "`t* Your commit message includes !deploy (Current: $ENV:BHCommitMessage)"
    }
}