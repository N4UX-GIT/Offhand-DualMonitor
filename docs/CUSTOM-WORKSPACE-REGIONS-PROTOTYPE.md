# Initial custom workspace region prototype

Update, 2 November: prototype 2 adds a visual desktop selection overlay to the
same single-monitor geometry. Prototype 1 and its live game evidence below remain
immutable. See the visual-editor section for the new workflow and evidence.

2 November 2026. Explicitly authorized initial runtime implementation on
`codex/custom-workspace-regions`, based on prepared Companion source `a4684a1`.
This overrides the previous deferral for stage 0 only. Unpublished; schema 2,
multiple workspaces and general discontiguous regions remain outside this slice.

## Visual desktop editor (prototype 2)

`Custom region...` now includes **Select area on monitor...**. The selected
monitor receives a translucent, full-monitor Companion overlay showing workspace,
game and free desktop areas in physical pixels. Drag the internal divider to
resize the workspace, or the outer divider to resize the occupied width while
retaining the workspace width. Drag the occupied area to snap between the left
and right monitor edges. **Swap game and workspace** reverses their order.
Left/Right keys select the occupied monitor edge. Enter accepts the selection;
Escape or Cancel discards it. The overlay remains reachable through Alt+Tab.

**Use selection** updates only the numeric editor's pending values and enables
custom mode. **Save plan** performs the existing validated atomic preference
write. **Span WoW Now** remains the separate native apply action. Cancelling the
numeric editor also discards a previously accepted visual selection.

This is a visual editor for the already-tested schema 1 slice, not arbitrary
rectangles or multi-monitor regions. It retains full monitor height, edge
anchoring, one selected display, minimum physical widths and manual-only apply.
The native span, clipping, addon protocol and saved-frame formats are unchanged.
The overlay never reads screenshots, manipulates WoW or saves preferences itself.

Desktop QA on the 2560x1440 primary monitor at 100% scaling passed workspace
divider drag (640 to 800), Escape cancellation retaining 640 in the numeric
editor, occupied-width drag (2240 to 2080), drag to the right monitor edge,
game/workspace swap, accept back to numeric values, and Save plan. The persisted
result was occupied 2080, workspace 640, edge RIGHT and game LEFT. Before Save,
disk preferences remained at the original 2240/640/LEFT/RIGHT values. No game was
launched. Companion exited normally and the original INI was restored exactly
and hash-verified. Private evidence and before/after preferences remain under
the ignored `dist/live-qa-overlay-editor-*` directory.

An initial borderless overlay was omitted from desktop window discovery. Giving
it its own taskbar/Alt+Tab entry made it independently selectable; Escape was
then verified on that window. Enter/Left/Right/Escape handling is explicitly
tested in the in-process overlay fixture, including acceptance independent of
focused buttons. The final Enter override has automated evidence; it was added
after the desktop gesture run.

Production model gesture tests cover both edges/sides, minimum workspace/game
widths, monitor-boundary clamping, drag-back behavior and round trips through the
actual topology planner. Preference/layout checks pass at 100/125/150/200% scale,
including the new visual-selection action. The partial topology, native rollback
(1269 assertions per x64/x86 build) and recovery suites pass. Live mixed-DPI and
offset-secondary overlay placement, hotplug during editing and final packaged
game smoke testing remain open. The earlier live game runs used prototype 1.

## Implemented workflow

Open **Custom region...** in Companion. Choose one display, enable the
experimental custom region, set occupied WoW width and workspace width in
physical pixels, select the occupied monitor edge and game side, and review
the game/free widths. **Save plan** atomically saves settings without resizing
WoW. **Span WoW Now** applies the plan. Select **Use Companion** in the addon's
Window Setup; reload a character UI that was already loaded when geometry changed.
**Restore Window** returns to the remembered ordinary window.

The example `5120 = WoW 4080 + free 1040`, with workspace 640 and game 3440,
is supported by the production planner. The native window bounds contain only
the occupied width. Its clipping region uses the actual game/workspace
rectangles, excluding reserved pixels. Existing transactional rollback and
schema 1 `SPLIT_ULTRAWIDE` handoff are reused.

Settings retain stable monitor identity and resolution, widths, edge and side.
Display renumbering and negative origins are supported. A changed resolution,
different/missing monitor, multi-display selection or invalid dimensions blocks
application until reviewed. Disable custom region in its editor to return to
the existing display workflow; select two displays or enable equal-half split
as appropriate. Existing equal-half dimensions and two-display behavior remain.

