#requires -Version 5.1
$moduleLoading = Get-Variable -Name 'LazaretteLiteLoading' -Scope 'Script' -ErrorAction SilentlyContinue
if (($null -eq $moduleLoading -or -not $moduleLoading.Value) -and -not (Get-Module LazaretteLite)) {
    # Standalone dot-source (a Fleet launcher that did not Import-Module first).
    # While LazaretteLite.psm1 is loading it sets $script:LazaretteLiteLoading,
    # so this branch is skipped and the import cannot recurse into the module
    # that is dot-sourcing this file. Get-Module alone is not enough: while the
    # psm1 is executing, the module is not yet in the loaded-module table, so
    # that check returns nothing and the import recursed to the 10-level
    # nesting limit (Modules_ModuleTooDeeplyNested, Lite v5).
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'LazaretteLite.psd1') -ErrorAction Stop
}

# Fleet fallback precedence (see lib/Resolver.ps1, Get-FleetSecret):
#   1. Full Lazarette, when a Lazarette checkout is found and its vault unlocks.
#   2. Lazarette Lite (this file): Windows Credential Manager under the Lite prefix.
# This file is the Lite half: Get-LazaretteSecret forwards to Get-LiteSecret, and
# -Field always throws â€” Lite keeps one secret per item, no custom fields, no TOTP,
# no attachments, no history, no Fairlead peer API. Those need full Lazarette.
# LazaretteLite.psm1 dot-sources this file after Secret.ps1; it must not
# Import-Module the manifest unconditionally (that would recurse while the
# module is loading) â€” see the guarded import above.

<#
.SYNOPSIS
    Reports Lite as unlocked. Its unlock is a no-op success; there is no vault to test.
#>
function Unlock-LazaretteVaultInteractive {
    param([string]$DataDir)
    if ($DataDir) { throw 'Lazarette Lite uses Windows Credential Manager and has no vault directory.' }
    [void]@(Get-LiteCredential -ErrorAction Stop)
    return $true
}

<#
.SYNOPSIS
    Reads one secret from Lazarette Lite by service and user, with the Lazarette calling shape.
#>
function Get-LazaretteSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Alias('Name')][string]$Service,
        [string]$User,
        [string]$Field
    )
    Get-LiteSecret @PSBoundParameters
}

<#
.SYNOPSIS
    Lists the item names Lite knows, with the Lazarette calling shape.
#>
function Get-LazaretteItemNames { Get-LiteItemNames }
