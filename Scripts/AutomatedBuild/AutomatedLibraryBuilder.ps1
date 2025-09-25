#
# AutomatedLibraryBuilder.ps1 - Automated PLC Library Build and Package Creation
#
# This script demonstrates a complete automation pipeline for TwinCAT PLC libraries:
# 1. Compile PLC projects and check for errors
# 2. Save error-free projects as libraries
# 3. Create TcPkg packages from the libraries
#

# --- Self-elevation block (preserve working directory) ---
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    $wd = (Get-Location).Path
    Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -WorkingDirectory $wd
    exit
}
# --- End self-elevation block ---

# Stop on any error
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "MessageFilter.ps1")
. (Join-Path $scriptDir "ErrorListHelper.ps1")

# =============================================================================
# CONFIGURATION
# =============================================================================

$config = @{
    SolutionPath = Join-Path $scriptDir "..\..\TwinCAT Project Library Creator\TwinCAT Project Library Creator.sln"
    PackageOutputDir = Join-Path $scriptDir "..\..\GeneratedPackages"
    CustomFeedName = "Custom Packages"
    Silent = $true
}

# Track results across the entire process
$buildResults = @{
    ProjectsProcessed = @()
    LibrariesCreated = @()
    PackagesCreated = @()
    ErrorProjects = @()
    WorkloadCreated = $false
    WorkloadInstalled = $false
}

# =============================================================================
# STEP 1: COMPILE AND CHECK PLC PROJECTS
# =============================================================================

