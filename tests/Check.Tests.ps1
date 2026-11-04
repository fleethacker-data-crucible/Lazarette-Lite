#requires -Version 5.1
BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')
    function Add-RawTest { param($Be, $Target, $User, $Secret, $Comment = '') $Be.Store[$Target] = [pscustomobject]@{ Target = $Target; UserName = $User; Comment = $Comment; Secret = $Secret; LastWritten = [datetime]::UtcNow } }
}
AfterAll { Set-LiteBackend $null; Set-LiteConsoleIO; Set-LitePrefix -Reset; Remove-Module LazaretteLite -ErrorAction SilentlyContinue }

Describe 'Test-LiteStore' {
    BeforeEach { $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset }

    It 'reports nothing for a healthy store, and for an empty one' {
        @(Test-LiteStore).Count | Should -Be 0
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'fine-secret') | Out-Null
        @(Test-LiteStore).Count | Should -Be 0
    }
    It 'flags a placeholder as a warning' {
        Add-RawTest $script:be 'lazarette-lite/wiki/bob' 'bob' ''
        $r = @(Test-LiteStore); $r.Count | Should -Be 1
        $r[0].Severity | Should -Be 'Warning'; $r[0].Problem | Should -Match 'No secret yet'
    }
    It 'flags whitespace and line breaks in a secret' {
        Add-RawTest $script:be 'lazarette-lite/a/u' 'u' 'pw '
        Add-RawTest $script:be 'lazarette-lite/b/u' 'u' "pw`n"
        @(Test-LiteStore | Where-Object Problem -Match 'whitespace').Count | Should -Be 2
    }
    It 'flags a name with no user part as an error' {
        Add-RawTest $script:be 'lazarette-lite/foreign' 'x' 'pw'
        $r = @(Test-LiteStore); $r[0].Severity | Should -Be 'Error'; $r[0].Problem | Should -Match 'no user part'
    }
    It 'flags a user name that differs from the target, and a secret near the limit' {
        Add-RawTest $script:be 'lazarette-lite/a/u' 'someone-else' ('x' * 1250)
        $p = (Test-LiteStore).Problem -join '|'
        $p | Should -Match 'differs from the name'; $p | Should -Match 'close to the 2,560'
    }
    It 'reports an unreadable item instead of failing' {
        Add-LiteCredential -Service 'a' -Secret (ConvertTo-LiteTestSecure 'x') | Out-Null
        $real = $script:be.Read
        $script:be.Read = { param($T) throw 'access denied' }
        try { @(Test-LiteStore)[0].Problem | Should -Match 'access denied' } finally { $script:be.Read = $real }
    }
    It 'changes nothing and never returns a secret' {
        Add-RawTest $script:be 'lazarette-lite/a/u' 'u' 'SYNTH-LEAK '
        $script:be.Calls.Clear()
        $r = Test-LiteStore
        ($r | ConvertTo-Json) | Should -Not -Match 'SYNTH-LEAK'
        @($script:be.Calls | Where-Object { $_ -match '^(Write|Delete)' }).Count | Should -Be 0
    }
    It 'is available as c in the console' {
        Add-RawTest $script:be 'lazarette-lite/wiki/bob' 'bob' ''
        $q = New-Object System.Collections.Queue; 'c', 'q' | ForEach-Object { $q.Enqueue($_) }
        $out = New-Object System.Collections.Generic.List[string]
        Set-LiteConsoleIO -Read ({ param($P, $S) $q.Dequeue() }.GetNewClosure()) -Write ({ param($T, $C) $out.Add($T) }.GetNewClosure())
        try { Start-LiteConsole } finally { Set-LiteConsoleIO }
        ($out -join "`n") | Should -Match 'Warning\s+wiki / bob: No secret yet'
        ($out -join "`n") | Should -Match '1 problem\.'
    }
}
