#requires -Version 5.1
# The older names of the same contract (Lazarette was ARC): a folder with lib\Arc.ps1, found through ARC_PATH,
# with Unlock-ArcVaultInteractive and Get-ArcSecret. TalkForge's token provider loads it this way.
. (Join-Path $PSScriptRoot 'Lazarette.ps1')
Set-Alias -Name Unlock-ArcVaultInteractive -Value Unlock-LazaretteVaultInteractive
Set-Alias -Name Test-ArcVaultUnlocked -Value Test-LazaretteVaultUnlocked
Set-Alias -Name Get-ArcSecret -Value Get-LazaretteSecret
Set-Alias -Name Get-ArcItemNames -Value Get-LazaretteItemNames
Set-Alias -Name Lock-ArcVault -Value Lock-LazaretteVault
