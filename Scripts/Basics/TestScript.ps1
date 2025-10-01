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
$CustomPackageSourceLocation = Join-Path $scriptDir "..\..\GeneratedPackages"
$CustomPackageSourceFeedName = "Custom Packages"

# Ensure package output directory exists
if (!(Test-Path $CustomPackageSourceLocation)) {
    New-Item -ItemType Directory -Path $CustomPackageSourceLocation -Force | Out-Null
}

# Build/Pack all Packages
Write-Host "Packing SignalGenLibPackage..."
tcpkg pack ".\Examples\SignalGenLibPackage\SignalGenLib.Package.nuspec" -o $CustomPackageSourceLocation

Write-Host "Packing ControlAlgorithmLibPackage..."
tcpkg pack ".\Examples\ControlAlgorithmLibPackage\ControlAlgorithmLib.Package.nuspec" -o $CustomPackageSourceLocation

Write-Host "Packing ScalingAndConversionLibPackage..."
tcpkg pack ".\Examples\ScalingAndConversionLibPackage\ScalingAndConversionLib.Package.nuspec" -o $CustomPackageSourceLocation

# Build/Pack workload
Write-Host "Packing CustomLibraries Workload..."
tcpkg pack ".\Examples\CustomLibrariesWorkload\CustomLibraries.Workload.nuspec" -o $CustomPackageSourceLocation

# Add custom feed if it doesn't already exist
Write-Host "Adding custom package feed if needed..."
if (-not (tcpkg source list | Select-String "$CustomPackageSourceFeedName" -Quiet)) {
   tcpkg source add -n "$CustomPackageSourceFeedName" -s "$CustomPackageSourceLocation"
}

# Turn off signature verification for 3rd party packages
Write-Host "Disabling signature verification for custom packages..."
tcpkg config unset -n VerifySignatures

# Install the workload
Write-Host "Installing CustomLibraries Workload..."
tcpkg install CustomLibraries.Workload -y

Write-Host "Finished - Press Enter"
Read-Host;