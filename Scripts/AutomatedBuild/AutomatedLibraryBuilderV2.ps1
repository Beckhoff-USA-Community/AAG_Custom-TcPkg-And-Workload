
# AutomatedLibraryBuilderV2.ps1 - Clean, Modular PLC Library Build Pipeline

# --- Helper function for conditional elevation ---
function Invoke-ElevatedCommand {
    param(
        [string]$Command,
        [string]$Arguments,
        [string]$Description
    )

    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($IsAdmin) {
        # Already running as admin, execute directly
        Write-Host "🔧 $Description" -ForegroundColor Blue
        $process = Start-Process -FilePath $Command -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
        return $process.ExitCode
    } else {
        # Need elevation for this specific command
        Write-Host "🔑 $Description (requesting elevation)" -ForegroundColor Yellow
        $process = Start-Process -FilePath $Command -ArgumentList $Arguments -Verb RunAs -Wait -PassThru -WindowStyle Hidden
        return $process.ExitCode
    }
}

# Stop on any error
$ErrorActionPreference = "Stop"

# Get script directory with robust path handling
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

# Load required Automation module
$automationModulePath = Join-Path $scriptDir "Automation.psm1"

if (-not (Test-Path $automationModulePath)) {
    Write-Host "❌ Required file not found: $automationModulePath" -ForegroundColor Red
    Write-Host "  Script directory: $scriptDir" -ForegroundColor Gray
    exit 1
}

Import-Module $automationModulePath -Force

# =============================================================================
# CONFIGURATION
# =============================================================================

$config = @{
    SolutionPath = Join-Path $scriptDir "..\..\TwinCAT Project Library Creator\TwinCAT Project Library Creator.sln"
    ExamplesDir = Join-Path $scriptDir "..\..\Examples"
    PackageOutputDir = Join-Path $scriptDir "..\..\GeneratedPackages"
    PackageTemplateDir = Join-Path $scriptDir "..\..\Templates\PackageTemplate"
    WorkloadTemplateDir = Join-Path $scriptDir "..\..\Templates\WorkloadTemplate"
    WorkloadPackageDir = Join-Path $scriptDir "..\..\Examples\CustomLibrariesWorkload"
    CustomFeedName = "Custom Packages"
    Silent = $false
}

# Track projects through the pipeline
$projects = @()

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Get-ProjectsByStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [switch]$NotEqual
    )

    if ($NotEqual) {
        $result = $script:projects | Where-Object { $_.Status -ne $Status }
    } else {
        $result = $script:projects | Where-Object { $_.Status -eq $Status }
    }

    # Force into an array using the comma operator
    return ,@($result)
}

# =============================================================================
# STEP 1: OPEN TWINCAT PROJECT
# =============================================================================

