@echo off
rem Starts Lazarette Lite in Windows PowerShell 5.1. It does not change the execution policy,
rem so on an AllSigned machine the scripts must be signed, as intended.
powershell.exe -NoProfile -File "%~dp0Lazarette-Lite.ps1" %*
