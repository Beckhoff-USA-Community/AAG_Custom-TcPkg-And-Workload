#
# Automation.psm1 - TwinCAT XAE Automation Helper Module
#
# This PowerShell module provides automation helper functions for TwinCAT XAE (DTE) operations.
# It centralizes common automation tasks and provides reusable functionality across build scripts.
#
# Author: Generated for AAG Custom TcPkg and Workload
# Version: 1.0
#

# =============================================================================
# MODULE-SCOPED VARIABLES AND COM MESSAGE FILTER
# =============================================================================

# PowerShell equivalents of Visual Studio constants
$script:vsProjectKindMisc = "{66A26720-8FB5-11D2-AA7E-00C04F688DDE}"

# Hard reference DTE2 assembly for error list functionality
Add-Type -Path "C:\Program Files\Beckhoff\TcXaeShell\Common7\IDE\PublicAssemblies\envdte80.dll"

# COM Message Filter Class for handling DTE automation threading issues
function AddMessageFilterClass {
    $source = @"
namespace EnvDteUtils{

using System;
using System.Runtime.InteropServices;
    public class MessageFilter : IOleMessageFilter
    {
        //
        // Class containing the IOleMessageFilter
        // thread error-handling functions.

        // Start the filter.
        public static void Register()
        {
            IOleMessageFilter newFilter = new MessageFilter();
            IOleMessageFilter oldFilter = null;
            CoRegisterMessageFilter(newFilter, out oldFilter);
        }

        // Done with the filter, close it.
        public static void Revoke()
        {
            IOleMessageFilter oldFilter = null;
            CoRegisterMessageFilter(null, out oldFilter);
        }

        //
        // IOleMessageFilter functions.
        // Handle incoming thread requests.
        int IOleMessageFilter.HandleInComingCall(int dwCallType,
          System.IntPtr hTaskCaller, int dwTickCount, System.IntPtr
          lpInterfaceInfo)
        {
            //Return the flag SERVERCALL_ISHANDLED.
            return 0;
        }

        // Thread call was rejected, so try again.
        int IOleMessageFilter.RetryRejectedCall(System.IntPtr
          hTaskCallee, int dwTickCount, int dwRejectType)
        {
            if (dwRejectType == 2)
            // flag = SERVERCALL_RETRYLATER.
            {
                // Retry the thread call immediately if return >=0 &
                // <100.
                return 99;
            }
            // Too busy; cancel call.
            return -1;
        }

        int IOleMessageFilter.MessagePending(System.IntPtr hTaskCallee,
          int dwTickCount, int dwPendingType)
        {
            //Return the flag PENDINGMSG_WAITDEFPROCESS.
            return 2;
        }

        // Implement the IOleMessageFilter interface.
        [DllImport("Ole32.dll")]
        private static extern int
          CoRegisterMessageFilter(IOleMessageFilter newFilter, out
          IOleMessageFilter oldFilter);
    }

    [ComImport(), Guid("00000016-0000-0000-C000-000000000046"),
    InterfaceTypeAttribute(ComInterfaceType.InterfaceIsIUnknown)]
    interface IOleMessageFilter
    {
        [PreserveSig]
        int HandleInComingCall(
            int dwCallType,
            IntPtr hTaskCaller,
            int dwTickCount,
            IntPtr lpInterfaceInfo);

        [PreserveSig]
        int RetryRejectedCall(
            IntPtr hTaskCallee,
            int dwTickCount,
            int dwRejectType);

        [PreserveSig]
        int MessagePending(
            IntPtr hTaskCallee,
            int dwTickCount,
            int dwPendingType);
    }
}
"@

    Add-Type -TypeDefinition $source
}

# =============================================================================
# AUTOMATION CONSTRUCTOR/DESTRUCTOR PATTERN
# =============================================================================

function Initialize-Automation {
    <#
    .SYNOPSIS
    Initializes the automation environment (constructor pattern).

    .DESCRIPTION
    Sets up the automation environment by registering the COM message filter.
    This should be called at the beginning of automation operations.

    .EXAMPLE
    Initialize-Automation
    #>
    [CmdletBinding()]
    param()

    # Register COM message filter (function is now internal to this module)
    AddMessageFilterClass
    [EnvDTEUtils.MessageFilter]::Register()
}

