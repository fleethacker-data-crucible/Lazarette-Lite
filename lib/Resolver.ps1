#requires -Version 5.1
# =============================================================================
# Fleet secret resolver: full Lazarette first, Lazarette Lite as the fallback.
# One function for Fleet tools that should work whether or not Lazarette is
# running or even present on the machine:
#
#   Get-FleetSecret -Service <name> [-User <user>] [-Field <field>]
#
# Precedence, per item:
#   1. Full Lazarette, when a Lazarette checkout is found (Find-FleetSecretRoot)
#      and its vault unlocks. This is the only path that can answer -Field,
#      TOTP, attachments or history.
#   2. Lazarette Lite: Windows Credential Manager under the Lite prefix
#      (Get-LiteSecret). -Field always throws here, by Lite's design.
#
# Errors name which store answered or failed: if both miss, the throw names
# Lazarette, Lazarette Lite and the item. Success is reported with
# Write-Verbose naming the store that answered.
#
# Notes:
#   * A checkout counts as full Lazarette only when it has BOTH
#     lib/Lazarette.ps1 AND lib/cli/Console.ps1 (where the full engine's
#     Get-LazaretteSecret lives). This matters because Start-LiteFleet.ps1
#     points LAZARETTE_PATH at Lite itself; Lite has no lib/cli folder, so it
#     is never mistaken for the full engine.
#   * Dot-sourcing the full engine redefines Get-LazaretteSecret,
#     Unlock-LazaretteVaultInteractive and Get-LazaretteItemNames in this
#     session (the engine's versions replace Lite's). Get-FleetSecret saves
#     Lite's versions first and restores them in a finally block, so a call
#     that falls back to Lite â€” or a later Lite-only call â€” is unaffected.
#   * Unlocking the full vault may prompt (passphrase / PIN / 2FA), exactly as
#     calling Unlock-LazaretteVaultInteractive directly would. There is no
#     Fairlead peer route here: that is real crypto work needing design
#     review, and a peer that needs it must talk to full Lazarette.
# =============================================================================

function Find-FleetSecretRoot {
    <#
    .SYNOPSIS
        Finds a full Lazarette checkout, or returns $null when there is none.
    .DESCRIPTION
        Checks, in order: $env:LAZARETTE_PATH, $env:ARC_PATH, then a Lazarette
        folder next to the Lite repo root (a sibling checkout). Each candidate
        may point at the repo root or at its lib folder. -NoSibling skips the
        sibling probe (used by tests and by callers that already configured a path).
    #>
    [CmdletBinding()]
    param([switch]$NoSibling)
    $candidates = @()
    if ($env:LAZARETTE_PATH) { $candidates += $env:LAZARETTE_PATH }
    if ($env:ARC_PATH) { $candidates += $env:ARC_PATH }
    if (-not $NoSibling) {
        $liteRoot = Split-Path $PSScriptRoot -Parent
        $candidates += (Join-Path (Split-Path $liteRoot -Parent) 'Lazarette')
    }
    foreach ($c in $candidates) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        $loader = Join-Path $c 'lib\Lazarette.ps1'
        $console = Join-Path $c 'lib\cli\Console.ps1'
        if ((Test-Path -LiteralPath $loader -PathType Leaf) -and (Test-Path -LiteralPath $console -PathType Leaf)) {
            return (Get-Item -LiteralPath $c).FullName
        }
        if ((Split-Path $c -Leaf) -ieq 'lib') {
            $loader = Join-Path $c 'Lazarette.ps1'
            $console = Join-Path $c 'cli\Console.ps1'
            if ((Test-Path -LiteralPath $loader -PathType Leaf) -and (Test-Path -LiteralPath $console -PathType Leaf)) {
                return (Get-Item -LiteralPath (Split-Path $c -Parent)).FullName
            }
        }
    }
    return $null
}

function Get-FleetSecret {
    <#
    .SYNOPSIS
        Returns the secret of exactly one item: full Lazarette first, Lite as fallback.
    .EXAMPLE
        $token = Get-FleetSecret -Service gitlab -User anthony
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][Alias('Name')][string]$Service,
        [string]$User = '',
        [string]$Field = '',
        [switch]$NoSibling
    )
    $itemDesc = "'$Service'"
    if ($User) { $itemDesc += " for user '$User'" }
    $lazRoot = Find-FleetSecretRoot -NoSibling:$NoSibling
    $lazErr = $null
    if ($lazRoot) {
        $saved = @{}
        foreach ($n in 'Get-LazaretteSecret', 'Unlock-LazaretteVaultInteractive', 'Get-LazaretteItemNames') {
            $cmd = Get-Command $n -CommandType Function -ErrorAction SilentlyContinue
            if ($cmd) { $saved[$n] = $cmd.ScriptBlock }
        }
        try {
            . (Join-Path $lazRoot 'lib\Lazarette.ps1')
            $unlocked = $false
            try { $unlocked = Unlock-LazaretteVaultInteractive } catch { $lazErr = $_.Exception.Message }
            if ($unlocked) {
                $lazArgs = @{ Service = $Service }
                if ($User) { $lazArgs.User = $User }
                if ($Field) { $lazArgs.Field = $Field }
                Write-Verbose "Get-FleetSecret: answered by Lazarette ($lazRoot)."
                return (Get-LazaretteSecret @lazArgs)
            }
            if (-not $lazErr) { $lazErr = 'the Lazarette vault did not unlock' }
        } catch {
            if (-not $lazErr) { $lazErr = $_.Exception.Message }
        } finally {
            foreach ($n in @($saved.Keys)) { Set-Item -Path "function:$n" -Value $saved[$n] }
        }
    } else {
        $lazErr = 'no Lazarette checkout found (LAZARETTE_PATH, ARC_PATH, or a sibling Lazarette folder)'
    }
    try {
        $liteArgs = @{ Service = $Service }
        if ($User) { $liteArgs.User = $User }
        if ($Field) { $liteArgs.Field = $Field }
        Write-Verbose 'Get-FleetSecret: answered by Lazarette Lite.'
        return (Get-LiteSecret @liteArgs)
    } catch {
        $liteErr = $_.Exception.Message
        $lazWhere = if ($lazRoot) { "Lazarette ($lazRoot)" } else { 'Lazarette (no checkout found)' }
        throw "Get-FleetSecret: no secret for item $itemDesc. $lazWhere failed: $lazErr Lazarette Lite failed: $liteErr"
    }
}