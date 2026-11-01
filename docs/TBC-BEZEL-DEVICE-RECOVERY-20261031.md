# Anniversary rapid bezel adjustment and D3D12 device recovery

Related investigation: OH-TBC-001. Local graphics failure established; original
Discord OOM equivalence and the initiating resource-lifetime fault unresolved.

## Local observation and preserved evidence

On 31 October the developer reports transient freezes while rapidly clicking
the bezel compensation adjustments, then one viewport reset. The attached
screenshot shows the geometry-mismatch recovery prompt after that operation.
Read-only inspection identifies running process 58204, WowClassic.exe, from
`C:/Games/World of Warcraft/_anniversary_`, executable version 2.5.6.70577.
No input, settings changes, addon deployment, reload or client shutdown was
performed by the investigator.

The current gx.log was copied before any further launch could replace it:
`dist/tbc-bezel-reset-20261031/anniversary-gx-234931.log`.
SHA256: `A8349EED1398B6817C7369F6178E2B85DB9B1D05C337AC4673C97292C6422C9E`.
The original copy is 16,299 bytes. Relevant log line numbers:

| Local log time | Line | Evidence |
| --- | --- | --- |
| 23:42:23-24 | startup | RTX 2080 Ti, 11 GB; D3D12; BGRA8Unorm, MSAA 8x |
| 23:47:28.280 | 165 | GPU budget report 7.8 GB / 9.1 GB, 85.3% |
| 23:47:30.933 | 166 | Separate video-memory notification: used 2.8 GB, budget 10.0 GB, total 10.8 GB |
| 23:47:32.217-227 | 167-168 | Texture defragmenter frees 64 MB across 582 textures |
| 23:47:41.250 | 169 | Failed to allocate a descriptor: DSV Heap |
| 23:47:41.250 | 170 | Retrying with DSV limit of 256 |
| 23:47:41.250 | 171 | Device context lost; recovery occurrence 1 |
| 23:47:41.259 | 172 | GxRestart, reason DeviceRecovery |
| 23:47:41-43 | following lines | D3D12 device destroyed, then successfully recreated |

The two memory reports expose different values; do not equate their counters,
interpret their difference as a measured leak/free, or claim VRAM reached 100%.
The log contains many changing render-size records during earlier manual resize
activity around 23:42-23:44. Those lines are not a timestamped trace of each later
bezel click. The failure window has no per-click addon instrumentation.

## What this establishes

A DSV descriptor allocation failed immediately before WoW restarted its graphics
device. This is a concrete native resource failure in the local run. The device
restart provides a plausible mechanism for the observed window/viewport reset
and subsequent topology mismatch, rather than proving an addon preference reset.

