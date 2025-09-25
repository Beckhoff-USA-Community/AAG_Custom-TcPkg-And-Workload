#
# ErrorListHelper.ps1 - Helper functions for capturing VS error list
#

# Hard reference DTE2 assembly
Add-Type -Path "C:\Program Files\Beckhoff\TcXaeShell\Common7\IDE\PublicAssemblies\envdte80.dll"

# Helper function to retrieve property of an object by type and name using reflection
Function Get-ObjectPropertyReflection {
    param($type, $propertyName, $obj)
    $type = [type]$type
    $ref = $type.GetProperties() | Where-Object Name -eq $propertyName
    return $ref.GetGetMethod($true).Invoke($obj, @())
}

# Function to get errors and warnings from the Visual Studio error list
Function Get-ErrorList {
    param(
        [Parameter(Mandatory=$true)]
        $DTE,
        [string]$ProjectName = "",
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

        #Write-Host "Found $($errorItems.Count) total items in error list"

        # Print header like VS error list
        if ($errorItems.Count -gt 0) {
            Write-Host "Severity`tCode`tDescription`tFile`tLine" -ForegroundColor White
            Write-Host "--------`t----`t-----------`t----`t----" -ForegroundColor White
        }

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
                $results.Errors += $errorInfo
                # Format like VS error list: Severity  Code  Description  File  Line
                $fileName = if ($file) { [System.IO.Path]::GetFileName($file) } else { "" }
                $errorCode = if ($desc -match '^([^:]+):') { $matches[1] } else { "" }
                $description = if ($desc -match '^[^:]+:\s*(.+)') { $matches[1] } else { $desc }
                Write-Host "Error`t$errorCode`t$description`t$fileName`t$line" -ForegroundColor Red
            }
            elseif (($level -eq "vsBuildErrorLevelMedium" -or $level -eq 2) -and $IncludeWarnings) {
                $results.Warnings += $errorInfo
                # Format like VS error list: Severity  Code  Description  File  Line
                $fileName = if ($file) { [System.IO.Path]::GetFileName($file) } else { "" }
                $errorCode = if ($desc -match '^([^:]+):') { $matches[1] } else { "" }
                $description = if ($desc -match '^[^:]+:\s*(.+)') { $matches[1] } else { $desc }
                Write-Host "Warning`t$errorCode`t$description`t$fileName`t$line" -ForegroundColor Yellow
            }
        }

        #Write-Host "Summary: $($results.Errors.Count) errors, $($results.Warnings.Count) warnings"
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

# Function to clear the error list
Function Clear-ErrorList {
    param(
        [Parameter(Mandatory=$true)]
        $DTE
    )

    try {
        # Clear the error list by rebuilding/refreshing
        $DTE.ExecuteCommand("View.ErrorList", " ")
    }
    catch {
        Write-Host "Could not clear error list: $($_.Exception.Message)" -ForegroundColor Red
    }
}