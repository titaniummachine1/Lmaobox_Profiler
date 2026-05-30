@echo off
REM Non-interactive build for rapid-dev (Go collector + speedscope patch; Rust optional).
cd /d "%~dp0"
set FAILED=0

set SCOPE_DIR=cmd\timing_collector\web\speedscope
if exist "%SCOPE_DIR%\index.html" (
    powershell -NoProfile -File "scripts\patch_speedscope_zoom.ps1" >nul 2>&1
)

if "%BUILD_RUST%"=="1" (
    where cargo >nul 2>&1
    if not errorlevel 1 (
        pushd flamegraph_gen
        cargo build --release >nul 2>&1
        if not errorlevel 1 (
            copy /Y target\release\flamegraph_gen.exe ..\run\flamegraph_gen.exe >nul
        ) else (
            set FAILED=1
        )
        popd
    ) else (
        set FAILED=1
    )
)

go build -o run\timing_collector.exe ./cmd/timing_collector
if errorlevel 1 (
    echo [build-fast] go build FAILED
    exit /b 1
)

if "%FAILED%"=="1" (
    echo [build-fast] OK timing_collector.exe ^(no flamegraph_gen — SVG fallback^)
) else (
    echo [build-fast] OK timing_collector.exe
)
exit /b 0
