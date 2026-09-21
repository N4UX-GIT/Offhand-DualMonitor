@echo off
setlocal
cd /d "%~dp0"

echo ===================================================
echo Building Offhand Companion (Standalone Executable)
echo ===================================================

set "CSC=%SystemRoot%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" (
    set "CSC=%SystemRoot%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)

if not exist "%CSC%" (
    echo [ERROR] Microsoft .NET Framework C# compiler was not found.
    pause
    exit /b 1
)

set "OUT=%~dp0Offhand.exe"
set "SRC=%~dp0Source\Program.cs"
set "MANIFEST=%~dp0Source\app.manifest"
set "ICO=%~dp0..\Media\offhand-logo.ico"
set "PNG=%~dp0..\Media\offhand-logo-small.png"
if not exist "%ICO%" set "ICO=%~dp0Media\offhand-logo.ico"
if not exist "%PNG%" set "PNG=%~dp0Media\offhand-logo-small.png"

echo Compiling %OUT% ...

"%CSC%" /target:winexe /optimize+ /platform:anycpu /out:"%OUT%" /win32icon:"%ICO%" /win32manifest:"%MANIFEST%" /resource:"%PNG%",Offhand.Companion.Resources.offhand-logo.png /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll "%SRC%"

if %ERRORLEVEL% equ 0 (
    echo ===================================================
    echo [SUCCESS] Offhand.exe built successfully!
    echo ===================================================
) else (
    echo ===================================================
    echo [FAILED] Compilation failed with error code %ERRORLEVEL%
    echo ===================================================
    exit /b %ERRORLEVEL%
)