function Close-Automation {
    <#
    .SYNOPSIS
    Cleans up the automation environment (destructor pattern).

    .DESCRIPTION
    Cleans up the automation environment by revoking the COM message filter.
    This should be called at the end of automation operations.

    .EXAMPLE
    Close-Automation
    #>
    [CmdletBinding()]
    param()

    # Revoke COM message filter
    [EnvDTEUtils.MessageFilter]::Revoke()
}

# =============================================================================
# DTE INITIALIZATION AND SOLUTION MANAGEMENT
# =============================================================================

function Open-ExistingTcProject {
    <#
    .SYNOPSIS
    Opens an existing TwinCAT solution with DTE initialization.

    .DESCRIPTION
    Creates a new TwinCAT XAE DTE instance and opens the specified solution file.
    This is equivalent to the C# OpenExistingTcProject method.

    .PARAMETER SolutionPath
    Full path to the solution file to open

    .PARAMETER SuppressUI
    Whether to suppress the UI (default: $false)

    .PARAMETER Silent
    Whether to suppress output messages (default: $false)

    .EXAMPLE
    $dte = Open-ExistingTcProject -SolutionPath "C:\Path\To\Solution.sln"

    .RETURNS
    DTE object instance or $null if failed
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SolutionPath,

        [Parameter(Mandatory = $false)]
        [bool]$SuppressUI = $false,

        [Parameter(Mandatory = $false)]
        [bool]$Silent = $false
    )

    try {
        if (!(Test-Path $SolutionPath)) {
            if (!$Silent) { Write-Host "❌ Solution file not found: $SolutionPath" -ForegroundColor Red }
            return $null
        }

        if (!$Silent) { Write-Host "🔧 Opening existing TwinCAT project..." -ForegroundColor Blue }

        # Create TwinCAT XAE DTE instance (equivalent to GetTypeFromProgID + CreateInstance)
        $dte = New-Object -ComObject TcXaeShell.DTE.17.0

        # Configure UI settings
        $dte.SuppressUI = $SuppressUI
        $dte.MainWindow.Visible = !$SuppressUI

        if (!$Silent) { Write-Host "📂 Opening solution: $SolutionPath" -ForegroundColor Blue }

        # Open the solution
        $solution = $dte.Solution
        $solution.Open($SolutionPath)

        if (!$Silent) { Write-Host "✅ TwinCAT project opened successfully" -ForegroundColor Green }
        return $dte
    }
    catch {
        if (!$Silent) { Write-Host "❌ Failed to open TwinCAT project: $($_.Exception.Message)" -ForegroundColor Red }
        return $null
    }
}

function Get-PlcProjects {
    <#
    .SYNOPSIS
    Discovers and returns all PLC projects in a solution.

    .DESCRIPTION
    Searches through all projects in the solution and returns those with .tspproj extension.
    This is based on the C# SetProjectReference pattern but focused on PLC projects.

    .PARAMETER DTE
    The TwinCAT XAE DTE object instance

    .PARAMETER Silent
    Whether to suppress output messages (default: $false)

    .EXAMPLE
    $plcProjects = Get-PlcProjects -DTE $dte

    .RETURNS
    Array of PLC project objects with .tspproj extension
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.__ComObject]$DTE,

        [Parameter(Mandatory = $false)]
        [bool]$Silent = $false
    )

    $plcProjects = @()

    try {
        if ($null -eq $DTE) {
            if (!$Silent) { Write-Host "❌ DTE object is null" -ForegroundColor Red }
            return $plcProjects
        }

        if ($null -eq $DTE.Solution) {
            if (!$Silent) { Write-Host "❌ Solution is null" -ForegroundColor Red }
            return $plcProjects
        }

        if (!$Silent) { Write-Host "🔍 Discovering PLC projects..." -ForegroundColor Blue }

        $solution = $DTE.Solution

        # Iterate through all projects in the solution
        foreach ($proj in $solution.Projects) {
            if ($null -eq $proj) {
                continue
            }

            # Get file extension to identify PLC projects (.tspproj)
            $fileExt = [System.IO.Path]::GetExtension($proj.FileName)
            if ($fileExt -eq ".tspproj") {
                $plcProjects += $proj
                if (!$Silent) {
                    Write-Host "  ✓ Found PLC project: $($proj.Name)" -ForegroundColor Green
                }
            }
        }

        if (!$Silent) {
            Write-Host "  📊 Total PLC projects found: $($plcProjects.Count)" -ForegroundColor Cyan
        }

        return $plcProjects
    }
    catch {
        if (!$Silent) {
            Write-Host "❌ Error discovering PLC projects: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $plcProjects
    }
}

