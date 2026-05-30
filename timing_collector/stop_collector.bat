@echo off
REM Stops whatever is listening on 127.0.0.1:9876 (old Rust server or stuck collector).
setlocal enabledelayedexpansion
set FOUND=0

for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":9876" ^| findstr "LISTENING"') do (
    set FOUND=1
    echo Stopping PID %%P on port 9876...
    taskkill /F /PID %%P >nul 2>&1
    if errorlevel 1 (
        echo   Could not kill PID %%P — try Task Manager as Administrator.
    ) else (
        echo   Stopped.
    )
)

if "!FOUND!"=="0" (
    echo Nothing is listening on port 9876.
) else (
    timeout /t 1 /nobreak >nul
)
endlocal
