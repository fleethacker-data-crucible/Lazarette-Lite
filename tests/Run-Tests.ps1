#requires -Version 5.1
# Runs the Pester suite under Windows PowerShell 5.1 (needs Pester 5 or newer, already on the machine).
# The one real Credential Manager smoke test is off unless you ask for it:  .\tests\Run-Tests.ps1 -Smoke
param([switch]$Smoke)

if ($PSVersionTable.PSVersion.Major -ne 5) { Write-Warning "These tests are meant for Windows PowerShell 5.1 (this is $($PSVersionTable.PSVersion))." }
$p = Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 } | Sort-Object Version -Descending | Select-Object -First 1
if (-not $p) { throw 'Pester 5 or newer is needed. Windows ships 3.4 only; ask for 5+ to be made available, or run in CI.' }
Import-Module $p.Path -Force
if ($Smoke) { $env:LITE_SMOKE = '1' } else { $env:LITE_SMOKE = $null }
$cfg = New-PesterConfiguration
$cfg.Run.Path = $PSScriptRoot
$cfg.Run.Exit = $true
$cfg.Output.Verbosity = 'Normal'
Invoke-Pester -Configuration $cfg