function Open-TwinCATProject {
    Write-Host "=== STEP 1: Opening TwinCAT Project ===" -ForegroundColor Cyan
    Write-Host ""

    try {
        # Initialize automation
        Initialize-Automation

        # Open TwinCAT solution
        $dte = Open-ExistingTcProject -SolutionPath $config.SolutionPath -SuppressUI $config.Silent -Silent $true
        if ($null -eq $dte) {
            throw "Failed to open TwinCAT project"
        }

        Write-Host "✅ TwinCAT project opened successfully" -ForegroundColor Green
        Write-Host "  📂 Solution: $($config.SolutionPath)" -ForegroundColor Gray
        Write-Host ""

        return $dte
    }
    catch {
        Write-Host "❌ Error opening TwinCAT project: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# =============================================================================
# STEP 2: GET LIST OF PLC PROJECTS
# =============================================================================

function Get-PlcProjectList {
    param(
        [Parameter(Mandatory = $true)]
        [System.__ComObject]$DTE
    )

    Write-Host "=== STEP 2: Discovering PLC Projects ===" -ForegroundColor Cyan
    Write-Host ""

    try {
        # Use the existing Get-PlcProjects function from Automation.psm1
        $plcProjects = Get-PlcProjects -DTE $DTE -Silent $true

        if ($plcProjects.Count -eq 0) {
            Write-Host "⚠️  No PLC projects found in solution" -ForegroundColor Yellow
            return @()
        }

        Write-Host "🔍 Discovering PLC projects..." -ForegroundColor Blue

        # Create project discovery results
        foreach ($proj in $plcProjects) {
            Write-Host "  ✓ Found PLC project: $($proj.Name)" -ForegroundColor Green
            $projectInfo = @{
                Name = $proj.Name
                FullPath = $proj.FileName
                ProjectObject = $proj
                Status = "Discovered"
                DiscoveredAt = Get-Date
            }
            $script:projects += $projectInfo
        }

        Write-Host "📊 Total PLC projects found: $($script:projects.Count)" -ForegroundColor Cyan
        Write-Host "✅ Project discovery completed" -ForegroundColor Green
        Write-Host ""

        return $script:projects
    }
    catch {
        Write-Host "❌ Error during project discovery: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# =============================================================================
# STEP 3: GET PLC PROJECT INFORMATION
# =============================================================================

function Get-PlcProjectInformation {
    param(
        [Parameter(Mandatory = $true)]
        [System.__ComObject]$DTE
    )

    Write-Host "=== STEP 3: Extracting PLC Project Information ===" -ForegroundColor Cyan
    Write-Host ""

    if ($script:projects.Count -eq 0) {
        Write-Host "⚠️  No projects to analyze" -ForegroundColor Yellow
        return
    }

    try {
        for ($i = 0; $i -lt $script:projects.Count; $i++) {
            $projectInfo = $script:projects[$i]
            Write-Host "📋 Analyzing: $($projectInfo.Name)" -ForegroundColor Yellow

            # Use the new Get-PlcProjectInfo function from Automation.psm1 (make it silent to avoid duplicate output)
            $projectDetails = Get-PlcProjectInfo -DTE $DTE -Project $projectInfo.ProjectObject -Silent $true

            # Update the existing project with XML information
            $script:projects[$i].Status = "Analyzed"
            $script:projects[$i].CompanyName = $projectDetails.CompanyName
            $script:projects[$i].Version = $projectDetails.Version
            $script:projects[$i].LibraryName = $projectDetails.LibraryName
            $script:projects[$i].Description = $projectDetails.Description
            $script:projects[$i].Author = $projectDetails.Author
            $script:projects[$i].PackageId = "$($script:projects[$i].Name)Lib.Package"
            $script:projects[$i].XmlParsed = $projectDetails.XmlParsed
            $script:projects[$i].AnalyzedAt = Get-Date

            # Show the extracted information
            if (!$config.Silent) {
                Write-Host "    Company: $($projectDetails.CompanyName)" -ForegroundColor Gray
                Write-Host "    Version: $($projectDetails.Version)" -ForegroundColor Gray
                Write-Host "    Library: $($projectDetails.LibraryName)" -ForegroundColor Gray
                if ($projectDetails.Description) {
                    Write-Host "    Description: $($projectDetails.Description)" -ForegroundColor Gray
                }
            }

            if (!$config.Silent) { Write-Host "" }
        }

        Write-Host "✅ Project information extraction completed" -ForegroundColor Green
        Write-Host "  📊 Projects analyzed: $($script:projects.Count)" -ForegroundColor Cyan
        Write-Host ""
    }
    catch {
        Write-Host "❌ Error during project information extraction: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# =============================================================================
# STEP 4: CHECK PLC PROJECTS
# =============================================================================

function Test-PlcProjects {
    param(
        [Parameter(Mandatory = $true)]
        [System.__ComObject]$DTE
    )

    Write-Host "=== STEP 4: Checking PLC Projects for Compilation Errors ===" -ForegroundColor Cyan
    Write-Host ""

    if ($script:projects.Count -eq 0) {
        Write-Host "⚠️  No projects to check" -ForegroundColor Yellow
        return
    }

    try {
        for ($i = 0; $i -lt $script:projects.Count; $i++) {
            $projectInfo = $script:projects[$i]
            Write-Host "🔨 Checking: $($projectInfo.Name)" -ForegroundColor Yellow

            # Use the existing Invoke-PlcProjectCheckAllObjects function (make it silent to avoid duplicate output)
            $checkResult = Invoke-PlcProjectCheckAllObjects -DTE $DTE -Project $projectInfo.ProjectObject -Silent $true

            # Update the existing project with compilation results
            $script:projects[$i].Status = $checkResult.Status
            $script:projects[$i].HasErrors = $checkResult.HasErrors
            $script:projects[$i].ErrorCount = $checkResult.ErrorCount
            $script:projects[$i].WarningCount = $checkResult.WarningCount
            $script:projects[$i].CheckedAt = Get-Date

            # Show the compilation result
            if (!$config.Silent) {
                if ($checkResult.Status -eq "Success") {
                    Write-Host "  ✅ Compilation successful" -ForegroundColor Green
                    if ($checkResult.WarningCount -gt 0) {
                        Write-Host "  ⚠️  $($checkResult.WarningCount) warnings (proceeding)" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  ❌ Compilation failed: $($checkResult.ErrorCount) errors" -ForegroundColor Red
                }
            }

            if (!$config.Silent) { Write-Host "" }
        }

        # Summary
        $successfulChecks = Get-ProjectsByStatus -Status "Success"
        $failedChecks = Get-ProjectsByStatus -Status "Success" -NotEqual

        Write-Host "✅ Project compilation check completed" -ForegroundColor Green
        Write-Host "  📊 Projects checked: $($script:projects.Count)" -ForegroundColor Cyan
        Write-Host "  ✅ Successful: $($successfulChecks.Count)" -ForegroundColor Green
        Write-Host "  ❌ Failed: $($failedChecks.Count)" -ForegroundColor Red
        Write-Host ""
    }
    catch {
        Write-Host "❌ Error during project checking: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# =============================================================================
# STEP 5: CREATE PACKAGE DIRECTORIES
# =============================================================================

function New-PackageDirectories {
    Write-Host "=== STEP 5: Creating Package Directories ===" -ForegroundColor Cyan
    Write-Host ""

    if ($script:projects.Count -eq 0) {
        Write-Host "⚠️  No projects to process" -ForegroundColor Yellow
        return
    }

    # Only process projects that compiled successfully
    $successfulProjects = Get-ProjectsByStatus -Status "Success"

    if ($successfulProjects.Count -eq 0) {
        Write-Host "⚠️  No successful projects to create packages for" -ForegroundColor Yellow
        return
    }

    try {
        foreach ($project in $successfulProjects) {
            Write-Host "📁 Creating package for: $($project.Name)" -ForegroundColor Yellow

            # Create package directory from template
            $packageDir = Join-Path $config.ExamplesDir "$($project.Name)LibPackage"

            # Remove existing package directory if it exists
            if (Test-Path $packageDir) {
                Remove-Item $packageDir -Recurse -Force | Out-Null
            }

            # Copy template directory to new package directory
            Copy-Item $config.PackageTemplateDir $packageDir -Recurse -Force | Out-Null
            Write-Host "    ✓ Package directory created: $packageDir" -ForegroundColor Green

            # Update .nuspec file
            $nuspecPath = Join-Path $packageDir "Template.Package.nuspec"
            $newNuspecPath = Join-Path $packageDir "$($project.PackageId).nuspec"

            $nuspecContent = Get-Content $nuspecPath -Raw
            # Use Author if available, otherwise fall back to CompanyName
            $authorsValue = if ($project.Author -and $project.Author.Trim() -ne "") { $project.Author } else { $project.CompanyName }

            # Ensure description is not empty (required by tcpkg)
            $descriptionValue = if ($project.Description -and $project.Description.Trim() -ne "") {
                $project.Description
            } else {
                "PLC library package for $($project.Name)"
            }

            $nuspecContent = $nuspecContent -replace "TEMPLATE_PACKAGE_ID", "$($project.PackageId)"
            $nuspecContent = $nuspecContent -replace "TEMPLATE_VERSION", $project.Version
            $nuspecContent = $nuspecContent -replace "TEMPLATE_TITLE", "$($project.Name)Lib Package"
            $nuspecContent = $nuspecContent -replace "TEMPLATE_AUTHORS", $authorsValue
            $nuspecContent = $nuspecContent -replace "TEMPLATE_COPYRIGHT", "(c) $($project.CompanyName)"
            $nuspecContent = $nuspecContent -replace "TEMPLATE_TAGS", "Beckhoff TwinCAT AllowMultipleVersions $($project.Name)"
            $nuspecContent = $nuspecContent -replace "TEMPLATE_DESCRIPTION", $descriptionValue
            $nuspecContent = $nuspecContent -replace "TEMPLATE_LIBRARY_FILE", "$($project.Name).library"

            $nuspecContent | Set-Content $newNuspecPath -Encoding UTF8
            Remove-Item $nuspecPath -Force | Out-Null
            Write-Host "    ✓ Updated .nuspec file" -ForegroundColor Green

            # Update chocolateyuninstall.ps1 with library details
            $uninstallPath = Join-Path $packageDir "tools\chocolateyuninstall.ps1"
            $uninstallContent = Get-Content $uninstallPath -Raw
            $libraryDetails = "$($project.LibraryName), $($project.Version) ($($project.CompanyName))"
            $uninstallContent = $uninstallContent -replace "TEMPLATE_LIBRARY_DETAILS", $libraryDetails
            $uninstallContent | Set-Content $uninstallPath -Encoding UTF8
            Write-Host "    ✓ Updated chocolateyuninstall.ps1" -ForegroundColor Green

            # Store package directory path for Step 6
            $projectIndex = $script:projects.IndexOf($project)
            $script:projects[$projectIndex].PackageDirectory = $packageDir

            Write-Host "  ✅ Package directory ready" -ForegroundColor Green
            Write-Host ""
        }

        Write-Host "✅ Package directory creation completed" -ForegroundColor Green
        Write-Host "  📦 Package directories created: $($successfulProjects.Count)" -ForegroundColor Cyan
        Write-Host ""
    }
    catch {
        Write-Host "❌ Error during package directory creation: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# =============================================================================
# STEP 6: SAVE LIBRARIES TO PACKAGE DIRECTORIES
# =============================================================================

function Save-LibrariesToPackages {
    param(
        [Parameter(Mandatory = $true)]
        [System.__ComObject]$DTE
    )

    Write-Host "=== STEP 6: Saving Libraries to Package Directories ===" -ForegroundColor Cyan
    Write-Host ""

    # Only process projects that compiled successfully and have package directories
    $successfulProjects = @($script:projects | Where-Object { $_.Status -eq "Success" -and $_.PackageDirectory })

    if ($successfulProjects.Count -eq 0) {
        Write-Host "⚠️  No projects ready for library saving" -ForegroundColor Yellow
        return
    }

    try {
        foreach ($project in $successfulProjects) {
            Write-Host "💾 Saving library for: $($project.Name)" -ForegroundColor Yellow

            # Save the project as a library
            $libraryResult = Save-PlcProjectAsLibrary -DTE $DTE -Project $project.ProjectObject -OutputDirectory $config.ExamplesDir -Silent $true

            if (-not $libraryResult.Success) {
                Write-Host "  ❌ Failed to save library: $($libraryResult.ErrorMessage)" -ForegroundColor Red
                $projectIndex = $script:projects.IndexOf($project)
                $script:projects[$projectIndex].Status = "Library Save Failed"
                continue
            }
            Write-Host "  ✅ Library saved successfully" -ForegroundColor Green
            Write-Host ""
        }

        Write-Host "✅ Library saving completed" -ForegroundColor Green
        Write-Host "  📚 Libraries saved: $($successfulProjects.Count)" -ForegroundColor Cyan
        Write-Host ""
    }
    catch {
        Write-Host "❌ Error during library saving: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# =============================================================================
# STEP 7: CLEANUP
# =============================================================================

function Close-TwinCATProject {
    param(
        [Parameter(Mandatory = $true)]
        [System.__ComObject]$DTE
    )

    Write-Host "=== STEP 7: Closing the TwinCAT Project ===" -ForegroundColor Cyan
    Write-Host ""

    try {
        # Close solution and DTE
        Close-Solution -DTE $DTE -SaveChanges $false -Silent $true | Out-Null
        Close-Automation

        Write-Host "✅ TwinCAT project closure completed" -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-Host "❌ Error during cleanup: $($_.Exception.Message)" -ForegroundColor Red
        # Continue even if cleanup fails
    }
}

# =============================================================================
# STEP 8: DETERMINE WORKLOAD VERSION
# =============================================================================

function Get-WorkloadVersion {
    Write-Host "=== STEP 8: Determining Workload Package Version ===" -ForegroundColor Cyan
    Write-Host ""

    # Check if all PLC library packages were created successfully
    $successfulProjects = Get-ProjectsByStatus -Status "Success"
    $projectsWithPackages = @($successfulProjects | Where-Object { $_.PackageDirectory })

    if ($projectsWithPackages.Count -eq 0) {
        Write-Host "⚠️  No library packages available for workload" -ForegroundColor Yellow
        return $null
    }

    if ($projectsWithPackages.Count -ne $successfulProjects.Count) {
        Write-Host "⚠️  Not all successful projects have packages" -ForegroundColor Yellow
        return $null
    }

    # Check for existing workload package and increment version
    $existingNuspecPath = Join-Path $config.WorkloadPackageDir "CustomLibraries.Workload.nuspec"
    $workloadVersion = "1.0.0"  # Default version if no existing package

    if (Test-Path $existingNuspecPath) {
        Write-Host "  📋 Found existing workload package, checking version..." -ForegroundColor Blue
        try {
            $existingContent = Get-Content $existingNuspecPath -Raw
            $versionMatch = [regex]::Match($existingContent, '<version>([^<]+)</version>')
            if ($versionMatch.Success) {
                $currentVersion = $versionMatch.Groups[1].Value
                Write-Host "    Current version: $currentVersion" -ForegroundColor Gray

                # Parse version and increment patch number (assuming semantic versioning)
                if ($currentVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
                    $major = [int]$matches[1]
                    $minor = [int]$matches[2]
                    $patch = [int]$matches[3] + 1
                    $workloadVersion = "$major.$minor.$patch"
                    Write-Host "    New version: $workloadVersion" -ForegroundColor Green
                } else {
                    Write-Host "    ⚠️  Could not parse version format, using default: $workloadVersion" -ForegroundColor Yellow
                }
            } else {
                Write-Host "    ⚠️  Could not find version in existing file, using default: $workloadVersion" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "    ⚠️  Error reading existing file, using default version: $workloadVersion" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  📋 No existing workload package found, using initial version: $workloadVersion" -ForegroundColor Blue
    }

    Write-Host "✅ Workload version determination completed" -ForegroundColor Green
    Write-Host "  📦 Next workload version: $workloadVersion" -ForegroundColor Cyan
    Write-Host ""

    # Return hashtable with version and projects info for Step 9
    return @{
        Version = $workloadVersion
        ProjectsWithPackages = $projectsWithPackages
    }
}

# =============================================================================
# STEP 9: CREATE WORKLOAD PACKAGE
# =============================================================================

function New-WorkloadPackage {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$WorkloadInfo
    )

    Write-Host "=== STEP 9: Creating Workload Package ===" -ForegroundColor Cyan
    Write-Host ""

    # Check if Step 8 provided workload info
    if (-not $WorkloadInfo -or -not $WorkloadInfo.Version -or -not $WorkloadInfo.ProjectsWithPackages) {
        Write-Host "⚠️  No workload information provided - skipping workload creation" -ForegroundColor Yellow
        return
    }

    # Use the data from Step 8
    $workloadVersion = $WorkloadInfo.Version
    $projectsWithPackages = $WorkloadInfo.ProjectsWithPackages

    try {
        Write-Host "📦 Creating workload package..." -ForegroundColor Yellow

        # Remove existing workload package directory if it exists
        if (Test-Path $config.WorkloadPackageDir) {
            Remove-Item $config.WorkloadPackageDir -Recurse -Force
        }

        # Copy workload template to new package directory
        Copy-Item $config.WorkloadTemplateDir $config.WorkloadPackageDir -Recurse -Force
        Write-Host "  ✓ Workload package directory created: $($config.WorkloadPackageDir)" -ForegroundColor Green

        # Update .nuspec file with workload-specific information
        Write-Host "  ✏️  Updating workload .nuspec file..." -ForegroundColor Blue

        $nuspecPath = Join-Path $config.WorkloadPackageDir "Template.Workload.nuspec"
        $newNuspecPath = Join-Path $config.WorkloadPackageDir "CustomLibraries.Workload.nuspec"

        $nuspecContent = Get-Content $nuspecPath -Raw

        # Get metadata from the first project (assuming all have same company)
        $workloadCompany = $projectsWithPackages[0].CompanyName

        # Define workload metadata
        $workloadId = "CustomLibraries.Workload"
        $workloadTitle = "Custom PLC Libraries Workload"
        $workloadDescription = "A workload package containing custom PLC libraries: $($projectsWithPackages.Name -join ', ')"
        $workloadAuthors = $workloadCompany
        $workloadCopyright = "(c) $workloadCompany"
        $workloadTags = "Beckhoff TwinCAT Workload CustomPLCLibraries CategoryCustom VariantPLC"

        # Update workload metadata using placeholder tokens
        $nuspecContent = $nuspecContent -replace "TEMPLATE_WORKLOAD_ID", $workloadId
        $nuspecContent = $nuspecContent -replace "TEMPLATE_VERSION", $workloadVersion
        $nuspecContent = $nuspecContent -replace "TEMPLATE_TITLE", $workloadTitle
        $nuspecContent = $nuspecContent -replace "TEMPLATE_AUTHORS", $workloadAuthors
        $nuspecContent = $nuspecContent -replace "TEMPLATE_DESCRIPTION", $workloadDescription
        $nuspecContent = $nuspecContent -replace "TEMPLATE_COPYRIGHT", $workloadCopyright
        $nuspecContent = $nuspecContent -replace "TEMPLATE_TAGS", $workloadTags

        # Build dependencies section with all library packages
        $dependenciesXml = ""
        foreach ($project in $projectsWithPackages) {
            $dependenciesXml += "      <dependency id=`"$($project.PackageId)`" version=`"$($project.Version)`" />`r`n"
        }
        # Remove the trailing newline for clean formatting
        $dependenciesXml = $dependenciesXml.TrimEnd("`r`n")

        # Replace the template dependencies placeholder with actual library dependencies
        $nuspecContent = $nuspecContent -replace "TEMPLATE_DEPENDENCIES", $dependenciesXml

        $nuspecContent | Set-Content $newNuspecPath -Encoding UTF8
        Remove-Item $nuspecPath -Force
        Write-Host "    ✓ Updated workload .nuspec file" -ForegroundColor Green

        Write-Host "  ✅ Workload package created successfully" -ForegroundColor Green
        Write-Host "    📦 Package: CustomLibraries.Workload" -ForegroundColor Cyan
        Write-Host "    📚 Includes $($projectsWithPackages.Count) library packages" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "✅ Workload package creation completed" -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-Host "❌ Error during workload package creation: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# =============================================================================
# STEP 10: PACK AND OUTPUT TO LOCAL REPOSITORY
# =============================================================================

function Invoke-PackageBuilding {
    Write-Host "=== STEP 10: Packing and Outputting to Local Repository ===" -ForegroundColor Cyan
    Write-Host ""

    # Create package output directory if it doesn't exist
    if (-not (Test-Path $config.PackageOutputDir)) {
        New-Item -ItemType Directory -Path $config.PackageOutputDir -Force | Out-Null
        Write-Host "  📁 Created package output directory: $($config.PackageOutputDir)" -ForegroundColor Green
    }

    $packagesCreated = @()
    $packingErrors = @()

    try {
        # Pack individual library packages
        $successfulProjects = Get-ProjectsByStatus -Status "Success"
        $projectsWithPackages = @($successfulProjects | Where-Object { $_.PackageDirectory })

        foreach ($project in $projectsWithPackages) {
            Write-Host "📦 Packing library package: $($project.Name)" -ForegroundColor Yellow

            $packageDir = $project.PackageDirectory
            $nuspecFile = Get-ChildItem -Path $packageDir -Filter "*.nuspec" | Select-Object -First 1

            if ($nuspecFile) {
                try {
                    $nuspecPath = $nuspecFile.FullName
                    Write-Host "  🔧 Running: tcpkg pack `"$nuspecPath`" -o `"$($config.PackageOutputDir)`"" -ForegroundColor Blue

                    $packResult = & tcpkg pack "$nuspecPath" -o "$($config.PackageOutputDir)" 2>&1 | Out-String

                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✅ Successfully packed: $($project.PackageId)" -ForegroundColor Green
                        $packagesCreated += $project.PackageId
                    } else {
                        Write-Host "  ❌ Failed to pack: $($project.PackageId)" -ForegroundColor Red
                        Write-Host "    Error: $packResult" -ForegroundColor Red
                        $packingErrors += "Library package $($project.PackageId): $packResult"
                    }
                } catch {
                    Write-Host "  ❌ Error packing $($project.PackageId): $($_.Exception.Message)" -ForegroundColor Red
                    $packingErrors += "Library package $($project.PackageId): $($_.Exception.Message)"
                }
            } else {
                Write-Host "  ❌ No .nuspec file found in: $packageDir" -ForegroundColor Red
                $packingErrors += "Library package $($project.PackageId): No .nuspec file found"
            }

            Write-Host ""
        }

        # Pack workload package if it exists
        if (Test-Path $config.WorkloadPackageDir) {
            Write-Host "📦 Packing workload package..." -ForegroundColor Yellow

            $workloadNuspecFile = Get-ChildItem -Path $config.WorkloadPackageDir -Filter "*.nuspec" | Select-Object -First 1

            if ($workloadNuspecFile) {
                try {
                    $workloadNuspecPath = $workloadNuspecFile.FullName
                    Write-Host "  🔧 Running: tcpkg pack `"$workloadNuspecPath`" -o `"$($config.PackageOutputDir)`"" -ForegroundColor Blue

                    $packResult = & tcpkg pack "$workloadNuspecPath" -o "$($config.PackageOutputDir)" 2>&1 | Out-String

                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✅ Successfully packed: CustomLibraries.Workload" -ForegroundColor Green
                        $packagesCreated += "CustomLibraries.Workload"
                    } else {
                        Write-Host "  ❌ Failed to pack workload package" -ForegroundColor Red
                        Write-Host "    Error: $packResult" -ForegroundColor Red
                        $packingErrors += "Workload package: $packResult"
                    }
                } catch {
                    Write-Host "  ❌ Error packing workload package: $($_.Exception.Message)" -ForegroundColor Red
                    $packingErrors += "Workload package: $($_.Exception.Message)"
                }
            } else {
                Write-Host "  ❌ No .nuspec file found in workload directory" -ForegroundColor Red
                $packingErrors += "Workload package: No .nuspec file found"
            }
        } else {
            Write-Host "  ℹ️  No workload package found to pack" -ForegroundColor Gray
        }

        # Summary
        Write-Host ""
        Write-Host "✅ Package building completed" -ForegroundColor Green
        Write-Host "  📦 Packages created: $($packagesCreated.Count)" -ForegroundColor Cyan
        Write-Host "  📁 Package output directory: $($config.PackageOutputDir)" -ForegroundColor Cyan

        if ($packagesCreated.Count -gt 0) {
            Write-Host "  🎯 Successfully packed packages:" -ForegroundColor Green
            foreach ($package in $packagesCreated) {
                Write-Host "    - $package" -ForegroundColor Green
            }
        }

        if ($packingErrors.Count -gt 0) {
            Write-Host "  ⚠️  Packing errors occurred:" -ForegroundColor Yellow
            foreach ($packingError in $packingErrors) {
                Write-Host "    - $packingError" -ForegroundColor Yellow
            }
        }

        Write-Host ""
    }
    catch {
        Write-Host "❌ Error during package building: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# =============================================================================
# STEP 11: ADD CUSTOM PACKAGE FEED
# =============================================================================

function Add-CustomPackageFeed {
    Write-Host "=== STEP 11: Adding Custom Package Feed ===" -ForegroundColor Cyan
    Write-Host ""

    try {
        # Ensure the package output directory exists
        if (-not (Test-Path $config.PackageOutputDir)) {
            Write-Host "⚠️  Package output directory not found: $($config.PackageOutputDir)" -ForegroundColor Yellow
            Write-Host "  📁 Creating package output directory..." -ForegroundColor Blue
            New-Item -ItemType Directory -Path $config.PackageOutputDir -Force | Out-Null
            Write-Host "    ✓ Package output directory created" -ForegroundColor Green
        }

        Write-Host "🔍 Checking if custom package feed already exists..." -ForegroundColor Blue
        Write-Host "  🔧 Running: tcpkg source list" -ForegroundColor Blue

        # Check if the feed already exists
        $sourceListResult = & tcpkg source list 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ❌ Failed to list package sources" -ForegroundColor Red
            Write-Host "    Error: $sourceListResult" -ForegroundColor Red
            throw "Failed to execute tcpkg source list"
        }

        $feedExists = $sourceListResult | Select-String $config.CustomFeedName -Quiet

        if ($feedExists) {
            Write-Host "  ✅ Custom package feed '$($config.CustomFeedName)' already exists" -ForegroundColor Green
        } else {
            Write-Host "  📦 Adding custom package feed..." -ForegroundColor Yellow
            Write-Host "    Name: $($config.CustomFeedName)" -ForegroundColor Gray
            Write-Host "    Source: $($config.PackageOutputDir)" -ForegroundColor Gray

            $addFeedExitCode = Invoke-ElevatedCommand -Command "tcpkg" -Arguments "source add -n `"$($config.CustomFeedName)`" -s `"$($config.PackageOutputDir)`"" -Description "Adding custom package feed"

            if ($addFeedExitCode -eq 0) {
                Write-Host "  ✅ Successfully added custom package feed: $($config.CustomFeedName)" -ForegroundColor Green
            } else {
                Write-Host "  ❌ Failed to add custom package feed" -ForegroundColor Red
                throw "Failed to add custom package feed (exit code: $addFeedExitCode)"
            }
        }

        # Verify the feed was added successfully
        Write-Host "  🔍 Verifying package feed..." -ForegroundColor Blue
        $verifyResult = & tcpkg source list 2>&1
        if ($verifyResult | Select-String $config.CustomFeedName -Quiet) {
            Write-Host "    ✓ Package feed verified successfully" -ForegroundColor Green
        } else {
            Write-Host "    ⚠️  Package feed verification failed" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "✅ Custom package feed management completed" -ForegroundColor Green
        Write-Host "  📦 Feed name: $($config.CustomFeedName)" -ForegroundColor Cyan
        Write-Host "  📁 Feed location: $($config.PackageOutputDir)" -ForegroundColor Cyan
        Write-Host ""
    }
    catch {
        Write-Host "❌ Error during custom package feed management: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# =============================================================================
# STEP 12: DISABLE SIGNATURE VERIFICATION
# =============================================================================

function Disable-SignatureVerification {
    Write-Host "=== STEP 12: Disabling Signature Verification ===" -ForegroundColor Cyan
    Write-Host ""

    try {
        Write-Host "🔓 Disabling signature verification for custom packages..." -ForegroundColor Yellow
        Write-Host "  ℹ️  This allows installation of unsigned custom packages" -ForegroundColor Gray

        $exitCode = Invoke-ElevatedCommand -Command "tcpkg" -Arguments "config unset -n VerifySignatures" -Description "Disabling signature verification"

        if ($exitCode -eq 0) {
            Write-Host "  ✅ Successfully disabled signature verification" -ForegroundColor Green
        } else {
            # Check if it's already disabled by running tcpkg config list
            $listExitCode = Invoke-ElevatedCommand -Command "tcpkg" -Arguments "config list" -Description "Checking current configuration"
            if ($listExitCode -eq 0) {
                Write-Host "  ✅ Signature verification configuration updated" -ForegroundColor Green
            } else {
                throw "Failed to disable signature verification (exit code: $exitCode)"
            }
        }

        # Verify the configuration was changed
        Write-Host "  🔍 Verifying signature verification setting..." -ForegroundColor Blue
        $verifyExitCode = Invoke-ElevatedCommand -Command "tcpkg" -Arguments "config list" -Description "Verifying configuration changes"

        if ($verifyExitCode -eq 0) {
            Write-Host "    ✓ Configuration verified successfully" -ForegroundColor Green
        } else {
            Write-Host "    ⚠️  Could not verify configuration change" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "✅ Signature verification management completed" -ForegroundColor Green
        Write-Host "  🔓 Custom packages can now be installed without signature verification" -ForegroundColor Cyan
        Write-Host ""
    }
    catch {
        Write-Host "❌ Error during signature verification management: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# =============================================================================
# STEP 13: INSTALL WORKLOAD PACKAGE
# =============================================================================

function Install-WorkloadPackage {
    Write-Host "=== STEP 13: Installing Workload Package ===" -ForegroundColor Cyan
    Write-Host ""

    $workloadPackageName = "CustomLibraries.Workload"

    try {
        Write-Host "📦 Installing CustomLibraries Workload..." -ForegroundColor Yellow

        $installExitCode = Invoke-ElevatedCommand -Command "tcpkg" -Arguments "install $workloadPackageName -y" -Description "Installing workload package"

        if ($installExitCode -eq 0) {
            Write-Host "  ✅ Workload installation completed" -ForegroundColor Green
        } else {
            throw "Failed to install workload package (exit code: $installExitCode)"
        }

        Write-Host ""
        Write-Host "🔍 Verifying workload installation..." -ForegroundColor Blue

        $verifyExitCode = Invoke-ElevatedCommand -Command "tcpkg" -Arguments "list -i -n `"$($config.CustomFeedName)`" -t workload" -Description "Verifying workload installation"

        if ($verifyExitCode -eq 0) {
            Write-Host "  ✅ Workload successfully installed and verified" -ForegroundColor Green
            Write-Host "    📦 Package: $workloadPackageName" -ForegroundColor Cyan
            Write-Host "    📁 Source: $($config.CustomFeedName)" -ForegroundColor Cyan
        } else {
            Write-Host "  ⚠️  Workload installation could not be verified" -ForegroundColor Yellow
            Write-Host "    The workload may have been installed but verification failed (exit code: $verifyExitCode)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "✅ Workload installation and verification completed" -ForegroundColor Green
        Write-Host "  🎯 The CustomLibraries workload and all its component libraries are now available in TwinCAT" -ForegroundColor Cyan
        Write-Host ""
    }
    catch {
        Write-Host "❌ Error during workload installation: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

function Main {
    Write-Host "🚀 Starting PLC Project Analysis Pipeline (V2)" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host ""

    try {
        # STEP 1: Open TwinCAT project
        $dte = Open-TwinCATProject
        if ($null -eq $dte) {
            Write-Host "❌ Failed to open TwinCAT project - stopping pipeline" -ForegroundColor Red
            return
        }

        # STEP 2: Get list of PLC projects
        Get-PlcProjectList -DTE $dte | Out-Null
        if ($script:projects.Count -eq 0) {
            Write-Host "❌ No PLC projects found - stopping pipeline" -ForegroundColor Red
            Close-TwinCATProject -DTE $dte
            return
        }

        # STEP 3: Get PLC project information from XML
        try {
            Get-PlcProjectInformation -DTE $dte
        }
        catch {
            Write-Host "❌ Step 3 failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "🛑 Stopping pipeline" -ForegroundColor Yellow
            Close-TwinCATProject -DTE $dte
            return
        }

        # STEP 4: Check PLC projects for compilation errors
        try {
            Test-PlcProjects -DTE $dte
        }
        catch {
            Write-Host "❌ Step 4 failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "🛑 Stopping pipeline" -ForegroundColor Yellow
            Close-TwinCATProject -DTE $dte
            return
        }

        # STEP 5: Create Package Directories
        try {
            New-PackageDirectories
        }
        catch {
            Write-Host "❌ Step 5 failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "🛑 Stopping pipeline" -ForegroundColor Yellow
            Close-TwinCATProject -DTE $dte
            return
        }

        # STEP 6: Save Libraries to Package Directories
        try {
            Save-LibrariesToPackages -DTE $dte
        }
        catch {
            Write-Host "❌ Step 6 failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "🛑 Stopping pipeline" -ForegroundColor Yellow
            Close-TwinCATProject -DTE $dte
            return
        }

        # STEP 7: Close TwinCAT Project
        try {
            Close-TwinCATProject -DTE $dte
        }
        catch {
            Write-Host "❌ Step 7 failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "🛑 Stopping pipeline" -ForegroundColor Yellow
            return
        }

        # STEP 8: Determine Workload Version
        $workloadInfo = $null
        try {
            $workloadInfo = Get-WorkloadVersion
        }
        catch {
            Write-Host "❌ Step 8 failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "🛑 Stopping pipeline" -ForegroundColor Yellow
            return
        }

        # STEP 9: Create Workload Package
        if ($workloadInfo) {
            try {
                New-WorkloadPackage -WorkloadInfo $workloadInfo
            }
            catch {
                Write-Host "❌ Step 9 failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "🛑 Stopping pipeline" -ForegroundColor Yellow
                return
            }
        }
        else {
            Write-Host "⚠️  Skipping Step 9 - No workload info from Step 8" -ForegroundColor Yellow
        }

        # STEP 10: Pack and Output to Local Repository
        try {
            Invoke-PackageBuilding
        }
        catch {
            Write-Host "❌ Step 10 failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "🛑 Stopping pipeline" -ForegroundColor Yellow
            return
        }

        # STEP 11: Add Custom Package Feed
        try {
            Add-CustomPackageFeed
        }
        catch {
            Write-Host "❌ Step 11 failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "🛑 Stopping pipeline" -ForegroundColor Yellow
            return
        }

        # STEP 12: Disable Signature Verification
        try {
            Disable-SignatureVerification
        }
        catch {
            Write-Host "❌ Step 12 failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "🛑 Stopping pipeline" -ForegroundColor Yellow
            return
        }

        # STEP 13: Install Workload Package
        try {
            Install-WorkloadPackage
        }
        catch {
            Write-Host "❌ Step 13 failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "🛑 Stopping pipeline" -ForegroundColor Yellow
            return
        }

        Write-Host "🎉 Pipeline completed successfully!" -ForegroundColor Green
        Read-Host "Press Enter to exit..."
    }
    catch {
        Write-Host "💥 Pipeline execution failed: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        # Ensure cleanup
        try {
            if ($dte) {
                Close-TwinCATProject -DTE $dte
            }
        }
        catch {
            # Silent cleanup failure
            Read-Host "Press Enter to exit..."
        }
        

        exit 1
    }
}


# Run the main function
Main