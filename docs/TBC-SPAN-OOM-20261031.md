# TBC Anniversary manual-span memory crash, 31 October 2026

Tracking: OH-TBC-001. Status: reported, awaiting diagnostic and crash evidence.

## Report and scope

A Discord user reports an out-of-memory exception while manually configuring
the WoW window span across monitors on TBC Anniversary. Exact exception text,
client build, Offhand release, operating system, hardware, monitor arrangement,
resize tool and enabled addons are unknown. The reporter subsequently confirmed
that the crash occurred during window dragging. Offhand
attribution and the exhausted resource are not established.

Further reporter detail: dragging an edge and clicking the numeric bottom-edge
adjustment buttons both triggered the problem; FPS dropped very low before the
error appeared. The developer confirmed these were Offhand's in-game bottom
offset buttons. Edge resizing is confirmed, but whether the dragged edge was
native or an in-game boundary remains unconfirmed. The bottom-button reproduction
does not require native window resizing. Exact exception text remains pending.

Review baseline: repository HEAD `2e5c008` (Beta 23), plus the existing uncommitted
working tree advertising Beta 24. The reporter's installed source is unknown.
No runtime or Companion change, deployment or release was made for this report.

## Source findings

- `Core/Init.lua`: display and UI-scale notifications cancel the previous
  0.75-second timer. Only the newest geometry generation applies the full layout
  and restores persistent frames. Generation checks also reject superseded work
  deferred through combat. This debounce is present in HEAD as well as the
  working tree. It does not suppress other listeners or native renderer work.
- `Core/Mainhand.lua` and `Core/MainhandGeometry.lua`: Mainhand geometry still
  updates immediately on each display/scale event. The anchor is reused;
  unchanged signatures skip writes. Changed geometry notifies registered
  consumers, so callback cost remains relevant during an actual resize.
- `UI/Onboarding.lua`: when the guide is visible, each display/scale event
  recenters it immediately and schedules two callbacks at 0.15 and 0.8 seconds.
  Generation checks skip stale work, but do not cancel pending callbacks.
  Consequently an event burst can create temporary timer/closure pressure.
  The guide frame itself is cached. This is an investigation lead, not a
  demonstrated unbounded leak or explanation for a native OOM crash.
- `Core/Viewport.lua`: nameplate updates coalesce to the next tick. Global scale
  writes compare the desired value before changing UIParent scale. Applying a
  spanned viewport changes WorldFrame anchors; resetting restores UIParent bounds.
  Neither operation resizes the native OS window directly.
- `Core/ManualCanvas.lua`: remembered canvas storage is limited to eight slots.
  The reviewed path does not append a saved geometry record for every resize.
- Setup can request windowed mode through an explicit action in
  `UI/Onboarding.lua`. Record whether the failing action was this button, a
  monitor/settings slider, dragging a native window edge, or an external tool.
- Confirmed bottom-offset path: `UI/Controls.lua:CreateBottomControl` updates
  `db.gameBottomPixels` and immediately calls `ApplyFullLayout` for every +/-
  click. This bypasses the display-event debounce. It also applies when clamping
  leaves the value unchanged. Full layout includes scale, viewport, Mainhand,
  Canvas and other layout consumers. `Viewport:Apply` clears and reapplies
  WorldFrame anchors without an unchanged-bounds guard. The fallback metrics
  path uses the offset to change the game's bottom bound and may reduce height
  to fit. Exact/manual topology paths must be evaluated using the reporter's
  actual metrics. This source path does not invoke an OS-window resize API.
- Normal `/offhand diag` captures build, release, geometry and operating state,
  but does not establish process commit, GPU memory or Lua memory trends.
  `GetPerformanceDiagnostics` exists in Viewport, but the current slash-command
  output does not print its complete graphics-settings snapshot.

These are source observations, not proof that native allocations or addon
callbacks are safe under the reporter's client and event timing.

## Resource hypotheses and evidence limits

Keep at least three possibilities open: native graphics allocation failure
during resize, system/process memory pressure, and addon-driven allocation or
layout churn. Another addon or injected graphics overlay is also a possible
participant. The reported exception alone does not select between them.

Confirmed during-drag timing prioritizes native resize/resource handling and
listeners that run immediately on display events, including Mainhand geometry
and visible guide recentering. The 0.75-second full-layout debounce is a lower
priority if geometry events continued throughout the drag, but it can still
fire during a pause while the mouse remains held. Actual event delivery remains
unknown. The initial move-versus-resize question was later narrowed to edge
dragging; whether this was a native or in-game boundary still needs clarification.

The subsequent confirmed in-game +/- reproduction changes that prioritization:
native OS-window resizing is not necessary for at least one reported trigger.
Offhand's immediate full-layout/WorldFrame update and any resulting engine
rendering work now require direct investigation. Low FPS before failure is
consistent with several forms of resource pressure or repeated work; it does
not prove a Lua leak, VRAM exhaustion or a particular allocation failure.
Do not attribute both triggers to native swap-chain resizing on timing alone.