function Invoke-CompileAndCheckProjects {
    Write-Host "=== STEP 1: Compiling and Checking PLC Projects ===" -ForegroundColor Cyan
    Write-Host ""

    AddMessageFilterClass
    [EnvDTEUtils.MessageFilter]::Register()

    # Initialize TwinCAT environment
    Write-Host "🔧 Initializing TwinCAT environment..." -ForegroundColor Blue
    $dte = New-Object -ComObject TcXaeShell.DTE.17.0

    # Configure for silent operation
    $dte.SuppressUI = $config.Silent
    $dte.MainWindow.Visible = !$config.Silent
    $automationSettings = $dte.GetObject("TcAutomationSettings")
    $automationSettings.SilentMode = $config.Silent

    # Open solution
    Write-Host "📂 Opening solution: $($config.SolutionPath)" -ForegroundColor Blue
    $sln = $dte.Solution
    $sln.Open($config.SolutionPath)

    # Save all projects to ensure they're in a consistent state
    Write-Host "💾 Saving all projects..." -ForegroundColor Blue
    try {
        if ($null -ne $sln.Projects) {
            for ($i = 1; $i -le $sln.Projects.Count; $i++) {
                $project = $sln.Projects.Item($i)
                # Skip virtual projects and folders (equivalent to vsProjectKindMisc)
                if ($project.Kind -ne "{66A26720-8FB5-11D2-AA7E-00C04F688DDE}") {
                    $project.Save()
                }
            }
        }
        $sln.SaveAs($sln.FullName)
        Write-Host "  ✅ All projects saved successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "  ⚠️  Warning: Could not save all projects: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Discover PLC projects
    Write-Host "🔍 Discovering PLC projects..." -ForegroundColor Blue
    $plcProjects = @()

    foreach ($proj in $sln.Projects) {
        $fileExt = [System.IO.Path]::GetExtension($proj.FileName)
        if ($fileExt -eq ".tspproj") {
            $plcProjects += $proj
            Write-Host "  ✓ Found PLC project: $($proj.Name)" -ForegroundColor Green
        }
    }

    # Process each PLC project
    foreach ($proj in $plcProjects) {
        Write-Host "🔨 Processing: $($proj.Name)" -ForegroundColor Yellow

        $projectResult = @{
            Name = $proj.Name
            HasErrors = $false
            ErrorCount = 0
            WarningCount = 0
            LibraryPath = ""
        }

        $sysManager = $proj.Object
        if ($sysManager) {
            $plcProjectPath = "$($proj.Name)^$($proj.Name) Project"
            $plcProject = $sysManager.LookupTreeItem($plcProjectPath)

            if ($plcProject) {
                # Clear existing errors and compile
                Clear-ErrorList -DTE $dte
                $plcProject.CheckAllObjects() | Out-Null

                # Check results
                $errorResults = Get-ErrorList -DTE $dte -ProjectName $proj.Name -IncludeWarnings $true
                $projectResult.ErrorCount = $errorResults.Errors.Count
                $projectResult.WarningCount = $errorResults.Warnings.Count
                $projectResult.HasErrors = ($errorResults.Errors.Count -gt 0)

                if ($projectResult.HasErrors) {
                    Write-Host "  ❌ Compilation failed: $($projectResult.ErrorCount) errors" -ForegroundColor Red
                    $buildResults.ErrorProjects += $projectResult
                } else {
                    Write-Host "  ✅ Compilation successful" -ForegroundColor Green
                    if ($projectResult.WarningCount -gt 0) {
                        Write-Host "  ⚠️  $($projectResult.WarningCount) warnings (proceeding)" -ForegroundColor Yellow
                    }

                    # Save library while VS is still open
                    $packageDir = Join-Path $scriptDir "..\..\PackageExamples\$($proj.Name)LibPackage"
                    $libraryPath = Join-Path $packageDir "$($proj.Name).library"
                    $projectResult.LibraryPath = $libraryPath

                    if (!(Test-Path $packageDir)) {
                        New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
                    }
                    if (Test-Path $libraryPath) {
                        Remove-Item $libraryPath -Force
                    }

                    try {
                        $plcProject.SaveAsLibrary($libraryPath, $false)
                        Write-Host "  💾 Library saved: $($proj.Name).library" -ForegroundColor Green
                        $buildResults.LibrariesCreated += $projectResult
                    }
                    catch {
                        Write-Host "  ❌ Failed to save library: $($_.Exception.Message)" -ForegroundColor Red
                        $buildResults.ErrorProjects += $projectResult
                    }
                }
            }
        }

        $buildResults.ProjectsProcessed += $projectResult
        Write-Host ""
    }

    # Clean up TwinCAT environment
    Write-Host "🔒 Closing TwinCAT XAE..." -ForegroundColor Blue
    $dte.Quit()
    [EnvDTEUtils.MessageFilter]::Revoke()
    Write-Host ""
}

# =============================================================================
# STEP 2: CREATE TCPKG PACKAGES
# =============================================================================

function New-TcPackages {
    Write-Host "=== STEP 2: Creating TcPkg Packages ===" -ForegroundColor Cyan
    Write-Host ""

    if ($buildResults.LibrariesCreated.Count -eq 0) {
        Write-Host "⚠️  No libraries were created - skipping package creation" -ForegroundColor Yellow
        return
    }

    # Ensure package output directory exists
    if (!(Test-Path $config.PackageOutputDir)) {
        New-Item -ItemType Directory -Path $config.PackageOutputDir -Force | Out-Null
        Write-Host "📁 Created package output directory: $($config.PackageOutputDir)" -ForegroundColor Gray
    }

    foreach ($library in $buildResults.LibrariesCreated) {
        Write-Host "📦 Creating package for: $($library.Name)" -ForegroundColor Yellow

        $packageDir = Join-Path $scriptDir "..\..\PackageExamples\$($library.Name)LibPackage"
        $nuspecFile = Join-Path $packageDir "$($library.Name)Lib.Package.nuspec"

        if (Test-Path $nuspecFile) {
            try {
                $tcpkgResult = & tcpkg pack $nuspecFile -o $config.PackageOutputDir 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✅ Package created successfully" -ForegroundColor Green
                    $buildResults.PackagesCreated += $library.Name
                } else {
                    Write-Host "  ❌ Package creation failed: $tcpkgResult" -ForegroundColor Red
                }
            }
            catch {
                Write-Host "  ❌ Error running tcpkg: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  ⚠️  Nuspec file not found: $($library.Name)Lib.Package.nuspec" -ForegroundColor Yellow
            Write-Host "  💡 Expected at: $nuspecFile" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

# =============================================================================
# STEP 3: CREATE WORKLOAD PACKAGE
# =============================================================================

function New-WorkloadPackage {
    Write-Host "=== STEP 3: Creating Workload Package ===" -ForegroundColor Cyan
    Write-Host ""

    if ($buildResults.PackagesCreated.Count -eq 0) {
        Write-Host "⚠️  No packages were created - skipping workload creation" -ForegroundColor Yellow
        return
    }

    Write-Host "🔗 Creating CustomPLCLibraries workload..." -ForegroundColor Yellow

    $workloadNuspecPath = Join-Path $scriptDir "..\..\WorkloadExample\CustomPLCLibrariesWorkload\CustomPLCLibraries.Workload.nuspec"

    if (Test-Path $workloadNuspecPath) {
        try {
            $tcpkgResult = & tcpkg pack $workloadNuspecPath -o $config.PackageOutputDir 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ Workload package created successfully" -ForegroundColor Green
                Write-Host "  📍 Location: $($config.PackageOutputDir)" -ForegroundColor Gray
                $buildResults.WorkloadCreated = $true
            } else {
                Write-Host "  ❌ Workload creation failed: $tcpkgResult" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "  ❌ Error creating workload: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ❌ Workload nuspec file not found: $workloadNuspecPath" -ForegroundColor Red
    }
    Write-Host ""
}

# =============================================================================
# STEP 4: SETUP TCPKG
# =============================================================================

function Initialize-TcPkg {
    Write-Host "=== STEP 4: Setting up TcPkg ===" -ForegroundColor Cyan
    Write-Host ""

    if ($buildResults.PackagesCreated.Count -eq 0) {
        Write-Host "⚠️  No packages were created - skipping tcpkg setup" -ForegroundColor Yellow
        return
    }

    # Setup custom package source
    Write-Host "🔧 Setting up custom package source..." -ForegroundColor Blue

    try {
        # Check if feed already exists
        $existingFeeds = & tcpkg source list 2>&1
        if ($existingFeeds -match [regex]::Escape($config.CustomFeedName)) {
            Write-Host "  ⚠️  Custom package feed '$($config.CustomFeedName)' already exists - skipping setup" -ForegroundColor Yellow
            Write-Host "  💡 Remove existing feed first if you need to reconfigure: tcpkg source remove -n '$($config.CustomFeedName)'" -ForegroundColor Gray
            return
        }

        # Add custom package source
        $addResult = & tcpkg source add -n $config.CustomFeedName -s $config.PackageOutputDir 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Added custom package feed: $($config.CustomFeedName)" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Failed to add package feed: $addResult" -ForegroundColor Red
            return
        }

        # Disable signature verification for custom packages
        $configResult = & tcpkg config unset -n VerifySignatures 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Disabled signature verification for custom packages" -ForegroundColor Green
        } elseif ($configResult -match "already disabled") {
            Write-Host "  ✅ Signature verification already disabled" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Signature verification config: $configResult" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ Error during tcpkg setup: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# =============================================================================
# STEP 5: INSTALL WORKLOAD
# =============================================================================

function Install-CustomWorkload {
    Write-Host "=== STEP 5: Installing Workload ===" -ForegroundColor Cyan
    Write-Host ""

    if (!$buildResults.WorkloadCreated) {
        Write-Host "⚠️  Workload was not created - skipping installation" -ForegroundColor Yellow
        return
    }

    # Install the workload
    Write-Host "📥 Installing CustomPLCLibraries workload..." -ForegroundColor Yellow
    try {
        $installResult = & tcpkg install CustomPLCLibraries.Workload -y 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Workload installed successfully!" -ForegroundColor Green
            $buildResults.WorkloadInstalled = $true

            # Verify installation
            Write-Host "🔍 Verifying workload installation..." -ForegroundColor Blue
            & tcpkg list -i -n $config.CustomFeedName -t workload | Out-Null
        } else {
            Write-Host "  ❌ Workload installation failed: $installResult" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ❌ Error during workload installation: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# =============================================================================
# STEP 6: SUMMARY REPORT
# =============================================================================

function Write-BuildSummary {
    Write-Host "=== STEP 6: Build Summary ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "📊 RESULTS SUMMARY" -ForegroundColor White
    Write-Host "─────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "Projects Processed: $($buildResults.ProjectsProcessed.Count)" -ForegroundColor White
    Write-Host "Libraries Created:  $($buildResults.LibrariesCreated.Count)" -ForegroundColor Green
    Write-Host "Packages Created:   $($buildResults.PackagesCreated.Count)" -ForegroundColor Green
    Write-Host "Workload Created:   $(if($buildResults.WorkloadCreated){'Yes'}else{'No'})" -ForegroundColor $(if($buildResults.WorkloadCreated){'Green'}else{'Red'})
    Write-Host "Workload Installed: $(if($buildResults.WorkloadInstalled){'Yes'}else{'No'})" -ForegroundColor $(if($buildResults.WorkloadInstalled){'Green'}else{'Red'})
    Write-Host "Failed Projects:    $($buildResults.ErrorProjects.Count)" -ForegroundColor Red
    Write-Host ""

    if ($buildResults.LibrariesCreated.Count -gt 0) {
        Write-Host "✅ SUCCESSFUL LIBRARIES:" -ForegroundColor Green
        foreach ($lib in $buildResults.LibrariesCreated) {
            Write-Host "  • $($lib.Name)" -ForegroundColor Green
            if ($lib.WarningCount -gt 0) {
                Write-Host "    ($($lib.WarningCount) warnings)" -ForegroundColor Yellow
            }
        }
        Write-Host ""
    }

    if ($buildResults.PackagesCreated.Count -gt 0) {
        Write-Host "📦 PACKAGES CREATED:" -ForegroundColor Green
        foreach ($pkg in $buildResults.PackagesCreated) {
            Write-Host "  • $pkg" -ForegroundColor Green
        }
        Write-Host "  📍 Location: $($config.PackageOutputDir)" -ForegroundColor Gray
        Write-Host ""
    }

    if ($buildResults.ErrorProjects.Count -gt 0) {
        Write-Host "❌ FAILED PROJECTS:" -ForegroundColor Red
        foreach ($failedProject in $buildResults.ErrorProjects) {
            Write-Host "  • $($failedProject.Name) ($($failedProject.ErrorCount) errors)" -ForegroundColor Red
        }
        Write-Host ""
    }

    Write-Host "🎯 NEXT STEPS:" -ForegroundColor Cyan
    if ($buildResults.WorkloadInstalled) {
        Write-Host "  🎉 All done! Your CustomPLCLibraries workload is installed and ready to use!" -ForegroundColor Green
        Write-Host "  1. Open TwinCAT XAE and create a new project" -ForegroundColor White
        Write-Host "  2. The custom libraries should be available in the library manager" -ForegroundColor White
        Write-Host "  3. Add library references as needed for your project" -ForegroundColor White
    } elseif ($buildResults.WorkloadCreated) {
        Write-Host "  1. Workload created but not installed - check installation errors above" -ForegroundColor White
        Write-Host "  2. Try manual installation: tcpkg install CustomPLCLibraries.Workload -y" -ForegroundColor White
    } elseif ($buildResults.PackagesCreated.Count -gt 0) {
        Write-Host "  1. Individual packages created successfully" -ForegroundColor White
        Write-Host "  2. Check workload nuspec file and try again" -ForegroundColor White
        Write-Host "  3. Review packages in: $($config.PackageOutputDir)" -ForegroundColor White
    } else {
        Write-Host "  1. Fix compilation errors in failed projects" -ForegroundColor White
        Write-Host "  2. Ensure .nuspec files exist for packaging" -ForegroundColor White
        Write-Host "  3. Re-run the build process" -ForegroundColor White
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Host "🚀 Starting Automated Library Build Process" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

try {
    Invoke-CompileAndCheckProjects
    New-TcPackages
    New-WorkloadPackage
    Initialize-TcPkg
    Install-CustomWorkload
    Write-BuildSummary

    Write-Host "🎉 Automated build process completed!" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
}
catch {
    Write-Host "💥 Build process failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Press Enter to exit..."
    Read-Host
    exit 1
}

Write-Host ""
Write-Host "Press Enter to exit..."
Read-Host
exit 0