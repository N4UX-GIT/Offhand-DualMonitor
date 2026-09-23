# Forever v2.1.2 release-candidate ledger -- 2026-09-23

This section is the authoritative current ledger. Earlier dated sections are
retained as engineering history; an older `pending`, failed smoke result, or
remaining-work list is superseded where this ledger records a later pass.

## Ordered execution plan

1. Preserve the accepted 4000x2560 Forever baseline and run the remaining
   combat/taint, post-combat, HUD-bar, transition, idle, relog and panel-reopen
   matrix one controlled live step at a time.
2. Exercise the complete Forever SavedVariables fallback live across `/reload`,
   relog and cold restart, then repeat on another character/account where
   practical.
3. Exercise Companion tray, hotkey, pause, update, help and repeated hotplug
   recovery behavior.
4. Test addon coexistence and arbitrary movable windows, then test additional
   physical topologies as hardware permits.
5. Recheck version, changelog, release notes, website copy and package contents;
   prepare review and final artifacts without publishing or merging.
6. Only after Forever acceptance, reproduce Retail v2.0.0 reports and port the
   proven fixes across the supported client families.

## Release-candidate matrix

| Area | Status | Evidence / remaining work |
| --- | --- | --- |
| Branch and checkpoint | PASS | `codex/forever-safe-recovery` is clean at `2d02266d842dbb148f05429d65f2fe7caa3ee7e1`; annotated tag `checkpoint/2026-09-22-forever-v2.1.2-stable` points at HEAD and the branch matches origin. |
| Automated addon baseline | PASS | All 21 Lua suites and all five addon manifest validations passed on 2026-09-23. |
| Companion preference regression | PASS | `tests/companion-preferences.ps1` passed on 2026-09-23, including compilation of the full Companion source. |
| Companion checkpoint binary | PASS | SHA-256 is `9FB8FA71CD76F71ABCB3BE73A69556630FCAE90153CBA10F95B5F7030BA2580A`. |
| Companion Beta 2 binary | PASS | Rebuilt v2.1.2.0 standalone SHA-256 is `CBA79B70788C904BBA13321CC16A1F00BCCDF6A265584C977DB5E255136A73B5`; this locally compiled beta has release checksums but no GitHub Actions provenance attestation. |
| Companion Beta 3 candidate | PASS | Rebuilt v2.1.2.0 standalone SHA-256 is `7CB2138A35CA34F2AF2440F5649451F211D5CBD0EC7CE0F0DCEC4D2DC01113F6`; source/compile regression passed. |
| Exact Forever topology | PASS | 1440x2560 portrait workspace plus 2560x1440 landscape Mainhand spans as 4000x2560; cold launch and respan retain the layout. |
| Beta 3 physical display identity / Mainhand reversal | FIXED IN SOURCE (automated) / CRITICAL LIVE RETEST | The user's standard 1440x2560 + 2560x1440 setup reproduced a concrete Companion failure: configuration stored `MainhandDevice=\\.\DISPLAY1`, Windows later assigned that label to the portrait display, and generated topology consequently declared the portrait `1440x2560` display as game/Mainhand. Companion now persists the physical monitor ID obtained from Windows, follows it across `DISPLAY#` renumbering, defaults an unupgraded configuration to the Windows primary display, and blocks automatic spanning until the user confirms the physical selection once. Regression swaps both `DISPLAY#` labels while retaining physical IDs and proves the landscape Mainhand remains selected. Existing Beta 3 binaries do not contain this fix. |
| Restored Options master-checkbox state | FIXED IN SOURCE (automated) / LIVE GAP | Disk SavedVariables and the generated Forever bridge both contained `enabled=true`; this was not evidence of another persistence loss. The settings frame could instead be restored by `Show()` without passing through `Options:Open()`, leaving its construction-time checkbox appearance stale. Every `OnShow` now resynchronizes the master toggle and all displayed settings from the active profile. Regression covers direct restoration with both enabled and disabled states. |
| Exact-topology settings and wizard classification | FIXED IN SOURCE (automated) / LIVE GAP | Companion topology intentionally owns display rectangles, so manual orientation and seam controls remain disabled while exact topology is active. The panel and wizard now state this explicitly. Exact side-by-side topology is classified from the independent game/workspace dimensions; a portrait workspace plus landscape Mainhand is no longer mislabeled or saved as `Dual Landscape 50/50`. |
| Missing-workspace recovery | PASS | Physical disconnect restores WoW to the surviving Mainhand; map, character, bags and chat remain reachable without replacing saved Offhand positions. |
| Reconnect recovery | PASS | Reconnection, selected-Mainhand restore and exact two-monitor respan passed. |
| Protected Edit Mode recovery | PASS | Player-click **Use Modern** and **Restore Offhand** prompts perform the protected layout changes Forever rejects from addon timers. |
| Raw mouse span handling | PASS | `OH RAW 1` was observed live and continuous right-button vertical camera movement passed; the prior CVar is restored outside the active span. |
| Core preference persistence | PASS | Master enable and minimap preference survived `/reload`. |
| Complete fallback logic | PASS (automated) / GAP (broad live) | Versioned, checksummed account and character snapshots are covered for geometry, themes, nested custom colors, profiles and Edit Mode recovery; equal-or-newer normal SavedVariables win. Broader live `/reload`, relog, cold-restart and multi-character coverage remains. |
| Combat, taint and HUD bars | GAP | Requires structured live combat/post-combat tests covering action, stance, pet, XP and reputation bars. |
| Runtime transitions and longevity | GAP | Long idle, zone/loading transitions, cinematics, relog/character changes and repeated map/bag/chat/tooltip/dropdown/panel reopen tests remain. |
| Companion controls and repeated hotplug | GAP | Tray, hotkey, pause, update/help behavior and repeated recovery cycles remain. |
| Addon coexistence | GAP | Chattynator, bag addons, RIF, OneWorld, Focused, DeSync and representative movable addon windows remain. |
| Additional physical topologies | GAP | Dual landscape, stacked, mixed 1440p/1080p, 32:9 combinations, negative origins and primary-display changes require available hardware. Unavailable hardware is not a defect. |
| Release source consistency | PASS / GAP | TOCs, Companion assembly/manifest/UI, packager default, README, release notes and website source identify v2.1.2; the changelog now has a dated v2.1.2 section. The website's combat-safe claim remains subject to the live combat/taint matrix. |
| Beta 2 release artifacts | PASS | Rebuilt and inspected: addon `E1DD209F...B3B4`, Companion archive `A8D6DD6F...BC91`, standalone EXE `CBA79B70...73B5`, and complete bundle `C313EB2A...0281`. All archives exclude development-only content. |
| Beta 3 release artifacts | PASS | Published and inspected: addon `10364E5E...A323`, Companion archive `343DE945...6F98`, standalone EXE `7CB2138A...13F6`, and complete bundle `80356CA6...AC7E`. GitHub-reported digests match local files; the addon archive matches current source and excludes development-only content. |
| Confirmed open runtime defects | THREE BETA 1 REPORTS FIXED IN SOURCE / LIVE GAP | Beta 1 user reports confirmed two secret-number taint paths (`CompactUnitFrame`, `TextStatusBar`) and Cooldown Viewer aura-table taint. Current source removes the shared unsafe global/panel mutations and excludes Blizzard managed frames, with focused regression coverage. Exact live retests remain required before acceptance. |
| Cross-client disabled-state isolation | PASS (automated) / GAP (live) | Retail mocks now prove disabled and temporary single-screen profiles leave tooltip and bag ownership untouched. Live confirmation remains required on every supported client family. |
| Mixed-resolution geometry | PASS (automated) / GAP (additional hardware) | Companion and Lua geometry regressions retain independent display widths, heights and offsets; the accepted Forever 1440x2560 + 2560x1440 layout is live proof. Additional 1440p/1080p and DPI combinations remain validation gaps, not confirmed defects. |
| Companion long status/log text | FIXED (automated) / GAP (visual) | The display-plan field now reserves two wrapped lines and the activity log uses a read-only word-wrapped surface. Source/compile regression passed; visually confirm the disconnected-display message and long log entries at normal and high DPI. |
| Single-display 32:9 split width | DOCUMENTED LIMITATION | The current explicit one-screen mode divides the display 50/50. Exact Companion topology disables the in-game seam slider, so arbitrary split width is not currently supported. |
| Forever Edit Mode layout identity | FIXED (automated) / GAP (live) | Layout-name matching was already case-insensitive; recovery now also re-resolves the saved name when its custom slot ID changes. Regression covers `OFFHAND` moving from global ID 6 to 5; repeat the disconnect/reconnect player-click flow live. |
| Beta 1 Forever Edit Mode / `CompactUnitFrame` taint | FIXED IN CURRENT SOURCE (automated) / GAP (exact live regression) | The report reproduced after the earlier protected-frame exclusions, proving that fix was incomplete. Audit found Forever still replacing `CloseAllWindows`, modifying `UIPanelWindows`/panel attributes and anchoring Edit Mode/menu panels. Current source preserves Blizzard's close functions, Edit Mode manager, Game Menu, panel metadata and native anchors. Repeat Edit Mode open/close with party frames visible, including after combat. |
| Beta 1 Forever CharacterFrame / `TextStatusBar` taint | FIXED IN CURRENT SOURCE (automated) / GAP (exact live regression) | The report also reproduced after the earlier PlayerFrame exclusions. The remaining shared path was Offhand's global close-function replacement and CharacterFrame panel-manager mutation. Both are now disabled on Forever; native Escape/panel behavior takes precedence over persistent-open workspace panels. Repeat CharacterFrame open/close with player status text shown. |
| Beta 1 Forever Cooldown Viewer aura-table taint | FIXED IN CURRENT SOURCE (automated) / GAP (exact live regression) | Three user stacks named `EssentialCooldownViewer`/`UtilityCooldownViewer` after an orientation change. These are unprotected but Blizzard Edit Mode-managed frames, so the generic UIParent void scanner could reanchor them and taint later aura registration. Named and semantic managed-frame detection now excludes them from movement, scripts and recovery; the native `UpdateContainerFrameAnchors` function is also preserved on Forever. Repeat vertical-orientation setup with all Cooldown Viewer types enabled and exercise aura add/remove alerts. |
| Forever Escape and native menu placement after taint hardening | MAP PROTECTED (automated) / PANEL + LIVE GAP | The dedicated map path removes a saved workspace `WorldMapFrame` from `UISpecialFrames`; a focused Forever regression proves Escape leaves it open while a Mainhand map retains native close behavior. Offhand no longer intercepts `CloseAllWindows` or mutates native panel metadata: Character and other active `UIPanelWindows` panels can close, and native bags use a separate close path; saved geometry remains. Game Menu visibility is expected on the accepted 4000x2560 topology but requires live confirmation. Edit Mode still opens through Blizzard, but its native top controls may land in mixed-height void; use Companion **Restore Window**, edit, then respan until a taint-safe in-span access path is proven. |
| v2.1.2 Forever locked/docked chat-tab drag | FIXED (automated) / GAP (live regression) | Confirmed from the reported `Core/Canvas.lua:1577` stack and locals: Offhand registered the tab for dragging, marked ChatFrame1 movable and called `StartMoving()` even though Forever reported `isLocked=true`, `isDocked=1` and a static dock. Offhand now observes Blizzard's native tab-drag lifecycle without overriding registration/movability or forcing movement. Regression makes those writes throw and verifies initialization plus drag observation remain safe. |
| Two-display vertical stack photo (`3818x2104`) | SUPPORTED IN CURRENT MODEL / GAP (exact hardware) | User clarification identifies the upper large landscape display as Offhand and the lower pad as Mainhand. Unequal resolution or DPI scaling is supported when Companion supplies both exact rectangles; it is not represented correctly by the legacy combined-resolution heuristic shown in the photo (`Mixed Portrait + Landscape`) or a manual 50% stacked split. Select exactly those two displays, explicitly select the lower pad as Mainhand, align their Windows rectangles, span, then `/reload`. A tiny Mainhand intentionally produces a tiny 3D viewport. Retain this hardware combination as a validation gap until its Windows display map and exact-topology result are available. |
| Three-display `1440x2560 + 3440x1440 + 1440x2560` report | CONFIRMED ARCHITECTURAL LIMITATION / DEFERRED THREE-DISPLAY SCOPE | The follow-up identifies two rotated 1440p portraits around one 3440x1440 ultrawide, for an approximately 6320x2560 desktop. The legacy 50% seam lands at x=3160, halfway through the ultrawide: one portrait plus half the ultrawide is assigned to each side, matching the screenshots' cut-off/letterboxed world. Windows alignment can change void placement but cannot repair this partition. Current Companion can safely use the ultrawide as Mainhand plus exactly one portrait as workspace (4880x2560 exact topology), leaving the other portrait outside WoW. Using both portraits as independent workspaces requires future three-display/multi-workspace geometry. Moving camera-dependent shadow splotches resolve in a restored single-monitor window, but must be retested under the supported exact two-display plan before classifying a separate renderer defect. |
| Forever Restore Window with no accepted exact topology | FIXED (automated) / GAP (live regression) | The Companion restores the native WoW window to Mainhand and pauses auto-span. Forever now treats absent exact topology as a safe single-screen recovery state: legacy percentage spanning is not applied, the viewport fills the current window, saved workspace visibility is preserved, ordinary panels receive temporary visible anchors, and protected Edit Mode HUD recovery offers the player-click Modern/Offhand handoff. Retail and Classic retain legacy manual-span behavior. Reproduce the reported Restore Window flow live, then verify `/reload` and exact respan. |
| Mob tooltip appearing on the other screen | VALIDATION GAP / UNSUPPORTED REPOSITIONING | The Discord suggestion to drag it in Edit Mode is not established by current source. Offhand normalizes tooltip scale while spanned but deliberately excludes `GameTooltip` from generic movement/recovery and provides no tooltip-anchor control. First reproduce under exact Companion topology and record the tooltip owner/anchor behavior; a future fix must preserve cursor-owned tooltips and coexist with tooltip addons rather than globally forcing one anchor. |
| Deferred product scope | DEFERRED | Antivirus submissions, code signing, more than two selected displays, guaranteed management of every arbitrary third-party frame and low-priority Companion UI refactoring. |
| External publication | GITHUB BETA 3 PUBLISHED / CURSEFORGE USER-MANAGED | GitHub pre-release `2.1.2-beta.3` was published on 2026-09-23 with addon, Companion, standalone EXE, complete bundle and checksum assets. GitHub-reported asset digests matched the local files. The user manages any CurseForge upload. Do not merge, promote to stable, modify the live website or submit antivirus reports without further approval. |

