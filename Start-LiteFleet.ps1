#requires -Version 5.1
# One launch with Lazarette Lite in place of Lazarette, without saving anything: sets the discovery variables
# for the launcher and its children only. Register-LazaretteLite.ps1 does the same once for every new process.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Launcher, [string[]]$LauncherArgs)

$launcherPath = (Get-Item -LiteralPath $Launcher -ErrorAction Stop).FullName
$previousPath = $env:LAZARETTE_PATH
$previousArcPath = $env:ARC_PATH
$previousGangplankPath = $env:GANGPLANK_LAZARETTE_PATH
try {
    $env:LAZARETTE_PATH = $PSScriptRoot
    $env:ARC_PATH = $PSScriptRoot
    $env:GANGPLANK_LAZARETTE_PATH = $PSScriptRoot
    & $launcherPath @LauncherArgs
} finally {
    $env:LAZARETTE_PATH = $previousPath
    $env:ARC_PATH = $previousArcPath
    $env:GANGPLANK_LAZARETTE_PATH = $previousGangplankPath
}
