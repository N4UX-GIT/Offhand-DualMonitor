# Companion independence plan

## Implementation status, 2026-10-15

The first independent-window implementation is active in source:

- `Core/ManualCanvas.lua` owns versioned account-wide canvas signatures,
  validation, confidence scoring, bounded storage, and geometry-source choice.
- An absent generated topology no longer proves that WoW is spanned. Offhand
  requires a remembered canvas match or uses safe single-screen geometry.
- Matching dimensions are classified as `MATCH`, `CLOSE`, `AMBIGUOUS`, or
  `MISMATCH`. Reference dimensions are updated only by an explicit remember
  action.
- The Display settings tab provides **Remember Current Window**. The same
  operation is available as `/offhand remember [name]` for focused testing.
- `/offhand diag` reports the remembered-canvas state, source preference,
  selected name, and candidate count.
- `AUTO`, `MANUAL`, and `EXACT` source preferences are implemented internally
  and through `/offhand geometry`; a complete player-facing selector remains a
  later UI refinement.
- Existing profile-scoped seam, Mainhand, and aspect choices remain canonical.
  A remembered canvas validates the native window size without coupling one
  physical setup to a particular character or UI profile.

Live Forever evidence establishes a high-value Windows assistant path:

| Case | Result |
| --- | --- |
| PowerToys FancyZones canvas | One cross-monitor Canvas zone covering the `4000x2512` Windows work-area union |
| First placement | DWM visible frame exactly `4000x2512`; WoW client canvas `3998x2480` |
| Addon layout | Workspace `1439x2480`; Mainhand `2559x1439`; viewport bounds passed |
| Cold relaunch | FancyZones restored the identical visible frame and client canvas automatically |
| Companion and bridge | Companion closed, topology absent, persistence loaded from ordinary SavedVariables |
| Ordinary one-monitor launch | Observed `2114x1353`; this must classify as mismatch and use safe single-screen geometry |

The addon still cannot observe the native window origin. A same-sized window
shifted away from the monitor seam therefore remains visually confirmable only.
FancyZones is an independent window-placement assistant, not an API or data
source that Offhand detects or controls.

## Product direction

Offhand is an in-game addon first. Manual spanning and third-party window
managers are supported setup methods. The Windows Companion is an optional
convenience tool for exact borderless geometry, automatic launch handling, and
recovery features. It is not required to remain running after a successful
span.

The long-term target is to make every in-game layout, calibration, persistence,
and recovery feature work without a resident desktop process. Native window
border removal and resizing remain outside the WoW addon sandbox, so those
actions must still be performed manually, by the operating system, by an
existing window manager, or by the optional Companion.

The addon onboarding now presents three equal, explicit placement paths:

1. **Microsoft PowerToys FancyZones**, the recommended Windows assistant.
2. **Offhand Companion**, retained for Linux/Wine and exact-topology workflows.
3. **Manual placement**, supported without another application.

FancyZones and manual placement both enter the remembered-canvas workflow.
Companion enters the exact-topology workflow. Offhand never claims to detect
FancyZones itself; it validates the resulting WoW canvas. General welcome,
settings, and help actions now open neutral **Window Setup** guidance instead
of sending every user to a Companion download.

## Forever recovery decision

The generated `Core/ForeverState.lua` bridge was introduced after a live
Forever 1.60.1 client wrote `Offhand.lua` but loaded stale/default addon state.
It must not be removed merely because recent sessions appear stable.

Retire the bridge only after the current Forever build passes this matrix with
the Companion fully exited and the packaged `ForeverState.lua` placeholder:

1. Record `/offhand diag` and the active persistence revision.
2. Change a distinctive account setting, a character setting, one Mainhand
   position, one workspace position, and one open-panel state.
3. Verify the same values after `/reload`.
4. Log out and back into the same character, then verify again.
5. Exit WoW normally, confirm no Companion process is running, cold-launch the
   client, and verify again.
6. Repeat the cold launch on a second character. Repeat on another account when
   practical.
