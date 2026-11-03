#requires -Version 5.1
Set-StrictMode -Version 2.0

foreach ($file in 'Backend.Windows.ps1', 'Clipboard.ps1', 'Console.ps1', 'Secret.ps1', 'Transfer.ps1', 'Vault.ps1') {
    . (Join-Path $PSScriptRoot "lib\$file")
}
