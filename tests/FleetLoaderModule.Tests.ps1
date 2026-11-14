#requires -Version 5.1
# Halyard and Gangplank load lib\Lazarette.ps1 inside a dynamic module (New-Module { . $loader }) imported
# globally, and then look the contract functions up by name. This file keeps its own scope free of the loader so
# the lookups must find the dynamic module's functions. Fake backend, synthetic data only.

BeforeAll {
    $script:root = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $script:root 'LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')
    $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset
    Add-LiteCredential -Service 'github' -User 'me' -Secret (ConvertTo-LiteTestSecure 'ghp-synthetic') | Out-Null
    $script:dyn = New-Module -Name LiteContractTest -ScriptBlock {
        param([string]$LoaderPath)
        $ErrorActionPreference = 'Stop'
        . $LoaderPath
        Export-ModuleMember -Function * -ErrorAction SilentlyContinue
    } -ArgumentList (Join-Path $script:root 'lib\Lazarette.ps1')
    Import-Module -ModuleInfo $script:dyn -Global -ErrorAction Stop -WarningAction SilentlyContinue
}
AfterAll {
    Remove-Module LiteContractTest -ErrorAction SilentlyContinue
    Set-LiteBackend $null; Set-LitePrefix -Reset
    Remove-Module LazaretteLite -ErrorAction SilentlyContinue
}

Describe 'The loader inside a dynamic module (Halyard, Gangplank)' {
    It 'exports every contract function from the dynamic module' {
        foreach ($n in 'Unlock-LazaretteVaultInteractive', 'Test-LazaretteVaultUnlocked', 'Get-LazaretteSecret', 'Get-LazaretteItemNames', 'Lock-LazaretteVault') {
            $cmd = Get-Command $n -ErrorAction SilentlyContinue
            $cmd | Should -Not -BeNullOrEmpty -Because "$n is in the contract"
            $cmd.Module.Name | Should -Be 'LiteContractTest'
        }
    }
    It 'reads through the one LazaretteLite module instance, so the store it sees is the real one' {
        & (Get-Command Test-LazaretteVaultUnlocked -Module LiteContractTest) | Should -BeTrue
        & (Get-Command Unlock-LazaretteVaultInteractive -Module LiteContractTest) | Should -BeTrue
        & (Get-Command Get-LazaretteSecret -Module LiteContractTest) -Service 'github' | Should -Be 'ghp-synthetic'
        @(& (Get-Command Get-LazaretteItemNames -Module LiteContractTest)).Count | Should -Be 1
    }
}
