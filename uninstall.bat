@echo off
setlocal
cd /d "%~dp0"

REM =============================================================================
REM free-claude-code uninstaller (Windows) - CMD launcher
REM Usage: uninstall.bat
REM Calls uninstall.ps1 in the same folder.
REM =============================================================================

if not exist "%~dp0uninstall.ps1" (
    echo [ERROR] uninstall.ps1 not found: %~dp0
    goto :fail
)

echo.
echo Starting uninstaller...
echo.

powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
if errorlevel 1 goto :fail

exit /b 0

:fail
echo.
echo [ERROR] Uninstall failed
pause
exit /b 1
