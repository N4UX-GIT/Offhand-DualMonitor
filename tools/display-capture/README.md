# Temporary display-reset capture

This observes one Graphics Options change. It does not install another Companion,
recover the span, change CVars, hook Blizzard controls or record screenshots/chat.
The temporary addon works alongside the existing Offhand version and can also run
with Offhand disabled. It saves only two bounded diagnostic captures in its own
SavedVariables file. Disable/delete the probe after investigation.

## Install once

Close WoW normally, then run `Install-Probe.ps1`. This copies the separate
`OffhandDisplayProbe` addon into the known Retail, Era and Anniversary clients.
No existing Offhand files or saved settings are replaced.

## One capture

1. Launch WoW with Offhand, Companion and Offhand Display Probe enabled. Start from
   the working span with VSync **Enabled**, using Graphics Options before spanning
   if needed. Keep other settings unchanged. Record which client/build is tested.
2. Open `Start-Capture.cmd`. Leave the window running and return to WoW.
3. Enter `/ohcapture start`.
4. In Graphics Options, change VSync from **Enabled** to **Disabled**, exactly as
   in the failing test. Take a result screenshot. Do not re-span yet.
5. Enter `/ohcapture stop`. The Windows observer stops after three minutes; let it
   finish or press Ctrl+C in its window. Only then use Span WoW Now to recover.
6. Exit WoW normally to flush the addon log. Do not restart another capture before
   collecting this one. A hang may prevent the addon log from saving; the external
   observer flushes each record independently.

## Results

- Native log: `D:\Tools\Code\Offhand\dist\display-captures\window-*.jsonl`.
- Addon log: the tested client's `WTF\Account\<account>\SavedVariables\OffhandDisplayProbe.lua`.
  The temporary addon does not record account or character names in its contents.
- Also retain the result screenshot and Companion activity log around the test.
- Logs share UTC timestamps. Native observations sample every 250ms, write on
  change plus a one-second heartbeat, and include window/client bounds, style,
  clipping-region bounds/count, layered attributes, responsiveness and monitors.
- The addon records selected graphics CVars, relevant events and canvas/Offhand
  metrics, with 250ms sampling, a five-second heartbeat and a three-minute limit.

No claim of native runtime, taint safety, or graphics-reset correctness follows
from parser, mock or interop self-tests. Captures can miss sub-250ms transitions.

## Map-opening variant

For a map-related reset, leave graphics settings unchanged and open the map once
in step 4. The updated probe source records native map lifecycle callbacks and
map/world/UIParent rectangles only during an active capture. These callbacks are
removed when recording stops. Retain `Logs/gx.log` before another launch replaces
it. See `docs/MAP-SPAN-RESET-20261028.md` for the established device-recovery
evidence and the remaining trigger question.
