#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Launcher, [string[]]$LauncherArgs)

$launcherPath = (Get-Item -LiteralPath $Launcher -ErrorAction Stop).FullName
$previousPath = $env:LAZARETTE_PATH
$previousArcPath = $env:ARC_PATH
try {
    $env:LAZARETTE_PATH = $PSScriptRoot
    $env:ARC_PATH = $PSScriptRoot
    & $launcherPath @LauncherArgs
} finally {
    $env:LAZARETTE_PATH = $previousPath
    $env:ARC_PATH = $previousArcPath
}
