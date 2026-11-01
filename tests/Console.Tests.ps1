#requires -Version 5.1
# The console menu, driven by scripted answers. Fake backend and clipboard, synthetic data only.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')
    . (Join-Path $PSScriptRoot 'FakeClipboard.ps1')

    # Feeds the answers to the menu in order and returns everything it printed. Always end answers with 'q'.
    function Invoke-TestMenu {
        param([string[]]$Answers)
        $q = New-Object System.Collections.Queue
        $Answers | ForEach-Object { $q.Enqueue($_) }
        $out = New-Object System.Collections.Generic.List[string]
        $prompts = New-Object System.Collections.Generic.List[string]
        $read = {
            param($Prompt, $Secret)
            $prompts.Add($Prompt)
            if ($q.Count -eq 0) { throw "test ran out of answers at '$Prompt'" }
            $a = [string]$q.Dequeue()
            if ($Secret) { if ($a -eq '') { New-Object System.Security.SecureString } else { ConvertTo-SecureString $a -AsPlainText -Force } } else { $a }
        }.GetNewClosure()
        $write = { param($Text, $Color) $out.Add([string]$Text) }.GetNewClosure()
        Set-LiteConsoleIO -Read $read -Write $write
        try { Start-LiteConsole } finally { Set-LiteConsoleIO }
        [pscustomobject]@{ Text = ($out -join "`n"); Lines = $out; Prompts = $prompts }
    }
}

AfterAll {
    Set-LiteConsoleIO
    Set-LiteBackend $null
    Set-LiteClipboardBackend $null
    Set-LitePrefix -Reset
    Remove-Module LazaretteLite -ErrorAction SilentlyContinue
}

