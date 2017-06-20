# PSake makes variables declared here available in other scriptblocks
# Init some things
Properties {
    # Find the build folder based on build system
    $ProjectRoot = $ENV:BHProjectPath
    if (-not $ProjectRoot)
    {
        $ProjectRoot = $PSScriptRoot
    }

    $Timestamp = Get-date -uformat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
    $TestFile = "TestResults_PS$PSVersion`_$TimeStamp.xml"
    $lines = '----------------------------------------------------------------------'

    $Verbose = @{}
    if ( $ENV:BHCommitMessage -match "!verbose" )
    {
        $Verbose = @{Verbose = $True}
    }
}

Task Default -Depends Deploy

Task Init {
    $lines
    Set-Location $ProjectRoot
    "Build System Details:"
    Get-Item ENV:BH* | Format-List
    "`n"
}

Task UnitTests -Depends Init {
    $lines
    'Running quick unit tests to fail early if there is an error'
    $TestResults = Invoke-Pester -Path $ProjectRoot\Tests\*unit* -PassThru -Tag Build 
    
    if ( $TestResults.FailedCount -gt 0 )
    {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}

Task Test -Depends UnitTests {
    $lines
    "`n`tSTATUS: Testing with PowerShell $PSVersion"

    # Gather test results. Store them in a variable and file
    $TestResults = Invoke-Pester -Path $ProjectRoot\Tests -PassThru -OutputFormat NUnitXml -OutputFile "$ProjectRoot\$TestFile" -Tag Build

    # In Appveyor?  Upload our tests! #Abstract this into a function?
    If ( $ENV:BHBuildSystem -eq 'AppVeyor' )
    {
        [xml]$content = Get-Content "$ProjectRoot\$TestFile"
        $content.'test-results'.'test-suite'.type = "Powershell"
        $content.Save( "$ProjectRoot\$TestFile" )

        "Uploading $ProjectRoot\$TestFile to AppVeyor"
        "JobID: $env:APPVEYOR_JOB_ID"
        (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path "$ProjectRoot\$TestFile"))
    }

    Remove-Item "$ProjectRoot\$TestFile" -Force -ErrorAction SilentlyContinue

    # Failed tests?
    # Need to tell psake or it will proceed to the deployment. Danger!
    if ( $TestResults.FailedCount -gt 0 )
    {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}

Task Build -Depends Test {
    $lines

    $functions = Get-ChildItem "$env:BHModulePath\Public\*.ps1" | 
        Where-Object { $_.name -notmatch 'Tests'} |
        Select-Object -ExpandProperty basename      

    # Load the module, read the exported functions, update the psd1 FunctionsToExport
    Set-ModuleFunctions -Name $env:BHPSModuleManifest -FunctionsToExport $functions

    # Bump the module version
    $Script:Version = [version] (Step-Version (Get-Metadata -Path $env:BHPSModuleManifest))
    $galleryVersion = Get-NextPSGalleryVersion -Name $env:BHProjectName
    if ( $version -lt $galleryVersion )
    {
        $version = $galleryVersion
    }
    $version = [version]::New($version.Major, $version.Minor, $version.Build, $env:BHBuildNumber)
    Write-Host "Using version: $version"
    
    Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ModuleVersion -Value $Version
}

Task Deploy -Depends Build {
    $lines

    If ($ENV:APPVEYOR_PULL_REQUEST_NUMBER -gt 0) {
        Write-Warning -Message "Skipping version increment and publish for pull request #$env:APPVEYOR_PULL_REQUEST_NUMBER"
    }
    # GitHub & PSGallery Deployment
    ElseIf ($ENV:BHBuildSystem -ne 'Unknown' -and $ENV:BHBranchName -eq "master") {
        # Publish To GitHub
        Write-Host "EAP:  $ErrorActionPreference"
        $EAPSaved = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        Try {
            # Set up a path to the git.exe cmd, import posh-git to give us control over git, and then push changes to GitHub
            # Note that "update version" is included in the appveyor.yml file's "skip a build" regex to avoid a loop
            Write-Host "Log:  Set-Location $($ENV:BHProjectPath)"
            Set-Location $ENV:BHProjectPath
            Write-Host 'Log:  git checkout master'
            git checkout master
            Write-Host "Log:  git add $ENV:BHPSModuleManifest"
            git add $ENV:BHPSModuleManifest
            Write-Host 'Log:  git status'
            git status
            Write-Host "Log:  git commit -s -m "Update version to $Version""
            git commit -s -m "Update version to $Version"
            Write-Host 'Log:  git push origin master'
            git push origin master
            Write-Host "Log:  Module version $Version published to GitHub." -ForegroundColor Cyan
        }
        Catch {
            Write-Warning "Publishing update $Version to GitHub failed."
            Throw $_
        }
        $ErrorActionPreference = $EAPSaved
        Throw "Forced Stop"

        # Publish to PSGallery
        If ($ENV:BHCommitMessage -match '!deploy') {
            $Params = @{
                Path = $ProjectRoot
                Force = $true
            }

            # Searches for .PSDeploy.ps1 files in the current and nested paths, and invokes their deployment
            Invoke-PSDeploy @Verbose @Params
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