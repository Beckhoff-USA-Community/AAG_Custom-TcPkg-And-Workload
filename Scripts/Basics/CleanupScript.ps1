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

# Clean up our testing
Write-Host "Uninstalling CustomLibraries Workload and dependencies..."
tcpkg uninstall CustomLibraries.Workload --include-dependencies -y

# Remove Custom Feed
Write-Host "Removing package feed $CustomPackageSourceFeedName"
tcpkg source remove $CustomPackageSourceFeedName

# Delete Custom feed folder
Remove-Item -Path $CustomPackageSourceLocation -Force

# Turn signature verification back on
Write-Host "Re-enabling signature verification..."
tcpkg config set -n VerifySignatures

Write-Host "Finished - Press Enter"
Read-Host;