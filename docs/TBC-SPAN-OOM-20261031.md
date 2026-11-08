# TBC Anniversary manual-span memory crash, 31 October 2026

Tracking: OH-TBC-001. Status: mitigated for reporter through Companion; cause
unresolved, local crash reproduction unsuccessful, original crash evidence pending.

Hardware update: reporter identifies the GPU as an NVIDIA GeForce RTX 4060.
Desktop/laptop variant, actual dedicated-memory capacity, driver version,
system RAM, memory use at failure and graphics settings remain unconfirmed.
The model name alone neither establishes nor excludes GPU allocation failure;
do not substitute it for the original exception or memory measurements.

New local evidence: rapid bezel adjustments coincided with a logged D3D12 DSV
descriptor allocation failure and DeviceRecovery restart on Anniversary build
70577, using the developer's RTX 2080 Ti and 8x MSAA. This establishes a local
graphics failure mechanism, not equivalence with the reporter's RTX 4060 OOM.
Preserved logs, installed-source hashes and follow-up gates:
[rapid bezel adjustment device recovery](TBC-BEZEL-DEVICE-RECOVERY-20261031.md).

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

Follow-up, 31 October: the developer attempted local reproduction and did not
observe the crash. The reporter switched to Companion and reports no further
occurrences. Neither observation establishes a root cause or a verified fix.
Keep the working setup intact; original crash artifacts and a current working
diagnostic snapshot are the next evidence priority.

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

## Follow-up comparison and regression

Source baseline for this follow-up: HEAD `09c6f31`, with existing uncommitted
compatibility/diagnostic work preserved. No product source or Companion artifact
was changed by this investigation.

The source comparison identifies an actual geometry-source difference:

- `Onboarding:SelectMethod` selects `AUTO` for Companion and `MANUAL` for manual
  setup. A remembered manual canvas also selects `MANUAL`; merely having a
  Companion bridge loaded does not override that preference.
- With accepted Companion topology and `AUTO`, `Viewport:GetMetrics` returns the
  supplied game/workspace rectangles before evaluating `gameBottomPixels`.
- With accepted manual geometry, bottom calibration changes the viewport's
  bottom bound, and can reduce height when it reaches the canvas top. Both
  sources eventually use the same layout dispatcher and WorldFrame anchor code.

This makes avoidance of the manual calibration path a plausible explanation
for the working Companion setup. It is an inference, not proof that this was
the difference in the reporter's session. Window size/style, setup sequence,
graphics settings, elapsed session time and addon environment were not held
constant. Companion success does not exclude addon participation or establish
a swap-chain, RAM or VRAM diagnosis.

Added `tests/manual-calibration-stress.lua`, loading the real bottom-control,
Init layout dispatcher, ManualCanvas and Viewport code. Other optional modules
are absent; native frames and engine behavior are mocked. It checks:

- 10,000 alternating +/- clicks after warmup, each reaching real layout and
  viewport calculations, with positive bounded geometry and matching anchors.
- No additional persistent frames or remembered-canvas records, and less than
  64 KiB retained growth after full collection in this isolated fixture.
  Observed retained delta: approximately 0.141 KiB. This is not a live memory
  measurement or a claim about allocation rate between collections.
- Bottom-offset boundary input clamps to a valid one-pixel game height.
- Explicit manual preference survives a loaded bridge, selecting `AUTO` allows
  Companion geometry to take precedence, and losing the bridge restores the
  remembered manual path on the next layout apply.

All 73 current Lua suites passed, including this regression. The fixture also
observed 10,000 WorldFrame clears for those 10,000 adjustments. This confirms
repeated native-facing writes, not that the writes caused the crash. The test
does not model display-event feedback, full optional-module interactions,
native frame resource retention, driver behavior or render-target allocations.
It cannot rule out a leak or stall in those paths.

No speculative crash correction is proposed. The most useful non-disruptive
next evidence is the original timestamped crash report (if still present) and
`/offhand diag` from the working Companion session, plus the original manual
values/topology and graphics settings if known. A current gx.log describes the
working session and must not be presented as the original failure log. If the
problem recurs, correlate Lua memory, process/system commit and GPU memory with
the first FPS collapse before choosing a targeted correction.

## Working Companion screenshot evidence and local FPS observation

Three full-diagnostic screenshots supplied by the developer on 31 October show
the reporter's working Companion session. Transcribed support facts, excluding
character identifiers:

