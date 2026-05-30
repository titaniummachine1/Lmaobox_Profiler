@echo off
cd /d "%~dp0"
echo Building run\timing_collector.exe ...
go build -o run\timing_collector.exe ./cmd/timing_collector
if errorlevel 1 (
    echo Build failed. Install Go from https://go.dev/dl/
    pause
    exit /b 1
)
echo.
echo Done. Double-click:  run\timing_collector.exe
pause
