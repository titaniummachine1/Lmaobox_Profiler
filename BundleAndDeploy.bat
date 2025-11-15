@echo off
echo Building and deploying Profiler Library...

node bundle.js
if errorlevel 1 (
    echo ❌ Bundle failed!
    pause
    exit /b 1
)

if "%localappdata%"=="" (
    echo ❌ LOCALAPPDATA is not set. Cannot deploy.
    pause
    exit /b 1
)

set "TARGET_DIR=%LOCALAPPDATA%\lua"
if not exist "%TARGET_DIR%" (
    mkdir "%TARGET_DIR%"
    if errorlevel 1 (
        echo ❌ Failed to create target directory %TARGET_DIR%!
        pause
        exit /b 1
    )
)

move /Y "Profiler.lua" "%TARGET_DIR%\Profiler.lua"
if errorlevel 1 (
    echo ❌ Deploy failed!
    pause
    exit /b 1
)

echo ✅ Profiler Library deployed successfully to %TARGET_DIR%

echo Deploying examples...
call "examples\deployexamples.bat"
if errorlevel 1 (
    echo ❌ Examples deploy failed!
    pause
    exit /b 1
)

echo ✅ All files deployed successfully!
exit