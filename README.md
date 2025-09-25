# TwinCAT Custom Package & Workload Examples

This repository contains complete working examples for creating custom TwinCAT packages and workloads using the TwinCAT Package Manager (TcPkg). Learn how to package and distribute custom PLC libraries within your organization using NuGet-style package management.

## Repository Structure

```
AAG_Custom-Tcpkg-And-Workload/
├── README.md                             # This overview
├── PackageExamples/                     # Individual Package Examples
│   ├── CustomPackages.md               # Package creation workflow documentation
│   ├── ControlAlgorithmLibPackage/      # Example PLC library package #1
│   ├── ScalingAndConversionLibPackage/  # Example PLC library package #2
│   └── SignalGenLibPackage/            # Example PLC library package #3
│
├── WorkloadExample/                     # Workload Creation Example
│   ├── README.md                        # Workload example overview
│   ├── WorkloadCreation.md             # Detailed workload theory & guide
│   └── CustomPLCLibrariesWorkload/     # Complete workload package
│       ├── CustomPLCLibraries.Workload.nuspec
│       ├── TF1000-Base.png
│       └── tools/ (empty scripts)
│
├── Scripts/                             # Automation Scripts
│   ├── TestScript.ps1                  # Automated test script for package workflow
│   └── CleanupScript.ps1               # Cleanup script to uninstall test packages
│
└── TwinCAT Project Library Creator/     # TwinCAT Development Environment
    └── TcPkgLibraryCreator.sln         # Visual Studio solution for PLC library development
```

## What's Included

### Individual Packages ([`PackageExamples/`](PackageExamples/))
- **3 complete PLC library packages** ready to pack and install
- Each demonstrates proper TcPkg package structure
- Each installs a custom `.library` file using RepTool.exe
- Includes comprehensive documentation on [package creation workflow](PackageExamples/CustomPackages.md)
- Can be used as templates for your own packages

### Workload Package ([`WorkloadExample/`](WorkloadExample/))
- **Complete workload** that bundles all 3 library packages together
- Demonstrates meta-package structure with dependencies
- Shows proper `<packageType name="Workload" />` configuration
- Includes both [theoretical guide](WorkloadExample/WorkloadCreation.md) and [practical implementation](WorkloadExample/CustomPLCLibrariesWorkload/)
- One command installs all 3 libraries

### TwinCAT Development Environment ([`TwinCAT Project Library Creator/`](TwinCAT%20Project%20Library%20Creator/))
- **Example TwinCAT solution** showing how to develop the PLC libraries
- Contains separate library projects: ControlAlgorithm, ScalingAndConversion, SignalGen
- Demonstrates how to build and export libraries for packaging
- Shows integration with Visual Studio/TwinCAT XAE

### Automation Scripts ([`Scripts/`](Scripts/))
- **TestScript.ps1** - Automated end-to-end testing script that:
  - Packs all 3 individual packages and the workload
  - Sets up custom package feed
  - Installs the complete workload
  - Verifies installation success
  - Includes progress reporting for each step
- **CleanupScript.ps1** - Cleanup script that uninstalls test packages and restores settings

## Quick Start Guide

### Option A: Automated Testing (Recommended)
```powershell
# Run the complete automated test (requires admin privileges)
.\Scripts\TestScript.ps1

# When finished testing, clean up
.\Scripts\CleanupScript.ps1
```

### Option B: Manual Step-by-Step

#### 0. Prerequisites
```bash
# Setup custom feed and disable signature verification
tcpkg source add -n "MyCustomFeed" -s "<feed-path>"
tcpkg config unset -n VerifySignatures
```

#### 1. Develop PLC Libraries (Optional)
```bash
# Open the TwinCAT solution to modify or create new libraries
start "TwinCAT Project Library Creator/TcPkgLibraryCreator.sln"
# Build libraries and export .library files for packaging
```

#### 2. Create Individual Packages
```bash
cd PackageExamples

# Create packages for each component
tcpkg pack "ControlAlgorithmLibPackage/ControlAlgorithmLib.Package.nuspec" -o "<feed-path>"
tcpkg pack "ScalingAndConversionLibPackage/ScalingAndConversionLib.Package.nuspec" -o "<feed-path>"
tcpkg pack "SignalGenLibPackage/SignalGenLib.Package.nuspec" -o "<feed-path>"
```

#### 3. Create and Use the Workload
```bash
cd "WorkloadExample/CustomPLCLibrariesWorkload"

# Create the workload package
tcpkg pack "CustomPLCLibraries.Workload.nuspec" -o "<feed-path>"

# Install entire workload (gets all 3 libraries)
tcpkg install CustomPLCLibraries.Workload
```

## Getting Started

1. **For Quick Testing**: Run `.\Scripts\TestScript.ps1` for automated end-to-end validation
2. **For PLC Development**: Open `TwinCAT Project Library Creator/TcPkgLibraryCreator.sln`
3. **For Individual Packages**: Start with [`PackageExamples/CustomPackages.md`](PackageExamples/CustomPackages.md)
4. **For Workloads**: Start with [`WorkloadExample/CustomWorkloads.md`](WorkloadExample/CustomWorkloads.md)
5. **For Implementation**: Use any package as a template and follow the workflows


## License

All sample code provided by [Beckhoff Automation LLC](https://www.beckhoff.com/en-us/) are for illustrative purposes only and are provided “as is” and without any warranties, express or implied. Actual implementations in applications will vary significantly. Beckhoff Automation LLC shall have no liability for, and does not waive any rights in relation to, any code samples that it provides or the use of such code samples for any purpose.
