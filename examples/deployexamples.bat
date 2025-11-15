@echo off

if "%LOCALAPPDATA%"=="" (
    echo LOCALAPPDATA is not set. Cannot deploy examples.
    pause
    exit /b 1
)

set "TARGET_DIR=%LOCALAPPDATA%\lua"
if not exist "%TARGET_DIR%" (
    mkdir "%TARGET_DIR%"
    if errorlevel 1 (
        echo Failed to create target directory %TARGET_DIR%!
        pause
        exit /b 1
    )
)

echo Copying Lua scripts to %TARGET_DIR%...
copy /Y "%~dp0*.lua" "%TARGET_DIR%\"

if errorlevel 1 (
    echo Example files copy failed.
    pause
    exit /b 1
)

echo All Lua scripts copied successfully!
pause
exit