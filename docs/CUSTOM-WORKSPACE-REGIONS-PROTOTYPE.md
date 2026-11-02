# Initial custom workspace region prototype

Update, 2 November: prototype 2 adds a visual desktop selection overlay to the
same single-monitor geometry. Prototype 1 and its live game evidence below remain
immutable. See the visual-editor section for the new workflow and evidence.

Update: prototype 3 adds a full game monitor plus a freely positioned rectangular
workspace on a second monitor, still using the existing schema 1 single-workspace
contract. This is separate from multiple independent workspace regions.

## Trying the current local prototype

Prototype 5 is the latest local build. Prototype 4 revision 2 remains the most
recent exact package with a completed Retail game workflow. Evidence and hashes
for both are kept below; neither is a public release.

1. Close any other Companion normally, then launch the chosen prototype's
   `Offhand.exe`. It uses the existing Companion preferences.
2. Open **Custom region...**, choose the one-monitor or two-monitor layout, and
   use its visual selector or numeric fields. Two-monitor mode keeps the full
   game monitor and one rectangular workspace on the other monitor.
3. **Use selection** accepts the overlay into the pending editor. **Save plan**
   saves settings. **Span WoW Now** applies them to a running Windowed WoW client.
   If the character UI was already loaded, use `/reload` once afterward.
4. Use **Use Companion** in the addon's setup guide when an older manual-canvas
   preference is active. That selection restores AUTO geometry; a manual canvas
   can otherwise override the newly generated Companion plan.
5. **Restore Window** returns the remembered native window. Disable the custom
   mode in its editor and save to return to ordinary display planning. Custom
   plans remain manual-only.

## Save validation follow-up (prototype 5)

Unpublished portable package: `dist/custom-workspace-regions-prototype-5/Offhand.exe`
and adjacent `Offhand-Companion-v2.1.3-beta.1.zip`, built from clean tracked source
`0df1f29ce7240f6e791ace6bd9b652db61037818`.

- EXE SHA-256: `150F56776371E779083D4891D126E8BFF6DBC5BF6A2C48CC3C3EB32D1A8E8898`
- ZIP SHA-256: `4B4252C732953CD8127C24DB3F26B8DA2065889B759E5B20DAA51E7E90D25A9E`

Packaging verified executable parity, archive contents and unchanged frozen
public artifacts. Packaged desktop Save/restart evidence is recorded below;
this build has no new in-game acceptance claim.

Custom-region Save now reads the current display list immediately before atomic
preferences publication and validates enabled custom plans against that snapshot.
The editor still validates pending inputs, and Span retains its separate current-
topology guard. This closes a persistence gap where an editor opened before a
disconnect or resolution change could otherwise save its stale plan.

The production save path's filesystem fixtures cover valid single/secondary
custom saves, missing displays, replacement identity and changed resolution.
Rejected saves preserve existing preferences, do not create an absent target and
remove their pending files. Disabling custom mode remains possible with a display
missing. The dashboard adopts the returned display snapshot only after successful
publication. The topology and preference/layout suites pass.

These are controlled display-snapshot and actual filesystem tests. Physical live
hotplug and mixed-DPI testing remain pending. The shared knowledge query reported
a gap; the local editor, planner and atomic preferences writer are the source
evidence for this change. Earlier packaged live results remain tied to their
original executables.

Desktop QA of the exact prototype 5 executable at 100%/100% scale passed saved-
mode keyboard selection, editing the secondary left offset from 500 to 520, and
Save through the new publication guard. The resulting file retained two-monitor
custom mode with auto-span disabled and left no pending preferences file.
After normal exit and a fresh Companion launch, the editor showed offset 520,
the saved 782x1290 dimensions, and the expected 3480x1640 backing surface.
Companion exited normally again; the exact original preferences were restored
and hash-verified. No game was launched or monitor disconnected during this
desktop check. Private evidence: `dist/live-qa-save-guard-20261102-145002`.

## Layout chooser follow-up (prototype 4)

**Custom region...** now opens an explicit layout chooser showing the saved mode.
Choose **One monitor: game and workspace...** or **Two monitors: full game and
custom workspace...**. Enter defaults to the saved custom mode; Cancel leaves
preferences unchanged. Each editor retains its own explicit Save plan action.
This removes the previous path through the single-monitor editor to reach an
active two-monitor plan, where saving the first dialog would replace that mode.
The single-monitor editor warns when its Save would replace a two-monitor plan.

