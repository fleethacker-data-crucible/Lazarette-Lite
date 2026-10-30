#requires -Version 5.1
# Export and import of names and notes. The point of these tests: no secret ever goes into, or comes
# out of, the file. Fake backend, synthetic data only.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')

    function Write-TestExport { param([string]$Path, $Doc) [IO.File]::WriteAllText($Path, ($Doc | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false))) }
    function New-TestDoc { param($Items) [ordered]@{ format = 'lazarette-lite-export'; version = 1; exported = '2026-10-30T00:00:00Z'; prefix = 'lazarette-lite/'; items = @($Items) } }
}

AfterAll {
    Set-LiteBackend $null
    Set-LitePrefix -Reset
    Remove-Module LazaretteLite -ErrorAction SilentlyContinue
}

Describe 'Export-LiteMetadata' {
    BeforeEach {
        $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'SYNTH-SECRET-ONE') -Comment 'build server' | Out-Null
        Add-LiteCredential -Service 'wiki' -User 'bob' -Secret (ConvertTo-LiteTestSecure 'SYNTH-SECRET-TWO') | Out-Null
        $script:file = Join-Path $TestDrive 'names-export.json'
        Remove-Item $script:file -ErrorAction SilentlyContinue
    }

    It 'writes names, users and notes, and the secrets appear nowhere in the file' {
        $r = Export-LiteMetadata -Path $script:file
        $r.Count | Should -Be 2
        $text = [IO.File]::ReadAllText($script:file)
        $text | Should -Not -Match 'SYNTH-SECRET'
        $doc = $text | ConvertFrom-Json
        $doc.format | Should -Be 'lazarette-lite-export'
        $doc.version | Should -Be 1
        $doc.prefix | Should -Be 'lazarette-lite/'
        @($doc.items).Count | Should -Be 2
        $g = $doc.items | Where-Object service -eq 'gitlab'
        $g.user | Should -Be 'anthony'
        $g.comment | Should -Be 'build server'
        $g.PSObject.Properties.Name | Should -Be @('service', 'user', 'comment')
    }

    It 'never reads a secret to do it' {
        $script:be.Calls.Clear()
        Export-LiteMetadata -Path $script:file | Out-Null
        @($script:be.Calls | Where-Object { $_ -like 'Read *' }).Count | Should -Be 0
        @($script:be.Calls | Where-Object { $_ -like 'Write *' -or $_ -like 'Delete *' }).Count | Should -Be 0
    }

    It 'writes UTF-8 without a byte-order mark' {
        Export-LiteMetadata -Path $script:file | Out-Null
        $bytes = [IO.File]::ReadAllBytes($script:file)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB) | Should -BeFalse
    }

    It 'refuses to overwrite a file unless told to' {
        Export-LiteMetadata -Path $script:file | Out-Null
        { Export-LiteMetadata -Path $script:file } | Should -Throw '*already exists*'
        { Export-LiteMetadata -Path $script:file -Force } | Should -Not -Throw
    }

    It 'writes a valid file with an empty list when there is nothing to export' {
        Set-LiteBackend (New-LiteFakeBackend)
        Export-LiteMetadata -Path $script:file | Out-Null
        $doc = [IO.File]::ReadAllText($script:file) | ConvertFrom-Json
        @($doc.items).Count | Should -Be 0
        { Import-LiteMetadata -Path $script:file } | Should -Not -Throw
    }

    It 'resolves a relative path against the current location' {
        Push-Location $TestDrive
        try { Export-LiteMetadata -Path '.\relative-export.json' | Out-Null } finally { Pop-Location }
        Test-Path (Join-Path $TestDrive 'relative-export.json') | Should -BeTrue
    }
}