7. Confirm `/offhand diag` reports `source=savedvariables`, `bridge=absent`, and
   matching nonzero disk and active revisions after each cold launch.

One clean launch is useful evidence, but it is not sufficient to remove a
fallback created for an intermittent client defect. Require several cold starts
across at least two days or client launches, with no stale/default restoration.

If the matrix passes, remove the generated bridge in a separate change while
retaining the in-client revisioned CVar fallback until `/reload` and relog are
also proven reliable. Keep downgrade handling for existing generated bridge
files so an old snapshot cannot overwrite newer normal SavedVariables.

## Standalone hardening

Priority work for the addon-only path:

- Make manual setup the first-class documented path, not an emergency fallback.
- Keep manual calibration explicit because addon Lua cannot read the native
  window origin, monitor identities, display rectangles, or Windows DPI layout.
- Improve `/offhand diag` so topology and persistence provenance are visible and
  supportable without the Companion.
- Preserve safe single-window recovery when generated topology is absent or
  stale.
- Test manual side-by-side, stacked, mixed-height, portrait/landscape, negative
  origin, and super-ultrawide layouts separately.
- Keep the topology file optional. Exact Companion geometry may enhance the
  experience, but core viewport, workspace, HUD, persistence, and recovery paths
  must not require it.
- Document operating-system and established window-manager recipes where they
  can apply a repeatable borderless span without an Offhand process.

## Companion guidance

After **Span WoW Now** succeeds, tell users that they may select **Exit
Companion** and continue playing. Explain the tradeoff plainly: exiting disables
automatic spanning, active monitor-disconnect recovery, topology-file repair,
the current-session exact Restore Window snapshot, and post-exit Forever bridge
refresh. It does not undo the current span or stop the in-game addon.

## Manual canvas memory implementation plan

### Status and scope

This section is a design and implementation plan. It does not authorize removal
of the Forever recovery bridge before the validation matrix above passes.

The objective is to let the addon remember and reuse a manually calibrated
layout when the player stretches the WoW window to approximately the same
canvas on a later launch. A user should not have to repeat Offhand's seam,
Mainhand, aspect, and workspace calibration merely because a hand-resized window
is several pixels different from the previous session.

This feature cannot make the WoW window resize or move itself. It also cannot
prove that a correctly sized native window is positioned on the same physical
monitors. The user promise must therefore be limited to remembering and
validating the in-game canvas layout.

Launch arguments are outside this design. Normal guidance should continue to
use WoW's in-game Windowed setting instead of asking users to maintain a Battle.net
argument.

### Product principles

- Manual setup is a durable supported mode, not a degraded Companion mode.
- A few pixels of hand-resize variation must not restart onboarding or discard
  calibration.
- The addon must never call a fuzzy canvas match "exact display alignment."
- Saved calibration must remain stable. Do not automatically rewrite the
  reference dimensions on every launch and allow cumulative drift.
- A major mismatch must fail safely without deleting saved frame positions or
  replacing the remembered profile.
- Exact Companion topology remains the highest-confidence geometry source when
  the user has selected automatic topology ownership.
- Generated topology, remembered manual calibration, and generic unconfirmed
  heuristics must remain distinguishable in diagnostics and user-facing state.

## Geometry ownership and source precedence

Introduce an explicit geometry-source preference with these modes:

1. `AUTO`: accept a current exact Companion topology when available; otherwise
   try remembered manual canvases.
2. `MANUAL`: ignore generated Companion topology for layout selection and use
   remembered manual canvases. This gives users a safe way to relinquish a stale
   topology without reinstalling the addon or editing Lua files.
3. `EXACT`: require a valid Companion topology and use safe single-screen
   recovery when it is missing or stale. This is primarily a diagnostic and
   support mode, not the recommended default.

Resolution order in `AUTO` should be:

1. Valid generated Companion topology.
2. Uniquely matching remembered manual canvas.
3. Explicitly confirmed current-session manual geometry.
4. Generic topology recommendation for setup preview only.
5. Safe single-screen recovery.

Generic heuristics must not silently become a remembered profile. The player
must confirm the visual layout once.

