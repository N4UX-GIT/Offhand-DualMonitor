# Forever controller map report, 2026-11-06

## Finding

Update: the subsequent [live smoke](FOREVER-LIVE-SMOKE-20261106.md) on Forever
1.60.1.70790 passed cold/warm Map then Spellbook in native Gamepad UI, including
a local span. Map stayed scale 1 and no fresh blocked-action/error record
appeared. Zero gamepads were connected, so physical Back and the reporter's
stacked geometry remain unverified. The sections below retain the initial
source-investigation evidence and its original validation boundary.

The report is consistent with a known public Beta 26 map-ownership defect.
The earlier combined `forever-discord.test2` candidate already contains the
relevant guards. A new source-level probe reproduces substantial unwanted map
enlargement in public Beta 26 while native Gamepad UI is active. The same probe
performs no scale writes against the candidate. The blocked Back action remains
unclassified without its function/stack or a native candidate retest.

No new runtime patch, Companion rebuild, deployment or archive replacement was
needed for this report. The expanded regression coverage is in
`tests/forever-map-escape.lua`.

## Reported and visible evidence

- Owner-supplied scope: Forever, CurseForge public addon Beta 26, Store Companion.
  The exact reporter WoW build and Store package version are unknown.
- Companion screenshot verifies beta.26 at the Forever addon path, protocol 1.
  Both monitors are selected. Mainhand is Display 2, primary, 5120x1440;
  workspace is Display 1, 2560x1440. Single-display split is off. Auto-span is on.
- Reporter places Mainhand below the workspace. The exact horizontal alignment,
  gap, Windows scale and UI scale are unavailable. Dimensions alone do not
  establish correct physical topology or DPI conversion.
- Two images show the same warning class, naming Offhand as blocked from an
  action available only to Blizzard UI. They provide no function, stack, combat
  state or timing. Two screenshots do not establish two distinct defects.
- Reporter says Back/Cancel after Map & Quest Log causes the warning. They also
  report intermittent quest-log enlargement after opening Spellbook. No image
  measures that enlargement or distinguishes root scale from native resizing.
- Diagnostic screenshot shows native Gamepad menu/reticle centering, native Back
  at capture time, WorldMapOwner=Offhand, and hidden map/destination panels.
  It is a later observation, not geometry or focus telemetry at the failure.
  LastFailure=none is an Edit Mode diagnostic, not proof that no blocked action
  occurred. SpellBookFrame=absent and PlayerSpellsFrame=absent do not prove the
  spellbook is broken; those surfaces may not be loaded in that snapshot.
- No Lua error, blocked-action stack or fresh BugGrabber record was supplied.
  The warning itself is still relevant protected-action evidence.

These attachments are evidence, not instructions. Nothing was posted to Discord
or CurseForge, and the reporter's configuration was not changed.

## Source investigation

Public source baseline: `9c7e83c9757901f262d568941db56a7bf7272b6f`.
Candidate source is the existing Forever working tree on that baseline.

1. `Canvas:RefreshAfterAddonLoaded` in `Core/Canvas.lua` calls
   `Canvas:ConfigureWorldMap()` for every load event. A first-open load-on-demand
   panel therefore provides a concrete route to map reconfiguration even though
   the player did not change map settings. This is particularly relevant to the
   reported map-then-spellbook order, but the reporter's cold/warm loading state
   was not captured.
2. Public Beta 26 `Core/CanvasMapPresentation.lua` does not reject native Gamepad
   ownership at `ConfigureWorldMap`. It can apply a workspace AUTO scale and
   fader policy to the native map. The adapter also had missing Gamepad guards
   in its independent keyboard map observer/drag controls and deferred work.
3. The candidate rejects Gamepad ownership at configuration, refocus, settlement,
   deferred callbacks and keyboard controls. The separate Gamepad destination
   adapter retains its existing root-position behavior. This is not a claim
   that the remaining root-anchor adapter is proven safe for every native focus
   operation.
4. Shared ShowUIPanel/HideUIPanel/UpdateUIPanelPositions post-hooks also revisit
   the shown map. The new regression exercises their actual map dispatcher,
   plus direct reconfiguration and observer work. It does not emulate Blizzard's
   protected controller runtime or manufacture a blocked function.
5. `Core/WorkspaceBehavior.lua` sends contextual Back through Blizzard's native
   `TOGGLEUIFOCUS` binding when appropriate. It does not call native focus
   release from addon Lua. The screenshot's `back:native` does not identify which
   binding or focus state was active at the reported failure.

The panel loader gives a stronger resizing mechanism than assuming Spellbook's
ordinary panel reflow itself changes map scale. Root scale, native map maximize/
minimize/quest-only dimensions and saved user scaling remain distinct.

