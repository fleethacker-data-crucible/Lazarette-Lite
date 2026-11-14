#requires -Version 5.1
# lib\Cli.ps1 (tools\lazarette.ps1): the verbs, output shapes and exit codes of Lazarette's command line, for
# what Lite can answer. Fake backend, synthetic data only.

BeforeAll {
    $script:root = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $script:root 'LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')
    . (Join-Path $script:root 'lib\Cli.ps1')
}
AfterAll { Set-LiteBackend $null; Set-LitePrefix -Reset; Remove-Module LazaretteLite -ErrorAction SilentlyContinue }

Describe 'Invoke-LiteCli' {
    BeforeEach {
        $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'glpat-synthetic-1') | Out-Null
        Add-LiteCredential -Service 'wiki' -User 'a' -Secret (ConvertTo-LiteTestSecure 'one') | Out-Null
        Add-LiteCredential -Service 'wiki' -User 'b' -Secret (ConvertTo-LiteTestSecure 'two') | Out-Null
    }

    It 'help lists the verbs Lite answers' {
        $r = Invoke-LiteCli -Verb help
        $r.Code | Should -Be 0
        $r.Data.verbs | Should -Be @('status', 'items', 'get', 'check')
    }
    It 'status names the store and counts items, with no secret' {
        $r = Invoke-LiteCli -Verb status
        $r.Code | Should -Be 0
        $r.Data.product | Should -Be 'Lazarette Lite'
        $r.Data.unlockedHere | Should -BeTrue
        $r.Data.items | Should -Be 3
        $r.Data.prefix | Should -Be 'lazarette-lite/'
        ($r.Data | ConvertTo-Json) | Should -Not -Match 'glpat'
    }
    It 'items lists names only' {
        $r = Invoke-LiteCli -Verb items
        $r.Code | Should -Be 0
        $r.Data.count | Should -Be 3
        $r.Text | Should -Match 'gitlab  anthony  login'
        ($r.Data | ConvertTo-Json -Depth 4) | Should -Not -Match 'glpat'
        (Invoke-LiteCli -Verb items -Type api).Code | Should -Be 1
    }
    It 'get returns the secret as the text with exit code 0, and -User chooses between same-named items' {
        $r = Invoke-LiteCli -Verb get -Name @('gitlab')
        $r.Code | Should -Be 0
        $r.Text | Should -Be 'glpat-synthetic-1'
        $r.Data.secret | Should -Be 'glpat-synthetic-1'
        (Invoke-LiteCli -Verb get -Name @('wiki') -User 'b').Text | Should -Be 'two'
    }
    It 'get answers 3 for a missing or ambiguous item, and for a field' {
        (Invoke-LiteCli -Verb get -Name @('nope')).Code | Should -Be 3
        $amb = Invoke-LiteCli -Verb get -Name @('wiki')
        $amb.Code | Should -Be 3
        $amb.Data.error | Should -Be 'ambiguous'
        (Invoke-LiteCli -Verb get -Name @('gitlab') -Field 'Host').Data.error | Should -Be 'no-field'
    }
    It 'get answers 1 without a name' {
        (Invoke-LiteCli -Verb get).Code | Should -Be 1
    }
    It 'check reports present, missing and ambiguous, and exit code 3 unless every name is present' {
        $r = Invoke-LiteCli -Verb check -Name @('gitlab', 'nope', 'wiki')
        $r.Code | Should -Be 3
        $r.Data.ok | Should -BeFalse
        @($r.Data.items | ForEach-Object { $_.state }) | Should -Be @('present', 'missing', 'ambiguous')
        (Invoke-LiteCli -Verb check -Name @('gitlab')).Code | Should -Be 0
    }
    It 'answers 2 when the store cannot be read, like a locked vault' {
        $broken = New-LiteFakeBackend
        $broken.Enumerate = { param($Filter) throw 'fake: access denied' }
        Set-LiteBackend $broken
        (Invoke-LiteCli -Verb items).Code | Should -Be 2
        (Invoke-LiteCli -Verb get -Name @('gitlab')).Code | Should -Be 2
        $s = Invoke-LiteCli -Verb status
        $s.Code | Should -Be 0
        $s.Data.unlockedHere | Should -BeFalse
    }
    It 'refuses totp and run with exit code 1 and a pointer to the full Lazarette' {
        $r = Invoke-LiteCli -Verb totp -Name @('gitlab')
        $r.Code | Should -Be 1
        $r.Text | Should -Match 'full Lazarette'
        (Invoke-LiteCli -Verb run).Code | Should -Be 1
        (Invoke-LiteCli -Verb bogus).Code | Should -Be 1
    }
}
