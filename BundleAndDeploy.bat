@echo off
cd /d "%~dp0"
echo Bundling Profiler.lua to %%LOCALAPPDATA%%\lua ...
node bundle-and-deploy.js
exit /b %ERRORLEVEL%
