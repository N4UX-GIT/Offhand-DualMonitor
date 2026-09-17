# Offhand - Multi-Monitor Workspace for World of Warcraft

Offhand places the 3D game view on your gaming monitor and uses a second monitor as a workspace for maps, bags and other supported windows. The addon controls the in-game layout; the Windows Companion spans and restores the game window.

## Installation and setup

1. Install the addon archive as `Interface/AddOns/Offhand` and enable it at character selection.
2. Download the separate Companion archive, extract it and run `Offhand.exe`.
3. Set WoW to **Windowed** mode. Click **Span Now** in the Companion (default shortcut: **Ctrl+Alt+S**).
4. Type `/offhand wizard`. The four steps cover recommendations, monitor layout, seam/bottom alignment and UI scale.
5. Check the recommendations against your physical monitors. Window dimensions alone cannot identify every monitor arrangement.
6. Click **Finish Setup**. Use `/offhand` for later adjustments.

For the common 1440x2560 portrait + 2560x1440 landscape arrangement, the portrait occupies 36% of the 4000-pixel combined width. Adjust the seam to match the actual client bounds; 55% is a custom split, not a universal portrait preset.

## Settings

- **Display:** Orientation, aspect ratio, seam, bottom offset, global UI scale, bezel compensation and OBS crop values.
- **Workspace:** Map size, window persistence, off-screen recovery and single-display preview.
- **Themes:** Warcraft-style presets, accent colors and workspace background. Settings dialogs keep an opaque backing for readability independently of workspace opacity.
- **Profiles:** Create or load settings profiles. Copying into the active profile, deleting another profile and resetting the active profile require confirmation.
- **FAQ & Help:** Short instructions for setup, workspace windows, recovery and Edit Mode.

Changes update the active profile as you use the controls. WoW writes SavedVariables to disk on logout or `/reload`. **Close** closes the settings window; **Reapply Layout** retries the current layout. Numeric edit fields commit with Enter or their Apply button.

The global UI scale is shared through the game's UI parent. Addons that explicitly set their own scale may still need adjustment in their own settings.

## Companion

- **Auto-span:** Watches for new WoW launches with an Offhand installation. Installation detection cannot verify whether the addon is enabled in the current session.
- **Restore Window / Ctrl+Alt+R:** Restores the bounds remembered before spanning, fitted to an available monitor's work area. Without remembered bounds, uses a window up to 1920x1080 on the primary monitor, reduced to fit.
- **Manual restore pauses auto-span for that WoW client:** It resumes after **Span Now**, a new WoW launch, or restarting the Companion. Pause Monitoring if you want to stop the watcher generally.
- **Shortcuts:** The span shortcut is configurable. Ctrl+Alt+R remains available independently; conflicts are reported and the buttons remain usable.
- **Preferences:** Stored in `%LOCALAPPDATA%/Offhand/OffhandConfig.ini`.

To return to one monitor, disable Offhand's dual-monitor mode in-game and use **Restore Window**. Choose your normal Edit Mode layout if needed.

The source is `Companion/Source/Program.cs`; `Companion/build.bat` embeds the icon, logo and DPI manifest. The PowerShell alternative has separate controls and does not share all native Companion features.

## Workspace and recovery

Drag supported windows by their headers to either monitor. Workspace settings can keep panels open independently, retain them when pressing Escape and reopen them after reloads. Hold **Ctrl + mouse wheel** over the world map to change its size.

**Gather Off-Screen UI**, available in Workspace, the minimap menu and `/offhand gather`, moves eligible open windows with inaccessible title edges to the game view. It leaves reachable windows alone, skips protected/forbidden frames and does nothing in combat. It does not reset other addons' stored positions.

Where Blizzard Edit Mode is available, use it outside combat to arrange stance, pet and raid frames. Save a layout named **Offhand** for automatic selection. Offhand yields management of these frames to Edit Mode to reduce conflicts; this is not a guarantee against taint from every addon combination.

## Commands

| Command | Effect |
| --- | --- |
| `/offhand` or `/oh` | Open settings. |
| `/offhand wizard` | Open guided setup. |
| `/offhand gather` | Recover eligible off-screen windows. |
| `/offhand diag` | Report viewport bounds and save a geometry snapshot. |
| `/offhand apply` | Reapply the current layout. |
| `/offhand reset` | Reset the active profile to defaults (immediate). |
| `/offhand toggle` | Toggle Offhand on or off. |

## Development and validation

Run the top-level Lua scripts in `tests` with Lua 5.1, then `tests/companion.ps1` and `tests/companion-preferences.ps1`. `package.ps1` rebuilds the Companion and stages addon/Companion ZIPs plus website downloads. `tests/package-artifacts.ps1` checks that packaged files match source.

See `docs/UI-REFACTOR-2026-09-17.md` for this iteration's changes and outstanding live checks. The addon and native Companion have separate version metadata; rebuilding artifacts does not publish a release.