function Close-Solution {
    <#
    .SYNOPSIS
    Closes the solution and shuts down the TwinCAT XAE DTE environment.

    .DESCRIPTION
    Closes the currently open solution and completely shuts down the DTE instance.
    This provides complete cleanup equivalent to the C# CloseSolution method.

    .PARAMETER DTE
    The TwinCAT XAE DTE object instance

    .PARAMETER SaveChanges
    Whether to save changes before closing (default: $false)

    .PARAMETER Silent
    Whether to suppress output messages (default: $false)

    .EXAMPLE
    Close-Solution -DTE $dte

    .EXAMPLE
    Close-Solution -DTE $dte -SaveChanges $true

    .RETURNS
    [bool] True if successful, false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.__ComObject]$DTE,

        [Parameter(Mandatory = $false)]
        [bool]$SaveChanges = $false,

        [Parameter(Mandatory = $false)]
        [bool]$Silent = $false
    )

    try {
        if ($null -eq $DTE) {
            if (!$Silent) { Write-Host "⚠️  DTE object is null - nothing to close" -ForegroundColor Yellow }
            return $true
        }

        # Close the solution first if one is open
        if ($null -ne $DTE.Solution) {
            if (!$Silent) {
                Write-Host "🔒 Closing solution..." -ForegroundColor Blue
                if ($SaveChanges) {
                    Write-Host "  💾 Saving changes before closing" -ForegroundColor Gray
                } else {
                    Write-Host "  ⚠️  Closing without saving changes" -ForegroundColor Yellow
                }
            }

            # Close the solution (equivalent to solution.Close(false) in C#)
            $DTE.Solution.Close($SaveChanges)

            if (!$Silent) { Write-Host "  ✅ Solution closed successfully" -ForegroundColor Green }
        } else {
            if (!$Silent) { Write-Host "  ℹ️  No solution was open" -ForegroundColor Gray }
        }

        # Quit the DTE instance completely
        if (!$Silent) { Write-Host "🔒 Closing TwinCAT XAE..." -ForegroundColor Blue }
        $DTE.Quit()

        if (!$Silent) { Write-Host "  ✅ TwinCAT XAE closed successfully" -ForegroundColor Green }
        return $true
    }
    catch {
        if (!$Silent) {
            Write-Host "  ❌ Error during shutdown: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $false
    }
}

function Save-AllProjects {
    <#
    .SYNOPSIS
    Saves all projects and the solution in a TwinCAT XAE environment.

    .DESCRIPTION
    This function iterates through all projects in the solution, saves each one (excluding virtual projects),
    and then saves the solution itself. Based on C# DTE automation patterns.

    .PARAMETER DTE
    The TwinCAT XAE DTE object instance

    .PARAMETER Silent
    Whether to suppress output messages (default: $false)

    .EXAMPLE
    Save-AllProjects -DTE $dte -Silent $false

    .RETURNS
    [bool] True if successful, false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.__ComObject]$DTE,

        [Parameter(Mandatory = $false)]
        [bool]$Silent = $false
    )

    try {
        if ($null -eq $DTE) {
            if (!$Silent) { Write-Host "  ❌ DTE object is null" -ForegroundColor Red }
            return $false
        }

        if ($null -eq $DTE.Solution) {
            if (!$Silent) { Write-Host "  ❌ Solution is null" -ForegroundColor Red }
            return $false
        }

        $sln = $DTE.Solution

        if (!$Silent) { Write-Host "💾 Saving all projects..." -ForegroundColor Blue }

        # Save individual projects
        if ($null -ne $sln.Projects) {
            for ($i = 1; $i -le $sln.Projects.Count; $i++) {
                $project = $sln.Projects.Item($i)

                # Skip virtual projects and folders (equivalent to vsProjectKindMisc)
                if ($project.Kind -eq $script:vsProjectKindMisc) {
                    if (!$Silent) { Write-Host "  ⏭️  Skipping virtual project: $($project.Name)" -ForegroundColor Gray }
                    continue
                }

                try {
                    $project.Save()
                    if (!$Silent) { Write-Host "  ✓ Saved project: $($project.Name)" -ForegroundColor Green }
                }
                catch {
                    if (!$Silent) { Write-Host "  ⚠️  Warning: Could not save project '$($project.Name)': $($_.Exception.Message)" -ForegroundColor Yellow }
                }
            }
        }

        # Save the solution
        try {
            $sln.SaveAs($sln.FullName)
            if (!$Silent) { Write-Host "  ✅ Solution saved successfully" -ForegroundColor Green }
            return $true
        }
        catch {
            if (!$Silent) { Write-Host "  ❌ Failed to save solution: $($_.Exception.Message)" -ForegroundColor Red }
            return $false
        }
    }
    catch {
        if (!$Silent) { Write-Host "  ❌ Error during save operation: $($_.Exception.Message)" -ForegroundColor Red }
        return $false
    }
}

