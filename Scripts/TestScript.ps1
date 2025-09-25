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

$CustomPackageSourceLocation = "C:\CustomPackages";
$CustomPacakgeSourceFeedName = "Custom Packages";

#Build/Pack all Packages
Write-Host "Packing SignalGenLibPackage..."
tcpkg pack ".\PackageExamples\SignalGenLibPackage\SignalGenLib.Package.nuspec" -o $CustomPackageSourceLocation

Write-Host "Packing ControlAlgorithmLibPackage..."
tcpkg pack ".\PackageExamples\ControlAlgorithmLibPackage\ControlAlgorithmLib.Package.nuspec" -o $CustomPackageSourceLocation

Write-Host "Packing ScalingAndConversionLibPackage..."
tcpkg pack ".\PackageExamples\ScalingAndConversionLibPackage\ScalingAndConversionLib.Package.nuspec" -o $CustomPackageSourceLocation

#Build/Pack workload
Write-Host "Packing CustomPLCLibraries Workload..."
tcpkg pack ".\WorkloadExample\CustomPLCLibrariesWorkload\CustomPLCLibraries.Workload.nuspec" -o $CustomPackageSourceLocation


#Add customer feed if it doesnt already exists.
Write-Host "Adding custom package feed if needed..."
if (-not (tcpkg source list | Select-String "$CustomPacakgeSourceFeedName" -Quiet)) {
   tcpkg source add -n "$CustomPacakgeSourceFeedName" -s "$CustomPackageSourceLocation"
}

#Check if packages are avliable in the feed
Write-Host "Checking available packages in feed..."
tcpkg list -n "$CustomPacakgeSourceFeedName"

#Turn off signature instlation for 3rd party packages
Write-Host "Disabling signature verification for custom packages..."
tcpkg config unset -n VerifySignatures

#Install the workload
Write-Host "Installing CustomPLCLibraries Workload..."
tcpkg install CustomPLCLibraries.Workload -y

#Check if workload shows up as installed.
Write-Host "Verifying workload installation..."
tcpkg list -i -n "$CustomPacakgeSourceFeedName" -t workload

Write-Host "Finished - Press Enter"
Read-Host;