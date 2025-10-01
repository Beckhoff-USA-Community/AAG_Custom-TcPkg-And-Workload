# --- Self-elevation block (preserve working directory) ---
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    $wd = (Get-Location).Path
    Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -WorkingDirectory $wd
    exit
}
# --- End self-elevation block ---

$ErrorActionPreference = "Stop"

Write-Host "🧹 AutomatedLibraryBuilderV2 Cleanup Script" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Configuration - must match AutomatedLibraryBuilderV2.ps1
$config = @{
    ExamplesDir = Join-Path $scriptDir "..\..\Examples"
    PackageOutputDir = Join-Path $scriptDir "..\..\GeneratedPackages"
    WorkloadPackageDir = Join-Path $scriptDir "..\..\Examples\CustomLibrariesWorkload"
    CustomFeedName = "Custom Packages"
}

$WorkloadName = "CustomLibraries.Workload"

# =============================================================================
# STEP 1: UNINSTALL WORKLOAD AND DEPENDENCIES
# =============================================================================

Write-Host "=== STEP 1: Uninstalling Workload ===" -ForegroundColor Cyan
try {
    Write-Host "📤 Uninstalling $WorkloadName and all dependencies..." -ForegroundColor Yellow
    $uninstallResult = & tcpkg uninstall $WorkloadName --include-dependencies -y 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Workload uninstalled successfully" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Uninstall completed with warnings" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ⚠️  Error during uninstall (may not exist): $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host ""

# =============================================================================
# STEP 2: REMOVE CUSTOM PACKAGE FEED
# =============================================================================

Write-Host "=== STEP 2: Removing Custom Package Feed ===" -ForegroundColor Cyan
try {
    Write-Host "🗑️  Removing package feed: $($config.CustomFeedName)" -ForegroundColor Yellow
    & tcpkg source remove $config.CustomFeedName 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Package feed removed successfully" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Feed removal completed with warnings" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ⚠️  Error removing feed (may not exist): $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host ""

# =============================================================================
# STEP 3: RE-ENABLE SIGNATURE VERIFICATION
# =============================================================================

Write-Host "=== STEP 3: Re-enabling Signature Verification ===" -ForegroundColor Cyan
try {
    Write-Host "🔒 Re-enabling signature verification..." -ForegroundColor Yellow
    & tcpkg config set -n VerifySignatures 2>&1 | Out-Null
    Write-Host "  ✅ Signature verification re-enabled" -ForegroundColor Green
}
catch {
    Write-Host "  ⚠️  Error re-enabling signature verification: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host ""

# =============================================================================
# STEP 4: CLEAN UP PACKAGE OUTPUT DIRECTORY
# =============================================================================

Write-Host "=== STEP 4: Cleaning Package Output Directory ===" -ForegroundColor Cyan
if (Test-Path $config.PackageOutputDir) {
    $packageFiles = Get-ChildItem -Path $config.PackageOutputDir -Filter "*.nupkg" -ErrorAction SilentlyContinue
    if ($packageFiles.Count -gt 0) {
        Write-Host "  📦 Found $($packageFiles.Count) package file(s)" -ForegroundColor Gray
        try {
            Remove-Item -Path "$($config.PackageOutputDir)\*.nupkg" -Force
            Write-Host "  ✅ Package files deleted" -ForegroundColor Green
        }
        catch {
            Write-Host "  ❌ Error deleting package files: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ℹ️  No package files found" -ForegroundColor Gray
    }

    # Remove directory if empty
    $remainingFiles = Get-ChildItem -Path $config.PackageOutputDir -ErrorAction SilentlyContinue
    if ($remainingFiles.Count -eq 0) {
        Remove-Item -Path $config.PackageOutputDir -Force
        Write-Host "  ✅ Empty directory removed" -ForegroundColor Green
    }
} else {
    Write-Host "  ℹ️  Package output directory does not exist" -ForegroundColor Gray
}
Write-Host ""

# =============================================================================
# STEP 5: CLEAN UP GENERATED PACKAGE FOLDERS IN EXAMPLES
# =============================================================================

Write-Host "=== STEP 5: Cleaning Generated Package Folders ===" -ForegroundColor Cyan
if (Test-Path $config.ExamplesDir) {
    # Find all package directories created by AutomatedLibraryBuilderV2
    $generatedPackages = Get-ChildItem -Path $config.ExamplesDir -Directory -Filter "*LibPackage" -ErrorAction SilentlyContinue

    if ($generatedPackages.Count -gt 0) {
        Write-Host "  📁 Found $($generatedPackages.Count) generated package folder(s):" -ForegroundColor Gray
        foreach ($pkg in $generatedPackages) {
            Write-Host "    • $($pkg.Name)" -ForegroundColor Gray
        }

        $response = Read-Host "  Delete these generated package folders? (y/N)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            try {
                foreach ($pkg in $generatedPackages) {
                    Remove-Item -Path $pkg.FullName -Recurse -Force
                    Write-Host "    ✅ Deleted: $($pkg.Name)" -ForegroundColor Green
                }
            }
            catch {
                Write-Host "    ❌ Error deleting package folders: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  ⏭️  Package folders preserved" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ℹ️  No generated package folders found" -ForegroundColor Gray
    }
} else {
    Write-Host "  ℹ️  Examples directory does not exist" -ForegroundColor Gray
}
Write-Host ""

# =============================================================================
# STEP 6: CLEAN UP GENERATED WORKLOAD FOLDER
# =============================================================================

Write-Host "=== STEP 6: Cleaning Generated Workload Folder ===" -ForegroundColor Cyan
if (Test-Path $config.WorkloadPackageDir) {
    Write-Host "  📁 Found workload folder: $(Split-Path -Leaf $config.WorkloadPackageDir)" -ForegroundColor Gray
    $response = Read-Host "  Delete generated workload folder? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        try {
            Remove-Item -Path $config.WorkloadPackageDir -Recurse -Force
            Write-Host "  ✅ Workload folder deleted" -ForegroundColor Green
        }
        catch {
            Write-Host "  ❌ Error deleting workload folder: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ⏭️  Workload folder preserved" -ForegroundColor Gray
    }
} else {
    Write-Host "  ℹ️  Workload folder does not exist" -ForegroundColor Gray
}
Write-Host ""

# =============================================================================
# VERIFICATION
# =============================================================================

Write-Host "=== Verification ===" -ForegroundColor Cyan
try {
    $installedWorkloads = & tcpkg list -i -t workload 2>&1
    if ($installedWorkloads -match "CustomLibraries") {
        Write-Host "  ⚠️  CustomLibraries workload may still be installed" -ForegroundColor Yellow
    } else {
        Write-Host "  ✅ Workload removed" -ForegroundColor Green
    }
}
catch {
    Write-Host "  ℹ️  Could not verify workload status" -ForegroundColor Gray
}

try {
    $sources = & tcpkg source list 2>&1
    if ($sources -match $config.CustomFeedName) {
        Write-Host "  ⚠️  Custom package feed may still exist" -ForegroundColor Yellow
    } else {
        Write-Host "  ✅ Package feed removed" -ForegroundColor Green
    }
}
catch {
    Write-Host "  ℹ️  Could not verify package source status" -ForegroundColor Gray
}
Write-Host ""

Write-Host "🎉 Cleanup completed!" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""
Write-Host "ℹ️  Note: This script cleaned up files generated by AutomatedLibraryBuilderV2.ps1" -ForegroundColor Gray
Write-Host "   The original template files in Templates/ have been preserved." -ForegroundColor Gray
Write-Host ""
Write-Host "Press Enter to exit"
Read-Host