# =============================================================================
# PLC PROJECT COMPILATION AND LIBRARY MANAGEMENT
# =============================================================================

function Invoke-PlcProjectCheckAllObjects {
    <#
    .SYNOPSIS
    Runs CheckAllObjects on a PLC project and returns validation results.

    .DESCRIPTION
    Executes the CheckAllObjects method on the specified PLC project, validates for errors and warnings,
    and returns a structured result object with validation status.

    .PARAMETER DTE
    The TwinCAT XAE DTE object instance

    .PARAMETER Project
    The PLC project object to check

    .PARAMETER Silent
    Whether to suppress output messages (default: $false)

    .EXAMPLE
    $result = Invoke-PlcProjectCheckAllObjects -DTE $dte -Project $plcProject

    .RETURNS
    Hashtable with validation results (Name, HasErrors, ErrorCount, WarningCount)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.__ComObject]$DTE,

        [Parameter(Mandatory = $true)]
        [System.__ComObject]$Project,

        [Parameter(Mandatory = $false)]
        [bool]$Silent = $false
    )

    $projectResult = @{
        Name = $Project.Name
        HasErrors = $false
        ErrorCount = 0
        WarningCount = 0
        LibraryPath = ""
        Status = "Processing"
    }

    try {
        if (!$Silent) {
            Write-Host "🔨 Processing: $($Project.Name)" -ForegroundColor Yellow
        }

        $sysManager = $Project.Object
        if ($null -eq $sysManager) {
            if (!$Silent) {
                Write-Host "  ❌ Could not get system manager for project: $($Project.Name)" -ForegroundColor Red
            }
            $projectResult.HasErrors = $true
            $projectResult.Status = "System Manager Error"
            return $projectResult
        }

        # Get PLC project reference
        $plcProjectPath = "$($Project.Name)^$($Project.Name) Project"
        $plcProject = $sysManager.LookupTreeItem($plcProjectPath)

        if ($null -eq $plcProject) {
            if (!$Silent) {
                Write-Host "  ❌ Could not find PLC project in system manager: $($Project.Name)" -ForegroundColor Red
            }
            $projectResult.HasErrors = $true
            $projectResult.Status = "PLC Project Not Found"
            return $projectResult
        }

        # Clear existing errors and compile
        Clear-ErrorList -DTE $DTE | Out-Null
        $plcProject.CheckAllObjects() | Out-Null

        # Check compilation results
        $errorResults = Get-ErrorList -DTE $DTE -ProjectName $Project.Name -IncludeWarnings $true
        $projectResult.ErrorCount = $errorResults.Errors.Count
        $projectResult.WarningCount = $errorResults.Warnings.Count
        $projectResult.HasErrors = ($errorResults.Errors.Count -gt 0)

        if ($projectResult.HasErrors) {
            if (!$Silent) {
                Write-Host "  ❌ Compilation failed: $($projectResult.ErrorCount) errors" -ForegroundColor Red
            }
            $projectResult.Status = "Compilation Failed"
        } else {
            if (!$Silent) {
                Write-Host "  ✅ Compilation successful" -ForegroundColor Green
                if ($projectResult.WarningCount -gt 0) {
                    Write-Host "  ⚠️  $($projectResult.WarningCount) warnings (proceeding)" -ForegroundColor Yellow
                }
            }
            $projectResult.Status = "Success"
        }

        return $projectResult
    }
    catch {
        if (!$Silent) {
            Write-Host "  ❌ Error during CheckAllObjects: $($_.Exception.Message)" -ForegroundColor Red
        }
        $projectResult.HasErrors = $true
        $projectResult.Status = "Compilation Failed"
        return $projectResult
    }
}

