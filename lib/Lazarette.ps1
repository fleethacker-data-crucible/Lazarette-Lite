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

# The Lazarette 5 integration contract (Lazarette docs/INTEGRATION.md), answered by Lazarette Lite.
#
# A Fleet tool finds a folder that holds lib\Lazarette.ps1 (LAZARETTE_PATH, a folder named Lazarette next
# to the tool, or %USERPROFILE%\Projects\Lazarette), dot-sources it once, and calls:
#   Unlock-LazaretteVaultInteractive [-DataDir d]   -> $true / $false
#   Test-LazaretteVaultUnlocked                     -> $true / $false
#   Get-LazaretteSecret -Service s [-User u] [-Field f]
#   Get-LazaretteItemNames
#   Lock-LazaretteVault
#
# Fleet fallback precedence (see lib/Resolver.ps1, Get-FleetSecret):
#   1. Full Lazarette, when a Lazarette checkout is found and its vault unlocks.
#   2. Lazarette Lite (this file): Windows Credential Manager under the Lite prefix.
# This file is the Lite half. -Field always throws: Lite keeps one secret per item,
# no custom fields, no TOTP, no attachments, no history, no Fairlead peer API.
#
# What is different here, on purpose:
#   * There is no lock. Windows opens Credential Manager with the user's session, so "unlocked" means
#     this process can read the store; unlocking asks nothing and never prompts.
#   * An item has one secret and no custom fields, so -Field fails the way Lazarette fails for a field
#     an item does not have. An item with no secret yet (an import placeholder) throws instead of
#     returning '', so a tool fails early instead of running with an empty password.
#   * -DataDir is accepted and ignored: Lite has no vault directory.
#
# Halyard and Gangplank load this file inside a dynamic module (New-Module { . $loader }), Semaphore and
# Eight Bells dot-source it at script scope. Both work: this file defines plain functions, and it imports
# the module only when this file is not already being loaded by that module.

function Test-LazaretteVaultUnlocked {
    <#
    .SYNOPSIS
        $true when Windows Credential Manager answers this process under the Lite prefix. Never prompts.
    #>
    [CmdletBinding()]
    param()
    try { [void]@(Get-LiteCredential -ErrorAction Stop); return $true } catch { return $false }
}

function Unlock-LazaretteVaultInteractive {
    <#
    .SYNOPSIS
        Nothing to unlock: reports whether the store can be read, with a warning saying why when it cannot.
    #>
    [CmdletBinding()]
    param([string]$DataDir)
    if ($DataDir) { Write-Verbose 'Lazarette Lite keeps secrets in Windows Credential Manager; -DataDir is ignored.' }
    try { [void]@(Get-LiteCredential -ErrorAction Stop); return $true }
    catch { Write-Warning ('Lazarette Lite could not open Windows Credential Manager: ' + $_.Exception.Message); return $false }
}

function Get-LazaretteSecret {
    <#
    .SYNOPSIS
        The secret of exactly one item, as a string. Throws when it is missing, ambiguous (pass -User) or empty.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Alias('Name')][string]$Service,
        [string]$User = '',
        [string]$Field = ''
    )
    return (Get-LiteSecret -Service $Service -User $User -Field $Field)
}

function Get-LazaretteItemNames {
    <#
    .SYNOPSIS
        Service, user, type and tags of every item. Names only, never a secret.
    #>
    [CmdletBinding()]
    param()
    return @(Get-LiteItemNames)
}

function Lock-LazaretteVault {
    <#
    .SYNOPSIS
        Lite holds no key material in memory, so there is nothing to zeroise. Kept so the contract is complete.
    #>
    [CmdletBinding()]
    param()
}
