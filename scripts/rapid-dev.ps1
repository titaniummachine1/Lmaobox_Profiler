# Bundle Profiler.lua, build timing_collector, restart collector — for rapid in-game testing.
param(
    [switch]$LuaOnly,
    [switch]$Full
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$sw = [System.Diagnostics.Stopwatch]::StartNew()

if (-not $LuaOnly) {
    Write-Host "[rapid-dev] Building timing_collector..."
    if ($Full) {
        $env:NOPAUSE = "1"
        & (Join-Path $root "timing_collector\build.bat")
    } else {
        & (Join-Path $root "timing_collector\build-fast.bat")
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "[rapid-dev] collector build failed (exit $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
} else {
    Write-Host "[rapid-dev] Skipping collector build (--no-collector)"
}

Write-Host "[rapid-dev] Bundling Profiler.lua..."
& node (Join-Path $root "bundle-and-deploy.js")
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "[rapid-dev] Restarting timing_collector..."
& (Join-Path $root "scripts\restart-collector.ps1")
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$sw.Stop()
Write-Host ("[rapid-dev] Done in {0:0.0}s - reload Lua in TF2" -f $sw.Elapsed.TotalSeconds)
