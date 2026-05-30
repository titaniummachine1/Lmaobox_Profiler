@echo off
cd /d "%~dp0"

if /I "%~1"=="/stop" (
    call "%~dp0stop_collector.bat"
    exit /b 0
)

echo Building timing_collector.exe...
go build -o timing_collector.exe .
if errorlevel 1 (
    pause
    exit /b 1
)

REM Free port 9876 if a previous collector or Rust timing_server is still running
call "%~dp0stop_collector.bat"

echo.
echo Starting timing_collector on http://127.0.0.1:9876
echo Output: %~dp0flame_graphs\
echo Close this window to stop the server.
echo.

timing_collector.exe
if errorlevel 1 (
    echo.
    echo timing_collector exited with an error.
    echo If port 9876 is still in use, run stop_collector.bat or close the other program.
    pause
)