## Saved data model

### Ownership

Keep physical-canvas recognition account-wide in `OffhandDB`, not in
`OffhandCharDB`. It describes the local installation and display arrangement,
not a character. Keep existing layout preferences, such as seam ratio and
Mainhand side, profile-scoped unless implementation evidence supports a cleaner
migration.

Do not simply duplicate the complete UI profile for each monitor setup. Store a
small canvas signature plus normalized layout geometry. Existing frame positions
already use the active Offhand profile and should remain independently
recoverable.

### Proposed schema

```lua
OffhandDB.manualCanvasSchema = 1
OffhandDB.manualCanvases = {
    ["manual-1"] = {
        name = "Desk",
        source = "MANUAL",
        referenceWidth = 4000,
        referenceHeight = 2560,
        referenceAspect = 1.5625,
        uiCanvasAspect = 1.5625,
        measurementMode = "PHYSICAL_CANVAS",
        arrangement = "SIDE_BY_SIDE",
        primaryPosition = "RIGHT",
        game = { x = 0.36, y = 0, width = 0.64, height = 0.5625 },
        workspace = { x = 0, y = 0, width = 0.36, height = 1 },
        confirmed = true,
        lastConfirmedBuild = "...",
    },
}
OffhandDB.preferredGeometrySource = "AUTO"
```

All stored rectangles are fractions of the observed WoW canvas. Absolute
reference dimensions are a recognition signature, not the coordinates used to
lay out frames on every later session.

`measurementMode` must account for clients that report one monitor through
`GetPhysicalScreenSize()` while `UIParent` still reflects the complete spanned
canvas. Initial supported values should be:

- `PHYSICAL_CANVAS`: physical dimensions represent the complete client surface.
- `ASPECT_FALLBACK`: the physical dimensions are not the complete surface, so
  matching also requires the saved `UIParent` aspect behavior.
- `UNVERIFIED`: neither signal is strong enough for automatic recognition. The
  current session can still be used after explicit confirmation.

Validate every field and reject malformed, non-finite, out-of-range, partial,
or future-schema records. Rejection must not mutate the stored record.

### Multiple setups

Support a small bounded collection of remembered canvases so one installation
can handle common changes such as:

- Desktop monitors versus a laptop-only session.
- A dock at home and a different dock at work.
- Side-by-side work and stacked streaming arrangements.
- Manual dual-monitor and single super-ultrawide modes.

Generate a useful default name from dimensions and arrangement, but allow the
player to rename it. Start with a limit such as eight profiles and use explicit
deletion instead of silent least-recently-used eviction.

If two profiles are equally plausible, do not guess. Show the two candidates
and let the player choose. Remembering the choice is an explicit update to the
selected profile, not a hidden global preference.

## Stable canvas observation

Do not evaluate the first dimensions reported during login. Startup, display
wake, full-screen transitions, graphics changes, and external resizing can
produce transient sizes.

Create one bounded canvas observer that:

1. Samples `GetPhysicalScreenSize()` plus `UIParent` width and height.
2. Reacts to supported display-size and UI-scale events when available.
3. Debounces changes and requires several identical or near-identical samples.
4. Declares stability after approximately 0.5 to 1 second without meaningful
   change.
5. Uses a generation token so an older delayed callback cannot accept a newer
   resize.
6. Stops after a bounded settlement window and reports `UNSTABLE` rather than
   polling indefinitely.

Changing only WoW UI scale must not invalidate a physical canvas. Render scale,
dynamic resolution, client-specific backbuffer reporting, and `GetPhysicalScreenSize()`
behavior require live characterization before deciding which measurement is
authoritative on each client.

Do not display mismatch guidance while the client is minimized, during a
loading-screen transition, or while dimensions are still settling. A temporary
zero or one-monitor reading must not destroy the last accepted state.

## Matching and confidence model

### Normalized comparison

For a reference width `rw`, reference height `rh`, live width `lw`, and live
height `lh`, calculate:

```text
widthError  = abs(lw - rw) / rw
heightError = abs(lh - rh) / rh
aspectError = abs((lw / lh) - (rw / rh)) / (rw / rh)
```

