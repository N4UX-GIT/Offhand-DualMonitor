# Retail maintenance attribution and controller detection candidate

## Live evidence

Retail 12.1.5 build 70575, interface 120105. Capture `maintenance` lasts
71.720 seconds and contains 35 maintenance cycles. The profiler records 35 new
ticks over 1 ms, zero new ticks over 5 ms, and no increase in the historical peak.
The source capture is preserved locally in
`dist/performance-maintenance-20261025/OffhandPerformanceProbe.lua`.

| Phase | Mean ms | Maximum ms | Calls over 1 ms |
| --- | ---: | ---: | ---: |
| Party recovery | 1.483729 | 2.818300 | 35 |
| Popup rescue | 0.052534 | 0.065000 | 0 |
| Transient discovery | 0.046200 | 0.062800 | 0 |
| Transient placement | 0.015586 | 0.023900 | 0 |
| Edit Mode recovery | 0.007186 | 0.008300 | 0 |
| Edit Mode hooks | 0.002003 | 0.002900 | 0 |

Each phase was called 35 times. This isolates the recurring workload to party
recovery; it does not establish FPS impact or explain an unrelated client hang.

## Source finding and candidate

Party recovery checks controller mode on every maintenance cycle. Previously,
`Mainhand:IsControllerLayout()` obtained full preset copies merely to read the
first preset's `interfaceStyle`. Blizzard's implementation of
[`GetCopyOfPresetLayouts`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_EditMode/Shared/EditModePresetLayoutsManager.lua)
uses `CopyTable(self.presetLayoutInfo)`.

The client adapter now reads that single scalar when the expected table and enum
are available. It does not cache the value, write native state, retain the table,
or traverse systems. ConsolePort/native Gamepad detection remains first. Missing
capabilities use the previous copy-based fallback. Forever returns to the existing
fallback before touching the native table, preserving its ownership boundary
until release-client testing is available. Layout creation still uses copies.

The expensive copy is the source-based explanation to verify with the matched
repeat. Live improvement is not yet established.

## Validation and installed scope

All 55 Lua suites, six manifests and Lua 5.1 syntax validation pass. The new
regression covers 450 unchanged checks without copies, immediate Gamepad and
keyboard transitions, missing-table fallback, and a native-table access trap on
Forever. No recovery cadence, frame positioning or saved-state contract changes.

With WoW closed, only `Core/MainhandCompatibility.lua` and
`Core/MainhandEditMode.lua` were installed into Retail and hash verified. Their
installed baselines matched source HEAD before replacement. Verified backups:
`D:/Games/World of Warcraft/_offhand_deploy_backups/controller-detection-perf-20261025-031339-405`.
The existing phase collector remains installed for comparison. Other performance
candidates, Companion, other clients and SavedVariables were not deployed.

## Matched repeat

Use the same Retail character, ordinary window and scene. Enable Offhand and
Offhand Performance Probe, leaving the old Display Probe disabled. After 30
seconds, run `/ohperf start maintenance-fixed` and confirm maintenance timing is
active. Keep the AddOn List open and the game foreground for 60 seconds. Run
`/ohperf stop`, exit normally, then inspect the newly saved capture. Compare phase
times and new slow ticks, without treating historical peaks as current events.
