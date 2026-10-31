#requires -Version 5.1
# List, search, add, edit and delete, against the fake backend. Synthetic data only.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')
}

AfterAll {
    Set-LiteBackend $null
    Set-LitePrefix -Reset | Out-Null
    Remove-Module LazaretteLite -ErrorAction SilentlyContinue
}

Describe 'Prefix' {
    BeforeEach { $env:LAZARETTE_LITE_PREFIX = $null; Set-LitePrefix -Reset }
    AfterAll { $env:LAZARETTE_LITE_PREFIX = $null; Set-LitePrefix -Reset }

    It 'defaults to lazarette-lite/' { Get-LitePrefix | Should -Be 'lazarette-lite/' }

    It 'can be set for the session and reset' {
        Set-LitePrefix 'team-a/' | Should -Be 'team-a/'
        Get-LitePrefix | Should -Be 'team-a/'
        Set-LitePrefix -Reset
        Get-LitePrefix | Should -Be 'lazarette-lite/'
    }

    It 'can come from LAZARETTE_LITE_PREFIX, and the session value wins' {
        $env:LAZARETTE_LITE_PREFIX = 'from-env/'
        Get-LitePrefix | Should -Be 'from-env/'
        Set-LitePrefix 'session/' | Out-Null
        Get-LitePrefix | Should -Be 'session/'
    }

    It 'rejects <p>' -ForEach @(
        @{ p = 'no-slash' }, @{ p = '/' }, @{ p = 'a*/' }, @{ p = 'PM/' }, @{ p = 'pm/' }, @{ p = "tab`t/" }
    ) {
        { Set-LitePrefix $p } | Should -Throw
    }

    It 'reports a bad environment value instead of using it' {
        $env:LAZARETTE_LITE_PREFIX = 'PM/'
        { Get-LitePrefix } | Should -Throw '*not usable*'
    }
}

Describe 'Add and list' {
    BeforeEach {
        $script:be = New-LiteFakeBackend
        Set-LiteBackend $script:be
        Set-LitePrefix -Reset | Out-Null
    }

    It 'stores a generic credential under <prefix><service>/<user> as UTF-16 text' {
        $r = Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'p@ss-1') -Comment 'work account'
        $e = $script:be.Store['lazarette-lite/gitlab/anthony']
        $e.Secret | Should -Be 'p@ss-1'
        $e.UserName | Should -Be 'anthony'
        $e.Comment | Should -Be 'work account'
        $r.Service | Should -Be 'gitlab'
        $r.User | Should -Be 'anthony'
        $r.HasSecret | Should -BeTrue
    }

    It 'uses the service as the user when none is given, as Lazarette does' {
        Add-LiteCredential -Service 'wiki' -Secret (ConvertTo-LiteTestSecure 'x') | Out-Null
        $script:be.Store.ContainsKey('lazarette-lite/wiki/wiki') | Should -BeTrue
    }

    It 'honours a custom prefix' {
        Set-LitePrefix 'team-a/' | Out-Null
        Add-LiteCredential -Service 'gitlab' -User 'u' -Secret (ConvertTo-LiteTestSecure 'x') | Out-Null
        $script:be.Store.ContainsKey('team-a/gitlab/u') | Should -BeTrue
        @(Get-LiteCredential).Count | Should -Be 1
        Set-LitePrefix -Reset | Out-Null
        @(Get-LiteCredential).Count | Should -Be 0
    }

    It 'refuses a duplicate, and -Force replaces it' {
        Add-LiteCredential -Service 'gitlab' -User 'u' -Secret (ConvertTo-LiteTestSecure 'one') | Out-Null
        { Add-LiteCredential -Service 'gitlab' -User 'u' -Secret (ConvertTo-LiteTestSecure 'two') } | Should -Throw '*already has*'
        $script:be.Store['lazarette-lite/gitlab/u'].Secret | Should -Be 'one'
        Add-LiteCredential -Service 'gitlab' -User 'u' -Secret (ConvertTo-LiteTestSecure 'two') -Force | Out-Null
        $script:be.Store['lazarette-lite/gitlab/u'].Secret | Should -Be 'two'
    }

    It 'lists names and metadata, never secrets, and never reads a blob to do it' {
        Add-LiteCredential -Service 'gitlab' -User 'u' -Secret (ConvertTo-LiteTestSecure 'topsecret') | Out-Null
        $script:be.Calls.Clear()
        $l = @(Get-LiteCredential)
        $l.Count | Should -Be 1
        ($l | ConvertTo-Json -Depth 3) | Should -Not -Match 'topsecret'
        $l[0].PSObject.Properties.Name | Should -Not -Contain 'Secret'
        $script:be.Calls | Where-Object { $_ -like 'Read *' } | Should -BeNullOrEmpty
    }

    It 'sees only entries under the prefix and ignores everything else' {
        $script:be.Store['Other/thing'] = [pscustomobject]@{ Target = 'Other/thing'; UserName = 'x'; Comment = ''; Secret = 'foreign'; LastWritten = [datetime]::UtcNow }
        $script:be.Store['PM/gitlab/me'] = [pscustomobject]@{ Target = 'PM/gitlab/me'; UserName = 'me'; Comment = ''; Secret = 'lazarette'; LastWritten = [datetime]::UtcNow }
        Add-LiteCredential -Service 'mine' -Secret (ConvertTo-LiteTestSecure 'x') | Out-Null
        @(Get-LiteCredential).Service | Should -Be @('mine')
        $script:be.Calls | Where-Object { $_ -like 'Read Other*' -or $_ -like 'Read PM*' } | Should -BeNullOrEmpty
    }

    It 'searches service, user and note, ignoring case' {
        Add-LiteCredential -Service 'GitLab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'x') -Comment 'build server' | Out-Null
        Add-LiteCredential -Service 'wiki' -User 'bob' -Secret (ConvertTo-LiteTestSecure 'x') | Out-Null
        @(Get-LiteCredential -Search 'GITLAB').Count | Should -Be 1
        @(Get-LiteCredential -Search 'BOB').Service | Should -Be @('wiki')
        @(Get-LiteCredential -Search 'build').Service | Should -Be @('GitLab')
        @(Get-LiteCredential -Search 'nothing-matches').Count | Should -Be 0
        @(Get-LiteCredential).Count | Should -Be 2
    }

    It 'returns an empty list when there is nothing' { @(Get-LiteCredential).Count | Should -Be 0 }
}

