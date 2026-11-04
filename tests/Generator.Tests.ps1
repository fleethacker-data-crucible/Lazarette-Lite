#requires -Version 5.1
BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')
    . (Join-Path $PSScriptRoot 'FakeClipboard.ps1')
    function ConvertTo-PlainTest { param([securestring]$S) [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($S)) }
}
AfterAll { Set-LiteRandomSource; Set-LiteBackend $null; Set-LiteClipboardBackend $null; Set-LiteConsoleIO; Set-LitePrefix -Reset; Remove-Module LazaretteLite -ErrorAction SilentlyContinue }

Describe 'New-LitePassword' {
    It 'returns a SecureString of the default 20 characters' {
        $p = New-LitePassword
        $p | Should -BeOfType ([securestring])
        $p.Length | Should -Be 20
    }
    It 'honours length 8 to 128 and refuses outside it' {
        (New-LitePassword -Length 8 -AsPlainText).Length | Should -Be 8
        (New-LitePassword -Length 128 -AsPlainText).Length | Should -Be 128
        { New-LitePassword -Length 7 } | Should -Throw
        { New-LitePassword -Length 129 } | Should -Throw
    }
    It 'has every class in every password, over many runs' {
        1..200 | ForEach-Object {
            $t = New-LitePassword -Length 8 -AsPlainText
            $t | Should -CMatch '[a-z]'; $t | Should -CMatch '[A-Z]'; $t | Should -Match '\d'; $t | Should -Match '[!#$%&*+=?@^_~-]'
        }
    }
    It '-NoSymbols gives letters and digits only' {
        1..100 | ForEach-Object { New-LitePassword -Length 12 -NoSymbols -AsPlainText | Should -Match '^[A-Za-z0-9]{12}$' }
    }
    It '-NoAmbiguous leaves out 0 O o 1 l I |' {
        1..100 | ForEach-Object { New-LitePassword -Length 30 -NoAmbiguous -AsPlainText | Should -Not -Match '[0Oo1lI|]' }
    }
    It 'does not repeat' {
        @(1..50 | ForEach-Object { New-LitePassword -AsPlainText } | Select-Object -Unique).Count | Should -Be 50
    }
    It 'picks uniformly from the whole range (Windows source, 100,000 draws over 10 values)' {
        $counts = InModuleScope LazaretteLite { $c = @(0) * 10; for ($i = 0; $i -lt 100000; $i++) { $c[(Get-LiteRandomInt 10)]++ }; $c }
        ($counts | Measure-Object -Minimum).Minimum | Should -BeGreaterThan 9500
        ($counts | Measure-Object -Maximum).Maximum | Should -BeLessThan 10500
    }
    It 'draws only values below Max from a stubbed source' {
        Set-LiteRandomSource { param($Max) $Max - 1 }
        try { (New-LitePassword -Length 8 -AsPlainText).Length | Should -Be 8 } finally { Set-LiteRandomSource }
    }
}

Describe 'Console generate' {
    It 'adds an item with a generated secret, never prints it, and can copy it' {
        $be = New-LiteFakeBackend; Set-LiteBackend $be; Set-LitePrefix -Reset
        $cb = New-LiteFakeClipboard; Set-LiteClipboardBackend $cb
        $q = New-Object System.Collections.Queue
        'g', 'gitlab', 'anthony', 'generated', '16', 'y', 'y', 'q' | ForEach-Object { $q.Enqueue($_) }
        $out = New-Object System.Collections.Generic.List[string]
        Set-LiteConsoleIO -Read ({ param($P, $S) $a = $q.Dequeue(); if ($S) { ConvertTo-SecureString $a -AsPlainText -Force } else { $a } }.GetNewClosure()) -Write ({ param($T, $C) $out.Add($T) }.GetNewClosure())
        try { Start-LiteConsole } finally { Set-LiteConsoleIO }
        $e = $be.Store['lazarette-lite/gitlab/anthony']
        $e.Secret.Length | Should -Be 16
        $e.Secret | Should -Match '^[A-Za-z0-9]{16}$'
        ($out -join "`n") | Should -Match 'generated 16-character'
        ($out -join "`n") | Should -Not -Match ([regex]::Escape($e.Secret))
        $cb.SetCount | Should -Be 1
    }
}
