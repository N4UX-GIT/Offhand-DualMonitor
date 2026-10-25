# Retail CPU capture results, 25 October 2026

Source: the user's normal-exit OffhandPerformanceProbe SavedVariables, copied to
local `dist/performance-captures-20261025/OffhandPerformanceProbe.lua`. SHA-256:
`485CA3876BBF3E14ECD01E3DCE6708EF9EAB440C7988C86F68633B3E4208E488`.
Raw account data and captured desktop images are not part of the repository.

Client: Retail 12.1.5 build 70575, interface 120105. Three captures are present:

| Capture | Duration | Modern samples | Offhand sampled recent mean | Sampled recent maximum | New ticks >1 ms | New ticks >5 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| offhand-on | 150.446 s | 301 | 0.043453 ms | 0.092797 ms | 75 | 0 |
| offhand-off | 40.208 s | 81 | 0 ms | 0 ms | 0 | 0 |
| offhand-off | 32.458 s | 66 | 0 ms | 0 ms | 0 | 0 |

The on-run's Offhand LastTime sampled maximum is 1.9413 ms. Sampling every half
second does not guarantee capturing the largest individual tick. The built-in
28.4913 ms Offhand peak and two >5 ms ticks were already present at the start and
did not increase during any capture. Do not attribute those historical peaks to
this capture or interpret them as current sustained CPU usage.

## Main finding

The 75 new >1 ms Offhand ticks occur at approximately two-second intervals across
150 seconds. This is strong timing evidence for a recurring Offhand workload,
not simply percentage rounding. The data identifies the cadence and addon;
individual functions are not measured by this capture.

The installed Core/SeamRedirect.lua has one persistent two-second maintenance
ticker containing these phases:

1. RedirectExternalPopups (including a broad child rescue only when spanned).
2. HookMainhandTransientFrames (discovery and load-on-demand hook checks).
3. PositionMainhandTransientFrames.
4. CheckEditModeHooks.
5. UpdateForeverEditModeControlsRecovery.
6. UpdateForeverPartyFrameRecovery (the name also covers modern Retail).

This is the leading source candidate, not a function-level proof. The broad
UIParent scan returns early when unspanned; do not remove or blame it solely
because it shares the cadence. Several phases return cheaply depending on mode,
while discovery and geometry checks may still run in an ordinary window.

## Interpreting the display

The sampled AddOn List header percentage averaged 0.229238% with Offhand on,
versus 0.074008% and 0.059202% in the two off runs. Its on-run sampled maximum was
0.629852%. These are all-addon/application ratios, not Offhand-specific percent.
The old Offhand Display Probe's recent metric was zero throughout the captures.

Application recent times varied substantially, including samples near 32.78 ms.
The runs have different lengths and different application-time distributions.
Therefore they do not establish a controlled FPS gain/loss from Offhand. The
0.043453 ms number is a mean of rolling averages sampled over time, not an exact
total CPU accumulator or a Windows processor-utilization measurement.

The counters also persist historical data across these recordings. Compare
start/end deltas, not absolute totals or assumptions that every reload resets
the application profiler.

## Next targeted experiment

Instrument the individual phases of the two-second maintenance pass in a private
diagnostic candidate. Measure calls, elapsed time, maxima and allocations where
available; preserve phase order, guards, native-frame ownership, retry behavior
and cadence. Start with the same ordinary-window idle scene, then spanned idle.
Do not disable safety recovery or globally slow observers merely to reduce the
percentage display. Any change should target a measured phase and retain its
functional regression coverage.

The initial measurement objective is complete: Offhand has a modest average cost
with a verified periodic >1 ms contribution. The exact costly phase and any
relationship to earlier visible stutter remain unresolved. No further runtime
optimization or client installation was performed from this result alone.

Reproduce the summary with:

```powershell
lua tools/performance/Analyze-Captures.lua dist/performance-captures-20261025/OffhandPerformanceProbe.lua
```