Custom mode disables auto-span and does not arm graphics-reset recovery. Apply
manually again after a graphics reset. Existing modes retain their recovery.
No tooltip behavior, saved-frame schema or addon protocol changed.

## Guardrails and limits

Initial physical-pixel guardrails are workspace at least 480, game at least 960,
height at least 600, and dimensions at most 32768 within the selected monitor.
These are input guardrails, not universal readable panel minimums. Narrow panels
may not fit; use Mainhand for such panels. In particular, the existing talents
adapter may shrink substantially. Generic panels are not automatically scaled.

## Automated evidence

- Production planner: both occupied edges, both game sides, negative origins,
  stable identity through renumbering, malformed/unsafe preferences and
  equal-half fallback.
- Native clipping: actual production region builder includes both occupied
  corners and excludes every tested outside boundary.
- Generated C# topology to actual Lua reader: 64 acceptance/rejection cases;
  32 metric/position round trips.
- All 64 Lua suites pass. Preferences/dashboard/editor layouts pass at
  100%, 125%, 150% and 200%. Native restore rollback passes 381 assertions on
  each of x64/x86; production recovery passes 121. Ordinary color/DPI passes
  228 assertions per architecture.
- Scoped Classic/Retail/Forever recovery configurations compile and pass 112
  assertions each; diagnostics configurations pass 232 per architecture.
  All six TOC manifests, runtime paths, XML and Lua 5.1 syntax validate.

## Exact review build

- Source commit `3f5bf0133672f83f8daeb61bb9d8798e6d594549`, clean tracked source at build.
- Directory `dist/custom-workspace-regions-prototype-1`.
- EXE SHA-256 `D6ADE042967D0135E7FE4E3929D36CDB79AF2516135B3E03E350FF0596112628`.
- ZIP SHA-256 `E55862AD1C3722EDE42E629850E79200C1182D89080D1AD227E0DBB7B4CB6AB2`.
- Build command: `./scripts/New-CompanionReleaseCandidate.ps1 -OutputDirectory <fresh-directory> -CustomRegionsPrototype`.
- Unsigned validation MSIX structure/startup/capability and embedded EXE parity
  passed with identity `N4UX.OffhandCompanion.Validation`, version `1.0.0.0`.
  It was not installed or submitted and reserves no production Store version.

This prototype retains public/file identifiers `2.1.3-beta.1` / `2.1.3.1`;
distinguish it by directory and hash. Prepared revision 4 and canonical public
Beta 20 artifacts are unchanged. Nothing was published.

## Retail live acceptance, 02:34-03:02 CET

Retail `12.1.5.70688`, installed addon `2.1.2-beta.24`, protocol 1; no addon
deployment. Same approved idle level-one Hunter in Coldridge Valley. No gameplay,
graphics-option changes or native Edit Mode layout creation. Mainhand monitor
`2560x1440` at `(0,0)`, SDR, Windows scaling 100%.

Configured through the actual editor: occupied 1920, workspace 640, game 1280,
occupied left edge, game on right. This leaves 640 physical pixels outside WoW.
The motivating physical 5120-wide monitor is unavailable here; its exact
4080/640/3440 combination is automated coverage, not live acceptance.

| Case | Result |
| --- | --- |
| Edit and Save plan | Pass: UI preview showed `WoW 1920 = workspace 640 + game 1280; free 640`; settings saved atomically. Native before/after remained `(215,0) 2130x1392`, bordered, no region |
| Manual apply at 02:37:28 | Pass: actual outer/client `1920x1440` at `(0,0)`, borderless style `140B0000`, rectangular region type 2; topology exact game `(640,0,1280,1440)`, workspace `(0,0,640,1440)` |
| Reserved application space | Pass: Companion moved entirely to `(1967,298) 526x788`, outside WoW and inside the free monitor band; its activity controls remained visible and interactive with WoW alongside |
| Direct geometry source | Existing manual preference temporarily switched via the addon's `SetGeometryPreference("AUTO")` helper and viewport Apply for QA; the user's original profile is restored below |
| First reload | Pass: returned in-world on the partial surface; optional stale HUD-layout regeneration prompt was dismissed |
| Diagnostic at 02:45:22 | Pass: `companionTopology=true`, `topologyStatus=READY`, `viewportMatches=true`, physical `1920x1440`; WorldFrame approximately `(640,0) 1280x1440` within floating-point tolerance |
| Character panel | Existing saved placement fits entirely in the narrow workspace. Opening and a second reload at 02:48 retained the panel and placement. A title-drag attempt did not move it, so live dragging is not accepted by this run |
| First Restore at 02:52:02 | Pass: exact original outer/client/style and no clipping |
| Both processes restarted | Pass: custom settings and selected monitor survived; auto-span remained off/disabled, WoW stayed ordinary until manual apply |
| Second apply at 02:56:43 | Pass: same exact native partial bounds/client/region after cold launch |
| Cold login at 02:57:52 | Pass as a visible smoke check: partial workspace and Character panel reopened. The first diagnostic remains the measured geometry evidence; no fresh second diagnostic claimed |
| Final Restore at 03:00:47 | Pass: original `(215,0) 2130x1392`, normal style `14CF0000`, no clipping |

