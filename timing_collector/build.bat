@echo off
cd /d "%~dp0"
set FAILED=0

echo.
echo [1/2] Building flamegraph_gen.exe (Rust / inferno — same engine as cargo flamegraph) ...
where cargo >nul 2>&1
if errorlevel 1 (
    echo   WARN: cargo not found — SVG will use built-in Go renderer only.
    echo   Install Rust: https://rustup.rs/  then re-run build.bat
    set FAILED=1
) else (
    pushd flamegraph_gen
    cargo build --release
    if errorlevel 1 (
        echo   WARN: flamegraph_gen build failed — Go fallback only.
        set FAILED=1
    ) else (
        copy /Y target\release\flamegraph_gen.exe ..\run\flamegraph_gen.exe >nul
        echo   OK: run\flamegraph_gen.exe
    )
    popd
)

echo.
echo [2/2] Building run\timing_collector.exe ...
go build -o run\timing_collector.exe ./cmd/timing_collector
if errorlevel 1 (
    echo Build failed. Install Go from https://go.dev/dl/
    pause
    exit /b 1
)

echo.
if "%FAILED%"=="1" (
    echo Done with warnings. Double-click:  run\timing_collector.exe
    echo For best flame graphs, install Rust and run build.bat again.
) else (
    echo Done. Double-click:  run\timing_collector.exe
    echo   ^(flamegraph_gen.exe sits in run\ — used automatically, ignore it^)
)
pause
