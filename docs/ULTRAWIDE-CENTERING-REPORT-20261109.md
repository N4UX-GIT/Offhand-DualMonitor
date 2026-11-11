# Single-monitor ultrawide centering report, 9 November 2026

## Report and evidence

The reporter identifies Companion 2.1.5, build 2.1.5.1, Windows 10.0.19045.0,
Microsoft Store settings storage, and one 5120 x 1440 display at 100% scaling.
They say spanning moves a previously centred WoW window to the left and uses
roughly two-thirds of the screen. Add-on version and WoW client/build are not
independently established. Updating both components that morning is reported.

The editor screenshot explicitly selects the one-monitor custom layout with
combined width 3790, workspace width 1181, Left anchor and Right game side.
Its preview and monitor overlay both show the workspace on the left, game in
the middle and 1330 pixels of free desktop on the right. The screenshots are
editor/overlay evidence, not post-apply viewport diagnostics. An incomplete
placement guide is visible underneath the overlay; this does not establish the
reporter's final setup state.

Source examined: published `v2.1.5` / `v2.1.5-beta.28`, merge commit `dc5e9eb`.
Shared knowledge status and workspace guidance were consulted. Cached game
source is review-due; no new WoW API assumption or live-client claim is made.

## Findings

The production planner gives these physical monitor coordinates:

| Area | Left | Width | Right (exclusive) |
| --- | ---: | ---: | ---: |
| Combined native WoW window | 0 | 3790 | 3790 |
| Offhand workspace | 0 | 1181 | 1181 |
| Mainhand game | 1181 | 2609 | 3790 |
| Free desktop | 3790 | 1330 | 5120 |

The occupied window is about 74% of the display and deliberately left anchored.
The planned game centre is 2485.5, only 74.5 pixels left of monitor centre 2560.
The native window includes both game and workspace; its centre is not the same
as the game's centre. The standard single-display equal-half checkbox does not
override an enabled custom partial plan.

PartialRegionSelection and PartialRegionOverlay support only Left/Right edge
anchors, including drag-to-edge and arrow-key selection. PartialSpanDialog lists
only those anchors. There is no arbitrary horizontal-position or Centre anchor
in this editor. Centre anchoring the entire combined window would not centre
its game area when a workspace occupies one side.

There is no demonstrated disagreement between the supplied selection, overlay
and planner, nor a displayed DPI/monitor-ID mismatch. This does not rule out a
separate failure after Span on the reporter's machine.

If the game fills all 3790 pixels, its centre is 1895, substantially left of the
physical monitor centre. The real Viewport:Apply code deliberately resets to the
full combined canvas when Offhand is disabled or the topology is not accepted.
An unreloaded topology file or unfinished/disabled setup is therefore a plausible
explanation for a larger game-view shift. It is a hypothesis, not a confirmed
reporter diagnosis. The existing Beta 28 Next activation correction should not
be replaced with automatic enabling on ordinary login/span recognition.

## Existing configuration for a centred 16:9 game

On 5120 x 1440, keep this same editor and set:

- Combined width: **3840**.
- Workspace width: **1280**.
- Anchor combined area to: **Left**.
- Game side within area: **Right**.

This places the game at x=1280 with size 2560 x 1440, exactly centred on the
physical monitor. Offhand uses the left 1280 pixels and desktop remains free on
the right 1280 pixels. The complete WoW window remains left anchored by design.
Use Save plan, Span WoW Now and manual `/reload`, then finish the in-game
guide/calibration if incomplete. Preserve SavedVariables and existing HUD edits.

For actual workspaces on both sides, the existing Flexible Layout preset
**Game between two workspaces** produces a centred 2560 x 1440 game and two
1280 x 1440 workspaces on this monitor. It uses both sides for Offhand rather
than leaving one side as desktop.

## Verification and next evidence

Expanded the existing production partial-topology fixture to cover the exact
reported 3790/1181 plan and the 3840/1280 centred-game plan, with the dashboard
equal-half setting both enabled and disabled. Both preserve the expected custom
geometry. The existing flexible centred-game preset also passes.