Native readbacks used a separate read-only observer; actual input used Companion
and game UI. Custom mode did not arm graphics-reset recovery. Fresh BugGrabber
comparison against the preserved previous baseline differs only in the session
counter, 333 to 337; no new error records or error counters changed. No visible
Lua error appeared. This does not establish combat/taint safety.

Both sessions exited normally and Companion closed. Nine original files,
including the full account/character profiles, config, generated bridges and
existing backups, were restored exactly and hash-checked after process exit.
Battle.net remains open. Private native JSON, activity logs, before/after files
and cleanup evidence are ignored under
`dist/live-qa-custom-regions-20261102-023329`.

## Follow-up live QA, 2026-11-02 07:28 to 07:43 CET

Same immutable prototype executable, Retail build and installed addon pairing as
above. The original nine configuration/profile/bridge files were backed up before
replaying the earlier QA geometry. No addon source was deployed.

- Character-frame diagnostics reported movable and Offhand-hooked. Dragging from
  physical `(280,510)` to `(340,280)` moved the panel from approximately `(56,492)`
  to `(116,262)`, entirely within the 640-pixel workspace. The earlier attempt
  started higher on the title bar. This successful gesture resolves the focused
  drag follow-up without a runtime code change; it does not prove every title-bar
  pixel is a drag surface.
- The moved position survived `/reload` at 07:38. Before/after screenshots and
  the closed-session saved workspace position were retained as private evidence.
- Restore, disable custom, select the existing equal-half split, and manual Apply
  at 07:40:27 produced native `(0,0) 2560x1440`, style `140B0000`, region type 2,
  with game/workspace widths 1280/1280. Ordinary graphics recovery armed after
  stable verification. Disabling custom alone requires selecting a valid ordinary
  plan, as documented above.
- Restore, reopen the editor, and re-enable custom retained the saved 1920/640
  dimensions. Saving did not resize WoW. Manual Apply at 07:42:02 returned native
  `(0,0) 1920x1440`, style `140B0000`, region type 2; custom mode again reported
  automatic graphics recovery disabled.
- Final Restore returned `(215,0) 2130x1392`, style `14CF0000`, no clipping.
  Both processes exited normally. All nine original files were restored and
  hash-verified after zero QA processes remained. BugGrabber differs only in its
  session counter, 337 to 339, with no new error records or counter changes.

Private evidence: `dist/live-qa-custom-drag-20261102-072815`. Optional native HUD
regeneration was not invoked; its acceptance limitation remains unchanged.

The production topology regression suite now also checks custom to equal-half,
custom to two-display, return to custom, rejection of multiple selected displays
while custom is enabled, and rejection of changed physical monitor resolutions,
across both edges/sides and negative origins. It passed together with the existing
64 C# to Lua acceptance/rejection cases and 32 persistence/metric round trips.

## Anniversary live QA, 2026-11-02 08:44 to 08:59 CET

Same immutable prototype 1 executable (`D6ADE042...6112628`), Anniversary
`2.5.6.70577`, installed addon `2.1.2-beta.24-tbc-test.11`, protocol 1. No addon
deployment. Launcher-selected existing level-69 Druid on Spineshatter, idle in
Terokkar Forest; no gameplay or graphics-option changes. Display remained
2560x1440 at `(0,0)`, SDR and 100% Windows scaling.

The user's current custom plan was already 2240 occupied, 640 workspace,
1600 game, occupied left edge and game right, leaving 320 monitor pixels free.
It was backed up and used as-is. No manual geometry preference override was
needed for the installed Anniversary profile.