Also compare arrangement, Mainhand side, measurement mode, and the available
UI canvas aspect signal. Do not select a canvas using aspect ratio alone.

### Initial confidence bands

Use configurable internal constants, not user-facing tolerance controls, for
the first implementation:

| State | Initial rule | Default behavior |
| --- | --- | --- |
| `MATCH` | Width and height within 1%, each capped at 48 pixels; aspect within 0.75% | Apply silently |
| `CLOSE` | Width and height within 3%; aspect within 1.5% | Reuse normalized layout and show one quiet verification notice |
| `AMBIGUOUS` | More than one profile has a similar score | Ask the player to choose; do not rewrite either profile |
| `MISMATCH` | Outside the close band, obvious single-display size, or incompatible arrangement | Use safe recovery and offer recalibration |
| `UNSTABLE` | No stable measurement inside the settlement window | Preserve the previous safe state and provide diagnostics |
| `UNVERIFIED` | Client signals cannot support automatic matching | Require visual confirmation for the session |

These thresholds are hypotheses. Before shipping, collect repeated manual
resize measurements and tune them from observed distributions. Include window
borders, title bars, taskbar arrangements, mixed DPI, and different Windows
versions in the sample.

### Hysteresis

Avoid changing state repeatedly near a threshold:

- Enter `MATCH` at the normal match threshold.
- Keep an already accepted match until it exceeds a slightly larger exit
  threshold, such as 1.5%.
- Require a stable `MISMATCH` for a short bounded period before changing to safe
  recovery.
- Do not show the same notice more than once per stable resize generation.

### Scoring multiple profiles

Rank candidates by a weighted score using dimension error, aspect error,
measurement compatibility, and arrangement. Require the winner to be
meaningfully better than the runner-up. A score tie or near-tie is
`AMBIGUOUS`, not permission to select the most recently used setup.

The matcher should be a pure Lua module with table inputs and outputs so its
edge cases can be covered without a running client.

## Applying remembered geometry

When a manual profile matches, derive the active game and workspace rectangles
from its normalized values and the current stable canvas. This lets a 4000x2560
reference continue to work at 3994x2556 without moving the intended seam by a
large amount.

Do not overwrite the reference dimensions after a successful fuzzy match.
Provide an explicit **Remember Current Window** or **Update Remembered Canvas**
action. That action should preview the old and new dimensions before saving.

Keep the currently saved seam ratio canonical. A fuzzy match may scale the seam
to the current canvas, but it must not feed the rounded result back into the
saved ratio. This prevents repeated rounding and resize drift.

Changes that affect protected Blizzard UI must continue to respect combat and
hardware-event restrictions. If a resize is accepted during combat, update only
safe addon-owned geometry immediately and defer protected HUD recovery until
combat ends or the player uses the existing recovery action.

## Alignment limits and visual confirmation

Addon Lua cannot observe the native window origin. A window can have the exact
remembered width and height while being shifted relative to the physical
monitor seam. Automatic validation can therefore confirm only the canvas size
and shape.

Add an optional alignment overlay containing:

- The expected physical seam line.
- Mainhand and workspace outlines.
- Corner or edge markers that make overscan and border offsets visible.
- The current confidence state and measured dimensions.
- **Looks Correct**, **Adjust Seam**, **Remember Current Window**, and **Use Safe
  Single Screen** actions.

Show the overlay automatically only for `CLOSE`, `AMBIGUOUS`, and explicitly
requested diagnostics. A `MATCH` should remain quiet. A shifted same-size
window is fundamentally undetectable, so settings and diagnostics must explain
that limitation without repeatedly warning ordinary users.

The existing seam guide should be extended rather than creating an unrelated
second overlay system.

## User experience flows

### First manual setup

1. The user selects Windowed mode in WoW and sizes the native window.
2. Offhand waits for stable geometry.
3. The user selects side-by-side, stacked, or single-display split.
4. The user selects Mainhand side and adjusts the seam and game rectangle.
5. Offhand shows the alignment overlay.
6. **Looks Correct and Remember** saves a manual canvas.
7. The remainder of onboarding continues without requiring Companion topology.

