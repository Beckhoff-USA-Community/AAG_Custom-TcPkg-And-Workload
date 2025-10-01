# Custom Packages

The TwinCAT Package Manager enables users to create and manage their own custom packages. It provides a "pack" command for this purpose.

## Use Case: PLC Library

TwinCAT users can use custom packages to manage and deliver custom PLC libraries within their company or working group by defining a custom feed and uploading new versions of those PLC libraries as custom packages.

## Steps to Create a Custom Package for a PLC Library

### 1. Copy the package template

Use the provided template as your starting point:

```powershell
# Copy the package template to your desired location
cp -r "Templates\PackageTemplate" "Examples\MyCustomLibPackage"
```

Alternatively, copy one of the existing example packages:
- `Examples\ControlAlgorithmLibPackage`
- `Examples\ScalingAndConversionLibPackage`
- `Examples\SignalGenLibPackage`

### 2. Add your .library file

Copy your compiled `.library` file to the package directory.

### 3. Update the .nuspec file

Rename `Template.Package.nuspec` to match your package (e.g., `MyCustomLib.Package.nuspec`) and update:

```xml
<!-- Define a unique package ID and version -->
<id>MyCustomLib.Package</id>
<version>1.0.0</version>

<!-- Set descriptive metadata -->
<title>My Custom Library Package</title>
<authors>Your Company Name</authors>
<description>Description of your library</description>

<!-- Keep required tags and add your own -->
<tags>Beckhoff TwinCAT AllowMultipleVersions YourTag</tags>

<!-- Update the library file reference -->
<file src="YourLibrary.library" target="tools\LibraryToInstall.library" />
```

### 4. Update chocolateyuninstall.ps1

Edit `tools\chocolateyuninstall.ps1` and set the library details for removal:

```powershell
# Replace with your library details
$libraryDetails = "YourLibraryName, 1.0.0 (Your Company)"
```

### 5. Add custom feed (if not already done)

```powershell
tcpkg source add -n "<feed name>" -s "<feed path>"
```

### 6. Create the package

```powershell
tcpkg pack "<path-to-nuspec>\MyCustomLib.Package.nuspec" -o "<feed path>"
```

### 7. Verify the package was created

```powershell
tcpkg list -n "<feed name>"
```

### 8. Disable signature verification (if not already done)

```powershell
tcpkg config unset -n VerifySignatures
```

### 9. Install package

```powershell
tcpkg install MyCustomLib.Package
```

### 10. Uninstall package

```powershell
tcpkg uninstall MyCustomLib.Package
```

## Package Structure

Your package should have this structure:

```
MyCustomLibPackage/
├── MyCustomLib.Package.nuspec    # Package metadata
├── YourLibrary.library            # Your compiled library
├── TF1000-Base.png                # Package icon
└── tools/
    ├── LICENSE.txt
    ├── VERIFICATION.txt
    ├── chocolateybeforemodify.ps1
    ├── chocolateyinstall.ps1      # Installs library using RepTool.exe
    └── chocolateyuninstall.ps1    # Uninstalls library
```

## Notes

- The `chocolateyinstall.ps1` script automatically finds and uses RepTool.exe to install the library
- The `.library` file is automatically renamed to `LibraryToInstall.library` during packaging
- Always test your package in a development environment before deploying to production
- Version numbers should follow semantic versioning (Major.Minor.Patch)
