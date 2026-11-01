# AddOn Usage video investigation, 25 October 2026

Source: user-provided `World Of Warcraft 2026.10.25 - 02.43.23.01.mp4`,
24.20 seconds, 2560x1440 at 60 fps. Extracted frames remain local under
`dist/performance-video-20261025`; do not distribute captures of private desktop
or chat context in the addon or release bundle.

## Observed

- Ordinary Retail window in Wingrest Embassy. The clip begins with Offhand,
  BugGrabber, BugSack and the temporary Offhand Display Probe checked.
- First eight seconds sampled every half-second: Current CPU approximately
  0.03%-0.4%, enabled session average approximately 0.4%-0.5%, displayed peak 9%.
  These are sample observations, not a frame-by-frame maximum.
- Offhand is unchecked, the UI reloads, and later samples show Current CPU 0%,
  session average 0.3%, displayed peak 3%. The old Display Probe remains enabled.
- This supports a recurring all-addon cost difference associated with Offhand
  enabled in this scene. It does not identify a function, prove a major sustained
  performance problem or establish a causal connection to earlier stutter reports.
- Installed Offhand is still the accepted development candidate, not the latest
  performance branch: Init/SeamRedirect hashes match but BagPersistence and
  CanvasForeverBags differ. No main-addon update was performed during this review.

## What the UI percentage means

The inspected [Blizzard AddonList Lua implementation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_AddOnList/AddonList.lua)
computes the header as GetOverallMetric(metric)/GetApplicationMetric(metric)*100.
Current uses RecentAverageTime, Average uses SessionAverageTime, and Peak uses
PeakTime. Current is for all user addons, not the Offhand row and not Windows'
whole-machine CPU utilization. Values below 0.01% are formatted as 0%.

The exported [metric documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnProfilerConstantsDocumentation.lua)
defines RecentAverageTime over the last 60 profiler ticks. Both numerator and
denominator change, so even stable periodic addon callbacks produce changing
percentages. Peak is a ratio of separate peak metrics, not proof of simultaneous
9% usage now. Without raw milliseconds, the header cannot establish an absolute
Offhand time budget. The inspected remote source is an exported UI snapshot, not
a verified extraction of this installed executable's precise build.

## Source candidates and limits

- The general popup/transient/recovery pass runs every two seconds. It is a
  candidate for the periodically higher samples, but no function timing has yet
  correlated it with the video. The broad UIParent scan itself exits early when
  metrics are unspanned, so it must not be blamed merely from cadence.
- Chat bubbles poll every 0.1 s; bag capture every 0.2 s; workspace behavior every
  0.5 s; chrome every second. Cheap return paths still incur calls, geometry
  calculation or allocation depending on active settings.
- The recent Forever native-bag proxy optimization is not evidence for this
  normal Retail window: that adapter is Forever-specific and its latest change
  is not installed. Do not promise it resolves this observation.
- No timing change, recovery removal or speculative production optimization was
  made on the strength of the video alone.

## Next matched capture

The user closed Retail normally and the updated standalone
OffhandPerformanceProbe was installed into its AddOns directory. Both copied
files were SHA-256 verified. Offhand runtime/settings and existing SavedVariables
were untouched. Modern API capture, missing-API behavior and the percentage
formula pass mocked tests; all 55 Lua suites pass.

1. Enable Offhand and Offhand Performance Probe. Disable the old Offhand Display
   Probe for this paired comparison. Keep all other addons and graphics/window
   settings the same between runs. No scriptProfile change is needed.
2. Enter the same location and wait 30 seconds for startup to settle. Run
   `/ohperf start offhand-on`, open the AddOn List and leave the scene unchanged
   for 60 seconds. Then `/ohperf stop`.
3. Disable Offhand, reload, and wait 30 seconds. Repeat the same sequence with
   `/ohperf start offhand-off`. Leave Performance Probe enabled in both runs.
4. Stop the second capture and exit normally. The recorder retains its own last
   six results; modern samples include Offhand raw ms, counters and overall/app
   metrics, bounded to 1,802 snapshots per run. Its per-frame callback is removed
   when capture stops. Memory endpoints do not measure total allocation.
5. Read the newly saved OffhandPerformanceProbe.lua after shutdown. Analyze the
   exact build and samples before function-level attribution or further changes.

Status: video interpreted and measurement setup prepared; live per-addon results
pending. The original hang/error report and historical periodic stutter are not
resolved by this evidence.
