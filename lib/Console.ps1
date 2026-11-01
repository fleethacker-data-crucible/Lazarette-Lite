#requires -Version 5.1
# =============================================================================
# The user interface: a plain console menu. No listener, no port, no browser,
# no window handles: it reads lines from the console and writes lines back.
# Each action is a few lines over the same functions a script would call.
#
# Secrets are typed with Read-Host -AsSecureString and are never printed. There is
# deliberately no "show secret" action: copy it (it clears itself) or call Get-LiteSecret.
# =============================================================================

$script:LiteConsoleIO = $null

function Set-LiteConsoleIO {
    # Test seam. -Read { param($Prompt, $Secret) ... }  -Write { param($Text, $Color) ... }. No arguments resets.
    param($Read, $Write)
    $script:LiteConsoleIO = if ($Read -and $Write) { [pscustomobject]@{ Read = $Read; Write = $Write } } else { $null }
}

function Read-LitePrompt {
    param([string]$Prompt, [switch]$Secret)
    if ($script:LiteConsoleIO) { return (& $script:LiteConsoleIO.Read $Prompt ([bool]$Secret)) }
    if ($Secret) { return (Read-Host -Prompt $Prompt -AsSecureString) }
    return (Read-Host -Prompt $Prompt)
}

function Write-LiteLine {
    param([string]$Text = '', [string]$Color)
    if ($script:LiteConsoleIO) { & $script:LiteConsoleIO.Write $Text $Color; return }
    if ($Color) { Write-Host $Text -ForegroundColor $Color } else { Write-Host $Text }
}

function Show-LiteList {
    param([object[]]$Items)
    if ($Items.Count -eq 0) { Write-LiteLine '  (no items)'; return }
    $w = [int][Math]::Min(30, [Math]::Max(7, ($Items | ForEach-Object { $_.Service.Length } | Measure-Object -Maximum).Maximum))
    $u = [int][Math]::Min(24, [Math]::Max(4, ($Items | ForEach-Object { $_.User.Length } | Measure-Object -Maximum).Maximum))
    Write-LiteLine ("  {0,3}  {1}  {2}  {3}" -f '#', 'Service'.PadRight($w), 'User'.PadRight($u), 'Note')
    $n = 0
    foreach ($it in $Items) {
        $n++
        $svc = if ($it.Service.Length -gt $w) { $it.Service.Substring(0, $w - 1) + '~' } else { $it.Service }
        $usr = if ($it.User.Length -gt $u) { $it.User.Substring(0, $u - 1) + '~' } else { $it.User }
        $note = $it.Comment + $(if ($it.HasSecret) { '' } else { '  [no secret yet]' })
        Write-LiteLine ("  {0,3}  {1}  {2}  {3}" -f $n, $svc.PadRight($w), $usr.PadRight($u), $note)
    }
}

function Select-LiteConsoleItem {
    # Shows the list (optionally filtered) and asks for a number. Returns the item, or $null.
    param([string]$Search = '')
    $items = @(Get-LiteCredential -Search $Search)
    Show-LiteList $items
    if ($items.Count -eq 0) { return $null }
    $a = [string](Read-LitePrompt 'Number (blank to cancel)')
    if ([string]::IsNullOrWhiteSpace($a)) { return $null }
    if ($a.Trim() -match '^\d+$' -and [int]$a.Trim() -ge 1 -and [int]$a.Trim() -le $items.Count) { return $items[[int]$a.Trim() - 1] }
    Write-LiteLine '  That is not a number in the list.' 'Yellow'
    return $null
}

function Read-LiteNewSecret {
    # Asks twice. Returns a SecureString, or $null if blank or the two do not match.
    $a = Read-LitePrompt 'Secret' -Secret
    if ($null -eq $a -or $a.Length -eq 0) { return $null }
    $b = Read-LitePrompt 'Secret again' -Secret
    if ($null -eq $b -or (ConvertFrom-LiteSecureString $a) -cne (ConvertFrom-LiteSecureString $b)) { Write-LiteLine '  The two entries differ. Nothing was saved.' 'Yellow'; return $null }
    return $a
}

function Invoke-LiteAdd {
    $svc = [string](Read-LitePrompt 'Service (for example gitlab)')
    if ([string]::IsNullOrWhiteSpace($svc)) { return }
    $usr = [string](Read-LitePrompt "User (blank = $svc)")
    $note = [string](Read-LitePrompt 'Note (optional)')
    $sec = Read-LiteNewSecret
    if ($null -eq $sec) { return }
    $r = Add-LiteCredential -Service $svc.Trim() -User $usr.Trim() -Secret $sec -Comment $note
    Write-LiteLine ("  Added {0} / {1}." -f $r.Service, $r.User) 'Green'
}

