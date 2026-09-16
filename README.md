# Offhand — Multi-Monitor Workspace for World of Warcraft

Offhand places the 3D world on a calibrated game viewport and provides a secondary
workspace within one spanned WoW window. Current geometry testing targets Classic
Era 1.15.x. Other client variants need separate runtime verification.

## Installation and spanning

Copy the addon into `World of Warcraft/_classic_era_/Interface/AddOns/Offhand`.
Enable it in the addon list. Restart WoW after first installation; use `/reload`
after updating existing Lua files.

Set WoW to Windowed mode and run the included `Offhand-Span.bat` or
`Offhand-Span.ps1` companion. The companion sizes the window to the Windows virtual
desktop. Configure monitor orientation and placement in Windows before calibration.

## Calibration

Open `/offhand wizard`, choose the game monitor side, and align the red seam guide.
Window-size suggestions are heuristics; the addon cannot identify individual
physical monitors from the combined client dimensions.

For the measured 4000 x 2560 span, the left display occupies 1440 pixels, so the
correct deck width is **36%**. The remaining 2560 pixels, with the 16:9 setting,
produce a **2560 x 1440** game viewport. The 55% preset is a custom split, not a
portrait-monitor recommendation. Other arrangements require their own calibration.

The game bottom inset measures pixels above the bottom of the full client canvas.
Use zero for aligned monitor bottoms. The measured test setup uses six pixels.
Use the **Game bottom offset** field in either wizard or settings. Enter a pixel
value and click Apply, or use the -1/+1 pixel buttons for fine alignment.
`/offhand bottom <pixels>` remains available.

Global UI size is based on the game viewport. Offhand applies one baseline to
`UIParent`, which Blizzard frames and addons inherit through their normal parent
hierarchy. It does not write the `uiScale` CVar or repeatedly set individual addon
frame scales. Addons retain their own relative scale settings. The original root
scale is restored when Offhand is disabled; after reload with Offhand disabled, WoW
uses its normal scale settings.

The default size is 70%; the wizard offers Compact (56%), Balanced (65%), and
Standard (70%). These affect the whole UI, not just action bars. Settings permit
25–125%. Settings and wizard deck-width ranges cover 15–80% in 0.5% steps.

Position management is separate: standard panels, tooltips, and movable top-level
windows are kept in visible monitor areas and dragged positions are saved. No
per-addon scaling list is needed. Addons that deliberately ignore parent scale or
render outside the normal frame hierarchy may still need their own adjustments.
Protected layout changes remain deferred in combat.

## Commands

| Command | Effect |
| --- | --- |
| `/offhand`, `/oh`, `/offhand wizard`, `/offhand setup` | Open the calibration wizard. |
| `/offhand settings` or `/offhand options` | Open detailed settings, including bezel gap and module toggles. |
| `/offhand guide` or `/offhand span` | Open the window-spanning guide. |
| `/offhand seam 36` | Set deck width to 36% of the whole window; supported range 15–80%. |
| `/offhand hud 70` | Set global UI size to 70% relative to the game viewport; range 25–125%. |
| `/offhand bottom 6` | Place the game bottom six physical pixels above the canvas bottom. |
| `/offhand 169` or `/offhand 219` | Select 16:9 or 21:9 game aspect ratio. |
| `/offhand ar 1.6` | Select a custom aspect ratio. |
| `/offhand fill` | Use the configured game-height fraction instead of a fixed aspect ratio. |
| `/offhand height 56.25` | Set game height to 56.25% of canvas height, used only in Fill mode (5–100%). |
| `/offhand chat game` or `/offhand chat deck` | Place managed chat in the game view or workspace. |
| `/offhand diag` | Report physical viewport bounds and save a geometry snapshot. |
| `/offhand apply` | Reapply the complete layout. |
| `/offhand toggle` | Toggle Offhand. |
| `/offhand reset` | Reset saved calibration and options to defaults, including zero bottom inset. |
| `/offhand debug` | Toggle diagnostic chat output. |

Aspect-ratio height is constrained by the available canvas above the bottom inset.
The seam ratio specifies deck width; with the game on the left, the seam is measured
from the opposite side. Popup and error redirection uses the game center, which
need not coincide with the center of the full window.

## Source and validation

