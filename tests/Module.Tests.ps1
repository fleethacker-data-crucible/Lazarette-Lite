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
    It 'loads every lib\*.ps1 except the Fleet loaders and the command line, which import the module themselves' {
        $psm1 = Get-Content -LiteralPath (Join-Path $script:root 'LazaretteLite.psm1') -Raw
        $loaders = @('Lazarette.ps1', 'Arc.ps1', 'Cli.ps1')
        foreach ($f in Get-ChildItem -LiteralPath (Join-Path $script:root 'lib') -File -Filter '*.ps1') {
            if ($f.Name -in $loaders) { $psm1 | Should -Not -Match ([regex]::Escape($f.Name)) -Because "$($f.Name) imports the module itself" }
            else { $psm1 | Should -Match ([regex]::Escape($f.Name)) -Because "$($f.Name) is part of the module" }
        }
    }
}