### Returning session with a match

- Reuse the remembered normalized layout silently.
- Restore normal workspace and Mainhand state.
- Record the match result in `/offhand diag`.
- Do not modify the remembered reference.

### Returning session with a close match

- Reuse the normalized layout provisionally.
- Show one non-modal notice after startup settles.
- Offer **Looks Correct**, **Adjust**, and **Use Safe Screen**.
- Do not block ordinary gameplay or reopen the full onboarding wizard.

### Major mismatch or single-display launch

- Preserve all dual-screen positions in SavedVariables.
- Use safe single-screen geometry for the current session.
- Keep important windows reachable.
- Offer the nearest remembered setup, a new calibration, or an intentional
  single-screen session.
- Never convert the dual-screen profile into a single-screen profile
  automatically.

### Display returns during the session

- Wait for dimensions to settle again.
- Re-evaluate remembered canvases.
- Offer restoration without automatically moving protected UI.
- If an exact Companion topology becomes current, follow the selected
  geometry-source preference.

### Profile reset and deletion

- Resetting an Offhand UI profile must not silently delete account-wide manual
  canvas signatures.
- Provide a separate **Forget Remembered Canvas** action with the exact target
  name and dimensions.
- Forgetting a canvas must not delete saved frame positions.
- A full settings reset should state whether canvas signatures are included.

## Companion close and tray behavior

Change the Companion's native close behavior independently from manual canvas
memory:

- Title-bar X exits by default.
- Add **Keep Companion running in the system tray when closed**, disabled by
  default and stored in `OffhandConfig.ini`.
- The explicit **Minimize to Tray** button should always minimize for the current
  run, even when close-to-tray is disabled.
- **Exit Companion** must always exit.
- If auto-span is enabled and the user exits, explain once that automatic span
  and active recovery stop. Do not silently override the exit.
- Decide an explicit migration for existing users. Preferred behavior is a
  one-time choice instead of silently opting every existing installation into
  background residency.
- Keep the tray icon and its controls available only while the process is
  actually running.

Automated Companion tests must cover fresh defaults, legacy settings without
the new key, explicit opt-in, title-bar close, Minimize to Tray, explicit exit,
and auto-span interaction.

## Supported setup matrix

### Primary resolution classes

The matcher and normalized geometry must not hard-code only known presets. Test
at least these representative surfaces:

| Setup | Representative canvas |
| --- | --- |
| Dual 1080p landscape | 3840x1080 |
| Dual 1200p landscape | 3840x1200 |
| Dual 1440p landscape | 5120x1440 |
| Dual 4K landscape | 7680x2160 |
| 1440p plus 1080p landscape | 4480x1440 bounding canvas |
| 4K plus 1440p landscape | 6400x2160 bounding canvas |
| 3440x1440 ultrawide plus 1080p | 5360x1440 bounding canvas |
| 3440x1440 ultrawide plus 1440p | 6000x1440 |
| 1080p portrait plus 1080p landscape | 3000x1920 |
| 1080p portrait plus 1440p landscape | 3640x1920 |
| 1440p portrait plus 1440p landscape | 4000x2560 |
| 1440p portrait plus 3440x1440 ultrawide | 4880x2560 |
| Single 21:9 manual split | 2560x1080 and 3440x1440 |
| Single 32:9 manual split | 3840x1080 and 5120x1440 |
| Single 32:10 manual split | 3840x1200 |

The dimensions above describe bounding surfaces, not proof that every pixel is
on a visible monitor. Exact monitor rectangles remain unavailable in manual
mode.

### Arrangement and platform cases

Test each applicable resolution class across:

- Mainhand left and right.
- Mainhand top and bottom.
- Aligned tops, aligned bottoms, centered vertical offsets, and asymmetric
  offsets.
