#requires -Version 5.1
# Get-FleetSecret: full Lazarette first, Lazarette Lite as the fallback. Lite runs
# on the fake backend; the full engine is a stub Lazarette checkout (two small
# files in $TestDrive) â€” no real vault, no prompts. Synthetic data only.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')
    $script:origLazPath = $env:LAZARETTE_PATH
    $script:origArcPath = $env:ARC_PATH

    function New-TestFakeLazarette {
        param([string]$Root, [bool]$Unlocks)
        $lib = Join-Path $Root 'lib'
        $cli = Join-Path $lib 'cli'
        New-Item -ItemType Directory -Force -Path $cli | Out-Null
        Set-Content -LiteralPath (Join-Path $cli 'Console.ps1') -Value '# marker file: full Lazarette has lib/cli/Console.ps1' -Encoding UTF8
        $unlockLine = if ($Unlocks) { 'return $true' } else { 'return $false' }
        $lines = @(
            'function Unlock-LazaretteVaultInteractive { param([string]$DataDir) ' + $unlockLine + ' }',
            'function Get-LazaretteSecret { param([Parameter(Mandatory)][string]$Service, [string]$User = "", [string]$Field = "") return ''fake-lazarette-secret'' }',
            'function Get-LazaretteItemNames { return @() }'
        )
        Set-Content -LiteralPath (Join-Path $lib 'Lazarette.ps1') -Value ($lines -join "`n") -Encoding UTF8
    }
}

AfterAll {
    $env:LAZARETTE_PATH = $script:origLazPath
    $env:ARC_PATH = $script:origArcPath
    Set-LiteBackend $null
    Set-LitePrefix -Reset
    Remove-Module LazaretteLite -ErrorAction SilentlyContinue
}

Describe 'Get-FleetSecret' {
    BeforeEach {
        $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'lite-secret-1') | Out-Null
        $script:emptyRoot = Join-Path $TestDrive 'empty-laz'
        New-Item -ItemType Directory -Force -Path $script:emptyRoot | Out-Null
        $env:LAZARETTE_PATH = $script:emptyRoot
        $env:ARC_PATH = $script:emptyRoot
    }

    Context 'signature' {
        BeforeAll { $script:cmd = Get-Command Get-FleetSecret }

        It 'has Service, User, Field, NoSibling; Service mandatory; -Name aliases -Service' {
            $names = $script:cmd.Parameters.Keys | Where-Object { $_ -notin [Management.Automation.PSCmdlet]::CommonParameters }
            @($names | Sort-Object) | Should -Be @('Field', 'NoSibling', 'Service', 'User')
            $script:cmd.Parameters['Service'].Attributes.Where({ $_ -is [Parameter] }).Mandatory | Should -BeTrue
            $script:cmd.Parameters['Service'].Aliases | Should -Contain 'Name'
        }
    }

    It 'falls back to Lite when no Lazarette checkout is configured' {
        Get-FleetSecret -Service 'gitlab' -NoSibling | Should -Be 'lite-secret-1'
        Get-FleetSecret -Name 'gitlab' -User 'anthony' -NoSibling | Should -Be 'lite-secret-1'
    }

    It 'prefers a full Lazarette checkout when it unlocks, then restores the Lite functions' {
        $script:fakeRoot = Join-Path $TestDrive 'fake-laz'
        New-TestFakeLazarette -Root $script:fakeRoot -Unlocks $true
        $env:LAZARETTE_PATH = $script:fakeRoot
        Get-FleetSecret -Service 'gitlab' -NoSibling | Should -Be 'fake-lazarette-secret'
        Get-LazaretteSecret -Service 'gitlab' | Should -Be 'lite-secret-1'
        Unlock-LazaretteVaultInteractive | Should -BeTrue
    }

    It 'falls back to Lite when the Lazarette vault does not unlock' {
        $script:fakeRoot = Join-Path $TestDrive 'fake-laz-locked'
        New-TestFakeLazarette -Root $script:fakeRoot -Unlocks $false
        $env:LAZARETTE_PATH = $script:fakeRoot
        Get-FleetSecret -Service 'gitlab' -NoSibling | Should -Be 'lite-secret-1'
    }

    It 'names both stores and the item when neither has it' {
        Set-LiteBackend (New-LiteFakeBackend)
        $err = $null
        try { Get-FleetSecret -Service 'nope' -NoSibling } catch { $err = $_.Exception.Message }
        $err | Should -Match 'Lazarette'
        $err | Should -Match 'Lazarette Lite'
        $err | Should -Match "'nope'"
    }

    It 'keeps the Lite -Field throw when Lite answers' {
        { Get-FleetSecret -Service 'gitlab' -Field 'token' -NoSibling } | Should -Throw "*no field 'token'*"
    }
}

Describe 'Find-FleetSecretRoot' {
    BeforeEach {
        $script:emptyRoot = Join-Path $TestDrive 'empty-laz'
        New-Item -ItemType Directory -Force -Path $script:emptyRoot | Out-Null
        $env:LAZARETTE_PATH = $script:emptyRoot
        $env:ARC_PATH = $script:emptyRoot
    }

    It 'returns the LAZARETTE_PATH checkout when it looks like full Lazarette' {
        $script:fakeRoot = Join-Path $TestDrive 'fake-laz'
        New-TestFakeLazarette -Root $script:fakeRoot -Unlocks $true
        $env:LAZARETTE_PATH = $script:fakeRoot
        Find-FleetSecretRoot -NoSibling | Should -Be $script:fakeRoot
    }

    It 'falls back to ARC_PATH when LAZARETTE_PATH has no Lazarette' {
        $script:fakeRoot = Join-Path $TestDrive 'fake-laz-arc'
        New-TestFakeLazarette -Root $script:fakeRoot -Unlocks $true
        $env:ARC_PATH = $script:fakeRoot
        Find-FleetSecretRoot -NoSibling | Should -Be $script:fakeRoot
    }

    It 'returns $null when the configured path has no Lazarette' {
        Find-FleetSecretRoot -NoSibling | Should -BeNullOrEmpty
    }

    It 'does not mistake the Lite checkout itself for full Lazarette' {
        $env:LAZARETTE_PATH = (Join-Path $PSScriptRoot '..')
        Find-FleetSecretRoot -NoSibling | Should -BeNullOrEmpty
    }
}