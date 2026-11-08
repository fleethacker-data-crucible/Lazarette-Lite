#requires -Version 5.1
# Import-LiteFromLazaretteCsv: a user exports their unlocked Lazarette vault to CSV
# (header name,url,username,password,note,totp,folder,type,fields) and imports it
# here. Fake backend, synthetic data only. The report never carries a secret.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')
}

AfterAll {
    Set-LiteBackend $null
    Set-LitePrefix -Reset
    Remove-Module LazaretteLite -ErrorAction SilentlyContinue
}

Describe 'Import-LiteFromLazaretteCsv' {
    BeforeEach {
        $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset
        $script:file = Join-Path $TestDrive 'lazarette-export.csv'
    }

    It 'imports name/username/password rows and maps note to the comment' {
        $csv = @(
            'name,url,username,password,note,totp,folder,type,fields',
            'gitlab,https://gitlab.example,anthony,SYNTH-MIGRATE-ONE,work account,,,login,',
            'wiki,,bob,SYNTH-MIGRATE-TWO,,,,login,'
        ) -join "`n"
        [IO.File]::WriteAllText($script:file, $csv, (New-Object Text.UTF8Encoding($false)))
        $r = Import-LiteFromLazaretteCsv -Path $script:file
        $r.Imported | Should -Be 2
        $r.SkippedOversize | Should -Be 0
        $r.SkippedEmpty | Should -Be 0
        $r.SkippedDuplicate | Should -Be 0
        @($r.Items.Status) | Should -Be @('imported', 'imported')
        (Get-LiteSecret -Service 'gitlab' -User 'anthony') | Should -Be 'SYNTH-MIGRATE-ONE'
        (@(Get-LiteCredential -Service 'gitlab')[0]).Comment | Should -Be 'work account'
        ($r | ConvertTo-Json -Depth 4) | Should -Not -Match 'SYNTH-MIGRATE'
    }

    It 'skips an oversize secret and writes nothing for it' {
        # v7: the row MUST be built outside the @(...) literal. PowerShell
        # splits "a" + "b" inside @(...) into separate array elements (proved
        # locally: @('h', 'b' + 'c') has 3 elements, not 2), so the 1,281-char
        # secret landed as its own CSV row and the password column was empty.
        $bigRow = 'big,,u,' + ('x' * 1281) + ',,,,login,'
        $csv = @(
            'name,url,username,password,note,totp,folder,type,fields',
            $bigRow
        ) -join "`n"
        [IO.File]::WriteAllText($script:file, $csv, (New-Object Text.UTF8Encoding($false)))
        $r = Import-LiteFromLazaretteCsv -Path $script:file
        $r.Imported | Should -Be 0
        $r.SkippedOversize | Should -Be 1
        $script:be.Store.Count | Should -Be 0
    }

    It 'skips rows with an empty secret or an empty service' {
        $csv = @(
            'name,url,username,password,note,totp,folder,type,fields',
            'empty-secret,,u,,,,,login,',
            ',,u,SYNTH-NO-NAME,,,,login,'
        ) -join "`n"
        [IO.File]::WriteAllText($script:file, $csv, (New-Object Text.UTF8Encoding($false)))
        $r = Import-LiteFromLazaretteCsv -Path $script:file
        $r.Imported | Should -Be 0
        $r.SkippedEmpty | Should -Be 2
    }

    It 'skips duplicates: already in Lite, and repeated in the file' {
        Add-LiteCredential -Service 'gitlab' -User 'anthony' -Secret (ConvertTo-LiteTestSecure 'already-there') | Out-Null
        $csv = @(
            'name,url,username,password,note,totp,folder,type,fields',
            'gitlab,,anthony,SYNTH-DUP-ONE,,,,login,',
            'fresh,,u,SYNTH-FRESH,,,,login,',
            'fresh,,u,SYNTH-FRESH,,,,login,'
        ) -join "`n"
        [IO.File]::WriteAllText($script:file, $csv, (New-Object Text.UTF8Encoding($false)))
        $r = Import-LiteFromLazaretteCsv -Path $script:file
        $r.Imported | Should -Be 1
        $r.SkippedDuplicate | Should -Be 2
        (Get-LiteSecret -Service 'gitlab' -User 'anthony') | Should -Be 'already-there'
        (Get-LiteSecret -Service 'fresh' -User 'u') | Should -Be 'SYNTH-FRESH'
    }

    It 'throws when a required column is missing, naming it' {
        $csv = @('name,url,username,note', 'gitlab,,anthony,work') -join "`n"
        [IO.File]::WriteAllText($script:file, $csv, (New-Object Text.UTF8Encoding($false)))
        { Import-LiteFromLazaretteCsv -Path $script:file } | Should -Throw '*password*'
    }

    It 'refuses a non-CSV file' {
        $json = Join-Path $TestDrive 'export.json'
        [IO.File]::WriteAllText($json, '{"format":"x"}', (New-Object Text.UTF8Encoding($false)))
        { Import-LiteFromLazaretteCsv -Path $json } | Should -Throw '*.csv*'
    }

    It 'maps other headers when the column parameters say so' {
        $csv = @('Service,User,Secret', 'csvc,u2,SYNTH-CUSTOM') -join "`n"
        [IO.File]::WriteAllText($script:file, $csv, (New-Object Text.UTF8Encoding($false)))
        $r = Import-LiteFromLazaretteCsv -Path $script:file -ServiceColumn 'Service' -UserColumn 'User' -SecretColumn 'Secret'
        $r.Imported | Should -Be 1
        (Get-LiteSecret -Service 'csvc' -User 'u2') | Should -Be 'SYNTH-CUSTOM'
    }
}