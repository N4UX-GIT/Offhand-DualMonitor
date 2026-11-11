# Two-second maintenance attribution candidate

Private diagnostic follow-up to the Retail capture's 75 >1 ms ticks in 150 seconds.
This candidate measures the six existing maintenance operations in their original
order without changing their two-second cadence, recovery guards or behavior.

Core/SeamRedirect advertises private timing capability version 1. Without the
temporary recorder, the original maintenance path executes. During `/ohperf start`,
the separate collector registers its recorder on the addon namespace only when
that capability and debugprofilestop are available and no recorder already owns
the slot. It measures each call's elapsed milliseconds, count, maximum, >1 ms
count and first 64 samples. It does not suppress errors, execute operations twice,
reset the profiler or attach code to native frame trees. Capture stop/logout/
duration expiry removes only its own recorder. Another owner is preserved.

These timings include called work and timing overhead; they are not a new
measurement of uninvolved native UI or a promise of zero taint. Compare the phase
timings to the observed two-second pattern before changing production behavior.

Automated evidence: all 55 Lua suites and six manifests pass. Regression covers
phase order, existing cadence, recorder lifecycle, one execution per call,
propagated errors, sample bounds and ownership-safe cleanup.

## Installed Retail candidate

With WoW closed, installed and hash verified three files:

- `Offhand/Core/SeamRedirect.lua`, timing gate only.
- `OffhandPerformanceProbe/Probe.lua` and its TOC.

Backups were verified before replacement at
`D:/Games/World of Warcraft/_offhand_deploy_backups/performance-phases-20261025-023943-756`.
SavedVariables, Companion and other clients are unchanged. Earlier bag-allocation
and proxy-layout performance candidates were not installed. Rollback consists of
closing WoW and copying these three backed-up files to their original locations.

## One capture

1. Launch Retail with Offhand and Offhand Performance Probe enabled. Leave the
   old Offhand Display Probe disabled. Use the same character and ordinary
   window as the preceding comparison, without spanning or graphics changes.
2. Enter the world and wait 30 seconds for startup to settle.
3. Run `/ohperf start maintenance`. Confirm chat says `Maintenance timing: active`.
   If it reports unavailable, stop and report that before continuing.
4. Open the AddOn List, keep the game foreground and scene unchanged for 60
   seconds, then run `/ohperf stop`.
5. Exit normally and report Done. Read the newly saved capture after shutdown.

Live phase attribution is pending. No further production optimization is claimed
or deployed by this timing candidate.