Microsoft documents that window resize normally entails resizing swap-chain
back buffers and requires release of outstanding buffer references:
[IDXGISwapChain::ResizeBuffers](https://learn.microsoft.com/en-us/windows/win32/api/dxgi/nf-dxgi-idxgiswapchain-resizebuffers).
This supports investigating native resize/resource handling; it does not
identify WoW's actual failing operation. Large spans and high render scale are
relevant inputs, but bounding-window area is not a measurement of WoW's actual
render targets, VRAM allocation or rendering cost after WorldFrame confinement.

The local Retail device-recovery case in `MAP-SPAN-RESET-20261028.md` has a
recorded DXGI failure, not this reported Anniversary OOM. Keep the cases separate
unless matching crash/log evidence connects them. No verified upstream finding
currently establishes a known TBC Anniversary resize/OOM defect for this report.

Shared knowledge consulted: `wowkb.ps1 status` and an `ask` query for
DISPLAY_SIZE_CHANGED, UI_SCALE_CHANGED and resize allocation, scoped to
`classic-anniversary`. Locked source is `68e0a2ec559d9761dfc4e7f864c3944f9d758a49`,
version `2.5.6.70577`, retrieved 29 October. Generated VideoDocumentation.lua
lines 86-91 and UIManagerDocumentation.lua lines 70-75 declare the synchronous
events. The query returned declarations, not native allocation evidence.
Reporter build and runtime behavior remain unresolved; original 2.4.3 is not
the target client.

## Evidence to request first

1. Exact crash text or screenshot and the matching crash text report from that
   client's `Errors` directory, if produced. Preserve `Logs/gx.log` before another
   launch can replace it. Include the crash timestamp and time zone.
2. `/offhand diag` from the last working window size, exact installed release,
   resize method and the action immediately preceding failure. Edge dragging and
   Offhand's in-game bottom +/- buttons are confirmed. Ask whether one click
   suffices or several adjustments are required, whether each direction fails,
   the starting/last displayed bottom offset, and whether FPS recovers if input
   stops. Clarify native window edge versus in-game boundary for the drag case.
3. OS, RAM, GPU and VRAM, driver version, monitor resolutions/arrangement and
   scaling, intended span width/height, graphics API, render scale and anti-aliasing
   settings. Record HDR and overlays if active.
4. If a controlled retry is practical, record WoW memory and system Committed
   used/limit plus dedicated/shared GPU memory before and during it. A crash can
   occur between samples; a low final reading does not exclude a transient peak.

Lua addon-memory counters cannot measure native renderer allocations or total
process commit. SavedVariables probes may lose their current capture on a crash;
existing external logs and crash reports take priority over adding instrumentation.

## Controlled comparison after preserving evidence

Use the same client, scene, starting window size and intended final dimensions.
Fully exit Companion for the manual comparisons. Preserve SavedVariables.

| Comparison | Interpretation if failure occurs |
| --- | --- |
| All addons disabled, same manual resize | Offhand Lua is not required for that reproduction; inspect native crash/resource evidence. |
| Offhand alone, guide closed | Tests Offhand participation without other addon interactions or guide recenter callbacks. |
| Offhand alone, guide open | A difference from the preceding case prioritizes visible setup work and its timer pressure. |
| Normal addon set | Failure only here prioritizes addon interaction or aggregate resource pressure. |

For the confirmed bottom-button trigger, hold native window dimensions fixed
and test separately with Offhand alone. Record initial geometry/offset and FPS,
then make one +1 px adjustment and wait. If healthy, restore with one -1 px
adjustment and wait. Stop if FPS collapses and preserve logs. Do not combine
this test with native resizing or a rapid stream of clicks. Compare the normal
addon set only after that baseline. A failure with Offhand alone establishes
participation, but still does not distinguish Lua layout work from engine work
caused by the viewport change.

Record the largest working and first failing dimensions. Only after the baseline
comparison, change one graphics variable at a time, such as a smaller span,
lower render scale if above 100%, or reduced anti-aliasing. Test another graphics
API only if the client exposes it, with a restart. A changed failure threshold
supports a resource/backend hypothesis, not a confirmed driver or addon diagnosis.

## Validation and next gate

All 63 existing Lua 5.1 suites passed on the working tree. Relevant suites include
lifecycle (display debounce and stale combat work), mainhand-placement, geometry,
manual-canvas, wizard-autoconfig, diagnostic-output and display-probe (bounded
event recording). The installed Lua executable could not launch inside the
sandbox; the successful run used approved execution outside it.

These are simulated regressions, not a native-memory stress test, packaged
verification or live Anniversary reproduction. No speculative fix is proposed.
The bottom-control suite stubs `ApplyFullLayout`; it verifies the control's
value handling, not the full layout/rendering path implicated by this report.
Shared knowledge was rechecked after the update: full-text search reported a
stale index; structured `api DISPLAY_SIZE_CHANGED --client classic-anniversary`
still returned the locked declaration above. No native-memory claim follows.
Next gate: correlate the exact exception/allocation failure and graphics log
with the addon-disabled comparison and resize timing, then target a regression
or bounded diagnostic at the implicated path.
