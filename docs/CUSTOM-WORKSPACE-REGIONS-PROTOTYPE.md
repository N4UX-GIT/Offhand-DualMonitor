# Initial custom workspace region prototype

2 November 2026. Explicitly authorized initial runtime implementation on
`codex/custom-workspace-regions`, based on prepared Companion source `a4684a1`.
This overrides the previous deferral for stage 0 only. Unpublished; schema 2,
multiple workspaces and general discontiguous regions remain outside this slice.

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

## Initial implementation confidence and remaining release scope

The initial contiguous single-display workflow works on this Retail pairing:
editor, validated settings, native apply with reserved app space, direct schema 1
viewport, reload, fitting-panel reopen, process restart and Restore. The existing
addon required no runtime changes for this path.

Broader release acceptance still includes other clients, the physical 5120-wide
monitor, live both-edge/game-side combinations, mixed DPI, hotplug, actual WoW
failure injection, protected actions, fresh HUD generation and the wider panel
matrix. The existing HUD diagnostic reported stale generated geometry from the
user's prior layout; its optional regeneration was deliberately not invoked.
Use the existing HUD setup/recovery flow when adopting new geometry. Do not
claim all HUD controls fit based solely on the WorldFrame PASS.

The 640-pixel example does not accept arbitrary oversized panels or talents
readability. The title-drag attempt also remains a focused follow-up. Schema 2,
multiple regions and automatic custom-region recovery are future work.

## Evidence routing

Shared knowledge status was consulted first. The broad workspace search reported
a stale index, and earlier native Companion routing supplied no matching runtime
evidence. Decisions use the local `MonitorSelection`, `SpanClipRegion`,
`PartialSpanDialog`, topology writer and existing Lua viewport/persistence source,
plus the exact automated and Retail observations above. No missing retrieval
result establishes API absence or safety on another client.
