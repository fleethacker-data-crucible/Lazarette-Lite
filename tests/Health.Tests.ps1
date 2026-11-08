#requires -Version 5.1
# GET /api/health: shape and product string, and the no-auth bypass in the
# dispatcher. The handler is Get-LiteHealthInfo, extracted from the route so it
# can be tested without the HTTP server; the dispatch test stubs Send-ArcJson /
# Send-ArcError in test scope and calls Invoke-ArcRoute / Invoke-ArcHttpRequest
# directly. Fake backend, synthetic data only.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LazaretteLite.psd1') -Force
    . (Join-Path $PSScriptRoot 'FakeBackend.ps1')
    . (Join-Path $PSScriptRoot '..\lib\server\Http.ps1')
    . (Join-Path $PSScriptRoot '..\lib\server\Routes.ps1')
    $script:captured = $null
    function Send-ArcJson { param([int]$Status, $Object, [string[]]$ExtraHeaders = @()) $script:captured = @{ Status = $Status; Body = $Object } }
    function Send-ArcError { param([int]$Status, [string]$Code, [string]$Message) $script:captured = @{ Status = $Status; Code = $Code; Message = $Message } }
}

AfterAll {
    Set-LiteBackend $null
    Set-LitePrefix -Reset
    Remove-Module LazaretteLite -ErrorAction SilentlyContinue
}

Describe 'Get-LiteHealthInfo' {
    BeforeEach { $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset }

    It 'reports product Lazarette Lite (never Lazarette), version from the manifest, unlocked, wincred' {
        $h = Get-LiteHealthInfo
        $h.ok | Should -BeTrue
        $h.product | Should -Be 'Lazarette Lite'
        $h.product | Should -Not -Be 'Lazarette'
        $h.version | Should -Be (Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\LazaretteLite.psd1')).ModuleVersion
        $h.state | Should -Be 'unlocked'
        $h.profile | Should -Be 'wincred'
        $h.prefix | Should -Be 'lazarette-lite/'
    }

    It 'reports the session prefix when one is set' {
        Set-LitePrefix 'team-a/' | Out-Null
        (Get-LiteHealthInfo).prefix | Should -Be 'team-a/'
    }
}

Describe 'GET /api/health route' {
    BeforeEach { $script:be = New-LiteFakeBackend; Set-LiteBackend $script:be; Set-LitePrefix -Reset; $script:captured = $null }

    It 'answers 200 with the health body through Invoke-ArcRoute' {
        Invoke-ArcRoute -Req ([pscustomobject]@{ Method = 'GET'; Path = '/api/health' })
        $script:captured.Status | Should -Be 200
        $script:captured.Body.product | Should -Be 'Lazarette Lite'
        $script:captured.Body.state | Should -Be 'unlocked'
    }

    It 'answers through the dispatcher with no session cookie and no client header' {
        $req = [pscustomobject]@{
            Method = 'GET'; Path = '/api/health'
            Headers = @{ Host = '127.0.0.1:0' }
            BodyBytes = [byte[]]@(); Json = $null; Cookies = @{}
        }
        Invoke-ArcHttpRequest -Req $req
        $script:captured.Status | Should -Be 200
        $script:captured.Body.product | Should -Be 'Lazarette Lite'
    }
}