@echo off
cd /d "%~dp0timing_collector"
go build -o timing_collector.exe .
if errorlevel 1 (
    echo Collector build failed.
    exit /b 1
)
echo Built timing_collector\timing_collector.exe
exit /b 0
