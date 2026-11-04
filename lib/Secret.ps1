#requires -Version 5.1
# =============================================================================
# The script-facing API. These mirror the integration API in Lazarette's
# lib\cli\Console.ps1 (Get-ArcSecret, Get-ArcItemNames) so a script can move to
# the full vault by changing the verb noun only:  Get-LiteSecret -> Get-ArcSecret.
# Same parameters, same return type (a plain string), same failure style (throw).
#
#   Get-ArcSecret  -Service <s> [-User <u>] [-Field <f>]
#   Get-LiteSecret -Service <s> [-User <u>] [-Field <f>]     (-Name works as an alias of -Service)
#
# Differences, on purpose:
#   * There is no lock. Windows already unlocks Credential Manager with the user's session,
#     so Lite never prompts and has no Unlock-... step.
#   * Lite items have no custom fields, so -Field always fails the way Lazarette does for a
#     field that does not exist.
#   * An item with no secret yet (an import placeholder) throws instead of returning ''.
# =============================================================================

function Get-LiteSecret {
    <#
    .SYNOPSIS
        Returns the secret of exactly one item, as a string. Throws if it is missing, ambiguous or empty.
    .EXAMPLE
        $token = Get-LiteSecret -Service gitlab -User anthony
    .EXAMPLE
        $token = Get-LiteSecret -Name gitlab        # -Name is the same as -Service
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Alias('Name')][string]$Service,
        [string]$User = '',
        [string]$Field = ''
    )
    $item = Resolve-LiteCredential -Service $Service -User $User
    if ($Field) { throw "Lazarette Lite item '$Service' has no field '$Field'. Lite keeps one secret per item; custom fields are a Lazarette feature." }
    $raw = & (Get-LiteBackend).Read $item.Target
    if ($null -eq $raw) { throw "Lazarette Lite item '$Service' disappeared while it was being read." }
    $s = [string]$raw.Secret
    if ($s.Length -eq 0) { throw "Lazarette Lite item '$Service' has no secret yet. Set one with Set-LiteCredential -Service '$Service' -Secret ..." }
    return $s
}

function Get-LiteItemNames {
    <#
    .SYNOPSIS
        Lists service, user, type and tags, like Get-ArcItemNames. Names only, never secrets.
    #>
    [CmdletBinding()]
    param()
    return @(Get-LiteCredential | ForEach-Object { [pscustomobject]@{ Service = $_.Service; User = $_.User; Type = 'login'; Tags = @() } })
}