function Save-PlcProjectAsLibrary {
    <#
    .SYNOPSIS
    Saves a compiled PLC project as a library file.

    .DESCRIPTION
    Creates the library directory structure and saves the PLC project as a .library file
    for packaging. Only call this for successfully compiled projects.

    .PARAMETER DTE
    The TwinCAT XAE DTE object instance

    .PARAMETER Project
    The PLC project object to save as library

    .PARAMETER OutputDirectory
    Base directory where package folders should be created

    .PARAMETER Silent
    Whether to suppress output messages (default: $false)

    .EXAMPLE
    $success = Save-PlcProjectAsLibrary -DTE $dte -Project $plcProject -OutputDirectory "C:\PackageExamples"

    .RETURNS
    Hashtable with success status and library path
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.__ComObject]$DTE,

        [Parameter(Mandatory = $true)]
        [System.__ComObject]$Project,

        [Parameter(Mandatory = $true)]
        [string]$OutputDirectory,

        [Parameter(Mandatory = $false)]
        [bool]$Silent = $false
    )

    $result = @{
        Success = $false
        LibraryPath = ""
        ErrorMessage = ""
    }

    try {
        # Create library package directory structure
        $packageDir = Join-Path $OutputDirectory "$($Project.Name)LibPackage"
        $libraryPath = Join-Path $packageDir "$($Project.Name).library"

        if (!(Test-Path $packageDir)) {
            New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
            if (!$Silent) {
                Write-Host "  📁 Created package directory: $packageDir" -ForegroundColor Gray
            }
        }

        # Remove existing library file if it exists
        if (Test-Path $libraryPath) {
            Remove-Item $libraryPath -Force
        }

        # Get system manager and PLC project reference
        $sysManager = $Project.Object
        $plcProjectPath = "$($Project.Name)^$($Project.Name) Project"
        $plcProject = $sysManager.LookupTreeItem($plcProjectPath)

        if ($null -eq $plcProject) {
            $result.ErrorMessage = "Could not find PLC project in system manager"
            return $result
        }

        # Save as library
        $plcProject.SaveAsLibrary($libraryPath, $false)

        if (!$Silent) {
            Write-Host "  💾 Library saved: $($Project.Name).library" -ForegroundColor Green
        }

        $result.Success = $true
        $result.LibraryPath = $libraryPath
        return $result
    }
    catch {
        $result.ErrorMessage = $_.Exception.Message
        if (!$Silent) {
            Write-Host "  ❌ Failed to save library: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $result
    }
}

