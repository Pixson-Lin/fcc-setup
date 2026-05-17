@echo off
setlocal
cd /d "%~dp0"

REM =============================================================================
REM free-claude-code 懶人安裝包 (Windows) — CMD 啟動器
REM 用法:
REM   直接執行: install.bat（雙擊或於 CMD 執行，不需認識 PowerShell）
REM   帶 key:   set NVIDIA_NIM_API_KEY=nvapi-xxx && install.bat
REM 說明: 自動設定執行原則並呼叫同目錄的 install.ps1
REM 需要: Windows 內建 PowerShell，建議以一般使用者身份執行（不需要系統管理員）
REM =============================================================================

if not exist "%~dp0install.ps1" (
    echo [ERROR] 找不到 install.ps1：%~dp0
    goto :fail
)

echo.
echo 正在啟動安裝程式...
echo.

REM 允許本機腳本執行（僅 CurrentUser，一次性設定）
powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force" >nul 2>&1

REM 執行實際安裝腳本（若上方原則設定失敗，以 Bypass 確保可執行）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 goto :fail

exit /b 0

:fail
echo.
echo [ERROR] 安裝失敗
pause
exit /b 1
