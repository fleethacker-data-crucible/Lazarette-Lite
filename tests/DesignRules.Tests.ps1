#requires -Version 5.1
# The README's design rules, checked against the shipped scripts so a change that breaks one fails here.
# These are blunt text checks, not a proof: they catch the obvious ways of breaking a rule by accident.

BeforeDiscovery {
    $root = Split-Path -Parent $PSScriptRoot
    $script:shipped = @(Get-ChildItem -LiteralPath $root -File | Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1', '.cmd' }) +
                      @(Get-ChildItem -LiteralPath (Join-Path $root 'lib') -File -Filter '*.ps1')
}

BeforeAll {
    $script:root = Split-Path -Parent $PSScriptRoot
    $script:shipped = @(Get-ChildItem -LiteralPath $script:root -File | Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1', '.cmd' }) +
                      @(Get-ChildItem -LiteralPath (Join-Path $script:root 'lib') -File -Filter '*.ps1')
    function Get-Code {
        # Shipped text with comment-only lines removed, so a rule can be named in a comment.
        param($File) (Get-Content -LiteralPath $File.FullName) | Where-Object { $_ -notmatch '^\s*#' }
    }
}

Describe 'Design rules' {
    It 'no network: <_.Name> has no web, socket, listener or download code' -ForEach $script:shipped {
        $bad = '(?i)Invoke-WebRequest|Invoke-RestMethod|\biwr\b|\birm\b|WebClient|System\.Net|HttpListener|TcpListener|TcpClient|Start-BitsTransfer|Test-NetConnection|Send-MailMessage|New-WebServiceProxy|curl|wget'
        Get-Code $_ | Where-Object { $_ -match $bad } | Should -BeNullOrEmpty
    }

    It 'no custom crypto: <_.Name> has no cryptography code' -ForEach $script:shipped {
        $bad = '(?i)System\.Security\.Cryptography|ProtectedData|Protect-CmsMessage|ConvertFrom-SecureString|AesManaged|AesCng|Rfc2898|HashAlgorithm|Get-FileHash'
        Get-Code $_ | Where-Object { $_ -match $bad } | Should -BeNullOrEmpty
    }

    It 'no DLLs and no installs: <_.Name> loads no assembly from disk and installs nothing' -ForEach $script:shipped {
        $bad = '(?i)Add-Type\s+-Path|Add-Type\s+-AssemblyName\s+(?!System\.Windows\.Forms)|LoadFrom|LoadFile|Install-Module|Install-Package|Install-Script|msiexec|winget|choco|Start-Process|RunAs|-Verb'
        Get-Code $_ | Where-Object { $_ -match $bad } | Should -BeNullOrEmpty
    }

    It 'no data store: only Transfer.ps1 writes a file, and nothing writes the registry or a config' {
        $writers = $script:shipped | Where-Object {
            (Get-Code $_) | Where-Object { $_ -match '(?i)WriteAllText|WriteAllBytes|Out-File|Set-Content|Add-Content|Export-Clixml|Export-Csv|New-Item|Set-ItemProperty|New-ItemProperty|\[IO\.File\]::Create|StreamWriter|reg\s+add' }
        }
        @($writers.Name) | Should -Be @('Transfer.ps1')
    }

    It 'current user only: no other-account, machine-store or elevation code' -ForEach $script:shipped {
        $bad = '(?i)LocalMachine|HKLM|\s-Credential\b|runas|Impersonat|LogonUser|CRED_PERSIST_ENTERPRISE|CRED_PERSIST_SESSION|NetUserEnum'
        Get-Code $_ | Where-Object { $_ -match $bad } | Should -BeNullOrEmpty
    }

    It 'no admin rights are required' {
        # No #requires -RunAsAdministrator anywhere.
        ($script:shipped | ForEach-Object { Get-Content -LiteralPath $_.FullName } | Where-Object { $_ -match '(?i)#requires\s+-RunAsAdministrator' }) | Should -BeNullOrEmpty
    }

    It 'runs on Windows PowerShell 5.1: every script declares #requires -Version 5.1 (the .cmd is exempt)' -ForEach ($script:shipped | Where-Object { $_.Extension -in '.ps1', '.psm1' }) {
        (Get-Content -LiteralPath $_.FullName -TotalCount 5) -join "`n" | Should -Match '#requires -Version 5\.1'
    }

    It 'signable: <_.Name> is plain ASCII, so the signature and the 5.1 default encoding agree' -ForEach $script:shipped {
        [IO.File]::ReadAllBytes($_.FullName) | Where-Object { $_ -gt 127 } | Should -BeNullOrEmpty
    }

    It 'small: the shipped scripts stay readable in one sitting (under 1,500 lines, comments included)' {
        $n = ($script:shipped | ForEach-Object { @(Get-Content -LiteralPath $_.FullName).Count } | Measure-Object -Sum).Sum
        $n | Should -BeLessThan 1500
    }

    It 'keeps the backend and file parsing private; Get-LiteSecret is the only export that returns a secret' {
        $m = Import-Module (Join-Path $script:root 'LazaretteLite.psd1') -Force -PassThru
        try {
            $names = $m.ExportedFunctions.Keys
            $names | Should -Contain 'Get-LiteSecret'
            $names | Should -Not -Contain 'Read-LiteExportFile'
            $names | Should -Not -Contain 'Get-LiteBackend'
        } finally { Remove-Module LazaretteLite -ErrorAction SilentlyContinue }
    }
}
