# Offhand Companion

Native Windows desktop companion application for the Offhand World of Warcraft add-on.

## Features
* **Auto-Spanning**: Detects World of Warcraft launches and spans the game window borderlessly across your multi-monitor virtual desktop.
* **Addon Verification**: Validates that the Offhand add-on is properly installed in your WoW client's `Interface\AddOns` folder.
* **Zero Console Flashing**: Compiled as a native Win32 subsystem application (`Offhand.exe`).
* **System Tray Integration**: Minimizes silently to the Windows notification tray with quick-actions and live status tips.
* **DPI-Aware**: Full Per-Monitor V2 scaling ensures crisp fonts and accurate window positioning on mixed-resolution / mixed-scale setups.

---

## Downloads & Distribution
* **`Offhand.exe`**: Ready-to-run standalone executable. No installer needed; uses the Windows .NET Framework.
* **Open Source Auditability**: 
  * Full source code is in `Source/Program.cs`.
  * To compile yourself, run `build.bat`. It uses the native Windows C# compiler (`csc.exe`) built into Windows 10 & 11.
* **PowerShell Alternative**: `Offhand-Companion.ps1` is included for technical users who prefer raw script execution.
## Settings and shortcuts

The native companion stores settings in `%LOCALAPPDATA%\Offhand\OffhandConfig.ini`,
independent of the launch working directory. If no saved file exists, it reads the
legacy INI next to the executable. Changing an option saves to the new location.
Unreadable/unwritable settings are reported without terminating the application.
The auto-span delay is clamped to 0–60 seconds. Shortcut conflicts are reported;
the manual Span button remains available. Registered shortcuts suppress repeat
while held and are released on application exit.

These settings describe the C# companion; the PowerShell alternative has its own
controls and does not share the native application's preference file.
