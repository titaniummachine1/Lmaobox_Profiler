@echo off

REM Bundle Profiler.lua + copy examples to %%LOCALAPPDATA%%\lua



setlocal

cd /d "%~dp0.."

call "%~dp0..\BundleAndDeploy.bat" --no-collector

exit /b %ERRORLEVEL%

