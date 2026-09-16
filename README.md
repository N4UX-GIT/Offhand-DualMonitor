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
hierarchy. Normal layout changes do not write the `uiScale` CVar or repeatedly set individual addon
frame scales. Disabling can restore CVar values saved by an older Offhand build. Addons retain their own relative scale settings. The original root
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
| `/offhand`, `/oh` | Open settings. |
| `/offhand wizard`, `/offhand setup` | Open the calibration wizard. |
| `/offhand settings` or `/offhand options` | Open detailed settings, including bezel gap and module toggles. |
| `/offhand guide` or `/offhand span` | Open the setup wizard. |
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
- `Core/Canvas.lua`: active workspace placement, map scaling, dragging and persistence.
- `Modules/`: historical docking implementation; not loaded by either TOC.
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

The World Map stays windowed and independent of the normal panel stack. Move it
using its title handle. On the workspace, it auto-fits the deck width unless you
choose a custom scale; the game monitor has a separate map scale preference.
Hold Ctrl and scroll over the map/title to adjust scale. This scales the native
map rather than changing its canvas dimensions with a resize grip. Scaling is
blocked during combat. Leatrix Maps takes precedence when present.

Panels dragged to the workspace can be independent of other panels, remain open
through Escape, and reopen after reload. These are separate settings. Standard
panels moved back to the game monitor resume native panel-stack behavior.

Configuration uses account-wide `OffhandDB.profiles` with the active profile in
per-character `OffhandCharDB`. Settings have Display, Workspace, Themes, Profiles,
and FAQ tabs. The minimap button opens settings or the setup/recovery menu.

See `tests/QA-notes.md` for the latest automated baseline and live-test limitations.

## Edit Mode layouts and runtime verification

Offhand leaves stance and pet bar positioning to native Edit Mode. Arrange these
frames on the game monitor and save a layout named `Offhand`. The current addon
attempts to select a matching layout during delayed setup. Select a normal layout
manually when returning to a single monitor.

Combat guards reduce unsafe layout changes, but do not prove absence of taint.
The current compatibility implementation replaces two `EditModeUtil` measurement
functions to tolerate missing bar anchors and wraps `CloseAllBags` for workspace
persistence. These remain explicit live-verification points, including combat,
stance/pet changes and other addons. See `tests/SECURE-UI-AUDIT.md`.

## Development checkpoint and test coverage

The as-is development checkpoint is tag
`checkpoint/2026-09-16-before-stabilization` (commit `85f62ac`). Stabilization work
is separate from that tag. Run every top-level `tests/*.lua` file with Lua 5.1;
CI uses the same selection. `tests/legacy/` preserves historical tests for unloaded
modules and is excluded from the active acceptance baseline.

The companion executable requires Windows .NET Framework. Source changes do not
update previously built downloads automatically; build/package and verify the
artifacts before a release.