The chooser and both explicit choices pass automated checks at 100/125/150/200%
scaling. The settings suite passes. Native planning, clipping, protocol and addon
runtime are unchanged; prototype 3's live evidence below remains tied to that
immutable executable. New build and desktop evidence are recorded separately.

The first prototype 4 build exposed a native keyboard-focus issue during desktop
QA: the first button received focus despite a different default button. Revision
2 explicitly focuses the saved mode and adds a regression check for that state.
The first build is superseded and has no acceptance claim.

Use `dist/custom-workspace-regions-prototype-4-revision-2/Offhand.exe` or its
adjacent `Offhand-Companion-v2.1.3-beta.1.zip`. This unpublished package was built
from clean tracked source `f9a8621a371c6e05a2efa6ec22c41a976f85f6db`.

- EXE SHA-256: `3863CAF187833D45B1CEACAFCF35AE0A178C3193DFE489FDC5FF528DDB971621`
- ZIP SHA-256: `354B08855918D6C5E4FCEFA7EDBCD45015E1C6B41C386E5B1F80774E0011F6FA`

Packaging verified executable parity, archive contents and unchanged frozen
public binaries. The preferences/layout suite passes, including the chooser at
four scales, both explicit choices, the saved-mode default and initial focus.
The topology suite also passed its native clipping and C# to Lua fixtures before
the focus-only correction; no planner or protocol code changed.

Desktop QA of revision 2 at 100% scale confirmed the saved two-monitor label,
initial focus on that mode, and actual Enter opening the two-monitor editor with
offsets `(500,914)` and dimensions `782x1290`. Changing the left offset to 510 and
cancelling left the preferences file byte-for-byte unchanged. Companion exited
normally and the exact original preferences were restored and hash-verified.
Private evidence is under ignored `dist/live-qa-layout-chooser-*`. No WoW client
was launched during that initial desktop test. The subsequent exact-artifact
Retail run is recorded below.

### Revision 2 packaged Retail workflow, 2 November 2026

The exact revision 2 executable identified above passed a targeted Retail
`12.1.5.70688` run with unchanged installed addon `2.1.2-beta.24`, protocol 1,
on the same 100%/100% SDR monitor setup. The chooser focused the saved two-monitor
mode; Enter opened its editor. Changing the workspace left offset from 500 to
510 and clicking Save plan persisted `SecondaryAreaEnabled=True`,
`PartialSpanEnabled=False`, `AutoSpan=False` and the intended rectangle.

The first Retail launch disconnected before any Span action. It was closed
normally and relaunched through Battle.net. Per the user's instruction, this
network disconnect is excluded from feature acceptance; its cause was not
independently established.

The retry retained the original native `(208,0) 2144x1392` window until manual
Span. Apply produced `(-930,-200) 3490x1640`, style `140B0000`, and a complex
window region. The actual bridge contained game `(930,0) 2560x1440` and workspace
`(0,350) 782x1290` in bottom-origin backing coordinates. A newly executed private
viewport diagnostic, flushed by UI reload, recorded `READY`, version `MATCH`,
and `viewportMatches=true`, with WorldFrame approximately `(930,0) 2560x1440`.
Native bounds/clipping survived reload, and full game screenshots show the
Character panel within the workspace before and after it. No panel drag or new
post-reload viewport diagnostic was performed in this run.

Manual Restore exactly recovered `(208,0) 2144x1392`, style `14CF0000`, and no
region. The installed addon showed its expected saved-layout mismatch prompt;
no recalibration or HUD generation was accepted. Both test apps exited normally,
nine original files were restored and hash-verified, and BugGrabber changed only
its session counter from 344 to 346, with no new stored errors. Battle.net was
left open. Private evidence: `dist/live-qa-chooser-retail-20261102-134140`.

This extends targeted Retail acceptance to the exact chooser revision 2 package.
Other exact-artifact client runs, mixed-DPI, live hotplug, HUD generation and
protected-action acceptance remain pending. Prototype 3's Anniversary and cold
restart evidence remains separate.

## Two-monitor custom workspace (prototype 3)

Local unpublished portable artifact: `dist/custom-workspace-regions-prototype-3/Offhand.exe`,
also packaged as `Offhand-Companion-v2.1.3-beta.1.zip` in that directory.
Built from clean tracked source `c5ef54b09c335b7b60ae1d958e2ca63d4c7609c6`.

- EXE SHA-256: `F49BFFC8FC9E76F1350EB7B9A46C8E0326833ABE860E0E78098DAFCCC7048D66`
- ZIP SHA-256: `481D46C73A34C36E0686F21CE2F209BF43EA97E15F5D3088012C5ABA1EEA6BEF`