Describe 'Limits and validation' {
    BeforeEach { $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset | Out-Null }

    It 'accepts a secret of exactly 1,280 characters (2,560 bytes)' {
        Add-LiteCredential -Service 's' -Secret (ConvertTo-LiteTestSecure ('a' * 1280)) | Out-Null
        $script:be.Store['lazarette-lite/s/s'].Secret.Length | Should -Be 1280
    }

    It 'refuses 1,281 characters with a clear error and writes nothing' {
        $err = $null
        try { Add-LiteCredential -Service 's' -Secret (ConvertTo-LiteTestSecure ('a' * 1281)) } catch { $err = $_.Exception.Message }
        $err | Should -Match '2,562 bytes'
        $err | Should -Match '2,560 bytes per credential'
        $err | Should -Match 'Nothing was written'
        $err | Should -Match 'Lazarette'
        $script:be.Calls | Where-Object { $_ -like 'Write *' } | Should -BeNullOrEmpty
    }

    It 'counts bytes, not characters, so non-ASCII text hits the limit the same way' {
        { Add-LiteCredential -Service 's' -Secret (ConvertTo-LiteTestSecure ([string][char]0x00e9 * 1281)) } | Should -Throw '*2,560 bytes*'
    }

    It 'refuses an empty secret on add' {
        { Add-LiteCredential -Service 's' -Secret (New-Object System.Security.SecureString) } | Should -Throw '*empty*'
    }

    It 'rejects <what>' -ForEach @(
        @{ what = 'a slash in the service'; svc = 'a/b'; usr = 'u' }
        @{ what = 'a slash in the user'; svc = 'a'; usr = 'u/v' }
        @{ what = 'a wildcard'; svc = 'a*'; usr = 'u' }
        @{ what = 'a blank service'; svc = ' '; usr = 'u' }
        @{ what = 'a padded name'; svc = ' a'; usr = 'u' }
        @{ what = 'a control character'; svc = "a`nb"; usr = 'u' }
        @{ what = 'a name over 100 characters'; svc = ('x' * 101); usr = 'u' }
    ) {
        { Add-LiteCredential -Service $svc -User $usr -Secret (ConvertTo-LiteTestSecure 'x') } | Should -Throw
        $script:be.Store.Count | Should -Be 0
    }

    It 'rejects a note over 256 characters' {
        { Add-LiteCredential -Service 's' -Secret (ConvertTo-LiteTestSecure 'x') -Comment ('n' * 257) } | Should -Throw '*256*'
    }
}

