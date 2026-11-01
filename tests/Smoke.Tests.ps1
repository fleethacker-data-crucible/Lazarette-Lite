#requires -Version 5.1
# The ONE test that talks to the real Windows Credential Manager. Off by default (run-tests.ps1 -Smoke
# turns it on). It uses a throwaway prefix that it makes up, writes only under that prefix, and deletes
# everything under it afterwards, so it never reads or changes any credential that was already there.

BeforeDiscovery {
    $script:smokeOn = ($env:LITE_SMOKE -eq '1') -and ($env:OS -eq 'Windows_NT')
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')
    $script:smokePrefix = 'lazarette-lite-smoke-{0}/' -f ([guid]::NewGuid().ToString('N').Substring(0, 12))
}

AfterAll {
    if ($env:LITE_SMOKE -eq '1' -and $script:smokePrefix) {
        Set-LiteBackend $null
        Set-LitePrefix $script:smokePrefix
        Get-LiteCredential | ForEach-Object { Remove-LiteCredential -Service $_.Service -User $_.User -Confirm:$false }
    }
    Set-LitePrefix -Reset
    Remove-Module LazaretteLite -ErrorAction SilentlyContinue
}

Describe 'Real Windows Credential Manager (throwaway prefix)' -Skip:(-not $script:smokeOn) {
    It 'adds, lists, edits, renames, reads, exports, imports and deletes, and takes a full 2,560-byte secret' {
        Set-LiteBackend $null
        Set-LitePrefix $script:smokePrefix

        @(Get-LiteCredential).Count | Should -Be 0
        Add-LiteCredential -Service 'smoke' -User 'tester' -Secret (ConvertTo-LiteTestSecure 'smoke-secret-1') -Comment 'throwaway' | Out-Null

        $l = @(Get-LiteCredential)
        $l.Count | Should -Be 1
        $l[0].Service | Should -Be 'smoke'
        $l[0].User | Should -Be 'tester'
        $l[0].HasSecret | Should -BeTrue

        $read = InModuleScope LazaretteLite { param($t) (& (Get-LiteBackend).Read $t).Secret } -Parameters @{ t = $l[0].Target }
        $read | Should -Be 'smoke-secret-1'

        Set-LiteCredential -Service 'smoke' -Comment 'edited' | Out-Null
        (Get-LiteCredential -Service 'smoke').Comment | Should -Be 'edited'

        Set-LiteCredential -Service 'smoke' -NewUser 'renamed' | Out-Null
        @(Get-LiteCredential).User | Should -Be @('renamed')

        $full = 'x' * 1280
        Set-LiteCredential -Service 'smoke' -Secret (ConvertTo-LiteTestSecure $full) | Out-Null
        $back = InModuleScope LazaretteLite { param($t) (& (Get-LiteBackend).Read $t).Secret } -Parameters @{ t = (Get-LiteCredential -Service 'smoke').Target }
        $back.Length | Should -Be 1280

        Get-LiteSecret -Service 'smoke' | Should -Be $full

        # Export carries no secret; importing it after a delete makes an empty placeholder.
        $file = Join-Path $TestDrive 'smoke-export.json'
        Export-LiteMetadata -Path $file | Out-Null
        [IO.File]::ReadAllText($file) | Should -Not -Match 'xxxxxxxx'
        Remove-LiteCredential -Service 'smoke' -Confirm:$false
        @(Get-LiteCredential).Count | Should -Be 0
        (Import-LiteMetadata -Path $file).Created | Should -Be 1
        (Get-LiteCredential -Service 'smoke').HasSecret | Should -BeFalse
        { Get-LiteSecret -Service 'smoke' } | Should -Throw '*no secret yet*'

        Remove-LiteCredential -Service 'smoke' -Confirm:$false
        @(Get-LiteCredential).Count | Should -Be 0
    }
}
