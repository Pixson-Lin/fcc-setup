@echo off
setlocal
cd /d "%~dp0"

REM =============================================================================
REM free-claude-code lazy installer (Windows) - CMD launcher
REM Usage:
REM   install.bat
REM   set NVIDIA_NIM_API_KEY=nvapi-xxx && install.bat
REM Calls install.ps1 in the same folder. No PowerShell knowledge required.
REM Requires built-in PowerShell. Run as normal user (no admin).
REM =============================================================================

if not exist "%~dp0install.ps1" (
    echo [ERROR] install.ps1 not found: %~dp0
    goto :fail
)

echo.
echo Starting installer...
echo.

REM Set-ExecutionPolicy for CurrentUser (one-time)
powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force" >nul 2>&1

REM Run installer (-Bypass if policy could not be set)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 goto :fail

exit /b 0

:fail
echo.
echo [ERROR] Install failed
pause
exit /b 1
