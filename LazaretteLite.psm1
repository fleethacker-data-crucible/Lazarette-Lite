#requires -Version 5.1
Set-StrictMode -Version 2.0

# Dependency order. The loading flag lets Lazarette.ps1 and Arc.ps1 live in this
# list: they import the manifest only when the flag is clear, so the import cannot
# recurse while this file is still running. lib\server is the browser listener and
# is loaded by Start-LazaretteLite.ps1 only.
# Generator.ps1 and Check.ps1 must stay in this list. Leaving them out removed
# New-LitePassword, Set-LiteRandomSource and Test-LiteStore, which the manifest
# exports and which the console menu calls. tests\Module.Tests.ps1 checks both.
$script:LazaretteLiteLoading = $true
foreach ($file in 'Backend.Windows.ps1', 'Vault.ps1', 'Secret.ps1', 'Generator.ps1', 'Clipboard.ps1', 'Transfer.ps1', 'Check.ps1', 'Console.ps1', 'Lazarette.ps1', 'Arc.ps1', 'Resolver.ps1') {
    . (Join-Path $PSScriptRoot "lib\$file")
}
$script:LazaretteLiteLoading = $false
