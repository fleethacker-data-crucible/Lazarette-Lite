#requires -Version 5.1
# Register-LazaretteLite.ps1 decides per variable: set when unset or stale, keep another working Lazarette unless
# -Force, remove only its own value. Process scope only here, so the test never touches the user's saved
# environment; the process values are restored afterwards.

Describe 'Register-LazaretteLite.ps1 (process scope)' {
    BeforeAll {
        $script:root = Split-Path $PSScriptRoot -Parent
        $script:register = Join-Path $script:root 'Register-LazaretteLite.ps1'
        $script:vars = @('LAZARETTE_PATH', 'ARC_PATH', 'GANGPLANK_LAZARETTE_PATH')
        $script:saved = @{}
        foreach ($v in $script:vars) { $script:saved[$v] = [Environment]::GetEnvironmentVariable($v, 'Process') }
        # A stand-in for the full Lazarette: any folder with lib\Lazarette.ps1.
        $script:other = Join-Path $TestDrive 'Lazarette'
        New-Item -ItemType Directory -Path (Join-Path $script:other 'lib') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:other 'lib\Lazarette.ps1') -Value '# stand-in'
    }
    AfterAll { foreach ($v in $script:vars) { [Environment]::SetEnvironmentVariable($v, $script:saved[$v], 'Process') } }
    BeforeEach { foreach ($v in $script:vars) { [Environment]::SetEnvironmentVariable($v, $null, 'Process') } }

    It 'sets all three variables when none is set' {
        $rows = @(& $script:register -Scope Process 6>$null)
        foreach ($v in $script:vars) { [Environment]::GetEnvironmentVariable($v, 'Process') | Should -Be $script:root }
        @($rows | Where-Object { $_.Action -eq 'set' }).Count | Should -Be 3
    }
    It 'keeps a variable that points at another working Lazarette, unless -Force' {
        [Environment]::SetEnvironmentVariable('LAZARETTE_PATH', $script:other, 'Process')
        $rows = @(& $script:register -Scope Process 6>$null)
        [Environment]::GetEnvironmentVariable('LAZARETTE_PATH', 'Process') | Should -Be $script:other
        ($rows | Where-Object { $_.Variable -eq 'LAZARETTE_PATH' }).Action | Should -Match '^kept'
        [Environment]::GetEnvironmentVariable('ARC_PATH', 'Process') | Should -Be $script:root
        & $script:register -Scope Process -Force 6>$null | Out-Null
        [Environment]::GetEnvironmentVariable('LAZARETTE_PATH', 'Process') | Should -Be $script:root
    }
    It 'treats ARC_PATH at a folder without lib\Arc.ps1 (the full Lazarette) as unusable and replaces it' {
        [Environment]::SetEnvironmentVariable('ARC_PATH', $script:other, 'Process')
        & $script:register -Scope Process 6>$null | Out-Null
        [Environment]::GetEnvironmentVariable('ARC_PATH', 'Process') | Should -Be $script:root
    }
    It 'replaces a stale value whose folder has no loader' {
        [Environment]::SetEnvironmentVariable('LAZARETTE_PATH', (Join-Path $TestDrive 'gone'), 'Process')
        & $script:register -Scope Process 6>$null | Out-Null
        [Environment]::GetEnvironmentVariable('LAZARETTE_PATH', 'Process') | Should -Be $script:root
    }
    It 'reports an existing registration without changing it, whatever the trailing slash or quotes' {
        [Environment]::SetEnvironmentVariable('LAZARETTE_PATH', ('"' + $script:root + '\"'), 'Process')
        $rows = @(& $script:register -Scope Process 6>$null)
        ($rows | Where-Object { $_.Variable -eq 'LAZARETTE_PATH' }).Action | Should -Be 'already set'
        [Environment]::GetEnvironmentVariable('LAZARETTE_PATH', 'Process') | Should -Be ('"' + $script:root + '\"')
    }
    It '-Unregister removes only values that point at this folder' {
        [Environment]::SetEnvironmentVariable('LAZARETTE_PATH', $script:root, 'Process')
        [Environment]::SetEnvironmentVariable('ARC_PATH', $script:other, 'Process')
        & $script:register -Scope Process -Unregister 6>$null | Out-Null
        [Environment]::GetEnvironmentVariable('LAZARETTE_PATH', 'Process') | Should -BeNullOrEmpty
        [Environment]::GetEnvironmentVariable('ARC_PATH', 'Process') | Should -Be $script:other
    }
    It '-WhatIf changes nothing' {
        & $script:register -Scope Process -WhatIf 6>$null | Out-Null
        [Environment]::GetEnvironmentVariable('LAZARETTE_PATH', 'Process') | Should -BeNullOrEmpty
    }
    It 'refuses a folder that is not a Lazarette Lite checkout' {
        { & $script:register -Scope Process -Root $TestDrive 6>$null } | Should -Throw '*lib\Lazarette.ps1*'
    }
}
