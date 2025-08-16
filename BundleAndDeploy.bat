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

echo Deploying examples...
call "examples\deployexamples.bat"
if errorlevel 1 (
    echo ❌ Examples deploy failed!
    pause
    exit /b 1
)

echo ✅ All files deployed successfully!
exit