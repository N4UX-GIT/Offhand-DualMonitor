# Offhand – Multi-Monitor Workspace for World of Warcraft

Offhand is a seamless multi-monitor UI manager that stretches your World of Warcraft client across multiple physical displays. It perfectly anchors your 3D Game View to your primary gaming monitor while converting your secondary portrait or landscape monitor into a dedicated UI workspace. 

## Installation & Setup

1. Copy the Offhand folder into your World of Warcraft/_classic_era_/Interface/AddOns directory.
2. Enable the addon in your character selection screen.
3. Set your World of Warcraft client to **Windowed Mode**.
4. Open the Companion folder inside the addon directory and run Offhand.exe. 
5. In the Companion App, click **Span WoW Window Now** (or press the global hotkey Ctrl+Alt+S). The window will seamlessly stretch across your virtual desktop, removing its borders.
6. In-game, type /offhand wizard to launch the one-click calibration wizard, which will perfectly align the 3D Game View to your primary monitor!

## Companion App Features

The included lightweight C# Companion App (Companion/Offhand.exe) is designed to run in your system tray and manage the physical window spanning. 
* **Auto-Span:** Automatically spans WoW when it detects a new launch.
* **Global Hotkeys:** Press Ctrl+Alt+S to span the window instantly, or Ctrl+Alt+R to restore it to a single monitor.
* **Pause Monitoring:** Temporarily pause the background watcher.
* **Preferences:** Saves your delay timers and hotkeys securely to %LOCALAPPDATA%\Offhand\OffhandConfig.ini.

## Workspace Window Management

Offhand completely overhauls the Blizzard UI engine to support an expanded canvas:
* **Freedom of Movement:** Click and drag the headers of standard Blizzard windows (Character, Spellbook, Quest Log, Bags) to freely move them onto your secondary monitor.
* **Persistence:** Panels dragged to your workspace stay open independently, survive the Escape key, and automatically reopen after loading screens or a /reload.
* **World Map:** The World Map stays windowed on your workspace. Hold Ctrl and scroll over the map to scale it instantly!
* **Gather Lost UI:** If you ever lose a window, right-click the Offhand minimap icon (or use the Options panel) and click **Gather Off-Screen UI** to instantly teleport all open windows back to the center of your screen.

## Edit Mode Layouts & Combat Taint

When you first span your UI, Blizzard's default Edit Mode presets (like "Classic") will anchor native combat frames (Stance Bar, Pet Bar, Raid Frames) to the absolute edges of your spanned window.

**Why doesn't Offhand move them automatically?**
World of Warcraft strictly protects combat frames. If an addon attempts to automatically intercept and reposition them, it triggers the internal **Taint System**, resulting in ADDON_ACTION_BLOCKED errors mid-combat. Offhand intentionally yields control of these frames to Edit Mode to guarantee flawless combat.

**The Secure Setup:**
1. With Offhand spanned, open Edit Mode in-game.
2. Manually drag your Stance Bar, Pet Bar, and Raid Frames to your preferred positions on your 3D Game View or Workspace monitor.
3. Save your arrangement as a **New Layout** named exactly: **"Offhand"**.

By manually dragging them, Edit Mode securely locks their coordinates into the Blizzard server cache. When you log in with Offhand enabled, it will automatically detect and silently load your "Offhand" layout in the background!

## Commands

| Command | Effect |
| --- | --- |
| /offhand or /oh | Open the main Settings panel. |
| /offhand wizard | Open the one-click calibration wizard. |
| /offhand gather | Teleports all open UI panels to the center of the game view. |
| /offhand diag | Report physical viewport bounds and save a geometry snapshot. |
| /offhand apply | Manually force a re-application of the layout engine. |
| /offhand reset | Reset saved calibration and options to defaults. |
| /offhand toggle | Toggle Offhand on or off. |

## Source and Architecture
* Core/Viewport.lua: Physical geometry, spanning, and scale conversion.
* Core/SeamRedirect.lua: Managed HUD scale, anchors, dialog routing, and Edit Mode layout detection.
* Core/Config.lua: SavedVariables and defaults.
* Core/Init.lua: Event dispatch, combat queues, slash commands, and void rescues.
* UI/Wizard.lua: Visual calibration laser guide.
* UI/Options.lua: Clean tabbed interface for settings.
* Core/Canvas.lua: Active workspace placement, persistence, and world map scaling.
