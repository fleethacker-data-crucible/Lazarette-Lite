#requires -Version 5.1
<#
.SYNOPSIS
  Makes the Fleet tools use Lazarette Lite in place of Lazarette, once per Windows user. No admin, nothing installed.
.DESCRIPTION
  Fleet tools (Halyard, Eight Bells, Semaphore, TalkForge and others) look for Lazarette in the folder named by
  an environment variable, then in a folder called Lazarette next to their own, then in
  %USERPROFILE%\Projects\Lazarette; the folder must hold lib\Lazarette.ps1. This script points the variables at
  this Lazarette Lite folder in the user's environment, so every tool started afterwards (a new window, a
  double-clicked launcher) loads Lite's lib\Lazarette.ps1 and reads Windows Credential Manager, with no change
  to any tool and without Lazarette installed.
    LAZARETTE_PATH            Halyard, Eight Bells, Semaphore: the Lazarette integration contract
    ARC_PATH                  TalkForge: the older name of the same contract (lib\Arc.ps1)
    GANGPLANK_LAZARETTE_PATH  Gangplank, which only ever uses a folder it was explicitly given
  A variable that already points at a working Lazarette (a folder with lib\Lazarette.ps1 that is not this one)
  is left alone unless -Force is given: the full Lazarette wins when it is installed. A variable that is unset,
  or that points at a folder which no longer has lib\Lazarette.ps1, is set. -Unregister removes the variables
  that point at this folder and leaves every other value alone.
  Tools already open keep their old environment; start them again.
.PARAMETER Scope
  User (default): saved in the user's environment for every new process. Process: this PowerShell session only,
  the same effect as Start-LiteFleet.ps1 for one launch.
.EXAMPLE
  .\Register-LazaretteLite.ps1             # or: Launch-LazaretteLite.bat --register
  .\Register-LazaretteLite.ps1 -Unregister
  .\Register-LazaretteLite.ps1 -WhatIf     # show what would change
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Unregister,
    [switch]$Force,
    [ValidateSet('User', 'Process')][string]$Scope = 'User',
    [string]$Root = $PSScriptRoot
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($Root).TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $root 'lib\Lazarette.ps1') -PathType Leaf)) { throw "No Lazarette Lite loader at $root\lib\Lazarette.ps1." }
$variables = @('LAZARETTE_PATH', 'ARC_PATH', 'GANGPLANK_LAZARETTE_PATH')

function Get-LiteRegistrationFolder {
    # The folder a variable names, trimmed the way the tools trim it, or '' when it is unset.
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    return $Value.Trim().Trim('"').Trim("'")
}

function Test-LiteRegistrationTarget {
    # Does this value point at a usable install (a folder with lib\Lazarette.ps1)?
    param([string]$Value)
    $folder = Get-LiteRegistrationFolder $Value
    if (-not $folder) { return $false }
    try { return (Test-Path -LiteralPath (Join-Path $folder 'lib\Lazarette.ps1') -PathType Leaf) } catch { return $false }
}

function Test-LiteRegistrationIsThisFolder {
    param([string]$Value)
    $folder = Get-LiteRegistrationFolder $Value
    if (-not $folder) { return $false }
    try { return ([IO.Path]::GetFullPath($folder).TrimEnd('\') -ieq $root) } catch { return $false }
}

$rows = foreach ($name in $variables) {
    $current = [Environment]::GetEnvironmentVariable($name, $Scope)
    $value = $current
    if ($Unregister) {
        if (Test-LiteRegistrationIsThisFolder $current) { $action = 'removed'; $value = $null }
        elseif ([string]::IsNullOrWhiteSpace($current)) { $action = 'not set' }
        else { $action = 'kept (not this folder)' }
    } elseif (Test-LiteRegistrationIsThisFolder $current) {
        $action = 'already set'
    } elseif ([string]::IsNullOrWhiteSpace($current)) {
        $action = 'set'; $value = $root
    } elseif (Test-LiteRegistrationTarget $current) {
        if ($Force) { $action = 'replaced (-Force)'; $value = $root } else { $action = 'kept (another Lazarette; -Force overrides)' }
    } else {
        $action = 'replaced (stale: no lib\Lazarette.ps1 there)'; $value = $root
    }
    $changes = ($action -eq 'set' -or $action -eq 'removed' -or $action -like 'replaced*')
    $what = "set to $root"; if ($null -eq $value) { $what = 'remove' }
    if ($changes -and $PSCmdlet.ShouldProcess("$name ($Scope)", $what)) {
        [Environment]::SetEnvironmentVariable($name, $value, $Scope)
        # The saved value reaches new processes only; this session gets it now too.
        if ($Scope -eq 'User') { [Environment]::SetEnvironmentVariable($name, $value, 'Process') }
    }
    $shown = ''; if ($null -ne $value) { $shown = [string]$value }
    [pscustomobject]@{ Variable = $name; Action = $action; Value = $shown }
}
if ($Unregister) { Write-Host 'Fleet tools started from now on look for Lazarette again. Tools already open keep their old setting.' }
else { Write-Host "Fleet tools started from now on use Lazarette Lite at $root. Tools already open keep their old setting; start them again." }
$rows