---

# Historical stabilization baseline -- 2026-09-16

## Build and deployment follow-up

- Rebuilt the native companion, addon ZIP and companion ZIP. Artifact checks
  verify source/TOC parity, matching executable copies and both checksum manifests.
- Packaging now always compiles current source, excludes unloaded legacy modules,
  retains existing build directories and uses unique temporary staging. Website
  checksums use the filenames actually served by the site. Release CI verifies
  artifacts before publication.
- Runtime addon version is read from TOC metadata (fallback 1.0.0), correcting the
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

## 2026-09-21: Forever v2.1.0 exact-topology acceptance

- Hardware topology: 1440x2560 portrait workspace beside a 2560x1440 landscape Mainhand, spanned as a 4000x2560 virtual desktop.
- Companion v2.1.0 displayed the new display selection and explicit Mainhand controls.
- Selecting both displays and the landscape gaming display as Mainhand succeeded.
- `Span WoW Now` generated the exact topology and spanned the client correctly.
- Forever loaded the workspace panels, protected HUD, and persistent Edit Mode options frame in their expected rectangles.
- A normal WoW exit followed by a cold relaunch with Companion running preserved the complete layout.
- User accepted all seven primary release-candidate steps. The disconnected-workspace-display fail-safe remains the final live safety check.
- Physical workspace-display disconnect confirmed Companion refused `Span WoW Now` and did not collapse the 4000x2560 span onto the 2560x1440 Mainhand. The stale topology was rejected and the game remained viewable.
- The first disconnected-display run exposed a protected-HUD gap: Forever retained the spanned `Offhand` Blizzard Edit Mode layout, so protected frames were readable but malformed. The initial v2.1.1 automatic API handoff was later proven ineffective because Forever ignores this protected change outside a hardware event; v2.1.2 replaces it with player-click recovery prompts.