Describe 'Import-LiteMetadata' {
    BeforeEach {
        $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset
        $script:file = Join-Path $TestDrive 'in.json'
    }

    It 'round-trips: a second machine gets the names and notes as placeholders, with no secret' {
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'SYNTH-SECRET-ONE') -Comment 'build server' | Out-Null
        Export-LiteMetadata -Path $script:file -Force | Out-Null

        $other = New-LiteFakeBackend; Set-LiteBackend $other
        $r = Import-LiteMetadata -Path $script:file
        $r.Created | Should -Be 1
        $r.Skipped | Should -Be 0
        $l = @(Get-LiteCredential)
        $l.Count | Should -Be 1
        $l[0].Service | Should -Be 'gitlab'
        $l[0].User | Should -Be 'anthony'
        $l[0].Comment | Should -Be 'build server'
        $l[0].HasSecret | Should -BeFalse
        $other.Store['lazarette-lite/gitlab/anthony'].Secret | Should -Be ''
        { Get-LiteSecret -Service 'gitlab' } | Should -Throw '*no secret yet*'

        Set-LiteCredential -Service 'gitlab' -Secret (ConvertTo-LiteTestSecure 'filled-in-here') | Out-Null
        Get-LiteSecret -Service 'gitlab' | Should -Be 'filled-in-here'
    }

    It 'leaves existing entries alone and never reads their secrets' {
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'keep-me') -Comment 'mine' | Out-Null
        Write-TestExport $script:file (New-TestDoc @(
                @{ service = 'GitLab'; user = 'Anthony'; comment = 'from file' }
                @{ service = 'wiki'; user = 'bob'; comment = '' }))
        $script:be.Calls.Clear()
        $r = Import-LiteMetadata -Path $script:file
        $r.Created | Should -Be 1
        $r.Skipped | Should -Be 1
        $script:be.Store['lazarette-lite/gitlab/anthony'].Secret | Should -Be 'keep-me'
        $script:be.Store['lazarette-lite/gitlab/anthony'].Comment | Should -Be 'mine'
        @($script:be.Calls | Where-Object { $_ -like 'Read *' }).Count | Should -Be 0
    }

    It 'imports under the current prefix, whatever prefix the file came from' {
        Write-TestExport $script:file (New-TestDoc @(@{ service = 'wiki'; user = 'bob'; comment = '' }))
        Set-LitePrefix 'team-b/'
        Import-LiteMetadata -Path $script:file | Out-Null
        $script:be.Store.ContainsKey('team-b/wiki/bob') | Should -BeTrue
    }

    It 'fills a missing user with the service, as Add-LiteCredential does' {
        Write-TestExport $script:file (New-TestDoc @(@{ service = 'wiki' }))
        Import-LiteMetadata -Path $script:file | Out-Null
        $script:be.Store.ContainsKey('lazarette-lite/wiki/wiki') | Should -BeTrue
    }

    It 'creates nothing under -WhatIf' {
        Write-TestExport $script:file (New-TestDoc @(@{ service = 'wiki'; user = 'bob'; comment = '' }))
        $r = Import-LiteMetadata -Path $script:file -WhatIf
        $script:be.Store.Count | Should -Be 0
        $r.Items[0].Status | Should -Be 'WouldCreate'
    }

    Context 'refuses a file that is not a plain list of names, and creates nothing' {
        It 'rejects <what>' -ForEach @(
            @{ what = 'an item with a secret field'; items = @(@{ service = 'a'; user = 'u'; secret = 'SYNTH-LEAK' }); msg = "*field 'secret'*" }
            @{ what = 'an item with a password field'; items = @(@{ service = 'a'; user = 'u'; password = 'SYNTH-LEAK' }); msg = "*field 'password'*" }
            @{ what = 'a slash in a name'; items = @(@{ service = 'a/b'; user = 'u' }); msg = '*Item 1 is not valid*' }
            @{ what = 'a blank service'; items = @(@{ service = ''; user = 'u' }); msg = '*Item 1 is not valid*' }
            @{ what = 'a note over 256 characters'; items = @(@{ service = 'a'; user = 'u'; comment = ('n' * 300) }); msg = '*Item 1 is not valid*' }
            @{ what = 'a repeated item'; items = @(@{ service = 'a'; user = 'u' }, @{ service = 'A'; user = 'U' }); msg = '*repeats*' }
            @{ what = 'a valid item followed by a bad one'; items = @(@{ service = 'ok'; user = 'u' }, @{ service = 'bad*'; user = 'u' }); msg = '*Item 2 is not valid*' }
        ) {
            Write-TestExport $script:file (New-TestDoc $items)
            $err = $null
            try { Import-LiteMetadata -Path $script:file } catch { $err = $_.Exception.Message }
            $err | Should -BeLike $msg
            $err | Should -Not -Match 'SYNTH-LEAK'
            $script:be.Store.Count | Should -Be 0
        }

        It 'rejects an unexpected top-level field' {
            $d = New-TestDoc @(@{ service = 'a'; user = 'u' }); $d['secrets'] = @{ a = 'SYNTH-LEAK' }
            Write-TestExport $script:file $d
            { Import-LiteMetadata -Path $script:file } | Should -Throw "*unexpected field 'secrets'*"
            $script:be.Store.Count | Should -Be 0
        }

        It 'rejects a wrong format, a wrong version, bad JSON and a missing file' {
            Write-TestExport $script:file ([ordered]@{ format = 'something-else'; version = 1; items = @() })
            { Import-LiteMetadata -Path $script:file } | Should -Throw '*not a Lazarette Lite export*'
            Write-TestExport $script:file ([ordered]@{ format = 'lazarette-lite-export'; version = 2; items = @() })
            { Import-LiteMetadata -Path $script:file } | Should -Throw '*version*not supported*'
            Set-Content -LiteralPath $script:file -Value '{ not json'
            { Import-LiteMetadata -Path $script:file } | Should -Throw '*not valid JSON*'
            { Import-LiteMetadata -Path (Join-Path $TestDrive 'missing.json') } | Should -Throw '*No export file*'
        }

        It 'rejects a file over 1 MB without parsing it' {
            [IO.File]::WriteAllText($script:file, ('x' * (1MB + 10)))
            { Import-LiteMetadata -Path $script:file } | Should -Throw '*larger than 1 MB*'
        }

        It 'rejects a file with more than 5,000 items' {
            Write-TestExport $script:file (New-TestDoc (1..5001 | ForEach-Object { @{ service = "s$_"; user = 'u' } }))
            { Import-LiteMetadata -Path $script:file } | Should -Throw '*limit is 5000*'
            $script:be.Store.Count | Should -Be 0
        }
    }
}
