# TwinCAT Custom Package & Workload Examples

This repository contains complete working examples for creating custom TwinCAT packages and workloads using the TwinCAT Package Manager (TcPkg). Learn how to package and distribute custom PLC libraries within your organization using NuGet-style package management.

## Repository Structure

```
AAG_Custom-Tcpkg-And-Workload/
├── README.md                             # This overview
├── Examples/                             # Package and Workload Examples
│   ├── ControlAlgorithmLibPackage/       # Example PLC library package #1
│   ├── ScalingAndConversionLibPackage/   # Example PLC library package #2
│   ├── SignalGenLibPackage/              # Example PLC library package #3
│   └── CustomLibrariesWorkload/          # Complete workload package
│
├── Templates/                            # Templates for New Packages/Workloads
│   ├── CustomPackages.md                 # Package creation workflow documentation
│   ├── CustomWorkloads.md                # Workload creation workflow documentation
│   ├── PackageTemplate/                  # Template for individual packages
│   └── WorkloadTemplate/                 # Template for workloads
│
├── Scripts/                              # Automation Scripts
│   ├── Basics/                           # Simple automation scripts
│   │   ├── TestScript.ps1                # Simple automated test script
│   │   └── CleanupScript.ps1             # Cleanup script to uninstall test packages
│   └── AutomatedBuild/                   # Advanced CI/CD-style automation
│       ├── README.md                     # Automated build documentation
│       ├── AutomatedLibraryBuilderV2.ps1 # Complete build pipeline automation
│       ├── Automation.psm1               # Reusable automation functions
│       ├── CleanupScript.ps1             # Advanced cleanup script
│       └── MessageFilter.ps1             # COM message filtering utilities
│
└── TwinCAT Project Library Creator/      # TwinCAT Development Environment
    └── TwinCAT Project Library Creator.sln # Visual Studio solution for PLC library development
```

## What's Included

### Example Packages ([`Examples/`](Examples/))
- **3 complete PLC library packages** ready to pack and install
  - ControlAlgorithmLibPackage
  - ScalingAndConversionLibPackage
  - SignalGenLibPackage
- Each demonstrates proper TcPkg package structure
- Each installs a custom `.library` file using RepTool.exe
- Can be used as templates for your own packages

### Example Workload ([`Examples/CustomLibrariesWorkload/`](Examples/CustomLibrariesWorkload/))
- **Complete workload** that bundles all 3 library packages together
- Demonstrates meta-package structure with dependencies
- Shows proper `<packageType name="Workload" />` configuration
- One command installs all 3 libraries

### Templates ([`Templates/`](Templates/))
- **PackageTemplate/** - Ready-to-use template for creating new library packages
- **WorkloadTemplate/** - Ready-to-use template for creating new workloads
- **CustomPackages.md** - Step-by-step guide for [package creation](Templates/CustomPackages.md)
- **CustomWorkloads.md** - Step-by-step guide for [workload creation](Templates/CustomWorkloads.md)

### TwinCAT Development Environment ([`TwinCAT Project Library Creator/`](TwinCAT%20Project%20Library%20Creator/))
- **Example TwinCAT solution** showing how to develop PLC libraries
- Contains separate library projects: ControlAlgorithm, ScalingAndConversion, SignalGen
- Demonstrates how to build and export libraries for packaging

### Automation Scripts ([`Scripts/`](Scripts/))
- **Basics/** - Simple scripts for quick testing:
  - **TestScript.ps1** - Packs and installs example packages
  - **CleanupScript.ps1** - Uninstalls packages and restores settings
- **AutomatedBuild/** - Advanced CI/CD automation:
  - **AutomatedLibraryBuilderV2.ps1** - Complete build pipeline that compiles TwinCAT projects, creates packages, and installs workloads automatically
  - **Automation.psm1** - Reusable PowerShell module with TwinCAT Automation Interface functions
  - Demonstrates zero-touch deployment workflows
  - Complete automation with error handling and validation

## Quick Start Guide

### Option A: Simple Testing (Recommended for Learning)
```powershell
# Run the basic automated test (requires admin privileges)
.\Scripts\Basics\TestScript.ps1

# When finished testing, clean up
.\Scripts\Basics\CleanupScript.ps1
```

### Option B: Advanced CI/CD Automation
```powershell
# Run the complete automated build pipeline
.\Scripts\AutomatedBuild\AutomatedLibraryBuilderV2.ps1

# Clean up after testing
.\Scripts\AutomatedBuild\CleanupScript.ps1

# See Scripts/AutomatedBuild/README.md for detailed documentation
```

### Option C: Manual Step-by-Step

#### 0. Prerequisites
```powershell
# Setup custom feed and disable signature verification
tcpkg source add -n "MyCustomFeed" -s "<feed-path>"
tcpkg config unset -n VerifySignatures
```

#### 1. Develop PLC Libraries (Optional)
```powershell
# Open the TwinCAT solution to modify or create new libraries
start "TwinCAT Project Library Creator\TwinCAT Project Library Creator.sln"
# Build libraries and export .library files for packaging
```

#### 2. Create Individual Packages
```powershell
cd Examples

# Create packages for each component
tcpkg pack "ControlAlgorithmLibPackage\ControlAlgorithmLib.Package.nuspec" -o "<feed-path>"
tcpkg pack "ScalingAndConversionLibPackage\ScalingAndConversionLib.Package.nuspec" -o "<feed-path>"
tcpkg pack "SignalGenLibPackage\SignalGenLib.Package.nuspec" -o "<feed-path>"
```

#### 3. Create and Use the Workload
```powershell
cd Examples

# Create the workload package
tcpkg pack "CustomLibrariesWorkload\CustomLibraries.Workload.nuspec" -o "<feed-path>"

# Install entire workload (gets all 3 libraries)
tcpkg install CustomLibraries.Workload
```

## Getting Started

### Choose Your Path:

1. **Learning the Basics**: Start with `.\Scripts\Basics\TestScript.ps1` for simple automated testing
2. **Individual Packages**: Start with [`Templates/CustomPackages.md`](Templates/CustomPackages.md)
3. **Workloads**: Start with [`Templates/CustomWorkloads.md`](Templates/CustomWorkloads.md)
4. **PLC Development**: Open `TwinCAT Project Library Creator\TwinCAT Project Library Creator.sln`
5. **Advanced Automation**: See [`Scripts/AutomatedBuild/README.md`](Scripts/AutomatedBuild/README.md) for complete CI/CD-style pipelines


## License

All sample code provided by [Beckhoff Automation LLC](https://www.beckhoff.com/en-us/) are for illustrative purposes only and are provided "as is" and without any warranties, express or implied. Actual implementations in applications will vary significantly. Beckhoff Automation LLC shall have no liability for, and does not waive any rights in relation to, any code samples that it provides or the use of such code samples for any purpose.
