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

Write-Host "🧹 Starting Cleanup Process..." -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CustomPackageSourceFeedName = "Custom Packages"
$CustomPackageSourceLocation = Join-Path $scriptDir "..\..\GeneratedPackages"

# =============================================================================
# STEP 1: UNINSTALL WORKLOAD AND DEPENDENCIES
# =============================================================================

Write-Host "=== STEP 1: Uninstalling CustomPLCLibraries Workload ===" -ForegroundColor Cyan
try {
    Write-Host "📤 Uninstalling CustomPLCLibraries.Workload and all dependencies..." -ForegroundColor Yellow
    $uninstallResult = & tcpkg uninstall CustomPLCLibraries.Workload --include-dependencies -y 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Workload uninstalled successfully" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Uninstall completed with warnings: $uninstallResult" -ForegroundColor Yellow
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
    Write-Host "🗑️  Removing package feed: $CustomPackageSourceFeedName" -ForegroundColor Yellow
    $removeResult = & tcpkg source remove $CustomPackageSourceFeedName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Package feed removed successfully" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Feed removal completed with warnings: $removeResult" -ForegroundColor Yellow
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
    Write-Host "🔒 Re-enabling signature verification for packages..." -ForegroundColor Yellow
    & tcpkg config set -n VerifySignatures 2>&1 | Out-Null
    Write-Host "  ✅ Signature verification re-enabled" -ForegroundColor Green
}
catch {
    Write-Host "  ⚠️  Error re-enabling signature verification: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host ""

# =============================================================================
# STEP 4: CLEAN UP PACKAGE FILES (OPTIONAL)
# =============================================================================

Write-Host "=== STEP 4: Package File Cleanup ===" -ForegroundColor Cyan
if (Test-Path $CustomPackageSourceLocation) {
    Write-Host "🗂️  Found package directory: $CustomPackageSourceLocation" -ForegroundColor Blue

    # List packages that would be deleted
    $packageFiles = Get-ChildItem -Path $CustomPackageSourceLocation -Filter "*.nupkg" -ErrorAction SilentlyContinue
    if ($packageFiles.Count -gt 0) {
        Write-Host "  📦 Found $($packageFiles.Count) package files:" -ForegroundColor Gray
        foreach ($pkg in $packageFiles) {
            Write-Host "    • $($pkg.Name)" -ForegroundColor Gray
        }

        $response = Read-Host "  ❓ Do you want to delete these package files? (y/N)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            try {
                Remove-Item -Path "$CustomPackageSourceLocation\*.nupkg" -Force
                Write-Host "  ✅ Package files deleted successfully" -ForegroundColor Green

                # Remove directory if empty
                $remainingFiles = Get-ChildItem -Path $CustomPackageSourceLocation -ErrorAction SilentlyContinue
                if ($remainingFiles.Count -eq 0) {
                    Remove-Item -Path $CustomPackageSourceLocation -Force
                    Write-Host "  ✅ Empty package directory removed" -ForegroundColor Green
                }
            }
            catch {
                Write-Host "  ❌ Error deleting package files: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  ⏭️  Package files preserved" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ℹ️  No package files found to clean up" -ForegroundColor Gray
    }
} else {
    Write-Host "  ℹ️  Package directory does not exist: $CustomPackageSourceLocation" -ForegroundColor Gray
}
Write-Host ""

# =============================================================================
# STEP 5: VERIFICATION
# =============================================================================

Write-Host "=== STEP 5: Verification ===" -ForegroundColor Cyan
Write-Host "🔍 Verifying cleanup..." -ForegroundColor Blue

# Check installed workloads
Write-Host "📋 Checking for remaining workloads..." -ForegroundColor Gray
try {
    $installedWorkloads = & tcpkg list -i -t workload 2>&1
    if ($installedWorkloads -match "CustomPLCLibraries") {
        Write-Host "  ⚠️  CustomPLCLibraries workload may still be installed" -ForegroundColor Yellow
    } else {
        Write-Host "  ✅ No CustomPLCLibraries workload found" -ForegroundColor Green
    }
}
catch {
    Write-Host "  ℹ️  Could not verify workload status" -ForegroundColor Gray
}

# Check package sources
Write-Host "📋 Checking package sources..." -ForegroundColor Gray
try {
    $sources = & tcpkg source list 2>&1
    if ($sources -match $CustomPackageSourceFeedName) {
        Write-Host "  ⚠️  Custom package feed may still exist" -ForegroundColor Yellow
    } else {
        Write-Host "  ✅ Custom package feed removed successfully" -ForegroundColor Green
    }
}
catch {
    Write-Host "  ℹ️  Could not verify package source status" -ForegroundColor Gray
}
Write-Host ""

# =============================================================================
# SUMMARY
# =============================================================================

Write-Host "📊 CLEANUP SUMMARY" -ForegroundColor White
Write-Host "─────────────────────────────────────────" -ForegroundColor Gray
Write-Host "✅ Workload uninstallation:    Attempted" -ForegroundColor Green
Write-Host "✅ Package feed removal:       Attempted" -ForegroundColor Green
Write-Host "✅ Signature verification:     Re-enabled" -ForegroundColor Green
Write-Host "📁 Package files:              $(if (Test-Path $CustomPackageSourceLocation) {'User Choice'} else {'N/A'})" -ForegroundColor Gray
Write-Host ""

Write-Host "🎯 NEXT STEPS:" -ForegroundColor Cyan
Write-Host "  1. Your system has been cleaned up and restored to its original state" -ForegroundColor White
Write-Host "  2. You can safely re-run the AutomatedLibraryBuilder.ps1 if needed" -ForegroundColor White
Write-Host "  3. Custom libraries are no longer available in TwinCAT projects" -ForegroundColor White
Write-Host ""

Write-Host "🎉 Cleanup process completed!" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Magenta

Write-Host "Finished - Press Enter to exit"
Read-Host