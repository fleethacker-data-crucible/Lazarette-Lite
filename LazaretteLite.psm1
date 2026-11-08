#requires -Version 5.1
Set-StrictMode -Version 2.0

$script:LazaretteLiteLoading = $true
foreach ($file in 'Backend.Windows.ps1', 'Clipboard.ps1', 'Console.ps1', 'Secret.ps1', 'Transfer.ps1', 'Vault.ps1', 'Lazarette.ps1', 'Arc.ps1', 'Resolver.ps1', 'Check.ps1', 'Generator.ps1') {
    . (Join-Path $PSScriptRoot "lib\$file")
}
$script:LazaretteLiteLoading = $false
