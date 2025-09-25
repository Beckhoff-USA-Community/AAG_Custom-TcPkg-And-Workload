# Automated Library Builder

The `AutomatedLibraryBuilder.ps1` script provides complete automation for building, packaging, and distributing TwinCAT PLC libraries.

## What It Does

Automates the entire workflow from TwinCAT compilation to workload installation:

- **Compiles TwinCAT Projects**: Uses the [TwinCAT Automation Interface](https://infosys.beckhoff.com/content/1033/tc3_automationinterface/index.html?id=3954232867334285510) to build PLC projects
- **Creates Packages**: Generates TcPkg packages from compiled libraries
- **Builds Workloads**: Bundles packages into distributable workloads
- **Installs Everything**: Sets up package sources and installs the complete workload
- **Handles Errors**: Only error-free projects proceed through the pipeline

## How It Works

1. **Compile PLC Projects** - Opens TwinCAT solution and compiles all `.tspproj` files
2. **Create Packages** - Builds TcPkg packages from compiled libraries
3. **Build Workload** - Bundles packages into a single workload
4. **Setup TcPkg** - Configures package sources and settings
5. **Install Workload** - Installs everything with dependency validation
6. **Report Results** - Shows build statistics and next steps

## Usage

### Prerequisites
- TwinCAT XAE installed
- PowerShell with admin privileges
- TcPkg command-line tools

### Run the Script
```powershell
.\Scripts\AutomatedBuild\AutomatedLibraryBuilder.ps1
```

## When to Use This

**Good for:**
- Development teams with multiple PLC libraries
- CI/CD pipelines
- Automated testing and validation
- Consistent build processes

**Benefits:**
- Eliminates manual build errors
- Faster than manual process
- Only deploys error-free libraries
- Complete build traceability

## Files Included

- **`AutomatedLibraryBuilder.ps1`** - Main automation script
- **`MessageFilter.ps1`** - COM message filtering utilities
- **`ErrorListHelper.ps1`** - TwinCAT error analysis functions