Describe 'Edit' {
    BeforeEach {
        $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset | Out-Null
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'old-secret') -Comment 'old note' | Out-Null
    }

    It 'changes the note and keeps the secret' {
        $r = Set-LiteCredential -Service 'gitlab' -Comment 'new note'
        $r.Comment | Should -Be 'new note'
        $script:be.Store['lazarette-lite/gitlab/anthony'].Secret | Should -Be 'old-secret'
    }

    It 'clears the note with an empty string' {
        (Set-LiteCredential -Service 'gitlab' -Comment '').Comment | Should -Be ''
    }

    It 'changes the secret and keeps the note' {
        Set-LiteCredential -Service 'gitlab' -Secret (ConvertTo-LiteTestSecure 'new-secret') | Out-Null
        $e = $script:be.Store['lazarette-lite/gitlab/anthony']
        $e.Secret | Should -Be 'new-secret'
        $e.Comment | Should -Be 'old note'
    }

    It 'renames by writing the new name before deleting the old one' {
        $script:be.Calls.Clear()
        $r = Set-LiteCredential -Service 'gitlab' -User 'anthony' -NewUser 'ahable' -NewService 'git'
        $r.Service | Should -Be 'git'
        $r.User | Should -Be 'ahable'
        $script:be.Store.ContainsKey('lazarette-lite/gitlab/anthony') | Should -BeFalse
        $script:be.Store['lazarette-lite/git/ahable'].Secret | Should -Be 'old-secret'
        $script:be.Store['lazarette-lite/git/ahable'].UserName | Should -Be 'ahable'
        $w = $script:be.Calls.FindIndex({ param($c) $c -like 'Write *' })
        $d = $script:be.Calls.FindIndex({ param($c) $c -like 'Delete *' })
        $w | Should -BeLessThan $d
    }

    It 'refuses to rename onto an existing entry and changes nothing' {
        Add-LiteCredential -Service 'gitlab' -User 'bob' -Secret (ConvertTo-LiteTestSecure 'bobs') | Out-Null
        { Set-LiteCredential -Service 'gitlab' -User 'anthony' -NewUser 'bob' } | Should -Throw '*already has*'
        $script:be.Store['lazarette-lite/gitlab/anthony'].Secret | Should -Be 'old-secret'
        $script:be.Store['lazarette-lite/gitlab/bob'].Secret | Should -Be 'bobs'
    }

    It 'refuses an oversize new secret and keeps the old one' {
        { Set-LiteCredential -Service 'gitlab' -Secret (ConvertTo-LiteTestSecure ('a' * 1500)) } | Should -Throw '*2,560 bytes*'
        $script:be.Store['lazarette-lite/gitlab/anthony'].Secret | Should -Be 'old-secret'
    }

    It 'asks for -User when the service is ambiguous, and names the missing item otherwise' {
        Add-LiteCredential -Service 'gitlab' -User 'bob' -Secret (ConvertTo-LiteTestSecure 'x') | Out-Null
        { Set-LiteCredential -Service 'gitlab' -Comment 'z' } | Should -Throw '*2 items named*pass -User*'
        { Set-LiteCredential -Service 'nope' -Comment 'z' } | Should -Throw "*no item 'nope'*"
    }
}

Describe 'Delete' {
    BeforeEach {
        $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset | Out-Null
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'x') | Out-Null
        Add-LiteCredential -Service 'wiki' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'y') | Out-Null
    }

    It 'removes only the chosen entry' {
        Remove-LiteCredential -Service 'gitlab' -Confirm:$false
        @(Get-LiteCredential).Service | Should -Be @('wiki')
    }

    It 'does nothing under -WhatIf' {
        Remove-LiteCredential -Service 'gitlab' -WhatIf
        @(Get-LiteCredential).Count | Should -Be 2
    }

    It 'throws for an item that is not there' {
        { Remove-LiteCredential -Service 'nope' -Confirm:$false } | Should -Throw "*no item 'nope'*"
    }
}
