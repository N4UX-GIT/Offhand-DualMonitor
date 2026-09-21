# Offhand Companion

Native Windows desktop companion application for the Offhand World of Warcraft add-on.

## Features
* **Optional Auto-Spanning**: Detects World of Warcraft launches and can span the game window borderlessly across your multi-monitor virtual desktop. This is disabled by default so a first launch cannot move WoW before the display selection is reviewed.
* **Addon Verification**: Validates that the Offhand add-on is properly installed in your WoW client's `Interface\AddOns` folder.
* **Zero Console Flashing**: Compiled as a native Win32 subsystem application (`Offhand.exe`).
* **System Tray Integration**: Minimizes silently to the Windows notification tray with quick-actions and live status tips.
* **Built-in Guidance**: Hover dashboard controls for detailed tooltips, or use the `?` button (also available from the tray menu) for the complete setup, daily-use, Forever recovery, and troubleshooting guide.
* **User-Initiated Updates**: The Companion never contacts an update service at startup. **Check for Updates** makes a one-time request to the official GitHub Releases API only when clicked.
* **DPI-Aware**: Full Per-Monitor V2 scaling ensures crisp fonts and accurate window positioning on mixed-resolution / mixed-scale setups.
* **Forever Layout Recovery**: While WoW is closed, mirrors the newest valid
  account and character Offhand SavedVariables into a guarded addon snapshot.
  This works around Forever beta builds that write `Offhand.lua` but fail to
  load it on the next client launch.
* **Forever Pre-Login Span**: Forever clients bypass the configurable launch
  delay once their main window exists, ensuring Blizzard Edit Mode and Offhand
  initialize against the final multi-monitor canvas rather than a temporary
  single-window geometry.

---

## Downloads & Distribution
* **`Offhand.exe`**: Ready-to-run standalone executable. No installer needed; uses the Windows .NET Framework.
* **Open Source Auditability**: 
  * Full source code is in `Source/Program.cs`.
  * To compile yourself, run `build.bat`. It uses the native Windows C# compiler (`csc.exe`) built into Windows 10 & 11.
  * Official releases include SHA-256 checksums and GitHub build-provenance attestations. See the project `SECURITY.md` for verification commands and the complete behavior disclosure.
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

On a fresh install, **Automatically span WoW window on game launch is disabled**.
Use **Span WoW Now** for the initial setup after reviewing the selected displays.
Enabling auto-span is an explicit preference and is remembered on later launches;
updating the Companion does not overwrite an existing saved choice.

The Companion does not perform an automatic update check. Clicking **Check for
Updates** makes one HTTPS request to
`api.github.com/repos/N4UX-GIT/Offhand-DualMonitor/releases/latest`. It opens the
official release page only after an update is found and the user confirms.

## Forever SavedVariables recovery

The Companion remembers the last detected WoW installation. When that client
closes—or when the Companion starts from the installed addon's `Companion`
folder while WoW is already closed—it finds the newest valid account-wide and
character-specific `Offhand.lua` files under that installation's `WTF` folder.
It atomically generates `Core\ForeverState.lua`, retaining the previous copy as
`ForeverState.lua.bak`. The generated Lua is guarded to interface versions
16000–16999, so it is inert on other WoW clients.

WoW must be fully closed before the Companion reads or updates this snapshot.
The addon consumes each generated version once per client session, then uses its
session CVar fallback for subsequent `/reload` operations. With multiple
accounts or characters, the most recently written valid account snapshot and
the most recently written valid character snapshot belonging to that account
are selected.

## Restore Window

Use the Restore Window button or Ctrl+Alt+R to return WoW to a bordered window.
The shortcut is independent of the selected span shortcut. The Companion remembers
the bounds before its first successful span of a window and fits restored bounds
inside a monitor's work area. If no bounds were remembered, it uses a window up to
1920x1080 on the primary monitor, reduced to fit. Remembered bounds last for the
current Companion session only.

A successful restore pauses automatic spanning for that WoW process. Click Span
Now to resume, or launch a new WoW client. Restarting the Companion clears this
temporary pause. Disable Offhand's dual-monitor mode in-game when returning to a
single monitor; the Companion cannot read live addon enablement.

Restore checks both Win32 results and the resulting bounds before reporting
success. If the requested move fails, it attempts to restore the previous style
and bounds and reports the failure.
