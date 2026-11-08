@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Capture-DisplayIdentity.ps1"
set "captureExitCode=%errorlevel%"
if not "%captureExitCode%"=="0" echo Capture failed. Please retain the error text.
pause
exit /b %captureExitCode%