Packaging verified executable parity, archive contents and unchanged frozen public
artifacts. The build manifest's `liveVerification: pending` describes build time;
the subsequent targeted Retail run is recorded below. No Store submission or
release promotion was performed.

In prototype 3, open **Custom region... > Two-monitor workspace...**. Choose distinct game and
workspace monitors. The game uses its full monitor. Define the workspace by
monitor-local physical left/top offsets, width and height, or use **Select
workspace on monitor...** to move the rectangle and resize its edges/corners.
Arrow keys move it by 10 pixels, Enter accepts, and Escape cancels. **Use
selection** changes pending fields; **Save plan** validates and atomically saves
both monitor selections. **Span WoW Now** remains manual. Disabling this mode
returns to ordinary monitor planning; saving a single-monitor custom layout
replaces it. The two custom modes cannot be active together.

The existing schema 1 `DUAL_DISPLAY` bridge already accepts one full game
rectangle and one arbitrary workspace rectangle. No addon runtime change is
needed for this data contract. The native bounds are their outer union; clipping
contains only those two rectangles, excluding unused secondary pixels and
physical voids. The editor reports the backing dimensions and pixel count because
clipping does not remove the underlying bounding-surface cost.

Guards require two selected connected monitors, matching workspace identity and
saved resolution, a workspace contained within its monitor with at least
480x600 pixels, no game/workspace overlap and a union no larger than 32768 pixels
per axis. These are physical guardrails, not universal panel-readability claims.
Custom secondary plans disable auto-span and automatic graphics-reset recovery.
Three or more selected monitors and multiple workspace regions are not supported.

Automated evidence includes four secondary layouts (offset portrait, internal
gap, right and above), actual GDI point membership excluding unused pixels/voids,
malformed and overflowing preferences, disconnected/changed displays, overlap,
conflicting modes and return to ordinary full-monitor planning. Actual generated
C# bridges pass Lua viewport and saved-position round trips at two UI scales.
The dialog passes 100/125/150/200% layout checks. Native rollback now covers
160 single/secondary custom cases and 2157 assertions per x64/x86 build. The
existing recovery-policy suite passes 112 assertions.

Desktop QA on the physical 1440x2560 monitor at `(-1440,-1114)`, 100% scale,
passed overlay placement, a free drag from local `(800,1114)` to `(500,914)`,
corner resizing from 640x1440 to 782x1290, Enter acceptance, preview of a
3500x1640 backing surface, and Save selecting both monitors with custom recovery
disabled. No game was launched during this editor test. Companion exited
normally; the exact original preferences were restored and hash-verified.
Private evidence is under ignored `dist/live-qa-secondary-editor-*`.

### Packaged Retail verification, 2 November 2026

The exact prototype 3 executable above passed a targeted run on Retail
`12.1.5.70688`, with the unchanged installed `2.1.2-beta.24` addon and protocol 1.
The game used the full primary 2560x1440 monitor; the workspace used the editor's
782x1290 rectangle at local `(500,914)` on the offset portrait monitor.

- Manual apply produced native outer/client bounds `(-940,-200) 3500x1640`,
  borderless style `140B0000` and a complex window region (type 3).
- The actual bridge reported game `(940,0) 2560x1440` and workspace
  `(0,350) 782x1290` in bottom-origin backing coordinates, mode `DUAL_DISPLAY`.
- The existing profile had a manual canvas override. Temporarily selecting
  Companion/AUTO geometry yielded `READY`, version `MATCH` and
  `viewportMatches=true`. The actual WorldFrame was approximately
  `(940,0) 2560x1440`, within subpixel rounding tolerance.
- A private diagnostic command followed by `ReloadUI()` wrote the first snapshot.
  A second private diagnostic after reload, saved on normal exit, again reported
  `READY`, `MATCH`, and `viewportMatches=true` with the same physical rectangles.
  Native bounds and complex clipping remained intact after reload.
- Full screenshots taken with WoW's screenshot key showed the Character panel
  inside the secondary workspace before and after reload. No panel drag was
  performed in this run. The desktop automation capture cropped the spanned
  surface, so it was not used to infer game click coordinates.
- Manual Restore exactly recovered the original native bounds
  `(208,0) 2144x1392`, style `14CF0000`, with no clipping region. The installed
  addon then showed its saved-layout mismatch prompt, as expected for the old
  bridge after restoring the ordinary window; no recalibration was accepted.