DSV means depth-stencil view. Microsoft describes it as a separate descriptor
heap type whose capacity is specified by descriptor count, and DSV heaps are
non-shader-visible. Descriptor failure does not by itself establish exhaustion
of physical VRAM, system RAM, or Lua memory:
[heap types and creation](https://learn.microsoft.com/en-us/windows/win32/direct3d12/creating-descriptor-heaps),
[non-shader-visible heaps](https://learn.microsoft.com/en-us/windows/win32/direct3d12/non-shader-visible-descriptor-heaps).

Rapid viewport changes may expose resource churn or lifetime/capacity handling in
the renderer. This remains a hypothesis: the log does not reveal WoW's descriptor
allocation/retirement implementation, the individual offending call or whether
a driver contributes. The 256 retry line is not a supported CVar recommendation.
8x MSAA is a controlled comparison variable, not a demonstrated cause.

This local failure occurred on the developer's RTX 2080 Ti with approximately
31.9 GB system RAM. The Discord user's reported RTX 4060 and OOM have no matching
crash/log evidence yet. Do not claim their GPU failed in the same way. Likewise,
the earlier Retail DXGI device-removed case is a separate failure signature.

## Source and window observations

Installed Viewport.lua, Controls.lua and Options.lua hashes match the reviewed
workspace. Init.lua differs only in unrelated notification-capture slash-command
and diagnostic-output additions in the workspace; its layout dispatcher matches.
Installed source copies and exact hash pairs are retained under
`dist/tbc-bezel-reset-20261031/installed-source/` and `module-hashes.json`.

The bezel slider in Options.lua writes `db.bezelGap`. Its +/- actions use the
shared Controls.lua direct-value path, which immediately calls ApplyFullLayout
for each click. The display-event debounce does not coalesce these calls.
Viewport.lua clears and rewrites WorldFrame anchors on every active apply.
There is no no-op guard there based on the already-applied geometry. The shared
slider can also dispatch a layout at a value limit if native SetValue emits a
value-change callback. No claim about event delivery follows from that condition.

The installed Companion topology expects 4000x2560, game=(1440,6 2560x1440),
workspace=(0,0 1440x2560). Whether that bridge was the selected geometry source
at each failing click is unknown. Source preference and runtime metrics matter;
bezel values can be ignored by an accepted Companion geometry path while full
layout still writes the viewport. Do not infer the active geometry source from
the installed bridge alone.

A one-second read-only native observer at 23:50:26, after the reported failure,
records window=(-8,-8 2576x1408), client=2560x1369, no explicit clipping region,
not hung/minimized. It establishes that the window was no longer the expected
4000x2560 span at capture time; it does not reconstruct the recovery's exact
native resizing sequence or exclude subsequent user actions. Capture:
`dist/tbc-bezel-reset-20261031/window-20261031-235026-758.jsonl`.

## Next engineering gate

Preserve this as the baseline. A targeted mitigation candidate is to coalesce
rapid geometry-control requests into one settled apply and avoid native viewport
writes when actual desired anchors already match. Such a change must preserve
final input, combat deferral, topology transitions and repair after Blizzard
changes WorldFrame. A cached geometry key alone must not suppress recovery.

Validate that candidate using bounded, timestamped layout/application counts and
the same native/graphics configuration. Then compare the same adjustment pattern
with MSAA disabled, separately from a D3D11 comparison if exposed by the client.
Change one variable at a time. Neither comparison is a confirmed fix until the
failure and stall evidence are retested. No product or graphics setting was
changed during this log inspection.

Shared knowledge status and scoped scheduling query were consulted before the
source decision. The returned authored guidance recommends coalescing redundant
refreshes and actual-client measurement; it supplies no native DSV allocation
contract. Native log evidence and the inspected installed source are primary
for this observation.

## Coalescing candidate prepared

At the developer's request, a source candidate now changes only Controls.lua
and the bezel opt-in in Options.lua. There is no Viewport.lua change in this
candidate, keeping redundant-write protection as a separate experiment.

- Bezel +/- and typed values, plus bottom-offset +/- and commits, store/display
  their value immediately. The two controls share a 250 ms quiet-period layout
  request. A reusable addon-owned OnUpdate frame replaces per-click application;
  it detaches its handler after settling and does not allocate a timer per edit.
- Further changes restart the countdown. Clamped or unchanged committed values
  do not request layout. A bezel drag pauses an earlier pending apply; release,
  hide or disabling the active slider preserves its final update. The scheduler
  is independent of the settings/wizard panel's visibility.
- The callback calls the normal ApplyFullLayout dispatcher using current state,
  including normal combat deferral. It captures no old profile/topology values.
  Other slider timing, client manifests, saved-variable schema and Companion
  artifacts are unchanged.

Regression coverage uses actual Options controls, not a standalone copy of
the scheduling algorithm. It verifies mixed-control bursts, 250 ms restart,
immediate displayed values, constant scheduler frame count, idle shutdown,
no-op limits, typing plus focus loss, hidden panels, step-then-drag, disabling
a drag, profile replacement, and existing unrelated slider behavior. The real
dispatcher/viewport fixture additionally verifies combat final-state handling
and a pending edit followed by switching to Companion topology.

### Local live acceptance

Use a local test installation of the two changed UI files, preserving rollback
copies. The client must reload them before testing; source-only tests do not
change the already running client. Keep the original log above as the baseline.

1. Keep DX12, 8x MSAA, scene and native window dimensions unchanged. Record the
   new test start time and current diagnostic geometry source. Use remembered
   manual geometry to verify actual calibration, and test Companion ownership
   separately because it intentionally ignores these manual geometry values.
2. Make isolated bezel/bottom steps and typed edits. Check immediate text,
   correct final geometry after the pause, both adjustment directions and limits.
3. Repeat the original bounded rapid-click pattern. Check that it settles once
   input stops, without the prior catch-up freeze, topology prompt or graphics
   restart. Stop at the first failure and preserve gx.log before another launch.
   Do not increase repetition just to force a device reset.
4. Check bezel drag/release, an adjustment followed by closing settings, and
   bottom controls in the wizard. Confirm final values survive /reload. Verify
   combat edits defer safely and apply the latest value after combat.
5. Check span/restore and ordinary viewport recovery. This candidate must not
   interfere with Blizzard-driven geometry repair or reapply stale manual values
   after changing to Companion. Any unexecuted portion remains pending.

Only after this same-settings comparison should MSAA or graphics API be changed.
An absence of failure in one short run is mitigation evidence, not proof that
WoW's descriptor handling or the separate reporter OOM is fixed. No live pass,
installation or release is claimed by preparing this source candidate.

Validation: all 73 current Lua suites pass after the candidate changes. The six
manifests, 65 runtime paths, XML references and all 64 runtime Lua files pass the
project validator with Lua 5.1 syntax compilation. The candidate adds no runtime
files and needs no TOC changes. The source stress fixture now advances the
quiet period between isolated adjustments; its separate burst case explicitly
asserts no synchronous apply and one latest-state apply after combat.

Developer overlay: `dist/tbc-geometry-coalescing-20261031/Offhand-geometry-coalescing-test.zip`.
It contains exactly the two changed UI files and README.txt. CRC and byte checks
confirm its UI files match the validated workspace. ZIP SHA256:
`05B948807EEA8DCBED22D7492FDDC62B2A81E6928DE7EF6580C3DE2684E06811`.
Baseline/candidate hashes are recorded beside it in module-hashes.json.
It is not a standalone addon package or a public release. The running client
has not been modified; live DX12/8x acceptance is pending.

## Local installation, 1 November 2026

At the developer's explicit request, installed only the candidate Controls.lua
and Options.lua into the running local Anniversary installation at
`C:/Games/World of Warcraft/_anniversary_/Interface/AddOns/Offhand/UI`.
Both installed hashes match the validated two-file overlay. Pre-install files,
the current gx.log and deployment/hash record are preserved under
`dist/local-deployments/20261101-geometry-coalescing-230205/`.
No client input or reload was performed. The developer must `/reload` before
testing the candidate. Live stall/recovery acceptance remains pending.
