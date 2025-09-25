# Custom Packages

The TwinCAT Package Manager enables users to create and manage their own custom packages. It provides a "pack" command for this purpose.

## Use Case: PLC Library

TwinCAT users can use custom packages to manage and deliver custom PLC libraries within their company or working group by defining a custom feed and uploading new versions of those PLC libraries as custom packages.

## Steps to Create a Custom Package for a PLC Library

### 1. Rename the .nuspec file

### 2. Modify configuration files

#### a. Update `<package name>.nuspec` file
- Define a unique combination of the id and version
- Set the name, author, description
- Add dependencies, if necessary
- Set library file

#### b. Update `chocolateyinstall.ps1` file
- Nothing to do up to now

#### c. Update `chocolateyuninstall.ps1` file
- Set the library details, e.g. "SignalGen, 0.0.0.1 (Beckhoff Automation LLC.)"

### 3. Add custom feed (if not already done)
```bash
tcpkg source add -n "<feed name>" -s "<feed path>"
```

### 4. Create new package via the "pack" command
```bash
tcpkg pack "<full path>\<package name>.nuspec" -o "<feed path>"
```

### 5. Check whether the package is added successfully
```bash
tcpkg list -n "<feed name>"
```

### 6. Disable signature verification (if not already done)
```bash
tcpkg config unset -n VerifySignatures
```

### 7. Install package
```bash
tcpkg install <package name>
```

### 8. Uninstall package
```bash
tcpkg uninstall <package name>
```