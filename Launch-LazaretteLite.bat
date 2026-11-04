@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "LITE_CONSOLE="
for %%A in (%*) do (
    if /I "%%~A"=="--console" set "LITE_CONSOLE=1"
    if /I "%%~A"=="--no-browser" set "LITE_CONSOLE=1"
    if /I "%%~A"=="--credential-console" set "LITE_CONSOLE=1"
)
if defined LITE_CONSOLE (
    powershell.exe -NoLogo -NoProfile -STA -File "%~dp0Start-LazaretteLite.ps1" %*
) else (
    start "" powershell.exe -NoLogo -NoProfile -STA -WindowStyle Hidden -File "%~dp0Start-LazaretteLite.ps1" %*
)
