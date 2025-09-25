﻿$RepToolLocations = @(Join-Path "C:\Program Files (x86)\Beckhoff\TwinCAT\3.1\Components\Plc\Build_4026.*\" "Common\RepTool.exe" -Resolve)
if ($RepToolLocations.Length -gt 0) {
	$RepToolLocation = $RepToolLocations[$RepToolLocations.Length-1]
	$index = $RepToolLocation.IndexOf("\Build_4026.")
	$plcProfile = $RepToolLocation.Substring($index + 1)
	$index = $plcProfile.IndexOf("\Common\RepTool.exe")
	$plcProfile = $plcProfile.Substring(0, $index)
	$RepToolArgs = "--profile=`"TwinCAT PLC Control_$plcProfile`"", "--uninstallLib `"ControlAlgorithm, 0.0.0.1 (Beckhoff Automation LLC.)`""
	Start-Process $RepToolLocations[$RepToolLocations.Length-1] -ArgumentList $RepToolArgs -Wait -WindowStyle Hidden
}