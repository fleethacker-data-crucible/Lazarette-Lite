#requires -Version 5.1
<#
.SYNOPSIS
    Starts the Lazarette Lite console menu.
.PARAMETER Prefix  Use this target prefix for this run instead of lazarette-lite/ (or LAZARETTE_LITE_PREFIX).
.EXAMPLE
    .\Lazarette-Lite.ps1
#>
param([string]$Prefix)

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Write-Warning 'This session is not single-threaded, so copying to the clipboard will not work. Start Windows PowerShell without -MTA.'
}
Import-Module (Join-Path $PSScriptRoot 'LazaretteLite.psd1') -Force
if ($Prefix) { Set-LitePrefix $Prefix | Out-Null }
Start-LiteConsole
