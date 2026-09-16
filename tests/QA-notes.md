# Current stabilization baseline — 2026-09-16

## Build and deployment follow-up

- Rebuilt the native companion, addon ZIP and companion ZIP. Artifact checks
  verify source/TOC parity, matching executable copies and both checksum manifests.
- Packaging now always compiles current source, excludes unloaded legacy modules,
  retains existing build directories and uses unique temporary staging. Website
  checksums use the filenames actually served by the site. Release CI verifies
  artifacts before publication.
- Runtime addon version is read from TOC metadata (fallback 1.0.1), correcting the
  previous hardcoded 1.1.0 message. Companion assembly version remains 1.2.0.0.
- The Classic Era AddOns/Offhand folder is a junction to this repository. Source
  edits are therefore already available on next login/reload, without copying.
  Earlier wording that fixes were not installed was incorrect.
- WoW was not running during this follow-up. No live login, combat or UI acceptance
  was performed. No new public release tag was created.

Historical entries below do not establish acceptance of the present Canvas
implementation. Rollback: checkpoint/2026-09-16-before-stabilization (85f62ac).

- Corrected test harnesses: separate event handlers, CENTER-relative offsets,
  GetChildren varargs, child registration and delayed Edit Mode initialization.
- Active map coverage is in escape-and-bags.lua and loads Core/Canvas.lua.
  Historical module tests moved to tests/legacy, outside CI's active selection.
- Regressions cover a single scanner, clamped-CVar independence, native map
  dimensions and Ctrl-wheel combat protection, plus game-monitor drag bounds.
- Verification: all 14 active Lua suites and both TOCs pass; simulated companion
  window-operation tests and compiled C# preference regressions pass.
- No game-folder deployment or live runtime acceptance in this pass.

---

# Lifecycle validation â€” 2026-09-12

## Global UI baseline and independent resizable map

Replaced per-frame scale corrections with one guarded UIParent:SetScale baseline,
calculated from physical game/canvas dimensions and the saved size preference.
No uiScale CVar writes: avoids the earlier CVAR_UPDATE/layout feedback path.
Repeated identical calculations do not write scale; recursion/combat are guarded,
and disabling restores the pre-Offhand root scale. Native addon relative scales remain.
Removed addon-specific placement names; generic top-level movable-window/tooltip
discovery handles placement separately from scaling. Standard panel names remain
for Blizzard docking and opening behavior, not for scale exceptions.

Docked WorldMapFrame alone is detached via UIPanelLayout area metadata after
releasing its existing panel-stack slot. Its mini-map display mode remains windowed.
Other panels retain normal Blizzard stack behavior. A bottom-right grip resizes the
window/scroll canvas and saves dimensions; disabling docking restores original map
metadata/display preference and hides the grip. No combat resize is attempted.

Global baseline, inherited custom relative scale, no-op/reentrant updates, disable
restore, persistence and map coexistence/resize/restore mocks pass. Lua/TOC validation
passes. Nine files installed with matching hashes and backups. Real map rendering,
click/zoom behavior after resize, coexistence and global UI appearance still need
live acceptance testing after reload. No live client input was sent for this revision.

## RIF, tooltip scaling and panel persistence follow-up

Added named RIF roots (RiF_StatusWidget/MainWindow/options/onboarding/copy), tooltip
and dropdown roots, LFG frames and OneWorld context menu. Top-level GameTooltips and
named movable AceGUI windows are discovered with a one-second supported-frame scan.
This is not an override of all addon frames. OnSizeChanged also rechecks fit.
Dragged panel positions are saved by frame name and monitor-relative coordinates;
saved positions override Blizzard reopen anchors. Prior positions cannot be recovered.
Added padding inside visible monitor bounds to accommodate frame border artwork.

Bag handling now anchors individual backpack/bag-slot buttons, raises their frame
levels above the main artwork, and anchors MicroMenu left of the final bag slot.
No bag visibility or action state is forcibly changed. Existing immediate repair
hooks cover the bag buttons. Panel persistence, simulated reload/reopen, RIF/tooltip
scale, and geometry/lifecycle regression tests pass; TOC syntax validation passes.
Four updated files installed with matching hashes and temporary backups. This
revision still needs live visual confirmation of bags, menus, tooltips and reopening.

## Missing/oversized panels and micro-menu overlap

User confirmed action-bar flicker resolved. Screenshot shows widgets in the physical
desktop gap above the game monitor. CharacterDock had removed UIPanelWindows.area
for Spellbook/Friends/etc. without replacement placement. Removed that mutation;
reload restores original Blizzard panel definitions. Standard named panels now use
HUD-relative scale, fit within the game or deck rectangle and recover from invisible
gap positions. Valid user-placed panels can remain on either visible rectangle.
Dragging defers placement until drop; combat defers until exit. Named OneWorld and
DeSync widgets are included; unknown third-party panels are not globally overridden.
MapDock delegates placement to the same geometry; character/map/bag docking options
select the deck. MicroMenu and BagsBar now have separate adjacent artwork anchors,
including MicroMenuContainer scale handling and immediate repair hooks.

