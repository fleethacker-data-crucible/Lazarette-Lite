#requires -Version 5.1
# Copy-LiteSecret against a fake backend and a fake clipboard. The real clipboard is never touched.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')
    . (Join-Path $PSScriptRoot 'FakeClipboard.ps1')
}

AfterAll {
    Set-LiteBackend $null
    Set-LiteClipboardBackend $null
    Set-LitePrefix -Reset
    Remove-Module LazaretteLite -ErrorAction SilentlyContinue
}

Describe 'Copy-LiteSecret' {
    BeforeEach {
        $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset
        $script:cb = New-LiteFakeClipboard; Set-LiteClipboardBackend $script:cb
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'glpat-synthetic-1') | Out-Null
    }

    It 'puts the secret on the clipboard, waits the default 20 seconds, then clears it' {
        $script:cb.OnWait = { param($t, $c) if ($t -eq 19) { $c.Text | Should -Be 'glpat-synthetic-1' } }
        $r = Copy-LiteSecret -Service 'gitlab'
        $script:cb.SetCount | Should -Be 1
        $script:cb.Waited | Should -Be 20
        $script:cb.Text | Should -BeNullOrEmpty
        $script:cb.ClearCount | Should -Be 1
        $r.Outcome | Should -Be 'Cleared'
        $r.Seconds | Should -Be 20
    }

    It 'honours -ClearAfterSeconds and -Name' {
        Copy-LiteSecret -Name 'gitlab' -ClearAfterSeconds 5 | Out-Null
        $script:cb.Waited | Should -Be 5
    }

    It 'accepts 5 to 300 seconds only' {
        { Copy-LiteSecret -Service 'gitlab' -ClearAfterSeconds 4 } | Should -Throw
        { Copy-LiteSecret -Service 'gitlab' -ClearAfterSeconds 301 } | Should -Throw
        $script:cb.SetCount | Should -Be 0
    }

    It 'does not wipe something else the user copied in the meantime' {
        $script:cb.OnWait = { param($t, $c) if ($t -eq 3) { $c.Text = 'something the user copied' } }
        $r = Copy-LiteSecret -Service 'gitlab' -ClearAfterSeconds 5
        $r.Outcome | Should -Be 'ClipboardChanged'
        $script:cb.Text | Should -Be 'something the user copied'
        $script:cb.ClearCount | Should -Be 0
    }

    It 'reports AlreadyEmpty if the clipboard was cleared by something else' {
        $script:cb.OnWait = { param($t, $c) if ($t -eq 2) { $c.Text = $null } }
        (Copy-LiteSecret -Service 'gitlab' -ClearAfterSeconds 5).Outcome | Should -Be 'AlreadyEmpty'
    }

    It 'still clears when interrupted (Ctrl+C stands in as a throw), and lets the interruption through' {
        $script:cb.OnWait = { param($t, $c) if ($t -eq 2) { throw 'interrupted' } }
        { Copy-LiteSecret -Service 'gitlab' -ClearAfterSeconds 10 } | Should -Throw 'interrupted'
        $script:cb.Text | Should -BeNullOrEmpty
        $script:cb.ClearCount | Should -Be 1
    }

    It 'copies nothing for an item that is missing, ambiguous or has no secret yet' {
        Add-LiteCredential -Service 'gitlab' -User 'bob' -Secret (ConvertTo-LiteTestSecure 'x') | Out-Null
        $script:be.Store['lazarette-lite/empty/empty'] = [pscustomobject]@{ Target = 'lazarette-lite/empty/empty'; UserName = 'empty'; Comment = ''; Secret = ''; LastWritten = [datetime]::UtcNow }
        { Copy-LiteSecret -Service 'nope' } | Should -Throw '*no item*'
        { Copy-LiteSecret -Service 'gitlab' } | Should -Throw '*pass -User*'
        { Copy-LiteSecret -Service 'empty' } | Should -Throw '*no secret yet*'
        $script:cb.SetCount | Should -Be 0
    }

    It 'never returns or prints the secret' {
        $r = Copy-LiteSecret -Service 'gitlab' -ClearAfterSeconds 5 6>&1 5>&1 4>&1
        ($r | Out-String) | Should -Not -Match 'glpat-synthetic'
        ($r | ConvertTo-Json -Depth 3 -ErrorAction SilentlyContinue) | Should -Not -Match 'glpat-synthetic'
    }
}
