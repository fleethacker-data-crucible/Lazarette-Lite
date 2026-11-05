@echo off
setlocal EnableExtensions
cd /d "%~dp0" || (echo ERROR: cannot open the Lazarette Lite folder & pause & exit /b 1)
REM Lazarette Lite - a browser window on Windows Credential Manager. Starts the loopback server without a
REM console window and opens your browser. It stops when the tab closes (or on Quit).
REM   Launch-LazaretteLite.bat --console              keep a console window open for troubleshooting
REM   Launch-LazaretteLite.bat --replace              stop a running copy and start fresh, without asking
REM   Launch-LazaretteLite.bat --stay                 keep running after the browser tab closes
REM   Launch-LazaretteLite.bat --credential-console   the terminal menu instead of the browser
REM   Launch-LazaretteLite.bat --register             make the Fleet tools use Lite in place of Lazarette (once per user)
REM   Launch-LazaretteLite.bat --unregister           undo --register
REM -ExecutionPolicy Bypass applies to this one process only, like the Lazarette and Gangplank launchers:
REM the Windows client default policy (Restricted) would otherwise refuse the script, silently when hidden.
REM It does not change the machine policy and cannot override Group Policy or AllSigned set by policy.
set "PS_ARGS=-NoLogo -NoProfile -ExecutionPolicy Bypass -STA"
where powershell.exe >nul 2>&1 || (echo ERROR: Windows PowerShell 5.1 not found & pause & exit /b 1)
if /I "%~1"=="--register" goto REGISTER
if /I "%~1"=="--unregister" goto UNREGISTER
set "LITE_CONSOLE="
for %%A in (%*) do (
    if /I "%%~A"=="--console" set "LITE_CONSOLE=1"
    if /I "%%~A"=="--no-browser" set "LITE_CONSOLE=1"
    if /I "%%~A"=="--credential-console" set "LITE_CONSOLE=1"
)
if defined LITE_CONSOLE (
    powershell.exe %PS_ARGS% -File "%~dp0Start-LazaretteLite.ps1" %*
) else (
    start "" powershell.exe %PS_ARGS% -WindowStyle Hidden -File "%~dp0Start-LazaretteLite.ps1" %*
)
exit /b %ERRORLEVEL%

:REGISTER
powershell.exe %PS_ARGS% -File "%~dp0Register-LazaretteLite.ps1"
goto FINISH

:UNREGISTER
powershell.exe %PS_ARGS% -File "%~dp0Register-LazaretteLite.ps1" -Unregister
goto FINISH

:FINISH
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
  echo.
  echo Register-LazaretteLite.ps1 exited with code %ERR%.
  pause
)
exit /b %ERR%
