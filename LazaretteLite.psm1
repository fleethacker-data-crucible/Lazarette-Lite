#requires -Version 5.1
# Lazarette Lite: a thin front end to Windows Credential Manager. See README.md.
# Everything lives in lib\; this file only loads it. Add a file there and it is picked up here.
Set-StrictMode -Version 2.0

Get-ChildItem -Path (Join-Path $PSScriptRoot 'lib') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
