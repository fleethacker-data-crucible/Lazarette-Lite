#requires -Version 5.1
# =============================================================================
# Command-line access for scripts and agents that are not PowerShell modules, the way Lazarette offers it
# (lib\cli\Cli.ps1 there; tools\lazarette.ps1 is the thin wrapper in both). Same verbs, output shapes and
# exit codes for what Lite can answer:
#   status                      store, prefix and item count; no secrets
#   items                       names only (service, user, type, tags, hasTotp)
#   get <service> [-User u]     the secret on the output
#   check <name>...             present / missing / ambiguous per name; exit 3 if any is not present
# Not offered by Lite: totp (no authenticator secrets), run and -Field (no custom fields), -Type and -Tag.
# Exit codes: 0 ok, 1 usage or error, 2 locked (here: the store cannot be read), 3 not found or ambiguous.
# =============================================================================
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'LazaretteLite.psd1') -ErrorAction Stop

function New-LiteCliResult {
    param([int]$Code = 0, $Data = $null, [string]$Text = '')
    return [pscustomobject]@{ Code = $Code; Data = $Data; Text = $Text }
}

function Test-LiteCliStore {
    # $null when the store can be read; otherwise a result with exit code 2, like a locked Lazarette.
    try { [void]@(Get-LiteCredential -ErrorAction Stop); return $null }
    catch { return (New-LiteCliResult -Code 2 -Data ([ordered]@{ error = 'locked'; message = $_.Exception.Message }) -Text ('Windows Credential Manager could not be read: ' + $_.Exception.Message)) }
}

function Invoke-LiteCli {
    [CmdletBinding()]
    param(
        [string]$Verb = 'help', [string[]]$Name = @(), [string]$User = '', [string]$Field = '',
        [string]$Type = '', [string]$Tag = '', [switch]$NoPrompt
    )
    $nl = [Environment]::NewLine
    switch ($Verb.ToLowerInvariant()) {
        'help' {
            $t = @('lazarette status | items | get <service> [-User u] | check <name>...',
                '  Lazarette Lite answers these four verbs of the Lazarette command line; totp, run, -Field, -Type and -Tag need the full Lazarette.',
                '  Add -Json for machine output. Exit codes: 0 ok, 1 usage or error, 2 store unreadable, 3 not found or ambiguous.') -join $nl
            return (New-LiteCliResult -Code 0 -Data ([ordered]@{ verbs = @('status', 'items', 'get', 'check') }) -Text $t)
        }
        'status' {
            $prefix = ''; $err = ''; $count = 0; $ok = $false
            try { $prefix = Get-LitePrefix; $count = @(Get-LiteCredential).Count; $ok = $true } catch { $err = $_.Exception.Message }
            $version = ''; $m = Get-Module LazaretteLite | Select-Object -First 1; if ($m) { $version = $m.Version.ToString() }
            $d = [ordered]@{ product = 'Lazarette Lite'; version = $version; store = 'windows-credential-manager'; prefix = $prefix; unlockedHere = $ok; items = $count; error = $err }
            $line = "Store unreadable: $err"
            if ($ok) { $line = "Store: Windows Credential Manager, prefix $prefix, $count items" }
            return (New-LiteCliResult -Code 0 -Data $d -Text ("Lazarette Lite $version" + $nl + $line))
        }
        'items' {
            if ($Type -or $Tag) { return (New-LiteCliResult -Code 1 -Data ([ordered]@{ error = 'unsupported'; option = 'Type/Tag' }) -Text 'Lite items have no type or tags; -Type and -Tag need the full Lazarette.') }
            $lock = Test-LiteCliStore; if ($lock) { return $lock }
            $rows = @(Get-LiteItemNames | ForEach-Object { [ordered]@{ service = [string]$_.Service; user = [string]$_.User; type = [string]$_.Type; tags = ''; hasTotp = $false } })
            return (New-LiteCliResult -Code 0 -Data @{ count = $rows.Count; items = $rows } -Text ((@($rows | ForEach-Object { '{0}  {1}  {2}' -f $_.service, $_.user, $_.type })) -join $nl))
        }
        'get' {
            if ($Name.Count -ne 1 -or [string]::IsNullOrWhiteSpace($Name[0])) { return (New-LiteCliResult -Code 1 -Data ([ordered]@{ error = 'usage' }) -Text 'Usage: lazarette get <service> [-User u]') }
            if ($Field) { return (New-LiteCliResult -Code 3 -Data ([ordered]@{ error = 'no-field'; service = $Name[0]; field = $Field }) -Text "Item '$($Name[0])' has no field '$Field' (Lite items have one secret and no custom fields).") }
            $lock = Test-LiteCliStore; if ($lock) { return $lock }
            $hits = @(Get-LiteCredential -Service $Name[0] -User $User)
            if ($hits.Count -eq 0) { return (New-LiteCliResult -Code 3 -Data ([ordered]@{ error = 'not-found'; service = $Name[0] }) -Text "No item '$($Name[0])'.") }
            if ($hits.Count -gt 1) { return (New-LiteCliResult -Code 3 -Data ([ordered]@{ error = 'ambiguous'; service = $Name[0]; matches = $hits.Count }) -Text "$($hits.Count) items are named '$($Name[0])'; pass -User.") }
            try { $secret = Get-LiteSecret -Service $hits[0].Service -User $hits[0].User }
            catch { return (New-LiteCliResult -Code 3 -Data ([ordered]@{ error = 'empty'; service = $Name[0] }) -Text $_.Exception.Message) }
            return (New-LiteCliResult -Code 0 -Data ([ordered]@{ service = [string]$hits[0].Service; user = [string]$hits[0].User; secret = $secret }) -Text $secret)
        }
        'check' {
            if ($Name.Count -eq 0) { return (New-LiteCliResult -Code 1 -Data ([ordered]@{ error = 'usage' }) -Text 'Usage: lazarette check <name>...') }
            $lock = Test-LiteCliStore; if ($lock) { return $lock }
            $rows = @(foreach ($n in $Name) {
                $c = @(Get-LiteCredential -Service $n -User $User).Count
                $state = 'ambiguous'; if ($c -eq 1) { $state = 'present' } elseif ($c -eq 0) { $state = 'missing' }
                [ordered]@{ name = $n; state = $state }
            })
            $bad = @($rows | Where-Object { $_.state -ne 'present' }).Count
            $code = 0; if ($bad) { $code = 3 }
            return (New-LiteCliResult -Code $code -Data @{ ok = ($bad -eq 0); items = $rows } -Text ((@($rows | ForEach-Object { '{0}: {1}' -f $_.name, $_.state })) -join $nl))
        }
        { $_ -in @('totp', 'run') } {
            return (New-LiteCliResult -Code 1 -Data ([ordered]@{ error = 'unsupported'; verb = $Verb }) -Text "'$Verb' needs the full Lazarette. Lazarette Lite offers status, items, get and check.")
        }
        default { return (New-LiteCliResult -Code 1 -Data ([ordered]@{ error = 'unknown-verb'; verb = $Verb }) -Text "Unknown command '$Verb'. Try: lazarette help") }
    }
}
