# Custom Workloads

The TwinCAT Package Manager enables users to create workloads that bundle multiple custom packages together. A workload is a meta-package that installs multiple related packages with a single command.

## Use Case: PLC Library Workload

TwinCAT users can use workloads to distribute complete sets of related PLC libraries as a single unit. This example bundles 3 PLC libraries: ControlAlgorithm, ScalingAndConversion, and SignalGen.

## Workload vs Package

- **Package**: Contains actual files and installation scripts
- **Workload**: Contains only metadata and dependencies - coordinates installation of multiple packages

## Steps to Create a Custom Workload

### 1. Copy an existing workload folder as a template
Copy the existing workload folder (`CustomPLCLibrariesWorkload`) to use as your starting template. This provides the correct folder structure and baseline configuration files.

```bash
# Example: Copy existing workload folder
cp -r "CustomPLCLibrariesWorkload" "MyCustomWorkload"
```
## Example Workload Structure

```
CustomPLCLibrariesWorkload/
├── CustomPLCLibraries.Workload.nuspec  # Main workload specification
├── TF1000-Base.png                     # Workload icon
└── tools/                              # Empty scripts
    ├── chocolateyinstall.ps1           # Empty
    ├── chocolateyuninstall.ps1         # Empty
    └── chocolateybeforemodify.ps1      # Empty
```


### 2. Create Component Packages First
```bash
# Navigate to PackageExamples directory and create each component
cd "../PackageExamples"
tcpkg pack "ControlAlgorithmLibPackage/ControlAlgorithmLib.Package.nuspec" -o "<feed-path>"
tcpkg pack "ScalingAndConversionLibPackage/ScalingAndConversionLib.Package.nuspec" -o "<feed-path>"
tcpkg pack "SignalGenLibPackage/SignalGenLib.Package.nuspec" -o "<feed-path>"
```

### 3. Modify workload configuration files

#### a. Update `<workload name>.nuspec` file
- Define unique ID and version
- Set name, author, description
- **Add dependencies section listing all component packages with exact versions**
- Include "Workload" in tags
- **Note**: The `<packageTypes><packageType name="Workload" /></packageTypes>` section is already present in the copied template - this is the critical element that makes this package show up in TcPkg as a workload

**Example .nuspec configuration:**

```xml
<packageTypes>
  <packageType name="Workload" />
</packageTypes>

<tags>TwinCAT Workload CustomCategory VariantPLC</tags>

<dependencies>
  <dependency id="ControlAlgorithmLib.Package" version="0.0.1" />
  <dependency id="ScalingAndConversionLib.Package" version="0.0.1" />
  <dependency id="SignalGenLib.Package" version="0.0.1" />
</dependencies>
```

#### b. No modifications needed to these PowerShell scripts in `tools/` directory
- `chocolateyinstall.ps1` - Empty file
- `chocolateyuninstall.ps1` - Empty file
- `chocolateybeforemodify.ps1` - Empty file


### 4. Create workload package via the "pack" command
```bash
tcpkg pack "<full path>\<workload name>.nuspec" -o "<feed path>"
```

### 5. Add custom feed (if not already done)
```bash
tcpkg source add -n "<feed name>" -s "<feed path>"
```

### 6. Check whether the workload is added successfully
```bash
tcpkg list -n "<feed name>" -t workload
```

### 7. Disable signature verification (if not already done)
```bash
tcpkg config unset -n VerifySignatures
```

### 8. Install workload (installs all component packages)
```bash
tcpkg install <workload name>
```

### 9. Uninstall workload and all of it's dependencies
```bash
tcpkg uninstall <workload name> --include-dependencies
```





## How It Works

1. `tcpkg install MyWorkload` downloads the workload metadata
2. TcPkg automatically resolves and downloads all dependency packages
3. Each component package runs its own installation scripts
4. Result: Complete set of libraries installed with one command