function Invoke-LiteEdit {
    $it = Select-LiteConsoleItem
    if ($null -eq $it) { return }
    Write-LiteLine '  Leave a field blank to keep it.'
    $svc = [string](Read-LitePrompt "Service [$($it.Service)]")
    $usr = [string](Read-LitePrompt "User [$($it.User)]")
    $note = [string](Read-LitePrompt "Note [$($it.Comment)] ('-' clears it)")
    $sec = Read-LitePrompt 'New secret (blank keeps the current one)' -Secret
    $p = @{ Service = $it.Service; User = $it.User }
    if ($svc.Trim()) { $p.NewService = $svc.Trim() }
    if ($usr.Trim()) { $p.NewUser = $usr.Trim() }
    if ($note) { $p.Comment = $(if ($note -eq '-') { '' } else { $note }) }
    if ($null -ne $sec -and $sec.Length -gt 0) {
        $again = Read-LitePrompt 'New secret again' -Secret
        if ($null -eq $again -or (ConvertFrom-LiteSecureString $sec) -cne (ConvertFrom-LiteSecureString $again)) { Write-LiteLine '  The two entries differ. Nothing was saved.' 'Yellow'; return }
        $p.Secret = $sec
    }
    if ($p.Count -eq 2) { Write-LiteLine '  Nothing to change.'; return }
    $r = Set-LiteCredential @p
    Write-LiteLine ("  Saved {0} / {1}." -f $r.Service, $r.User) 'Green'
}

function Invoke-LiteDelete {
    $it = Select-LiteConsoleItem
    if ($null -eq $it) { return }
    $typed = [string](Read-LitePrompt "Type the service name '$($it.Service)' to delete it (blank cancels)")
    if ($typed.Trim() -ine $it.Service) { Write-LiteLine '  Not deleted.'; return }
    Remove-LiteCredential -Service $it.Service -User $it.User -Confirm:$false
    Write-LiteLine ("  Deleted {0} / {1}." -f $it.Service, $it.User) 'Green'
}

function Invoke-LiteCopy {
    $it = Select-LiteConsoleItem
    if ($null -eq $it) { return }
    if (-not $it.HasSecret) { Write-LiteLine '  That item has no secret yet. Use Edit to set one.' 'Yellow'; return }
    Write-LiteLine '  Copying. The clipboard is cleared in 20 seconds, or press Ctrl+C to clear it now.'
    $r = Copy-LiteSecret -Service $it.Service -User $it.User
    $msg = switch ($r.Outcome) {
        'Cleared'          { 'Clipboard cleared.' }
        'ClipboardChanged' { 'You copied something else meanwhile, so the clipboard was left alone.' }
        default            { 'The clipboard was already empty.' }
    }
    Write-LiteLine "  $msg"
}

function Invoke-LiteExport {
    $p = [string](Read-LitePrompt 'File to write [.\lazarette-lite-export.json]')
    if ([string]::IsNullOrWhiteSpace($p)) { $p = '.\lazarette-lite-export.json' }
    $force = $false
    if (Test-Path -LiteralPath (Resolve-LiteFilePath $p)) {
        if (([string](Read-LitePrompt 'That file exists. Overwrite? [y/N]')).Trim() -notmatch '^(?i:y|yes)$') { Write-LiteLine '  Not exported.'; return }
        $force = $true
    }
    $r = Export-LiteMetadata -Path $p -Force:$force
    Write-LiteLine ("  Wrote {0} names to {1}. Secrets are not included." -f $r.Count, $r.Path) 'Green'
}

function Invoke-LiteImport {
    $p = [string](Read-LitePrompt 'File to read')
    if ([string]::IsNullOrWhiteSpace($p)) { return }
    $r = Import-LiteMetadata -Path $p
    Write-LiteLine ("  {0} created without a secret, {1} already there." -f $r.Created, $r.Skipped) 'Green'
    if ($r.Created -gt 0) { Write-LiteLine '  Use Edit to give each new item its secret.' }
}

function Invoke-LitePrefix {
    Write-LiteLine ("  Prefix: {0}" -f (Get-LitePrefix))
    Write-LiteLine '  Set LAZARETTE_LITE_PREFIX to make a change permanent for your account.'
    $p = [string](Read-LitePrompt 'New prefix for this session (blank keeps it)')
    if ([string]::IsNullOrWhiteSpace($p)) { return }
    Set-LitePrefix $p.Trim() | Out-Null
    Write-LiteLine ("  Prefix is now {0}" -f (Get-LitePrefix)) 'Green'
}

