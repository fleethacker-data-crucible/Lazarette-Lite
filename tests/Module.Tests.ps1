#requires -Version 5.1
# The manifest and the module must agree: every function LazaretteLite.psd1 exports has to exist after
# Import-Module. (The browser-app change of 2026-11-03 listed the lib\ files by name and left out Generator.ps1
# and Check.ps1, which silently removed New-LitePassword, Set-LiteRandomSource and Test-LiteStore.)

BeforeAll {
    $script:root = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $script:root 'LazaretteLite.psd1') -Force
}
AfterAll { Remove-Module LazaretteLite -ErrorAction SilentlyContinue }

Describe 'LazaretteLite module' {
    It 'defines every function the manifest exports' {
        $manifest = Import-PowerShellDataFile (Join-Path $script:root 'LazaretteLite.psd1')
        $missing = @($manifest.FunctionsToExport | Where-Object { -not (Get-Command $_ -Module LazaretteLite -ErrorAction SilentlyContinue) })
        $missing | Should -BeNullOrEmpty
    }
    It 'still exports New-LitePassword, Set-LiteRandomSource and Test-LiteStore' {
        foreach ($n in 'New-LitePassword', 'Set-LiteRandomSource', 'Test-LiteStore') {
            Get-Command $n -Module LazaretteLite -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "$n disappears when Generator.ps1 or Check.ps1 leaves the loader"
        }
    }
    It 'loads every lib script except the command line, including Generator.ps1 and Check.ps1' {
        $psm1 = Get-Content -LiteralPath (Join-Path $script:root 'LazaretteLite.psm1') -Raw
        foreach ($f in Get-ChildItem -LiteralPath (Join-Path $script:root 'lib') -File -Filter '*.ps1') {
            $quoted = "'" + $f.Name + "'"
            if ($f.Name -eq 'Cli.ps1') {
                $psm1 | Should -Not -Match ([regex]::Escape($quoted)) -Because 'the command line imports the module itself'
            } else {
                $psm1 | Should -Match ([regex]::Escape($quoted)) -Because "$($f.Name) is part of the module"
            }
        }
    }
}