## 2026-09-22: Forever v2.1.2 recovery findings

- The primary seven-step exact-topology and cold-launch sequence passed on the
  1440x2560 portrait workspace plus 2560x1440 landscape Mainhand.
- Companion refused a new span after the workspace was physically disconnected,
  and Offhand rejected stale topology. Temporary single-screen recovery now gives
  map, character, bag, and chat windows clean reachable positions while retaining
  their saved Offhand coordinates for reconnection.
- Forever layout IDs are global: Modern 1, Classic 2, and the tested custom
  Offhand layout 6. A timer/addon call to `C_EditMode.SetActiveLayout(6)` was
  ignored, while the same call issued directly by the player succeeded. Recovery
  therefore uses player-click **Use Modern** and **Restore Offhand** prompts.
- A stale generated Forever bridge was found overwriting newly saved state during
  `/reload`. The bridge is now consumed once, and current SavedVariables win on
  subsequent reloads.
- Disconnecting the workspace from an already-spanned session exposed desktop
  content where the missing monitor had been. Companion v2.1.2 now detects this
  state and restores a bordered WoW window that fills the surviving Mainhand work
  area. Later v2.1.2 acceptance confirmed the native-window disconnect recovery,
  reconnection and exact respan; the original pending status is superseded.
- During the first v2.1.2 retest, the workspace was reconnected after Companion
  launched. Its status calculation saw both displays, but the selectors retained
  the one-display startup inventory, and manual Restore Window returned WoW to its
  stale portrait-workspace position. The selectors now refresh on Windows topology
  changes without rewriting saved device identities, and manual restore fills the
  selected or surviving Mainhand. The selected-Mainhand restore and subsequent
  exact two-monitor respan passed later in this same acceptance cycle.
