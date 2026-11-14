#requires -Version 5.1
# Only the checking half of scripts\Sign-Release.ps1 can be tested here: there is no code-signing
# certificate in this repository, and the tests must not create one in anybody's certificate store.

Describe 'Sign-Release.ps1 -Verify' {
    BeforeAll {
        $script:script = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\Sign-Release.ps1'
        $script:fake = Join-Path $TestDrive 'pkg'
        New-Item -ItemType Directory -Path (Join-Path $script:fake 'lib\server') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:fake 'a.ps1') -Value 'Write-Output 1'
        Set-Content -LiteralPath (Join-Path $script:fake 'lib\b.ps1') -Value 'Write-Output 2'
        Set-Content -LiteralPath (Join-Path $script:fake 'lib\server\c.ps1') -Value 'Write-Output 3'
        Set-Content -LiteralPath (Join-Path $script:fake 'ignored.txt') -Value 'not a script'
    }

    It 'fails, and names the files, when scripts are not signed' {
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:script -Verify -Root $script:fake 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 1
        $out | Should -Match 'NotSigned'
        $out | Should -Match 'a\.ps1'
        $out | Should -Match 'lib\\b\.ps1'
        $out | Should -Match 'lib\\server\\c\.ps1'
        $out | Should -Match '3 of 3 files are not validly signed'
        $out | Should -Not -Match 'ignored\.txt'
    }

    It 'refuses to sign with an unknown thumbprint and signs nothing' {
        $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:script -Thumbprint ('0' * 40) -Root $script:fake 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        (Get-AuthenticodeSignature -LiteralPath (Join-Path $script:fake 'a.ps1')).Status | Should -Be 'NotSigned'
    }
}
