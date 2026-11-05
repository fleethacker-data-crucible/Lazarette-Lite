#requires -Version 5.1
# lib\Lazarette.ps1 and lib\Arc.ps1 answer the Lazarette 5 integration contract (Lazarette docs/INTEGRATION.md),
# so a Fleet tool pointed at this folder works without change: Eight Bells and Semaphore dot-source the loader at
# script scope and call Test-LazaretteVaultUnlocked first, Halyard and Gangplank require all of
# Unlock-LazaretteVaultInteractive, Test-LazaretteVaultUnlocked, Get-LazaretteSecret and Get-LazaretteItemNames,
# TalkForge uses the Arc names. Fake backend, synthetic data only. (FleetLoaderModule.Tests.ps1 covers the
# dynamic-module way of loading.)

BeforeAll {
    $script:root = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $script:root 'LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')
    . (Join-Path $script:root 'lib\Arc.ps1')        # dot-sources lib\Lazarette.ps1 too
}
AfterAll { Set-LiteBackend $null; Set-LitePrefix -Reset; Remove-Module LazaretteLite -ErrorAction SilentlyContinue }

Describe 'The Lazarette 5 contract, answered by Lite' {
    BeforeEach {
        $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'glpat-synthetic-1') | Out-Null
        Add-LiteCredential -Service 'wiki' -User 'a' -Secret (ConvertTo-LiteTestSecure 'one') | Out-Null
        Add-LiteCredential -Service 'wiki' -User 'b' -Secret (ConvertTo-LiteTestSecure 'two') | Out-Null
    }

    It 'defines every function a Fleet tool calls' {
        foreach ($n in 'Unlock-LazaretteVaultInteractive', 'Test-LazaretteVaultUnlocked', 'Get-LazaretteSecret', 'Get-LazaretteItemNames', 'Lock-LazaretteVault') {
            Get-Command $n -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "$n is in the contract"
        }
    }
    It 'keeps the Get-LazaretteSecret signature: Service (mandatory), User, Field' {
        $cmd = Get-Command Get-LazaretteSecret
        $names = $cmd.Parameters.Keys | Where-Object { $_ -notin [Management.Automation.PSCmdlet]::CommonParameters }
        @($names | Sort-Object) | Should -Be @('Field', 'Service', 'User')
        $cmd.Parameters['Service'].Attributes.Where({ $_ -is [Parameter] }).Mandatory | Should -BeTrue
    }
    It 'is unlocked as soon as the store can be read, with no prompt, and ignores -DataDir' {
        Test-LazaretteVaultUnlocked | Should -BeTrue
        Unlock-LazaretteVaultInteractive | Should -BeTrue
        Unlock-LazaretteVaultInteractive -DataDir 'C:\nowhere' | Should -BeTrue
    }
    It 'reports a store that cannot be read as locked, and unlock as failed, without throwing' {
        $broken = New-LiteFakeBackend
        $broken.Enumerate = { param($Filter) throw 'fake: access denied' }
        Set-LiteBackend $broken
        Test-LazaretteVaultUnlocked | Should -BeFalse
        (Unlock-LazaretteVaultInteractive -WarningAction SilentlyContinue) | Should -BeFalse
    }
    It 'reads a secret by service, by service and user, and through the -Name alias' {
        Get-LazaretteSecret -Service 'gitlab' | Should -Be 'glpat-synthetic-1'
        Get-LazaretteSecret -Service 'wiki' -User 'b' | Should -Be 'two'
        Get-LazaretteSecret -Name 'gitlab' | Should -Be 'glpat-synthetic-1'
    }
    It 'accepts an empty -User and -Field, as the tools pass them' {
        Get-LazaretteSecret -Service 'gitlab' -User '' -Field '' | Should -Be 'glpat-synthetic-1'
    }
    It 'throws for a missing, ambiguous or field read, with Lazarette wording' {
        { Get-LazaretteSecret -Service 'nope' } | Should -Throw "*no item 'nope'*"
        { Get-LazaretteSecret -Service 'wiki' } | Should -Throw '*2 items named*pass -User*'
        { Get-LazaretteSecret -Service 'gitlab' -Field 'Host' } | Should -Throw "*no field 'Host'*"
    }
    It 'throws for an item with no secret yet instead of returning an empty string' {
        $script:be.Store['lazarette-lite/placeholder/placeholder'] = [pscustomobject]@{ Target = 'lazarette-lite/placeholder/placeholder'; UserName = 'placeholder'; Comment = ''; Secret = ''; LastWritten = [datetime]::UtcNow }
        { Get-LazaretteSecret -Service 'placeholder' } | Should -Throw '*no secret yet*'
    }
    It 'lists names only' {
        $names = @(Get-LazaretteItemNames)
        $names.Count | Should -Be 3
        @($names | ForEach-Object { $_.Service }) | Should -Contain 'gitlab'
        $names[0].PSObject.Properties.Name | Should -Be @('Service', 'User', 'Type', 'Tags')
        ($names | ConvertTo-Json) | Should -Not -Match 'glpat'
    }
    It 'locks without error and stays readable afterwards (Windows holds the key, not Lite)' {
        { Lock-LazaretteVault } | Should -Not -Throw
        Test-LazaretteVaultUnlocked | Should -BeTrue
    }
    It 'answers the older ARC names too (TalkForge)' {
        Unlock-ArcVaultInteractive | Should -BeTrue
        Test-ArcVaultUnlocked | Should -BeTrue
        Get-ArcSecret -Service 'gitlab' | Should -Be 'glpat-synthetic-1'
        @(Get-ArcItemNames).Count | Should -Be 3
        { Lock-ArcVault } | Should -Not -Throw
    }
}
