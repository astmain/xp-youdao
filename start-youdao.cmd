@echo off
setlocal
cd /d "%~dp0"

where powershell >nul 2>nul
if errorlevel 1 (
    echo [ERROR] powershell not found. This launcher requires Windows.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-youdao.ps1"

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to start. See the messages above.
    pause
    exit /b 1
)

endlocal