- Both test apps exited normally. Nine original preferences, client configuration,
  bridge and SavedVariables files, including prior backups, were restored and
  hash-verified. BugGrabber changed only its session counter from 340 to 342;
  no new stored error was recorded.

Private evidence: ignored `dist/live-qa-secondary-retail-20261102-101055`, including
native before/apply/reload/Restore snapshots, applied bridge bytes, full game
screenshots and before/after SavedVariables. This establishes the initial
two-monitor viewport and reload path on this physical 100%/100% SDR setup.

### Cold restart and Anniversary follow-up, 2 November 2026

The same immutable prototype 3 executable passed a further Retail cold-start run
using the saved test preferences and AUTO account/character state from the prior
run. Companion reopened with both monitor selections, the 782x1290 workspace and
auto-span disabled. A newly launched Retail process stayed at its ordinary
`(208,0) 2144x1392` window until the explicit Span action. Manual apply recreated
`(-940,-200) 3500x1640` with complex clipping. Seven point checks read from the
actual WoW window region included game/workspace points and excluded unused
secondary areas and the internal gap. These are region-membership checks, not a
separate desktop click-through test.

The Character panel returned within the workspace on cold entry. A newly executed
private diagnostic, flushed by UI reload, again recorded `READY`, version `MATCH`
and `viewportMatches=true` with WorldFrame approximately `(940,0) 2560x1440`.
Native bounds and clipping survived reload. Restore recovered the exact ordinary
window bounds/style and removed the region. Both apps exited normally, nine
original files were restored and hash-verified, and BugGrabber changed only its
session counter from 342 to 344. No fresh error record was stored.
Private evidence: `dist/live-qa-secondary-cold-retail-20261102-124544`.

A separate targeted run passed on Anniversary `2.5.6.70577`, with the unchanged
installed `2.1.2-beta.24-tbc-test.11` addon, protocol 1, and the selected idle
character on Spineshatter. Its existing geometry preference was already AUTO.
The same secondary rectangle produced native `(-940,-200) 3500x1640`, style
`140B0000`, and a complex region. The pre-reload diagnostic flushed by reload
reported `READY`, version `MATCH`, and `viewportMatches=true` with the expected
game/workspace rectangles and WorldFrame. Native clipping survived reload; full
game screenshots show the Character panel in the workspace before and after it.
No fresh post-reload viewport diagnostic or panel drag was performed in this run.

Anniversary Restore exactly recovered `(215,0) 2130x1392`, style `14CF0000`, and no
region. This is native window restoration evidence; the installed addon still
displayed its old viewport until subsequent refresh/reload. Both apps exited
normally, and fourteen original files were restored and hash-verified. Both
backed-up BugGrabber stores were unchanged, but BugGrabber/BugSack were disabled
for this client, so this is not a fresh runtime error audit. HUD generation and
protected actions were not exercised.
Private evidence: `dist/live-qa-secondary-anniversary-20261102-125732`.

Shared knowledge routing reported a gap. The local `GetCompanionTopology`,
`GetMetrics`, persistence and production native planner/clipping source, plus
the fixture and targeted live results above, support the data-contract decision.
Mixed-DPI desktop selection, live hotplug, HUD generation, protected actions and
clients beyond the targeted Retail/Anniversary runs remain unverified for this
new mode. Oversized game-options tooltips remain a separate reported issue.

2 November 2026. Explicitly authorized initial runtime implementation on
`codex/custom-workspace-regions`, based on prepared Companion source `a4684a1`.
This overrides the previous deferral for stage 0 only. Unpublished; schema 2,
multiple workspaces and general discontiguous regions remain outside this slice.

## Visual desktop editor (prototype 2)

Local unpublished portable artifact:
`dist/custom-workspace-regions-prototype-2/Offhand.exe`, also packaged in
`Offhand-Companion-v2.1.3-beta.1.zip` in that directory. Built from clean tracked
source `822fee854757d2cb5187968f399bf595d8157788`.

- EXE SHA-256: `598815690C7940F3784C69670EB03E77ABF0118440B797D1296B02BB81BA6440`
- ZIP SHA-256: `06795660AB01B3FB4C2B1930296F8C40FAA0E817F92921F6305B0E4512554CA5`

Packaging verified exact executable parity, archive contents and unchanged frozen
public artifacts. Prototype 2 has desktop editor and automated evidence below;
live WoW and Store package acceptance are not inherited from prototype 1.

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