tests/panels.lua passes for panel metadata preservation, HUD scale, game/deck bounds,
gap rescue, dragging, combat and left-primary geometry. Geometry suite includes
micro-menu/bag anchor separation. Lifecycle and Lua/TOC validation pass. Six changed
runtime/documentation files installed with matching hashes and temporary backups.
No live reload or visual acceptance test performed for this revision yet.

## Idle Action Bar 2/3 and shapeshift flicker follow-up

User confirmed recurring flicker while idle out of combat. Previous XP-only fix
left action bars on a 50 ms timer and omitted modern StanceBar/PetActionBar hooks.
Action-frame scale and anchors now replay the last committed layout synchronously
after external SetScale/SetPoint calls, with recursion guards. Manager completion
also repairs the action frames. No visibility calls or method replacements added.
Modern and legacy stance/pet names are included. Combat repair remains deferred.

Geometry regression now simulates 100 scale/anchor resets on each bottom action
bar, StanceBar, legacy shapeshift frame and PetActionBar. Each returns to its desired
geometry before the setter returns, without timers. Combat/disabled checks pass;
existing geometry/lifecycle and TOC checks pass. Installed SeamRedirect.lua hash
matches the project. This revision still needs live idle/form-change verification.

## Companion unification and vertical alignment controls

- GUI, one-shot spanner and watcher now use Companion/Offhand-Window.ps1.
  Batch launchers use process-local execution-policy settings; no machine policy changes.
- Shared path restores minimized/maximized windows, uses physical DPI coordinates,
  verifies window ownership and immediate final bounds, and rolls back borders/bounds
  if spanning fails. More than one game client is treated as ambiguous.
- Installation is checked against the running client's directory, including the
  Vanilla TOC. Live enabled status is explicitly unknown; unrelated AddOns.txt files
  are no longer inspected. Unreadable installation paths do not pass the gate.
- Added the shared Game bottom offset field, Apply, and one-pixel nudges to settings
  and wizard. SavedVariables were not edited. Opening the field preserves calibration.
- tests/companion.ps1 passed under Windows PowerShell 5.1 with simulated native
  operations: install/unknown state, negative origins, restore, failure rollback,
  DPI-context cleanup, process ownership and multi-client refusal.
- Real shared native declarations compiled under Windows PowerShell 5.1. Read-only
  desktop measurement returned X=-1440, Y=-1114, width=4000, height=2560.
- tests/bottom-control.lua passed: opening, nudges, clamp, invalid text and refresh.
  Existing geometry/lifecycle suites and Lua/TOC validation passed. PowerShell files parse.
- Nine updated runtime/documentation files copied to the installed addon with hash
  verification and backups under the temporary Offhand-before-companion-update folder.
- No live window mutation, GUI launch, or game reload was performed in this follow-up.
  Actual spanning and new control rendering still require live acceptance testing.
  Restart the companion and reload the addon to load the updated versions.

## Calibration reference cleanup

Updated wizard/settings labels, heuristic detection wording, guide, README,
default comments and command help. Removed the unused uiScale initialization.
The 55% button is explicitly a custom split; 36% names its 1440/4000 geometry.
HUD presets are relative sizes, not resolution presets. Settings percentage
formatting now multiplies stored fractions by 100. Settings seam range matches
the wizard (15â€“80%, 0.5% steps); HUD range is 25â€“125%, with matching command clamps.
Added /Offhand settings and /Offhand options; clarified Fill and height behavior.
SavedVariables were not edited. Five updated files were backed up and copied to
the installed addon, with matching hashes. Existing geometry/lifecycle tests and
both TOC validations pass; revised graphical labels have not been checked live.

## Recurring XP/action-bar flicker follow-up

User reported continuous resizing, which invalidates acceptance of the earlier
transient recovery as sufficient. Classic's StatusTrackingManager UpdateBarVisuals
calls SetScale(ClassicScale) on each update. Offhand previously repaired that 50 ms
later and routed all HUD hooks through ApplyFullLayout.

- XP scale now corrects synchronously through a guarded post-hook; combat defers.
- Other HUD notifications coalesce into a HUD-only pass, without touching the
  viewport, canvas, or dock modules.
- Identical anchors are no longer cleared and rewritten.
- Regression passes: 100 XP resets recover before return without timers; 100
  manager notifications schedule one HUD pass; unchanged anchors remain untouched;
  100 combat resets defer to one post-combat repair. Geometry/lifecycle suites and
  both TOC validations pass. Installed Core/SeamRedirect.lua matches the workspace.
- This follow-up has not yet been verified in the live client. Continuous idle,
  XP/reputation updates, and combat transitions remain the runtime acceptance tests.

Source: https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_ActionBar/Classic/StatusTrackingManagerOverrides.lua

## Geometry fix â€” final live result

The geometry work below supersedes the initial failing smoke test in this file.

- Measured physical client: 4000 x 2560. Left display: 1440 x 2560;
  right display: 2560 x 1440, bottom six pixels above the client bottom.
