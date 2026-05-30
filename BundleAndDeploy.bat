@echo off
cd /d "%~dp0"
if /i "%~1"=="--no-collector" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\rapid-dev.ps1" -LuaOnly
) else if /i "%~1"=="--full" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\rapid-dev.ps1" -Full
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\rapid-dev.ps1"
)
exit /b %ERRORLEVEL%
