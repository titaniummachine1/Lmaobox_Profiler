@echo off
setlocal
cd /d "%~dp0"

echo [BundleAndDeploy] Bundling Profiler.lua and deploying to %%localappdata%%\lua ...
node bundle-and-deploy.js
if errorlevel 1 (
    echo [BundleAndDeploy] NOT DEPLOYED: bundle failed.
    exit /b 1
)

if /I "%~1"=="--no-collector" goto :done

echo [BundleAndDeploy] Building timing_collector.exe ...
pushd "%~dp0timing_collector"
go build -o timing_collector.exe .
set GO_EXIT=%ERRORLEVEL%
popd
if not "%GO_EXIT%"=="0" (
    echo [BundleAndDeploy] WARN: Go collector build failed ^(install Go or use --no-collector^).
) else (
    echo [BundleAndDeploy] Built timing_collector\timing_collector.exe
)

:done
echo [BundleAndDeploy] OK
exit /b 0
