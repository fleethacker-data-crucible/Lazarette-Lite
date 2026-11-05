#requires -Version 5.1
Set-StrictMode -Version 2.0

# Every file of the module, in dependency order. Not listed on purpose: lib\Lazarette.ps1, lib\Arc.ps1 and
# lib\Cli.ps1 are the loaders Fleet tools dot-source, and they import this module themselves; lib\server\ is
# the browser app's listener, loaded by Start-LazaretteLite.ps1 only.
# tests\Module.Tests.ps1 checks that every function LazaretteLite.psd1 exports exists after import.
foreach ($file in 'Backend.Windows.ps1', 'Vault.ps1', 'Secret.ps1', 'Generator.ps1', 'Clipboard.ps1', 'Transfer.ps1', 'Check.ps1', 'Console.ps1') {
    . (Join-Path $PSScriptRoot "lib\$file")
}