- The selected Mainhand restore and subsequent exact two-monitor respan passed.
  Repeated full-range vertical camera sweeps while holding right mouse eventually
  exhausted cursor travel; releasing the button reset it. Setting
  `rawMouseEnable=1` eliminated the block in the same live session. Offhand now
  enables raw input only while its span is active and restores the prior setting
  on single-screen recovery, disable, or logout. Automated lifecycle coverage was
  added. Later live acceptance observed `OH RAW 1` and confirmed continuous RMB
  vertical camera movement; the original pending status is superseded.
- A clean cold-launch control with both displays continuously connected reproduced
  the vertical camera block with `rawMouseEnable=0`, establishing that it is a
  normal mixed-height span requirement rather than a disconnect-test artifact.
  The same control also exposed a false missing-workspace prompt during the brief
  pre-span startup interval. Recovery now waits eight seconds for a sustained
  mismatch, cancels if exact topology arrives, and hides obsolete prompts.
- Enabling the master dual-monitor mode was then proven to revert to disabled on
  `/reload`. Forever had reloaded the profile default while its normal
  SavedVariables update was unavailable. The session fallback now mirrors the
  master enabled and raw-mouse preference flags together, and updates them from
  the options UI, auto-configure, slash toggle, profile changes, and reset.
- The same client defect can affect every account or character field, not only the
  master switch. Forever now records a bounded, checksummed, data-only snapshot
  of the complete Offhand account and character state at the reload boundary. The ordinary account
  table carries the same monotonically increasing revision: an equal or newer
  standard load wins automatically, while only a stale revision activates the
  fallback. Tests cover geometry, themes, nested custom colors, Mainhand frame
  positions, active profile selection, and protected Edit Mode recovery state.

