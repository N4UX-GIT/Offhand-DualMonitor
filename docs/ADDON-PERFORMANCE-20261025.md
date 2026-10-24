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
| Forever bag observer | OnUpdate with internal cadence | Required visibility/input reconciliation; profile while bags closed/open and in Gamepad before altering |
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

It reads existing aggregate CPU/memory APIs when available and never enables
profiling, resets global CPU counters, hooks Blizzard frames or mutates Offhand.
For CPU evidence, manually enable `/console scriptProfile 1`, reload, and retain
the same profiling setting for every paired comparison. If unavailable, CPU is
reported unavailable rather than zero. Profiling and the observer add overhead;
results apply to the instrumented session. Restore the original profiling setting
afterwards and reload.

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