- Negative Windows desktop coordinates.
- A physical gap between monitors.
- Taskbar on each edge, taskbar auto-hide, and differing title-bar dimensions.
- Windows scaling at 100%, 125%, 150%, 175%, and mixed per-monitor DPI.
- Window moved without resizing, which must remain documented as unobservable.
- Resolution or orientation change while WoW is running.
- Display sleep, disconnect, reconnect, dock, and undock.
- Alt-Enter or a switch to full-screen/windowed-fullscreen and back.
- Graphics reset, client crash, normal shutdown, `/reload`, relog, and cold
  launch.
- Retail, current Classic branches, Forever, and supported legacy clients.
- Wine/Proton under XWayland and supported window managers. Native Wayland
  behavior remains separately qualified by live evidence.
- Multiple WoW processes, where each addon instance sees only its own canvas.
- Very high resolutions and GPU surface limits. Do not claim 8K-class support
  without live renderer evidence.

### Settings and addon lifecycle cases

Also validate:

- UI scale minimum and maximum.
- Render scale below and above 100% where supported.
- Localization expansion in every new notice and action row.
- Existing profiles created before the manual-canvas schema.
- Profile copy, rename, switch, and reset.
- Malformed, partial, stale, and future-version manual-canvas records.
- Companion topology becoming available while manual mode is selected.
- Stale generated topology while a valid manual profile exists.
- Combat during a display-size change.
- Cinematic, movie, loading screen, pet battle, and Edit Mode transitions.
- Controller-style Blizzard UI and ConsolePort ownership.
- Saved positions near every canvas edge and inside a mixed-height physical void.

## Diagnostics and supportability

Extend `/offhand diag` with concise machine-readable fields:

```text
geometrySource=manual
manualCanvas=Desk
manualCanvasState=MATCH
reference=4000x2560
live=3994x2556
widthError=0.15%
heightError=0.16%
aspectError=0.01%
measurementMode=PHYSICAL_CANVAS
stable=yes
exactAlignment=unknown
```

Diagnostics should also report the runner-up profile and score for an ambiguous
match, the settlement timeout for `UNSTABLE`, and why a malformed record was
rejected. Normal chat output should remain short and player-oriented.

Add an optional debug capture that records only bounded recent dimension
samples. Do not run an unbounded ticker or log every frame.

## Implementation stages

### Stage 0: evidence and characterization

- Complete the independent Forever bridge validation first.
- Record repeated manual-resize dimensions from representative setups.
- Characterize `GetPhysicalScreenSize()`, `UIParent` aspect, UI scale, render
  scale, and resize events on each supported client family.
- Record how Windows borders, taskbars, and mixed DPI affect observed client
  dimensions.
- Establish matcher thresholds from that evidence.

Deliverable: a short evidence table in `tests/QA-notes.md`; no behavior change.

### Stage 1: pure data and matcher foundation

- Add versioned manual-canvas validation and migration helpers.
- Add the pure candidate scorer and confidence states.
- Add malformed-data and multi-profile ambiguity tests.
- Add normalized rectangle conversion tests.
- Keep the feature disconnected from runtime behavior initially.

Deliverable: tested internal API with no user-facing activation.

### Stage 2: stable observation and diagnostics

- Add the bounded stable-canvas observer.
- Add generation cancellation and hysteresis.
- Expose observations and match results through `/offhand diag`.
- Confirm no repeated hooks, timers, or frame writes after `/reload`.

Deliverable: read-only runtime evidence.

### Stage 3: remembered manual application

- Add first-time save, explicit update, selection, rename, and deletion.
- Apply normalized geometry only after a stable unique match.
- Add safe mismatch recovery without clearing positions.
- Add geometry-source preference and manual relinquish behavior.
- Preserve existing exact Companion behavior unchanged in this stage.

Deliverable: addon-only remembered calibration behind a beta flag.

### Stage 4: alignment and recovery experience

- Extend the existing seam guide into the alignment overlay.
- Add quiet `CLOSE`, `AMBIGUOUS`, and `MISMATCH` notices.
- Integrate the workflow into onboarding and settings.
- Localize all player-facing text and test scale extremes.

Deliverable: complete beta user experience.

