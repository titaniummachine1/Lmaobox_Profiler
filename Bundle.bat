@echo off
echo Building Profiler Library...

node bundle.js
if errorlevel 1 (
    echo ❌ Bundle failed!
) else (
    echo ✅ Profiler Library bundled successfully!
)
pause