| Field | Observed value |
| --- | --- |
| Client | WoW 2.5.6, build 70577, interface 20506, project 5 |
| Addon | 2.1.2-beta.24 |
| Companion writer / paired | 2.1.2-beta.20 / 2.1.2-beta.20 |
| Companion minimum / protocol / status | 2.1.2-beta.19 / 1 / MATCH |
| State | Enabled=1, Spanned=1, Source=Companion, Combat=0, Setup=1 |
| Layout | LANDSCAPE_DUAL, Mainhand RIGHT |
| Mainhand physical rectangle | x=1280, y=3, width=1920, height=1080 |
| Workspace physical rectangle | x=0, y=0, width=1280, height=1024 |
| Physical canvas | 3200x1083 |
| Viewport check | PASS |
| Topology | READY, loaded, schema=1, expected/live=3200x1083 |
| UI diagnostic screen/canvas | 3250x1100, effective scale about 0.698 |
| Manual canvas | preference=AUTO, remembered=4, selected=none, state=UNEVALUATED |
| Combat text | Current=1, Original=1, WorldTextScale_v2, AppliedRatio=1 |
| Relevant optional integrations | MoveAny absent, DialogueUI absent, user media missing/disabled |

The UI screen/canvas numbers are not a second physical resolution or evidence
that render scale exceeds 100%. Companion geometry is internally consistent:
the right game rectangle ends at y=1083, while the shorter workspace ends at
y=1024. The three-pixel bottom offset is observable; its origin and whether the
failed manual attempt used the same size/offset remain unknown. Manual matching
is not evaluated because Companion currently owns geometry. Four remembered
canvases establish stored history, not a leak or the number of resizing events.

WorldMapFrame's `generic/peer-repair#141` diagnostic is the last activity's global
sequence number (`NotePanelControllerActivity` in Canvas.lua), not a count of 141
map repairs or an event rate. The screenshot does not establish a repair loop.
No process memory, GPU memory, frame-time trace, graphics API, render scale,
anti-aliasing settings or exception/allocation stack is supplied by these images.
Missing optional-frame diagnostics are capability observations, not error stacks.

The developer separately reports significant FPS loss while moving the window
manually, without reproducing the crash. This corroborates a movement-time
performance symptom on another local setup, not a common cause or memory leak.
Record title-bar movement versus edge resizing, whether it crosses displays,
and recovery after release independently of the reporter's in-game +/- trigger.
Windows enters a native modal move/size loop during title-bar or sizing-border
drags ([Microsoft WM_ENTERSIZEMOVE](https://learn.microsoft.com/en-us/windows/win32/winmsg/wm-entersizemove)).
This is another path to investigate for drag-time frame pacing; the documentation
does not establish WoW's FPS behavior or connect it to the bottom-button crash.

The calibration regression now also exercises the supplied physical geometry:
3200x1083, 40% left workspace, 1920x1080 right game, bottom=3. In manual 16:9
mode, increasing bottom to 4 makes the viewport height clamp to 1079; the desired
UIParent scale decreases with that height. Reversing the step restores height
1080 and scale. With accepted Companion geometry the same manual-setting edit
leaves the game at y=3, height=1080 and unchanged scale.

An additional 2,000 alternating adjustments pass through this boundary in the
mock, alongside the original 10,000-adjustment case. This establishes a concrete
manual-versus-Companion behavioral difference on the supplied geometry. Native
UI-scale/display callbacks and renderer reallocations remain unmodeled. It is
a candidate trigger to measure, not a confirmed crash cause or an invalid
geometry calculation. No product behavior was changed.

## Local resize isolation result

Developer follow-up: FPS stays stable during title-bar movement, falls during
edge resizing, and shows similar resizing behavior with Offhand disabled.
No local out-of-memory crash has been reproduced. The exact disabled mechanism,
remaining addon set, measured FPS and graphics backend were not specified.

This supersedes the earlier broad description of movement-time FPS loss:
title-bar movement and edge resizing are now distinguished. Offhand is not
required for the observed local resize slowdown under the reported disabled
condition. Native size-dependent rendering/resource work is consequently a
stronger lead for that performance symptom than Offhand's display listeners.
Do not treat this as proof that all addons were disabled, a driver defect,
memory exhaustion, or an explanation for the reporter's crash.

Keep two investigative tracks distinct:

- Local native edge-resize slowdown, also observed without Offhand, with no
  crash. If further measurement is needed, compare the same start/end sizes
  and scene, record FPS recovery after release, and observe process/system
  commit and GPU memory. A slowdown confined to active resizing is not itself
  evidence of retained-memory growth.
- Reporter OOM after severe FPS loss, including the confirmed in-game bottom
  +/- action. That action does not require OS-window resizing, so the local
  disabled-addon resize result does not clear or implicate its layout path.
  Original crash text/report remains the most useful discriminator; native
  rendering work triggered by either kind of geometry change is a hypothesis.

No addon correction follows from this local isolation result alone. Keep the
reporter on the stable Companion setup and the issue mitigated, cause unresolved.

Developer additionally confirms FPS recovers after releasing the resizing edge.
The established local symptom is therefore transient, resize-time slowdown,
including with Offhand disabled, without a reproduced crash. This weakens using
the local FPS dip as evidence for persistent layout churn or retained resource
pressure. Memory was not measured, so recovery neither proves nor excludes a
leak. Do not treat this observation as reproduction of the reporter's OOM or
as a reason to change addon behavior. Prioritize original crash evidence and
the distinct in-game bottom-adjustment trigger for further crash investigation.