The actual Companion writer emits both plans, and the actual Lua consumer
accepts the generated files. Simulated Viewport:Apply checks cover enabled and
disabled state at three UI scales in standard and Forever policy branches:
enabled applies the workspace offset; disabled fills the combined window.
All existing partial/secondary clipping, persistence and stale-canvas cases pass.
This is production planner/writer plus mocked Lua viewport evidence, not live
WoW or Windows 10 acceptance. No installed files, preferences, window placement
or published release artifacts were changed.

Requested reporter follow-up: WoW client/build and `/offhand diag` text after
Span WoW Now and `/reload`, plus whether guide/calibration completed. The enabled
state, actual canvas dimensions, topology source/status and viewport-bounds match
will distinguish expected outer-window placement from an unapplied game region.

A useful UX follow-up is a **Centre game on monitor** preset with explicit game,
workspace and free-desktop dimensions. It should not silently change existing
plans or imply that centring the combined window centres the game. No such new
runtime behavior was implemented or released in this investigation.

## Reporter diagnostics received

The next screenshots identify Forever 1.60.1 build 70862, interface 16001,
Offhand 2.1.5-beta.28, paired Companion 2.1.5, keyboard/mouse UI. They show:

- Enabled=0, Setup=0, Spanned=0 and Source=Single-screen.
- Companion Writer=not-recorded and version Status=unavailable, rather than a
  demonstrated incompatible version.
- Topology state=ABSENT, loaded=no, schema=none, expected=unknown x unknown.
- Current physical client size 2502 x 1401, not the selected 3790 x 1440 canvas.
- Workspace=(0,0 0x0). Generated HUD=none, Geometry=none.
- Native map owner Offhand; LeatrixMaps/OpenMap absent in this capture.
- Viewport bounds check PASS, which validates the current single-screen fallback,
  not the intended custom span. Forever persistence source SavedVariables with
  bridge absent/session none does not by itself establish a persistence fault.

This confirms that setup is incomplete and Offhand's game/workspace layout is
inactive at capture. It also confirms no Companion topology is loaded. Finishing
calibration alone is not the first step while the expected span/handoff is absent.
The capture does not establish whether it preceded Span/reload, followed Restore,
or reflects a failed/wrong-path handoff. Do not attribute ABSENT to incomplete
calibration alone: successful Companion span writes the bridge before resizing,
and a subsequent add-on reload must read it from the active client's installation.

Recommended sequence: ordinary Windowed mode, verify Companion recognizes this
Forever installation, save/apply the desired plan with Span WoW Now, then continue
the in-game guide's Window is positioned / Reload UI / Confirm placement sequence.
Complete calibration and the supported HUD/reload steps afterward. Preserve saved
settings and existing HUD work. For the centred 16:9 layout use 3840 combined,
1280 workspace, Left anchor, Right game as above.

Expected follow-up after completed setup: Enabled=1, Setup=1, Source=Companion,
Spanned=1, topology loaded/READY, physical canvas matching the applied plan and a
nonzero workspace. If topology remains ABSENT after a successful Span and reload,
inspect the Companion Activity Log, verified client/add-on installation path and
span/write result instead of resetting settings or repeating calibration blindly.

The report also supports a guidance follow-up: explicitly distinguish moving the
combined window from activating/calibrating the add-on's game viewport on first
setup. No automatic enabling or gameplay input should be introduced to hide that
required user action.

## Resolution

The owner relayed the reporter's confirmation that completing setup resolved the
issue. Close this report as incomplete first-time setup, resolved by the existing
guide/calibration flow. This is reporter-confirmed resolution, not an independently
observed post-setup diagnostic capture. No Companion geometry fix, runtime change,
new package or release is required for this report. The planner/bridge regression
cases remain useful characterization coverage. Clearer guidance distinguishing
native spanning from first-time add-on activation/calibration remains a separate
UX improvement, not an open failure in this resolved case.
