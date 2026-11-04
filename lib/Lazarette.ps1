#requires -Version 5.1
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'LazaretteLite.psd1') -ErrorAction Stop

function Unlock-LazaretteVaultInteractive {
    param([string]$DataDir)
    if ($DataDir) { throw 'Lazarette Lite uses Windows Credential Manager and has no vault directory.' }
    [void]@(Get-LiteCredential -ErrorAction Stop)
    return $true
}

function Get-LazaretteSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Alias('Name')][string]$Service,
        [string]$User,
        [string]$Field
    )
    Get-LiteSecret @PSBoundParameters
}

function Get-LazaretteItemNames { Get-LiteItemNames }