- Root cause: WorldFrame anchors received UIParent coordinates without converting
  effective scales. HUD offsets had the same mismatch. Geometry now rounds in
  physical pixels and converts offsets for each target frame.
- Installed updated Core files and Wizard into the existing Classic Era addon.
  Backup: `C:\Users\NAUX\AppData\Local\Temp\Offhand-geometry-20260912-001124`.
- Final saved settings: seam 0.36, HUD multiplier 0.70, bottom inset 6 pixels.
- `/Offhand diag` passed after reload. Saved WorldFrame physical rectangle:
  x=1439.9999, y=6, width=2560, height=1439.9999. Deck width=1439.9999.
- MainMenuBar, MainActionBar, ActionButton1, PlayerFrame, and MinimapCluster
  share effective scale 0.39375. ActionButton1 measures 47.25 x 47.25 pixels.
- Full 4000 x 2560 screenshot inspected: left workspace contains no world render;
  primary game area and managed HUD align. Evidence remains local at
  `C:\Games\World of Warcraft\_classic_era_\Screenshots\WoWScrnShot_091226_002328.jpg`.
- Chattynator primary window and chat entry now follow the game HUD size.
- A transient Blizzard bar reposition was observed and recovered on the deferred
  layout pass. This is not a guarantee of zero visible movement during updates.
- Closed WoW normally with `/quit`; saved settings and diagnostics verified.
  Latest BugGrabber session 371 contained two errors, neither referencing Offhand.
- Lua 5.1 geometry and lifecycle suites pass; both TOCs pass syntax/file validation.
  Geometry tests cover multiple global scales, nested frames, left-primary layouts,
  manual seam changes, bottom inset, fill bounds, and invalid values.
- Not verified: live combat/taint stress, cinematics, zone transitions, or arbitrary
  third-party addon positioning. OWL and other independent widgets still use their
  own anchors outside the managed HUD.

Scope: configuration preservation, master layout combat deferral, draggable panel
setup deferral, and reporting of caught layout errors.

## Automated checks

- Lua 5.1 syntax and referenced file validation passed for both TOCs using the
  addon development skill's `validate-addons.ps1`.
- `lua tests/lifecycle.lua` passed: existing seam/HUD settings survive migration;
  malformed root settings recover; install/reset geometry defaults agree; twenty
  combat layout requests execute once after combat; caught errors are reported;
  layout reentrancy guards recover after a failure.

## Live smoke test

- Client: existing Classic Era client under `C:\Games\World of Warcraft\_classic_era_`.
- Character: Shapeshifted, idle in Stormwind. Realm not independently verified.
- Backed up the four installed Core files to
  `C:\Users\NAUX\AppData\Local\Temp\Offhand-before-qa-20260912-000301`,
  then installed the four changed source files.
- Entered `/reload` after visually verifying chat focus and the exact command.
- Returned to the world; Offhand startup and viewport messages appeared without a
  visible Lua error dialog. This does not establish absence of taint or hidden errors.
- Existing visible HUD misalignment persisted. Geometry is not accepted as passing.
- Saved settings observed after reload: seam 0.36, HUD scale 0.56, game height 1.0,
  enabled true. No saved calibration was intentionally changed.
- Viewport message reported 960 x 540; these values come from the addon's current
  GetScreenWidth/GetScreenHeight calculation, not verified physical pixels.
- Issued normal window close for the target client after evidence capture.

## Remaining work

- Measure physical client bounds, monitor rectangles, UIParent dimensions/effective
  scale and WorldFrame bounds together. A 1440/4000 layout implies a 36% seam only
  when those physical bounds match the actual spanned client.
- Correct scaled HUD anchor offsets and left-primary handling with live measurements.
- Exercise actual combat/post-combat, cinematics, zone changes, and load-on-demand
  panels. Mock combat tests cannot establish protected-frame safety in the client.
- Review disabling/restoring managed frames, obsolete Deck bay references, and
  companion behavior before expanding workspace features or preparing a release.

## 2026-09-12: inaccessible child and RIF reset errors
- CharacterDock probes forbidden/inaccessible children and isolates discovery per frame. Failed hook installs stay inactive; discovery avoids combat. Added bad-self and forbidden-child regression; later valid frames and ticker initialization continue.
- RedIsFriend UI_Settings reset now declares its function-local locale table. Isolated reset test verifies localized and fallback values without touching player data.
- All five Offhand Lua test files, RIF settings-reset test, and both project validators passed. Both changed runtime files backed up, deployed to Classic Era and hash verified. Live reload remains to be tested.


## Deferred native layout corrections
- Panel OnShow/OnSizeChanged/SetPoint hooks now coalesce to next tick, allowing native multi-anchor transactions to finish. Explicit dimensions retained before replacing anchors. Tooltip placement preserves native location and clamps only when outside visible monitors; no tooltip position persistence.
- Map OnShow/display synchronization now defers configuration to avoid reentrant minimize/resize during native layout.
- Bag reopen and tooltip position/dimension regressions, map deferred-show regression, existing Lua suites and validator pass. Two runtime files deployed with backups and matching hashes. User screenshots exposed behavior not covered by former mocks; live verification remains required.

