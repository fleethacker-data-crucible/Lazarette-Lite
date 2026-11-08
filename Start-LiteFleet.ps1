#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Launcher, [string[]]$LauncherArgs)

$launcherPath = (Get-Item -LiteralPath $Launcher -ErrorAction Stop).FullName
$previousPath = $env:LAZARETTE_PATH
$previousArcPath = $env:ARC_PATH
try {
# Fallback precedence for Fleet tools that read secrets through Get-FleetSecret
# (lib/Resolver.ps1): full Lazarette first (LAZARETTE_PATH / ARC_PATH / a sibling
# Lazarette folder, only when its vault unlocks), then Lazarette Lite. This
# wrapper points LAZARETTE_PATH at Lite itself, so under it Get-FleetSecret
# answers from Lite unless a full Lazarette checkout is also configured.
    $env:LAZARETTE_PATH = $PSScriptRoot
    $env:ARC_PATH = $PSScriptRoot
    & $launcherPath @LauncherArgs
} finally {
    $env:LAZARETTE_PATH = $previousPath
    $env:ARC_PATH = $previousArcPath
}