function Get-PlcProjectInfo {
    <#
    .SYNOPSIS
    Extracts detailed information from a PLC project by parsing its XML files.

    .DESCRIPTION
    Analyzes a TwinCAT PLC project to extract metadata such as company name, version,
    library name, and description from the project's XML configuration files.

    .PARAMETER DTE
    The TwinCAT XAE DTE object instance

    .PARAMETER Project
    The PLC project object to analyze

    .PARAMETER Silent
    Whether to suppress output messages (default: $false)

    .EXAMPLE
    $projectInfo = Get-PlcProjectInfo -DTE $dte -Project $plcProject

    .RETURNS
    Hashtable with project metadata (CompanyName, Version, LibraryName, Description)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.__ComObject]$DTE,

        [Parameter(Mandatory = $true)]
        [System.__ComObject]$Project,

        [Parameter(Mandatory = $false)]
        [bool]$Silent = $false
    )

    $projectInfo = @{
        CompanyName = "Unknown"
        Version = "0.0.0.0"
        LibraryName = $Project.Name
        Description = ""
        Author = ""
        XmlParsed = $false
        ErrorMessage = ""
    }

    try {
        # Get system manager and PLC project reference (same pattern as Save-PlcProjectAsLibrary)
        $sysManager = $Project.Object
        if ($null -eq $sysManager) {
            $projectInfo.ErrorMessage = "Could not get system manager for project"
            return $projectInfo
        }

        $plcProjectPath = "$($Project.Name)^$($Project.Name) Project"
        $plcProject = $sysManager.LookupTreeItem($plcProjectPath)

        if ($null -eq $plcProject) {
            $projectInfo.ErrorMessage = "Could not find PLC project in system manager"
            return $projectInfo
        }

        # Use ProduceXML() to get the project XML directly from TwinCAT
        $xmlContent = $plcProject.ProduceXML()

        if ([string]::IsNullOrEmpty($xmlContent)) {
            $projectInfo.ErrorMessage = "ProduceXML() returned empty content"
            return $projectInfo
        }

        # Parse the XML content
        [xml]$projectXml = $xmlContent

        # Navigate to ProjectInfo section: TreeItem -> IECProjectDef -> ProjectInfo
        $projectInfoNode = $projectXml.TreeItem.IECProjectDef.ProjectInfo

        if ($null -ne $projectInfoNode) {
            if ($null -ne $projectInfoNode.Company) {
                $projectInfo.CompanyName = $projectInfoNode.Company
            }

            if ($null -ne $projectInfoNode.Title) {
                $projectInfo.LibraryName = $projectInfoNode.Title
            }

            if ($null -ne $projectInfoNode.Version) {
                $projectInfo.Version = $projectInfoNode.Version
            }

            if ($null -ne $projectInfoNode.Description) {
                $projectInfo.Description = $projectInfoNode.Description
            }

            if ($null -ne $projectInfoNode.Author) {
                $projectInfo.Author = $projectInfoNode.Author
            }
        }

        $projectInfo.XmlParsed = $true

        if (!$Silent) {
            Write-Host "  ✅ XML parsing completed" -ForegroundColor Green
            Write-Host "    Company: $($projectInfo.CompanyName)" -ForegroundColor Gray
            Write-Host "    Version: $($projectInfo.Version)" -ForegroundColor Gray
            Write-Host "    Library: $($projectInfo.LibraryName)" -ForegroundColor Gray
            if ($projectInfo.Author) {
                Write-Host "    Author: $($projectInfo.Author)" -ForegroundColor Gray
            }
            if ($projectInfo.Description) {
                Write-Host "    Description: $($projectInfo.Description)" -ForegroundColor Gray
            }
        }

        return $projectInfo
    }
    catch {
        $projectInfo.ErrorMessage = $_.Exception.Message
        if (!$Silent) {
            Write-Host "  ❌ Error parsing project XML: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $projectInfo
    }
}

# =============================================================================
# ERROR LIST MANAGEMENT
# =============================================================================

function Get-ObjectPropertyReflection {
    <#
    .SYNOPSIS
    Helper function to retrieve property of an object by type and name using reflection.

    .DESCRIPTION
    Uses reflection to access object properties, particularly useful for DTE objects.

    .PARAMETER Type
    The type of the object

    .PARAMETER PropertyName
    The name of the property to retrieve

    .PARAMETER Object
    The object instance

    .RETURNS
    The property value
    #>
    param($Type, $PropertyName, $Object)

    $type = [type]$Type
    $ref = $type.GetProperties() | Where-Object Name -eq $PropertyName
    return $ref.GetGetMethod($true).Invoke($Object, @())
}