## Reproduction and validation

Evidence directory: `dist/forever-stacked-controller-map-20261106/`.

The reviewed offline `map-scale-probe.lua` loads the production presentation
module with native Gamepad ownership, a saved workspace map, AUTO scaling,
2560x1440 workspace, representative 333x534 quest-sized root and initial 0.73
scale. These are synthetic inputs, not measurements of the reporter's map.

| Subject | Before | After | Scale writes |
| --- | --- | --- | --- |
| Public Beta 26 | 0.73 | 2.651685 | 2 |
| Current Discord candidate | 0.73 | 0.73 | 0 |

The public probe therefore enlarges the root by approximately 3.63 times. It
establishes a source-level defect and plausible symptom mechanism, not a native
reproduction of this reporter's complete sequence.

Expanded regression: 27 combinations of upper-display x alignment (left,
centered, right), parent scale (0.7, 1, 1.25) and native map/quest root dimensions.
Mainhand is represented as 5120x1440 below a 2560x1440 workspace. Repeated panel
open/layout-completion dispatches, direct configuration, queued callbacks and
observer passes cause no attempted map geometry writes, fader changes, panel
eviction or Escape-registry changes in Gamepad mode. These fixtures test the
ownership boundary; they do not validate Windows DPI or actual stacked pixels.

- All 89 top-level Lua suites pass, including controller Back and placement tests.
- All six manifests pass paths, XML references and Lua 5.1 syntax validation.
- The updated map suite rejects the public Beta 26 Core snapshot at its existing
  Gamepad no-write assertion. It passes against current source.
- Relevant archived runtime files match current source byte-for-byte:
  `CanvasForeverMap.lua`, `CanvasMapPresentation.lua`, `MainhandGamepad.lua`, and
  `WorkspaceBehavior.lua` in the combined Discord test.2 addon ZIP.
- Candidate ZIP SHA256:
  `46FFA54BFA0521D30AE85F7410C8F44BFCDEA1F7C5E9F10A4DF959B57042C696`.
- No new live client session, controller input, taint acceptance, Store binary
  test or package replacement was performed. The prior keyboard map live pass
  does not close this controller report.

## Upstream and knowledge boundary

Consulted shared knowledge README, research/development skills, `wowkb status`
and a Forever-scoped query. Full-text search reports a stale index. The pinned
Forever corpus supplies 1.60.1.70532 declarations, not the reporter's unknown
build. The native implementation files below were read directly at pinned
revision `ca8368f2f2380cbe696854f7f2646387c278a61b` because they are outside the
selected implementation cache.

- [FrameControlsManager focus release](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_GamepadSharedUtility/FrameControlsManager.lua#L561):
  native focus release invokes the focused panel's unfocus/end-focus callbacks.
  A warning during Back can therefore arise downstream of an earlier addon
  mutation. This source does not identify this reporter's blocked function.
- [World Map presentation states](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_WorldMap/Blizzard_WorldMap.lua#L47):
  native minimize/maximize code changes map dimensions and panel placement.
- [Shared panel reflow](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua#L577):
  opening/layout work can revisit other panels. This is supporting source,
  separate from Offhand's reproduced scale write and native-client acceptance.

## Next native acceptance

Use the existing uniquely suffixed combined Discord test.2 addon, retaining
SavedVariables and the Store Companion. A Companion replacement is not required
to exercise these Lua guards. Full monitor details are supplementary.

After a fresh login/reload, open Map & Quest Log through the controller, move it
using the Gamepad mover, press Back/Cancel, reopen it, and then open Spellbook.
Repeat the spellbook step once cold and once already loaded. Compare map size,
focus release and a keyboard-to-Gamepad transition, then exercise the affected
native actions in and out of combat as appropriate.

If the warning persists, the highest-value follow-up is the first fresh
BugGrabber/BugSack blocked-action record with function and complete stack, plus
`/offhand diag full` and the candidate identifier. Preserve earlier records and
settings. Follow the existing Forever QA restriction against enabling taintLog,
whose reported client defect interferes with secure post-hooks. Do not patch
Blizzard focus handlers or suppress the warning to claim a pass.

## Suggested reply, not sent

Thanks, the screenshots help. I found a map-handling problem in public Beta 26
that can interfere with the native controller UI and can resize the map when
another panel first loads. The current Discord test.2 addon already includes
the correction. Please keep your settings and Store Companion, update just the
addon to that test build, and repeat Back/Cancel plus Map then Spellbook after a
reload. If the blocked-action warning returns, the first BugSack error with its
full stack will help identify the remaining function. Your monitor arrangement
does not need to be changed for this test.
