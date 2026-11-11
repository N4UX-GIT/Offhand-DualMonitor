@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-LayoutSimulator.ps1" %*
endlocal
