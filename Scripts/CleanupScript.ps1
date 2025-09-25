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
$CustomPacakgeSourceFeedName = "Custom Packages"

#clean up our testing
Write-Host "Uninstalling CustomPLCLibraries Workload and dependencies..."
tcpkg uninstall CustomPLCLibraries.Workload --include-dependencies -y

#remove Custom Feed
Write-Host "Removing package feed $CustomPacakgeSourceFeedName"
tcpkg source remove $CustomPacakgeSourceFeedName

#Turn signature verfication back on
Write-Host "Re-enabling signature verification..."
tcpkg config set -n VerifySignatures

Write-Host "Finished - Press Enter"
Read-Host;