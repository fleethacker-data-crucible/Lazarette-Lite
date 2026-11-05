#requires -Version 5.1
# =============================================================================
# The Lazarette 5 integration contract (Lazarette docs/INTEGRATION.md), answered by Lazarette Lite.
#
# A Fleet tool finds a folder that holds lib\Lazarette.ps1 (LAZARETTE_PATH, a folder named Lazarette next
# to the tool, or %USERPROFILE%\Projects\Lazarette), dot-sources it once, and calls:
#   Unlock-LazaretteVaultInteractive [-DataDir d]   -> $true / $false
#   Test-LazaretteVaultUnlocked                     -> $true / $false
#   Get-LazaretteSecret -Service s [-User u] [-Field f]
#   Get-LazaretteItemNames
#   Lock-LazaretteVault
# Point LAZARETTE_PATH at this folder (Register-LazaretteLite.ps1 does it once per user) and every such
# tool reads Windows Credential Manager through Lite instead, with no change to the tool and without
# Lazarette installed.
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
# Eight Bells dot-source it at script scope; both work: this file defines plain functions and imports
# the module into whatever scope it is loaded in.
# =============================================================================
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'LazaretteLite.psd1') -ErrorAction Stop

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