function Get-ErrorList {
    <#
    .SYNOPSIS
    Gets errors and warnings from the Visual Studio error list.

    .DESCRIPTION
    Retrieves compilation errors and warnings from the TwinCAT XAE error list,
    with optional project filtering and warning inclusion.

    .PARAMETER DTE
    The TwinCAT XAE DTE object instance

    .PARAMETER ProjectName
    Optional project name to filter results (default: empty = all projects)

    .PARAMETER IncludeWarnings
    Whether to include warnings in results (default: $true)

    .EXAMPLE
    $results = Get-ErrorList -DTE $dte -ProjectName "MyProject"

    .RETURNS
    Hashtable with Errors, Warnings, and Count properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.__ComObject]$DTE,

        [Parameter(Mandatory = $false)]
        [string]$ProjectName = "",

        [Parameter(Mandatory = $false)]
        [bool]$IncludeWarnings = $true
    )

    try {
        # Activate the error list window in VS
        $DTE.ExecuteCommand("View.ErrorList", " ")

        # Get the error list DTE objects
        $toolWindows = Get-ObjectPropertyReflection "EnvDTE80.DTE2" "ToolWindows" $DTE
        $errorItems = Get-ObjectPropertyReflection "EnvDTE80.ErrorList" "ErrorItems" $toolWindows.ErrorList

        $results = @{
            Errors = @()
            Warnings = @()
            Count = $errorItems.Count
        }

        $headerPrinted = $false

        # Iterate through error list items
        foreach ($errorItem in $errorItems) {
            $level = Get-ObjectPropertyReflection "EnvDTE80.ErrorItem" "ErrorLevel" $errorItem
            $desc = Get-ObjectPropertyReflection "EnvDTE80.ErrorItem" "Description" $errorItem
            $file = ""
            $line = 0
            $column = 0
            $project = ""

            try {
                $file = Get-ObjectPropertyReflection "EnvDTE80.ErrorItem" "FileName" $errorItem
                $line = Get-ObjectPropertyReflection "EnvDTE80.ErrorItem" "Line" $errorItem
                $column = Get-ObjectPropertyReflection "EnvDTE80.ErrorItem" "Column" $errorItem
                $project = Get-ObjectPropertyReflection "EnvDTE80.ErrorItem" "Project" $errorItem
            }
            catch {
                # Some properties might not be available for all error types
            }

            $errorInfo = @{
                Level = $level
                Description = $desc
                File = $file
                Line = $line
                Column = $column
                Project = $project
            }

            # Filter by project name if specified
            if ($ProjectName -ne "" -and $project -notlike "*$ProjectName*") {
                continue
            }

            # TwinCAT uses string-based error levels: vsBuildErrorLevelHigh = Error, vsBuildErrorLevelMedium = Warning
            if ($level -eq "vsBuildErrorLevelHigh" -or $level -eq 4) {
                # Print header only when we have actual errors/warnings to show
                if (-not $headerPrinted) {
                    Write-Host "Severity`tCode`tDescription`tFile`tLine" -ForegroundColor White
                    Write-Host "--------`t----`t-----------`t----`t----" -ForegroundColor White
                    $headerPrinted = $true
                }

                $results.Errors += $errorInfo
                # Format like VS error list: Severity  Code  Description  File  Line
                $fileName = if ($file) { [System.IO.Path]::GetFileName($file) } else { "" }
                $errorCode = if ($desc -match '^([^:]+):') { $matches[1] } else { "" }
                $description = if ($desc -match '^[^:]+:\s*(.+)') { $matches[1] } else { $desc }
                Write-Host "Error`t$errorCode`t$description`t$fileName`t$line" -ForegroundColor Red
            }
            elseif (($level -eq "vsBuildErrorLevelMedium" -or $level -eq 2) -and $IncludeWarnings) {
                # Print header only when we have actual errors/warnings to show
                if (-not $headerPrinted) {
                    Write-Host "Severity`tCode`tDescription`tFile`tLine" -ForegroundColor White
                    Write-Host "--------`t----`t-----------`t----`t----" -ForegroundColor White
                    $headerPrinted = $true
                }

                $results.Warnings += $errorInfo
                # Format like VS error list: Severity  Code  Description  File  Line
                $fileName = if ($file) { [System.IO.Path]::GetFileName($file) } else { "" }
                $errorCode = if ($desc -match '^([^:]+):') { $matches[1] } else { "" }
                $description = if ($desc -match '^[^:]+:\s*(.+)') { $matches[1] } else { $desc }
                Write-Host "Warning`t$errorCode`t$description`t$fileName`t$line" -ForegroundColor Yellow
            }
        }

        return $results
    }
    catch {
        Write-Host "Error accessing error list: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Errors = @()
            Warnings = @()
            Count = 0
        }
    }
}

function Clear-ErrorList {
    <#
    .SYNOPSIS
    Clears the Visual Studio error list.

    .DESCRIPTION
    Clears the error list by refreshing the error list window.

    .PARAMETER DTE
    The TwinCAT XAE DTE object instance

    .EXAMPLE
    Clear-ErrorList -DTE $dte

    .RETURNS
    [bool] True if successful, false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.__ComObject]$DTE
    )

    try {
        # Clear the error list by rebuilding/refreshing
        $DTE.ExecuteCommand("View.ErrorList", " ")
        return $true
    }
    catch {
        Write-Host "Could not clear error list: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}



# =============================================================================
# MODULE EXPORTS
# =============================================================================

# Export only the public functions
Export-ModuleMember -Function @(
    'Initialize-Automation',
    'Close-Automation',
    'Open-ExistingTcProject',
    'Get-PlcProjects',
    'Close-Solution',
    'Save-AllProjects',
    'Invoke-PlcProjectCheckAllObjects',
    'Save-PlcProjectAsLibrary',
    'Get-PlcProjectInfo',
    'Get-ErrorList',
    'Clear-ErrorList'
)