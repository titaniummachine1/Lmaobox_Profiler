@echo off
cd /d "%~dp0"
node bundle-and-deploy.js
if errorlevel 1 exit /b 1
echo Bundle complete.
exit /b 0
