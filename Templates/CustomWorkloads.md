# Custom Workloads

The TwinCAT Package Manager enables users to create workloads that bundle multiple custom packages together. A workload is a meta-package that installs multiple related packages with a single command.

## Use Case: PLC Library Workload

TwinCAT users can use workloads to distribute complete sets of related PLC libraries as a single unit. This example bundles 3 PLC libraries: ControlAlgorithm, ScalingAndConversion, and SignalGen.

## Workload vs Package

- **Package**: Contains actual files and installation scripts
- **Workload**: Contains only metadata and dependencies - coordinates installation of multiple packages

## Steps to Create a Custom Workload

### 1. Copy the workload template

Use the provided template as your starting point:

```powershell
# Copy the workload template to your desired location
cp -r "Templates\WorkloadTemplate" "Examples\MyCustomWorkload"
```

Alternatively, copy the existing example workload:
```powershell
cp -r "Examples\CustomLibrariesWorkload" "Examples\MyCustomWorkload"
```

## Example Workload Structure

```
MyCustomWorkload/
├── MyCustom.Workload.nuspec       # Main workload specification
├── TF1000-Base.png                # Workload icon
└── tools/                         # Empty scripts (required but not used)
    ├── chocolateyinstall.ps1      # Empty
    ├── chocolateyuninstall.ps1    # Empty
    └── chocolateybeforemodify.ps1 # Empty
```

### 2. Create Component Packages First

Before creating the workload, you must create and publish all component packages:

```powershell
# Navigate to Examples directory and create each component
cd Examples

tcpkg pack "ControlAlgorithmLibPackage\ControlAlgorithmLib.Package.nuspec" -o "<feed-path>"
tcpkg pack "ScalingAndConversionLibPackage\ScalingAndConversionLib.Package.nuspec" -o "<feed-path>"
tcpkg pack "SignalGenLibPackage\SignalGenLib.Package.nuspec" -o "<feed-path>"
```

### 3. Update the workload .nuspec file

Rename `Template.Workload.nuspec` to match your workload (e.g., `MyCustom.Workload.nuspec`) and update:

```xml
<!-- Define unique workload ID and version -->
<id>MyCustom.Workload</id>
<version>1.0.0</version>

<!-- Set descriptive metadata -->
<title>My Custom PLC Libraries Workload</title>
<authors>Your Company Name</authors>
<description>Contains custom PLC libraries: Library1, Library2, Library3</description>

<!-- Keep the required packageTypes element -->
<packageTypes>
  <packageType name="Workload" />
</packageTypes>

<!-- Include Workload in tags -->
<tags>Beckhoff TwinCAT Workload MyCustom CategoryCustom VariantPLC</tags>

<!-- List all component packages with exact versions -->
<dependencies>
  <dependency id="Library1.Package" version="1.0.0" />
  <dependency id="Library2.Package" version="1.0.0" />
  <dependency id="Library3.Package" version="1.0.0" />
</dependencies>
```

**Important:**
- The `<packageTypes><packageType name="Workload" /></packageTypes>` element is **required** - this makes the package show up as a workload in TcPkg
- Dependency versions must match **exactly** with the published package versions

### 4. No modifications needed to PowerShell scripts

The scripts in the `tools/` directory should remain empty:
- `chocolateyinstall.ps1` - Empty file
- `chocolateyuninstall.ps1` - Empty file
- `chocolateybeforemodify.ps1` - Empty file

These files are required by the package structure but don't need any content for workloads.

### 5. Create the workload package

```powershell
tcpkg pack "<path-to-nuspec>\MyCustom.Workload.nuspec" -o "<feed path>"
```

### 6. Add custom feed (if not already done)

```powershell
tcpkg source add -n "<feed name>" -s "<feed path>"
```

### 7. Verify the workload was created

```powershell
tcpkg list -n "<feed name>" -t workload
```

### 8. Disable signature verification (if not already done)

```powershell
tcpkg config unset -n VerifySignatures
```

### 9. Install workload (installs all component packages)

```powershell
tcpkg install MyCustom.Workload
```

### 10. Uninstall workload and all dependencies

```powershell
tcpkg uninstall MyCustom.Workload --include-dependencies
```

## How It Works

1. `tcpkg install MyCustom.Workload` downloads the workload metadata
2. TcPkg automatically resolves and downloads all dependency packages
3. Each component package runs its own installation scripts
4. Result: Complete set of libraries installed with one command

## Best Practices

- Always create and test individual component packages before creating the workload
- Use exact version numbers in dependencies (not ranges)
- Keep workload versions aligned with component package updates
- Test workload installation in a clean environment before distribution
- Document which libraries are included in the workload description
