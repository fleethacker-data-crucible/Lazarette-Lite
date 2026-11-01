@{
    RootModule            = 'LazaretteLite.psm1'
    ModuleVersion         = '0.1.0'
    GUID                  = '5b0f3c1e-6a43-4e0a-9d0b-3f4e7a1c2b90'
    Author                = 'Fleet'
    Description           = 'A thin front end to Windows Credential Manager. No data store, no crypto, no network.'
    PowerShellVersion     = '5.1'
    CompatiblePSEditions  = @('Desktop')
    FunctionsToExport     = @(
        'Get-LiteCredential', 'Add-LiteCredential', 'Set-LiteCredential', 'Remove-LiteCredential',
        'Get-LiteSecret', 'Get-LiteItemNames',
        'Start-LiteConsole', 'Set-LiteConsoleIO',
        'Copy-LiteSecret', 'Export-LiteMetadata', 'Import-LiteMetadata',
        'Get-LitePrefix', 'Set-LitePrefix', 'Set-LiteBackend', 'Set-LiteClipboardBackend'
    )
    CmdletsToExport       = @()
    VariablesToExport     = @()
    AliasesToExport       = @()
}
