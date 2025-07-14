@echo off
echo Building and deploying Profiler Library...

node bundle.js
if errorlevel 1 (
    echo ❌ Bundle failed!
    pause
    exit /b 1
)

move /Y "Profiler.lua" "%localappdata%"
if errorlevel 1 (
    echo ❌ Deploy failed!
    pause
    exit /b 1
)

echo ✅ Profiler Library deployed successfully to %localappdata%
exit