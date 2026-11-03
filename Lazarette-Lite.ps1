#requires -Version 5.1
param([string]$Prefix, [switch]$Console, [switch]$NoBrowser, [switch]$Stay)
& (Join-Path $PSScriptRoot 'Start-LazaretteLite.ps1') -Prefix $Prefix -CredentialConsole:$Console -NoBrowser:$NoBrowser -Stay:$Stay
