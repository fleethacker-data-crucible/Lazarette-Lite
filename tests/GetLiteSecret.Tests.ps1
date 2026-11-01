#requires -Version 5.1
# Get-LiteSecret must behave like Lazarette's Get-ArcSecret (lib\cli\Console.ps1) for the cases a
# script can hit. Fake backend, synthetic data only.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')
}

AfterAll {
    Set-LiteBackend $null
    Set-LitePrefix -Reset
    Remove-Module LazaretteLite -ErrorAction SilentlyContinue
}

Describe 'Get-LiteSecret' {
    BeforeEach {
        $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'glpat-synthetic-1') | Out-Null
        Add-LiteCredential -Service 'wiki' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'wiki-pass') | Out-Null
        Add-LiteCredential -Service 'wiki' -User 'bob' -Secret (ConvertTo-LiteTestSecure 'bobs-pass') | Out-Null
    }

    Context 'signature (so a script can move to Get-ArcSecret unchanged)' {
        BeforeAll { $script:cmd = Get-Command Get-LiteSecret }

        It 'has the same parameters as Get-ArcSecret: Service, User, Field, all strings' {
            $names = $script:cmd.Parameters.Keys | Where-Object { $_ -notin [Management.Automation.PSCmdlet]::CommonParameters }
            @($names | Sort-Object) | Should -Be @('Field', 'Service', 'User')
            'Service', 'User', 'Field' | ForEach-Object { $script:cmd.Parameters[$_].ParameterType | Should -Be ([string]) }
        }
        It 'requires -Service only' {
            $script:cmd.Parameters['Service'].Attributes.Where({ $_ -is [Parameter] }).Mandatory | Should -BeTrue
            $script:cmd.Parameters['User'].Attributes.Where({ $_ -is [Parameter] }).Mandatory | Should -Not -Contain $true
            $script:cmd.Parameters['Field'].Attributes.Where({ $_ -is [Parameter] }).Mandatory | Should -Not -Contain $true
        }
        It 'accepts -Name as an alias of -Service' { $script:cmd.Parameters['Service'].Aliases | Should -Contain 'Name' }
        It 'takes the service positionally' { Get-LiteSecret 'gitlab' | Should -Be 'glpat-synthetic-1' }
    }

    It 'returns the secret as a plain string' {
        $s = Get-LiteSecret -Service 'gitlab'
        $s | Should -BeOfType ([string])
        $s | Should -Be 'glpat-synthetic-1'
    }

    It 'works with -Name' { Get-LiteSecret -Name 'gitlab' | Should -Be 'glpat-synthetic-1' }

    It 'matches the service and user without regard to case' {
        Get-LiteSecret -Service 'GITLAB' -User 'ANTHONY' | Should -Be 'glpat-synthetic-1'
    }

    It 'uses -User to choose between items of the same service' {
        Get-LiteSecret -Service 'wiki' -User 'bob' | Should -Be 'bobs-pass'
    }

    It 'throws when there is no such item, naming it' {
        { Get-LiteSecret -Service 'nope' } | Should -Throw "*no item 'nope'*"
        { Get-LiteSecret -Service 'gitlab' -User 'zed' } | Should -Throw "*no item 'gitlab' for user 'zed'*"
    }

    It 'throws when the service is ambiguous and tells the caller to pass -User' {
        { Get-LiteSecret -Service 'wiki' } | Should -Throw '*2 items named*pass -User*'
    }

    It 'throws for -Field, like Get-ArcSecret does for a field an item does not have' {
        { Get-LiteSecret -Service 'gitlab' -Field 'token' } | Should -Throw "*no field 'token'*"
    }

    It 'throws for an item that has no secret yet instead of returning an empty string' {
        $script:be.Store['lazarette-lite/placeholder/placeholder'] = [pscustomobject]@{ Target = 'lazarette-lite/placeholder/placeholder'; UserName = 'placeholder'; Comment = ''; Secret = ''; LastWritten = [datetime]::UtcNow }
        { Get-LiteSecret -Service 'placeholder' } | Should -Throw '*no secret yet*'
    }

    It 'reads only the one entry it was asked for' {
        $script:be.Calls.Clear()
        Get-LiteSecret -Service 'gitlab' | Out-Null
        @($script:be.Calls | Where-Object { $_ -like 'Read *' }) | Should -Be @('Read lazarette-lite/gitlab/anthony')
    }

    It 'never sees entries outside its prefix' {
        $script:be.Store['Other/gitlab/x'] = [pscustomobject]@{ Target = 'Other/gitlab/x'; UserName = 'x'; Comment = ''; Secret = 'foreign'; LastWritten = [datetime]::UtcNow }
        Set-LitePrefix 'team-b/'
        { Get-LiteSecret -Service 'gitlab' } | Should -Throw '*no item*'
    }
}

Describe 'Get-LiteItemNames' {
    BeforeEach { $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset }

    It 'returns service, user, type and tags, and no secret, like Get-ArcItemNames' {
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'hunter-synthetic') | Out-Null
        $n = @(Get-LiteItemNames)
        $n.Count | Should -Be 1
        $n[0].PSObject.Properties.Name | Should -Be @('Service', 'User', 'Type', 'Tags')
        ($n | ConvertTo-Json) | Should -Not -Match 'hunter'
    }
}