Describe 'Console menu' {
    BeforeEach {
        $env:LAZARETTE_LITE_PREFIX = $null
        $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset
        $script:cb = New-LiteFakeClipboard; Set-LiteClipboardBackend $script:cb
    }

    It 'shows the menu and quits' {
        $r = Invoke-TestMenu 'q'
        $r.Text | Should -Match 'Prefix lazarette-lite/  \(0 items\)'
        $r.Text | Should -Match '1 List'
        $r.Text | Should -Match 'q Quit'
    }

    It 'rejects an unknown choice and carries on' {
        (Invoke-TestMenu 'zz', 'q').Text | Should -Match 'Pick an option from the menu'
    }

    It 'adds an item, asking for the secret twice, and never prints it' {
        $r = Invoke-TestMenu '3', 'gitlab', 'anthony', 'build server', 'SYNTH-PW-1', 'SYNTH-PW-1', 'q'
        $r.Text | Should -Match 'Added gitlab / anthony'
        $script:be.Store['lazarette-lite/gitlab/anthony'].Secret | Should -Be 'SYNTH-PW-1'
        $script:be.Store['lazarette-lite/gitlab/anthony'].Comment | Should -Be 'build server'
        $r.Text | Should -Not -Match 'SYNTH-PW'
    }

    It 'saves nothing when the two secret entries differ' {
        $r = Invoke-TestMenu '3', 'gitlab', '', '', 'SYNTH-ONE', 'SYNTH-TWO', 'q'
        $r.Text | Should -Match 'differ'
        $script:be.Store.Count | Should -Be 0
    }

    It 'lists items with notes, flags a placeholder, and prints no secret' {
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'SYNTH-PW-1') -Comment 'build server' | Out-Null
        $script:be.Store['lazarette-lite/wiki/bob'] = [pscustomobject]@{ Target = 'lazarette-lite/wiki/bob'; UserName = 'bob'; Comment = ''; Secret = ''; LastWritten = [datetime]::UtcNow }
        $r = Invoke-TestMenu '1', 'q'
        $r.Text | Should -Match 'gitlab\s+anthony\s+build server'
        $r.Text | Should -Match 'wiki\s+bob\s+\[no secret yet\]'
        $r.Text | Should -Not -Match 'SYNTH-PW'
    }

    It 'searches' {
        Add-LiteCredential -Service 'gitlab' -Secret (ConvertTo-LiteTestSecure 'x') | Out-Null
        Add-LiteCredential -Service 'wiki' -Secret (ConvertTo-LiteTestSecure 'x') | Out-Null
        $r = Invoke-TestMenu '2', 'wik', 'q'
        $r.Text | Should -Match 'wiki'
        ($r.Lines | Where-Object { $_ -match '^\s+\d+\s+gitlab' }) | Should -BeNullOrEmpty
    }

    It 'edits: blank fields keep their values, a new note and secret are saved' {
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'OLD-PW') -Comment 'old' | Out-Null
        $r = Invoke-TestMenu '4', '1', '', '', 'new note', 'NEW-PW', 'NEW-PW', 'q'
        $e = $script:be.Store['lazarette-lite/gitlab/anthony']
        $e.Comment | Should -Be 'new note'
        $e.Secret | Should -Be 'NEW-PW'
        $r.Text | Should -Match 'Saved gitlab / anthony'
        $r.Text | Should -Not -Match 'NEW-PW|OLD-PW'
    }

    It 'edits with everything blank and changes nothing' {
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'OLD-PW') -Comment 'old' | Out-Null
        $r = Invoke-TestMenu '4', '1', '', '', '', '', 'q'
        $r.Text | Should -Match 'Nothing to change'
        $script:be.Store['lazarette-lite/gitlab/anthony'].Secret | Should -Be 'OLD-PW'
    }

    It "clears a note with '-' and renames the user" {
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'x') -Comment 'old' | Out-Null
        Invoke-TestMenu '4', '1', '', 'ahable', '-', '', 'q' | Out-Null
        $script:be.Store.ContainsKey('lazarette-lite/gitlab/anthony') | Should -BeFalse
        $script:be.Store['lazarette-lite/gitlab/ahable'].Comment | Should -Be ''
    }

    It 'deletes only after the service name is typed' {
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'x') | Out-Null
        Invoke-TestMenu '5', '1', 'wrong', 'q' | Out-Null
        $script:be.Store.Count | Should -Be 1
        $r = Invoke-TestMenu '5', '1', 'GitLab', 'q'
        $script:be.Store.Count | Should -Be 0
        $r.Text | Should -Match 'Deleted gitlab / anthony'
    }

    It 'cancels a pick on a blank or out-of-range number' {
        Add-LiteCredential -Service 'gitlab' -Secret (ConvertTo-LiteTestSecure 'x') | Out-Null
        Invoke-TestMenu '5', '', 'q' | Out-Null
        (Invoke-TestMenu '5', '9', 'q').Text | Should -Match 'not a number in the list'
        $script:be.Store.Count | Should -Be 1
    }

    It 'copies a secret to the clipboard, clears it, and never prints it' {
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'SYNTH-PW-1') | Out-Null
        $r = Invoke-TestMenu '6', '1', 'q'
        $script:cb.SetCount | Should -Be 1
        $script:cb.Text | Should -BeNullOrEmpty
        $r.Text | Should -Match 'Clipboard cleared'
        $r.Text | Should -Not -Match 'SYNTH-PW'
    }

    It 'will not copy a placeholder' {
        $script:be.Store['lazarette-lite/wiki/bob'] = [pscustomobject]@{ Target = 'lazarette-lite/wiki/bob'; UserName = 'bob'; Comment = ''; Secret = ''; LastWritten = [datetime]::UtcNow }
        (Invoke-TestMenu '6', '1', 'q').Text | Should -Match 'no secret yet. Use Edit'
        $script:cb.SetCount | Should -Be 0
    }

    It 'exports and imports through the menu' {
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'SYNTH-PW-1') -Comment 'build' | Out-Null
        $f = Join-Path $TestDrive 'menu-export.json'
        $r = Invoke-TestMenu '7', $f, 'q'
        $r.Text | Should -Match 'Wrote 1 names'
        [IO.File]::ReadAllText($f) | Should -Not -Match 'SYNTH-PW'
        Invoke-TestMenu '7', $f, 'n', 'q' | Out-Null     # exists: declined
        (Invoke-TestMenu '7', $f, 'y', 'q').Text | Should -Match 'Wrote 1 names'

        $script:be2 = New-LiteFakeBackend; Set-LiteBackend $script:be2
        $r = Invoke-TestMenu '8', $f, 'q'
        $r.Text | Should -Match '1 created without a secret, 0 already there'
        $script:be2.Store['lazarette-lite/gitlab/anthony'].Secret | Should -Be ''
    }

    It 'shows an error and keeps going instead of crashing' {
        $r = Invoke-TestMenu '3', 'gitlab', '', '', ('a' * 1300), ('a' * 1300), 'q'
        $r.Text | Should -Match '2,600 bytes'
        $r.Text | Should -Match 'q Quit'
        $script:be.Store.Count | Should -Be 0
        (Invoke-TestMenu '8', (Join-Path $TestDrive 'missing.json'), 'q').Text | Should -Match 'No export file'
    }

    It 'changes the prefix for the session' {
        $r = Invoke-TestMenu '9', 'team-a/', 'q'
        $r.Text | Should -Match 'Prefix is now team-a/'
        (Invoke-TestMenu '9', 'PM/', 'q').Text | Should -Match 'belongs to Lazarette'
        Get-LitePrefix | Should -Be 'team-a/'
    }

    It 'refuses to start with an unusable prefix in the environment' {
        $env:LAZARETTE_LITE_PREFIX = 'PM/'
        try { (Invoke-TestMenu 'q').Text | Should -Match 'not usable' } finally { $env:LAZARETTE_LITE_PREFIX = $null }
    }

    It 'stops when the console cannot be read, rather than looping' {
        { Invoke-TestMenu @() } | Should -Throw '*ran out of answers*'
    }
}

Describe 'Console help' {
    BeforeEach { Set-LiteBackend (New-LiteFakeBackend); Set-LitePrefix -Reset }

    It 'shows help for h and ? and returns to the menu' {
        foreach ($k in 'h', '?') {
            $r = Invoke-TestMenu $k, 'q'
            $r.Text | Should -Match 'keeps your credentials in Windows Credential Manager'
            $r.Text | Should -Match 'Get-LiteSecret -Service gitlab'
        }
    }

    It 'documents every key on the menu line' {
        $menu = (Invoke-TestMenu 'q').Lines | Where-Object { $_ -match '^\s+(1 List|7 Export)' }
        $keys = [regex]::Matches(($menu -join ' '), '(?<![A-Za-z])([0-9a-z]) [A-Z][a-z]+') | ForEach-Object { $_.Groups[1].Value }
        $help = (Invoke-TestMenu 'h', 'q').Text
        foreach ($k in $keys) { $help | Should -Match ("(?m)^\s+{0} \w+" -f [regex]::Escape($k)) }
        @($keys).Count | Should -BeGreaterThan 10
    }

    It 'has a synopsis for every public command' {
        $cmds = (Get-Module LazaretteLite).ExportedFunctions.Keys | Where-Object { $_ -notmatch '^Set-Lite(Backend|ClipboardBackend|ConsoleIO|RandomSource)$' }
        foreach ($c in $cmds) { (Get-Help $c).Synopsis | Should -Not -Match "^\s*$c\s" -Because "$c needs a .SYNOPSIS" }
    }
}