function Invoke-LiteGenerate {
    # Adds an item whose secret is generated; the secret is never shown, only copied if you ask.
    $svc = [string](Read-LitePrompt 'Service (for example gitlab)')
    if ([string]::IsNullOrWhiteSpace($svc)) { return }
    $usr = [string](Read-LitePrompt "User (blank = $svc)")
    $note = [string](Read-LitePrompt 'Note (optional)')
    $len = [string](Read-LitePrompt 'Length [20]')
    $p = @{ Length = $(if ($len.Trim()) { [int]$len.Trim() } else { 20 }) }
    if (([string](Read-LitePrompt 'Letters and digits only? [y/N]')).Trim() -match '^(?i:y|yes)$') { $p.NoSymbols = $true }
    $r = Add-LiteCredential -Service $svc.Trim() -User $usr.Trim() -Secret (New-LitePassword @p) -Comment $note
    Write-LiteLine ("  Added {0} / {1} with a generated {2}-character secret." -f $r.Service, $r.User, $p.Length) 'Green'
    if (([string](Read-LitePrompt 'Copy it now? [y/N]')).Trim() -match '^(?i:y|yes)$') {
        $c = Copy-LiteSecret -Service $r.Service -User $r.User
        Write-LiteLine "  Clipboard: $($c.Outcome)."
    }
}

function Invoke-LiteCheck {
    $rows = @(Test-LiteStore)
    if ($rows.Count -eq 0) { Write-LiteLine '  No problems found.' 'Green'; return }
    foreach ($r in $rows) { Write-LiteLine ("  {0,-7} {1} / {2}: {3}" -f $r.Severity, $r.Service, $r.User, $r.Problem) $(if ($r.Severity -eq 'Error') { 'Red' } else { 'Yellow' }) }
    Write-LiteLine ("  {0} problem{1}." -f $rows.Count, $(if ($rows.Count -eq 1) { '' } else { 's' }))
}

function Show-LiteHelp {
    foreach ($l in @(
            'Lazarette Lite keeps your credentials in Windows Credential Manager. Nothing else stores them.',
            '',
            '  1 List      shows service, user and note. Secrets are never shown.',
            '  2 Search    matches service, user or note, ignoring case.',
            '  3 Add       asks for the secret twice, hidden. Limit: 1,280 characters.',
            '  4 Edit      blank keeps a value; "-" clears the note; a new secret is asked twice.',
            '  5 Delete    you type the service name to confirm.',
            '  6 Copy      puts the secret on the clipboard and clears it after 20 seconds (Ctrl+C clears now).',
            '  7 Export    names and notes to a JSON file. Never secrets.',
            '  8 Import    makes empty placeholders for names you lack; fill them in with Edit.',
            '  9 Prefix    where Lite looks in Credential Manager (default lazarette-lite/).',
            '  g Generate  adds an item with a random secret you never have to see.',
            '  c Check     read-only report of items that may not work in scripts.',
            '  h or ?      this help.',
            '  q Quit      leaves the menu.',
            '',
            'In a script:  Import-Module .\LazaretteLite.psd1;  Get-LiteSecret -Service gitlab -User you',
            'More:         Get-Help Get-LiteSecret -Full   (same for the other commands)')) { Write-LiteLine $l }
}

function Start-LiteConsole {
    <#
    .SYNOPSIS
        The Lazarette Lite menu. Quit with q.
    #>
    [CmdletBinding()]
    param()
    Write-LiteLine 'Lazarette Lite: your Windows credentials, nothing more.' 'Cyan'
    try { [void](Get-LitePrefix) } catch { Write-LiteLine ("  {0}" -f $_.Exception.Message) 'Red'; return }
    while ($true) {
        $count = try { @(Get-LiteCredential).Count } catch { Write-LiteLine ("  Could not read Credential Manager: {0}" -f $_.Exception.Message) 'Red'; '?' }
        Write-LiteLine ''
        Write-LiteLine ("Prefix {0}  ({1} item{2})" -f (Get-LitePrefix), $count, $(if ($count -eq 1) { '' } else { 's' }))
        Write-LiteLine '  1 List   2 Search   3 Add   4 Edit   5 Delete   6 Copy secret'
        Write-LiteLine '  7 Export names   8 Import names   9 Prefix   g Generate   c Check   h Help   q Quit'
        # A failed read here (no console attached) ends the menu instead of looping on the error.
        $c = ([string](Read-LitePrompt 'Choose')).Trim().ToLowerInvariant()
        try {
            switch ($c) {
                '1' { Show-LiteList @(Get-LiteCredential) }
                '2' { Show-LiteList @(Get-LiteCredential -Search ([string](Read-LitePrompt 'Search for'))) }
                '3' { Invoke-LiteAdd }
                '4' { Invoke-LiteEdit }
                '5' { Invoke-LiteDelete }
                '6' { Invoke-LiteCopy }
                '7' { Invoke-LiteExport }
                '8' { Invoke-LiteImport }
                '9' { Invoke-LitePrefix }
                'g' { Invoke-LiteGenerate }
                'c' { Invoke-LiteCheck }
                { $_ -in 'h', '?', 'help' } { Show-LiteHelp }
                { $_ -in 'q', '0', 'quit', 'exit' } { return }
                default { Write-LiteLine '  Pick an option from the menu, h for help, or q to quit.' 'Yellow' }
            }
        } catch {
            Write-LiteLine ("  {0}" -f $_.Exception.Message) 'Red'
        }
    }
}