| Case | Result |
| --- | --- |
| Before apply | Native ordinary `(215,0) 2130x1392`, style `14CF0000`, no region |
| Manual apply at 08:51:31, before world entry | Pass: Companion and independent read-only observer agree on native outer/client `2240x1440` at `(0,0)`, style `140B0000`, rectangular region type 2. Automatic custom recovery remains disabled |
| World entry | Pass: workspace and game seam visible; optional stale HUD regeneration prompt dismissed |
| `/offhand diag`, persisted by reload | Pass: `companionTopology=true`, `topologyStatus=READY`, version status `MATCH`, `viewportMatches=true`; physical `2240x1440`; WorldFrame approximately `(640,0) 1600x1440` within floating-point tolerance |
| Character panel | Pass: opened entirely within workspace; drag from `(430,573)` to `(270,330)` moved it approximately 160 pixels left and 243 pixels up |
| `/reload` at approximately 08:53 | Pass: returned in-world, panel reopened at the moved position. Saved position references the new canvas dimensions |
| Final native Restore | Pass: exact original `(215,0) 2130x1392`, style `14CF0000`, no clipping |
| Cleanup | Pass: normal game/Companion exits; 14 original config/profile/bridge/error-store files restored and hash-verified after zero test processes remained; Battle.net left open |

No visible Lua error appeared. Both backed-up BugGrabber stores were unchanged,
but BugGrabber and BugSack are disabled for this character, so this run does not
provide a fresh error-store audit. Protected actions, combat/taint safety, native
HUD regeneration, cold relaunch and graphics-reset behavior were not exercised.
After native Restore the loaded addon still needed geometry reconciliation;
this run accepts the native restoration, not a fresh ordinary-window viewport.
The original profiles were restored after exit.

Private evidence: `dist/live-qa-custom-anniversary-20261102-084438`, including
native readbacks, exact generated bridge, Companion log, drag/reload screenshots
and before/after profile files. These contain private account/chat metadata and
remain ignored. Shared knowledge routing returned a runtime-verification gap;
the exact installed source and live diagnostic supply this limited acceptance.

## Initial implementation confidence and remaining release scope

Follow-up native failure coverage: `tests/companion-span-rollback.ps1` now uses
the production custom planner, topology writer and clipping-region builder in
80 synthetic hidden-window rollback cases per architecture. Each combination of
occupied edge, game side, zero/negative origin and prior clipping/no clipping is
rolled back after topology write, style change, clipping change, resize or final
bounds readback. Exact original file bytes, bounds, style and clipping must be
restored; repeated rollback must remain harmless. Both x64 and x86 passed 1,269
total assertions each, including the existing ordinary rollback cases.

These native fixtures use a 2560x1440 monitor model with a 1920/640 occupied and
workspace width, matching the live geometry. An initial 4080-wide hidden
WinForms fixture was constrained to 4020 by this desktop's native maximum tracking
size. It was replaced with the smaller fixture rather than treating that
WinForms behavior as WoW evidence. The 5120/4080/640 planner, generated topology
and clipping coverage remains in the separate partial-topology suite. These
synthetic tests do not inject a failure into a running WoW client.

The initial contiguous single-display workflow works on the recorded Retail pairing:
editor, validated settings, native apply with reserved app space, direct schema 1
viewport, panel dragging and persisted placement, reload, fitting-panel reopen,
process restart, switching to/from the ordinary equal-half mode and Restore. The existing
addon required no runtime changes for this path.

The same artifact also passed the targeted Anniversary apply, direct viewport,
panel drag/reload persistence and native Restore sequence above. Retail retains
the broader process-restart and mode-transition evidence.

Broader release acceptance still includes other clients, the physical 5120-wide
monitor, live both-edge/game-side combinations, mixed DPI, hotplug, actual WoW
failure injection, protected actions, fresh HUD generation and the wider panel
matrix. The existing HUD diagnostic reported stale generated geometry from the
user's prior layout; its optional regeneration was deliberately not invoked.
Use the existing HUD setup/recovery flow when adopting new geometry. Do not
claim all HUD controls fit based solely on the WorldFrame PASS.

The 640-pixel example does not accept arbitrary oversized panels or talents
readability. Schema 2,
multiple regions and automatic custom-region recovery are future work.

## Evidence routing

Shared knowledge status was consulted first. The broad workspace search reported
a stale index, and earlier native Companion routing supplied no matching runtime
evidence. Decisions use the local `MonitorSelection`, `SpanClipRegion`,
`PartialSpanDialog`, topology writer and existing Lua viewport/persistence source,
plus the exact automated and Retail observations above. No missing retrieval
result establishes API absence or safety on another client.