- `Core/Viewport.lua`: physical geometry and conversion between frame scales.
- `Core/SeamRedirect.lua`: managed HUD scale, anchors, and update hooks.
- `Core/Config.lua`: saved settings and defaults.
- `Core/Init.lua`: events, combat queue, and slash commands.
- `UI/Wizard.lua`: visual calibration; `UI/Options.lua`: settings and span guide.
- `Core/Canvas.lua` and `Modules/`: workspace and optional docking modules.
- `tests/geometry.lua`, `tests/lifecycle.lua`: Lua 5.1 regression checks.
- `tests/QA-notes.md`: live observations, historical results, and remaining checks.

## Companion behavior

`Offhand-Companion.bat (or Companion\Offhand.exe)` opens the GUI/tray controller. `Offhand-Span.bat` spans once;
`Offhand-Watcher.bat` monitors subsequent game launches. All use the shared
`Companion/Offhand-Window.ps1`, which must be included when distributing the scripts.
Run exactly one WoW client. Minimized or maximized windows are restored before
spanning. Coordinates include negative monitor origins and are measured in physical
pixels. Window bounds are checked immediately after the operation; a rejected span
attempt restores the pre-span bounds and borders (after any window restoration).

The companion verifies installation in the selected client's addon folder. It cannot
verify the current character's live enabled state: enable Offhand in WoW yourself.
An unreadable client path is reported as unverified and is not automatically spanned.
The companion never edits SavedVariables or assumes a universal seam or bottom offset.
Saved calibration is reapplied by the addon when the display changes. Recalibrate
when the Windows monitor arrangement changes. Restart the companion after updating
its scripts; `/reload` updates only the in-game addon.

## Workspace windows and map

Dragged named panel positions are stored by monitor-relative coordinates and
restored when reopened or reloaded. Generic discovery handles movable top-level
windows and tooltips without maintaining an addon-name list. Frames anchored to a
custom parent or not marked movable may still require manual placement.

With **Independent, resizable World Map on Deck** enabled, Offhand removes only the
map from Blizzard's exclusive panel stack. You can keep it open while opening the
Character sheet, Social window, or another standard panel. Those other panels retain
Blizzard's normal opening/closing rules. The map remains windowed while docked.

Drag the map's bottom-right grip to resize it; its dimensions and dragged position
are saved. Resizing is disabled in combat. Disabling map docking restores the map's
panel-stack behavior and hides the grip. The movement option controls the map's
PLAYER_STARTED_MOVING registration when that event is used by the client.

Global-scale inheritance and map behavior have automated regression coverage.
Current live-client acceptance results and limitations are in tests/QA-notes.md.

## Edit Mode Layouts & Combat Taint
When you first enable **Offhand**, your UI will seamlessly expand across both monitors. However, because Blizzard hardcodes their default Edit Mode presets (like "Classic" or "Modern") to the absolute edges of your screen, some native combat frames like the **Stance Bar**, **Pet Action Bar**, and **Raid Frames** will automatically snap to the far left of your Workspace monitor.

### Why doesn't Offhand move them automatically?
World of Warcraft's security engine strictly protects these specific combat frames. If an addon attempts to programmatically intercept and reposition them while Edit Mode is managing them, it triggers the internal **Taint System**. The moment you enter combat and cast a spell, change stances, or command your pet, the game will throw an ADDON_ACTION_BLOCKED error and lock up your interface.

To guarantee flawless, error-free combat, **Offhand** strictly yields control of these specific frames to Edit Mode.

### How to setup your layout (The Secure Way):
1. With **Offhand** enabled, open Edit Mode in-game.
2. Manually drag your Stance Bar, Pet Bar, and Raid Frames back to your preferred positions on your 3D Game View monitor.
3. Save your arrangement as a **New Layout** and name it exactly: **"Offhand"** (case insensitive).

By manually dragging and saving them, Edit Mode securely locks their coordinates into the Blizzard server cache, completely bypassing the taint system and keeping your combat 100% safe!

### Automatic Layout Switching
When you disable Offhand to play on a single monitor, your frames will dynamically shift. To fix this, simply select the standard **"Classic"** or **"Modern"** layout from the Edit Mode dropdown, and everything will snap back to normal.

When you re-enable Offhand, the addon will automatically detect your saved **"Offhand"** layout and securely load it for you in the background!
