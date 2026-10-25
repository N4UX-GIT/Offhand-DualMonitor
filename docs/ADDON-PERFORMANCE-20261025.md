# Addon performance investigation

Status: source audit and first synthetic allocation comparison complete. Live CPU,
frame-time and periodic-stutter attribution remain unmeasured. User acceptance of
other addon fixes does not establish performance.

## Initial audit

| Recurring work | Cadence | Finding |
| --- | --- | --- |
| BagPersistence capture | 0.2 s | Replaced an empty saved-state table on every resumed idle poll; candidate now retains an already-empty table and clears stale intent once |
| Chat bubble replacement | 0.1 s, plus chat events | Candidate for real profiling in busy scenes; do not remove the sweep without testing bubble lifecycle and fading |
| Edit Mode recovery | 0.25 s, also called by 2 s popup pass | Possible redundant work; pending actual inclusive CPU/call counts |
| Forever bag observer | Every rendered frame, no elapsed-time throttle in this callback | Geometry checks and addon-owned proxy layout repeat even for a settled visible bag; preserve first-frame correction while evaluating redundant work |
| Workspace behavior | 0.5 s | Character scale and lock recovery; compare feature-off and feature-on cases |
| Workspace chrome | 1 s | Known bounded registry, no recurring global scan; opted-in hidden buttons still receive writes each refresh |
| Transient panels/popups | 2 s | Discovery/positioning/recovery; investigate cost with many loaded UI addons |
| Forever panel observer | 0.5 s | Professions/chat/Edit Mode transition checks; ordinary idle path often returns early |

Global scans still exist in bounded discovery/startup/diagnostic paths. Presence
of `pairs(_G)` is not proof that it runs periodically. Existing regression confirms
no repeated global bag scans when Baganator is absent.

## Reproduced allocation issue

The existing bag-discovery test originally left BagPersistence paused. Expanded
coverage explicitly resumes the simulated gameplay observer, then runs 4,500 polls
(15 minutes at five polls/second). Garbage collection is stopped only inside this
standalone test so allocation is visible; the addon never changes GC behavior.

- Before: 4,500 snapshot replacements, approximately 421.9 KiB allocated.
- Candidate: zero empty snapshot replacements, approximately 281.3 KiB allocated.
- Difference: approximately 140.6 KiB in this synthetic workload, about 33% of its
  measured allocation. This is a small absolute cost.
- Recorded CPU time was approximately 4-5 ms for the complete synthetic loop,
  within coarse local timing variation. No CPU or FPS improvement is claimed.
- Last-bag close still clears stale open intent; existing visible bag, reload,
  Escape and compatibility suites must continue passing.

This does not establish the cause of the historical one-second frame-time spike.
Keep optimization separate from the accepted stabilization merge.

## Live measurement package

Temporary standalone addon: `tools/performance/OffhandPerformanceProbe`. It is not
in the shipped Offhand package. Copy that folder beside Offhand in AddOns when
ready to test, and remove it afterwards. It writes only its own SavedVariables,
keeps six results, and does nothing per-frame until `/ohperf start LABEL`.

It prefers C_AddOnProfiler when available, recording Offhand-specific raw
milliseconds, slow-tick counters, all-addon/application recent metrics and the old
display probe separately at half-second intervals. It never enables profiling,
resets global CPU counters, hooks Blizzard frames or mutates Offhand. Modern
captures do not require scriptProfile. Legacy aggregate CPU counters remain a
fallback only when the client provides them and scriptProfile is already enabled.
If unavailable, CPU is reported unavailable rather than zero. The observer adds
overhead; compare identical instrumented sessions. Do not change scriptProfile
for this Retail capture.

1. Record actual build, topology, addon commit and enabled compatibility addons.
   Fix render scale, VSync, foreground state, camera and scene for each pair.
2. After warm-up, run `/ohperf start idle-accepted` for 15 minutes, then
   `/ohperf stop`. Repeat with the performance candidate and the same setup.
3. Compare bags closed versus open, idle versus busy chat, lock/chrome features
   off versus on, and normal UI versus Gamepad. Exercise map/bag actions in a
   separate short capture to keep startup/action spikes out of idle results.
4. If investigating client-wide stutter, compare Offhand enabled/disabled while
   holding Companion and window geometry constant. The observer stays enabled.
5. Exit normally to save results. Compare Offhand CPU ms/s, memory endpoints and
   whole-client frame counts/max interval. Memory endpoints do not measure total
   allocation or GC cost. Frame intervals describe all client work, not Offhand
   alone. Counter resets invalidate CPU deltas.
6. Use the client's profiler, where present, to attribute expensive functions and
   correlate periodic spikes before reducing polling or removing recovery checks.

No live capture was performed as part of this source audit. Forever live testing
remains deferred under the user's release plan; Retail/Anniversary can provide an
earlier baseline when the user is ready. No diagnostic addon was installed into
a game client by this change.

## Deeper review, 25 October

Reproducible characterization: run `tools/performance/Measure-MockedWork.ps1` from
PowerShell with Lua 5.1 available. It appends counters to the existing functional
mocks in temporary files and exercises the actual module code. It does not hook
the live client, modify production source or treat mocked time as measured CPU.