### Stage 5: Companion lifecycle preference

- Add the opt-in close-to-tray preference and migration prompt.
- Make title-bar close exit by default.
- Update help, portable documentation, website guidance, Store screenshots or
  text, and Companion preference tests.
- Keep this release unit separable from addon matcher work.

Deliverable: non-resident Companion behavior by default.

### Stage 6: release validation and rollout

- Run all Lua suites, Companion tests, manifest validation, and localization
  checks.
- Complete the live matrix below on source and packaged candidates.
- Release as beta with diagnostics requested from uncommon client/reporting
  modes.
- Promote only after cold-launch, mismatch recovery, and rollback paths pass.

## Automated test requirements

Add table-driven tests for:

- Pixel differences from 0 through the match, close, and mismatch thresholds.
- Positive and negative width/height drift independently.
- Aspect-preserving and aspect-changing resize.
- Reference dimensions at 1080p, 1440p, 4K, ultrawide, and mixed-height sizes.
- Rounding of normalized seams without cumulative drift.
- Two equally plausible profiles.
- A clearly superior candidate.
- One-monitor current size against a remembered dual-monitor canvas.
- Side-by-side versus stacked disagreement.
- Physical-canvas and aspect-fallback measurement modes.
- Transient zero dimensions and alternating startup sizes.
- Debounce generation cancellation and hysteresis.
- Resize during combat and deferred protected recovery.
- Invalid rectangles, NaN-equivalent values, excessive profile counts, and
  future schemas.
- Reset and deletion preserving unrelated SavedVariables.
- Existing users with no manual-canvas table.

Existing exact-topology, wizard, profile, viewport, persistence, and recovery
tests must continue to pass without changing their meaning.

## Minimum live acceptance matrix

For each selected representative topology:

1. Confirm a manual canvas and finish calibration.
2. `/reload` at the same size.
3. Cold-launch with an exact or nearly exact size.
4. Cold-launch after independently changing each window edge by several pixels.
5. Test the outer edge of `MATCH` and `CLOSE` tolerance.
6. Launch on one display and verify safe recovery without position loss.
7. Restore the remembered span and verify the prior workspace state returns.
8. Move the same-sized native window away from the physical seam and confirm
   diagnostics say alignment is unknown rather than exact.
9. Change UI scale without changing the native canvas.
10. Change display resolution or orientation and verify a real mismatch.
11. Resize during combat, leave combat, and verify deferred recovery.
12. Verify no new Lua error, blocked action, taint evidence, duplicate timer, or
    repeated notice.

The minimum release sample should include:

- Equal-height dual landscape.
- Mixed-resolution dual landscape.
- Portrait workspace plus landscape Mainhand.
- Stacked displays.
- Single super-ultrawide split.
- One client that reports the complete physical canvas normally.
- One supported client that requires aspect fallback.
- Windows mixed-DPI coverage.
- Wine/Proton coverage where claimed.

## Release gates

- The Forever bridge decision is recorded separately and is not bundled into
  the manual-canvas matcher merely for convenience.
- No pixel-exact comparison is used for remembered manual canvases.
- No fuzzy result is labeled exact.
- A major mismatch cannot strand required UI or erase saved positions.
- A shifted same-size window is documented as unobservable.
- Existing Companion exact topology remains behaviorally unchanged unless the
  user selects manual ownership.
- Existing users migrate without deleting SavedVariables.
- Title-bar close behavior and close-to-tray migration are explicit and tested.
- Automated, live, and packaged evidence levels are recorded separately.

## Explicit non-goals

- Resizing, moving, or removing borders from the native WoW window in Lua.
- Discovering Windows monitor identities or native window X/Y from the addon.
- Treating a canvas-size match as proof of physical display alignment.
- Requiring Battle.net launch arguments.
- Automatically relearning dimensions on every launch.
- Automatically selecting between ambiguous saved setups.
- Expanding this work into general multi-region workspaces. That remains owned
  by `docs/CUSTOM-WORKSPACE-REGIONS-IMPLEMENTATION-PLAN.md`.
