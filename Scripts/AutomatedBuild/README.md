# Automated Library Builder V2

The `AutomatedLibraryBuilderV2.ps1` script provides complete automation for building, packaging, and distributing TwinCAT PLC libraries.

## What It Does

Automates the entire workflow from TwinCAT compilation to workload installation:

- **Compiles TwinCAT Projects**: Uses the [TwinCAT Automation Interface](https://infosys.beckhoff.com/content/1033/tc3_automationinterface/index.html?id=3954232867334285510) to build PLC projects
- **Extracts PLC Project Metadata**: Reads Author, Company Name, Description, and Version from project properties
- **Validates Compilation**: Checks for errors and only processes error-free projects
- **Saves Libraries**: Exports compiled projects as `.library` files
- **Creates Package Structures**: Generates package directories from templates
- **Populates Package Metadata**: Automatically fills `.nuspec` files with project metadata (author, version, description, etc.)
- **Builds Packages**: Creates TcPkg packages for each library
- **Builds Workloads**: Bundles packages into distributable workloads with automatic version incrementing
- **Sets Up Package Feed**: Configures TcPkg with custom package source
- **Installs Everything**: Installs the complete workload with all dependencies
- **Comprehensive Reporting**: Provides detailed status and error reporting at each step


**Supporting Files:**
- **Automation.psm1** - Reusable PowerShell module with TwinCAT automation functions
- **MessageFilter.ps1** - COM message filtering for DTE operations
- **CleanupScript.ps1** - Removes all generated artifacts and restores system state

## Configuration

All paths and settings are centralized in the `$config` hashtable at the top of the script:

```powershell
$config = @{
    SolutionPath          # Path to TwinCAT solution
    ExamplesDir           # Where to create package directories
    PackageOutputDir      # Where to output .nupkg files
    PackageTemplateDir    # Template for individual packages
    WorkloadTemplateDir   # Template for workloads
    WorkloadPackageDir    # Where to create workload package
    CustomFeedName        # Name for the TcPkg package source
    Silent                # Suppress UI during automation
}
```


### Prerequisites

- TwinCAT XAE installed (3.1.4026 or later)
- PowerShell 7 or later
- Administrative privileges (for TcPkg operations)
- Tested against TcPkg 2.3.55 
### Run the Script

```powershell
# From the repository root
.\Scripts\AutomatedBuild\AutomatedLibraryBuilderV2.ps1

# The script will automatically elevate when needed for TcPkg commands
```

### Clean Up After Testing

```powershell
# Run the cleanup script to remove all generated artifacts
.\Scripts\AutomatedBuild\CleanupScript.ps1
```

## Output

The script generates:

- **GeneratedPackages/** - Directory containing `.nupkg` files
- **Examples/[ProjectName]LibPackage/** - Package directories for each library
- **Examples/CustomLibrariesWorkload/** - Workload package directory
- Package feed registered in TcPkg as "Custom Packages"
- Installed workload with all component libraries available in TwinCAT

## Error Handling

The script includes comprehensive error handling:

- Projects with compilation errors are skipped but don't stop the pipeline
- Failed library exports are reported but don't block other libraries
- Package creation failures are logged with detailed error messages
- Each step validates prerequisites before execution
- All errors are clearly reported with context

## When to Use This

**Good for:**
- Development teams with multiple PLC libraries
- CI/CD pipelines for automated builds
- Automated testing and validation
- Consistent, repeatable build processes
- Creating release packages from source

**Benefits:**
- Eliminates manual build errors
- Much faster than manual process
- Only deploys error-free libraries
- Complete build traceability
- Automatic version management
- Zero-touch deployment capability

## Advanced Features

### Automatic Version Incrementing

The script automatically increments the workload version by:
1. Checking for existing workload package
2. Reading the current version from the `.nuspec` file
3. Incrementing the patch number (semantic versioning)
4. Using default version (1.0.0) for new workloads

### Conditional Elevation

The script uses `Invoke-ElevatedCommand` to only elevate specific commands that require admin privileges:
- Adding package sources (`tcpkg source add`)
- Disabling signature verification (`tcpkg config unset`)
- Installing packages (`tcpkg install`)

This allows the script to run with minimal privileges and only request elevation when necessary.

### Template-Based Package Creation

Packages are created from templates in `Templates/` directory:
- **PackageTemplate/** - Contains all files needed for a library package
- **WorkloadTemplate/** - Contains structure for workload packages

Templates are copied and customized with project-specific information automatically.

## Troubleshooting

### TwinCAT Automation Issues

If the script fails to open the TwinCAT solution:
- Ensure TwinCAT XAE is properly installed
- Close any open TwinCAT instances
- Check that the solution path in `$config.SolutionPath` is correct

### Package Installation Failures

If package installation fails:
- Ensure you have administrative privileges
- Check that signature verification is disabled
- Verify the package feed path is accessible
- Review TcPkg logs for detailed error messages

### Compilation Errors

If projects fail compilation:
- Open the solution in TwinCAT XAE manually
- Fix any compilation errors in the IDE
- Re-run the script - it will automatically skip failed projects