| Steady-state scenario | Measured mocked work | Interpretation |
| --- | --- | --- |
| One native Forever bag shown, 600 observer frames | 1,200 viewport metric reads, 1,800 addon proxy layout writes, zero native bag anchor writes | Two geometry calculations per frame and three proxy layout writes per frame; prioritize idempotent proxy updates and callback-local geometry reuse |
| One already-hidden map close button, 600 chrome refreshes | 600 SetAlpha calls and 600 EnableMouse calls for that button | Reassertion protects against native/skin refreshes, but property comparison may avoid unchanged writes without removing enforcement |

The native bag root already has a coordinate-tolerance no-op check. The redundant
writes are on the addon-owned drag proxy, not evidence of repeated protected bag
reanchoring. Preserve that ownership distinction. The native bag observer is truly
per-frame; the previous inventory incorrectly described an internal cadence.
The Gamepad observer does throttle substantial panel work, although interface
mode detection still happens each frame.

Viewport GetMetrics constructs a new metrics table and validates current geometry
on each call. Cross-callback caching is risky because resizing, UI scale, profile,
manual calibration and Companion topology can all change. Begin with reuse inside
one synchronous observer pass, with no change in stale-state lifetime.

### Recommended coverage order

1. **Inactive versus active work:** disabled addon, single-screen fallback, no
   bag addon, native bags hidden/shown, custom bag provider, settings closed/open,
   Gamepad off/on and no speech bubbles versus a busy chat scene. Assert fixtures
   reach the active callback; the original paused-bag test demonstrated why this
   matters.
2. **Redundant writes:** count proxy SetPoint/SetSize, visibility changes, button
   alpha/mouse writes and repeated scale application in settled scenes. After
   optimization, disturb geometry/skin state and ensure one prompt repair still
   occurs. Preserve immediate bag opening correction and drag responsiveness.
3. **Lifecycle and scheduling:** repeated initialization and show/hide, event
   bursts, reload/profile changes, combat entry/exit, cancelled/superseded timers,
   retry ceilings and display-transition guards. Detect duplicated tickers and
   cumulative callbacks, not just whether the final UI position is correct.
4. **Allocation and persistence:** closed versus visible bag capture, saved-state
   writes when unchanged, bubble creation/fading/pooling, geometry objects and
   repeated serialization. Inspect operation/allocation counts separately from
   end-of-session memory, which can conceal GC churn.
5. **Representative live profiling:** stable 15-minute idle pairs, busy chat,
   repeated panel actions and a combat/group scene on available clients. Compare
   Offhand CPU per second and client frame intervals with identical profiling,
   render settings, display geometry and scene. Use function-level profiler
   evidence to prioritize any larger rewrite. Final Forever-client runs remain
   deferred as instructed.

### What to change first, and what to leave alone

- Keep the small empty-snapshot allocation candidate; it has a targeted regression
  and does not alter observation cadence.
- Next low-scope candidate: skip unchanged addon-owned proxy layout writes while
  still detecting size, scale and position changes. Add characterization before
  editing the controller. No additional runtime optimization was made in this pass.
- Consider guarded chrome writes and synchronous geometry reuse after verifying
  property reads do not cross secret/protected boundaries on target clients.
- Do not blanket-throttle every OnUpdate, introduce long-lived geometry caches,
  force garbage collection, disable recovery, or claim performance from timer
  counts alone. Source frequency and mocked counts are prioritization evidence;
  they do not establish a live bottleneck or explain the historical 1 Hz spike.

Recommendation: proceed with deeper targeted performance coverage. It is distinct
from reopening the accepted functional fixes or conducting another broad refactor.

## Drag-proxy layout optimization candidate

The next targeted candidate is now implemented in Core/CanvasForeverBags.lua.
The addon-owned grip compares its actual anchor and dimensions against the desired
geometry before writing. It still checks each rendered frame; no timing, native
bag ownership, protected tree, recovery or persistent-state contract changed.
No per-frame helper closure or long-lived geometry cache was introduced.

Mocked steady-state measurement over 600 frames:

- Proxy ClearAllPoints/SetPoint/SetSize writes: 1,800 before, zero after.
- Native bag anchor writes: zero before and after.
- Viewport metrics reads: 1,200 before and after; geometry reuse remains separate.

The regression first failed on the old implementation. It now verifies zero
settled writes, immediate drag movement, size-only resizing, effective-scale
updates, recovery from displaced anchors and changed dimensions, and reopening a
hidden grip. All 55 Lua suites, six manifests and Lua 5.1 syntax checks pass.
These are automated/mock results. Live CPU/FPS/taint behavior is not inferred;
Forever runtime checks remain deferred until the release as instructed. No game
installation or public package was changed. This stays in draft performance PR #36.

## First live Retail capture result

The user's saved paired captures are analyzed in
PERFORMANCE-CAPTURE-RESULTS-20261025.md. Offhand's sampled recent mean is about
0.043453 ms, with 75 new >1 ms ticks in 150.446 seconds and no new >5 ms ticks.
Counter-increment spacing has a 2.000-second median. Both disabled runs report
zero recent Offhand time and no new >1 ms ticks. Historical peak and >5 ms counts
were already present before recording and did not increase.

This narrows investigation to periodic work, led by the two-second maintenance
pass. Individual phases remain unmeasured. Application-time distributions and run
lengths differ, so no FPS causation is inferred. Next is phase-level timing in a
private diagnostic candidate, preserving order and recovery behavior.
