#requires -Version 5.1
. (Join-Path $PSScriptRoot 'Lazarette.ps1')
Set-Alias -Name Unlock-ArcVaultInteractive -Value Unlock-LazaretteVaultInteractive
Set-Alias -Name Get-ArcSecret -Value Get-LazaretteSecret
Set-Alias -Name Get-ArcItemNames -Value Get-LazaretteItemNames
