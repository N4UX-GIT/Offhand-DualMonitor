# Custom workspace regions: initial source study

1 November 2026. Evidence: local source and simulated regression cases only.
No native WoW partial-span result or schema 2 implementation is claimed.

2 November follow-up: Retail `12.1.5.70688` reported a matching `4000x2560`
surface after spanned reload, but its geometry diagnostic selected the existing
FancyZones manual canvas (`companionTopology=false`). This establishes neither
direct Companion-topology consumption nor the motivating `4080x1440` partial
window. See [the exact live evidence](COMPANION-RC3-RETAIL-LIVE-20261102.md).
Future acceptance must record geometry source as well as READY/dimensions.

A later Retail run selected Companion through supported Window Setup and
confirmed `companionTopology=true`, writer `2.1.3-beta.1`, READY and a matching
viewport on the existing full two-display surface after cold relaunch. This
closes the geometry-source ambiguity for that baseline only. Direct-mode reload
was interrupted by an unexplained disconnect, and the `4080x1440` partial-window
reporting gate remains untested. The original manual profile was restored.

## Recommended implementation order

Prepare and validate the existing Companion changes first. Then pursue the
contiguous single-display schema 1 fast path in sections 4.2 and 5.0.1 of
CUSTOM-WORKSPACE-REGIONS-IMPLEMENTATION-PLAN.md. Keep general schema 2 regions
as a separate increment. The feature branch still starts from stabilized,
tested main when the plan's entry criteria are met.

## Verified source boundaries

| Area | Current source behavior | Work required |
| --- | --- | --- |
| `MonitorSelection.CreatePlan`, Program.cs | One or two displays; one-display plan always divides the entire display equally | Add validated occupied width/edge, workspace width and game side, preserving existing defaults |
| `CompanionTopologyBridge.TryWrite` / `IsCurrent` | Writes schema 1 and normalizes rectangles to plan bounds, including Windows top-origin to Lua bottom-origin conversion | Reuse for contiguous partial span; test both edges, both game sides and negative monitor origins |
| `InvokeSpanWoW` | Native clipping is built from complete selected display rectangles | Construct clipping from actual game/workspace rectangles before partial plans can be applied |
| Span failure path | Candidate continuation now captures file bytes, native bounds/style, placement and a copy of the prior region before mutation | Validate rollback on actual WoW clients, including minimized/maximized states, asynchronous changes and application-sharing layouts |
| `Viewport:GetCompanionTopology` | Accepts only schema 1 and requires physical/canvas agreement | Keep strict matching; establish actual partial-window reporting per client before enabling the feature |
| Viewport/canvas placement | Singular workspace bounds and canvas remain central | General regions need collection helpers, primary aliases, per-region canvases and persistence migration |
| Preferences | Candidate now stages and flushes UTF-8 settings, then atomically replaces the destination without a truncating fallback | New region/partial records still need a versioned schema, validation and migration |

The rollback requirement is not already met merely because generated-file writes
use a temporary file and replacement. File atomicity and native-window rollback
are separate responsibilities.

Same-day continuation implements an operation-level rollback snapshot in the
ordinary Companion span path. x64/x86 synthetic windows pass 113 assertions each
for failures after file writing, style, clipping, resize and verification, with
both absent and complex preexisting regions. Raw file bytes are restored and
detected external file changes are preserved. This advances a shared stability
prerequisite; custom sizing is still absent and WoW rollback acceptance is pending.

## Schema 1 characterization result

Added four cases to `tests/companion-topology.lua` using game `(640,0,3440,1440)`
and workspace `(0,0,640,1440)` in a `4080x1440` occupied window:

- Matching physical and canvas dimensions: READY.
- Full `5120x1440` monitor reported with a `4080x1440` canvas: MISMATCH.
- Full-monitor canvas with partial physical dimensions: MISMATCH.
- Restored game-only window: MISMATCH.

This supports the existing schema's rectangle contract under matching reports.
It does not prove that a live client reports the occupied window as its physical
surface. If a client keeps reporting the full monitor, stop at this gate and
follow the plan's fallback rather than weakening validation.

The example uses 5,875,200 backing pixels instead of 7,372,800 for the full
5120x1440 monitor, a geometric reduction of 20.3125%. This is not a measured GPU
or frame-rate improvement. Excluded pixels must remain available to Windows
applications in live testing.

## First implementation slice and acceptance

1. Add a pure partial-plan builder and validation tests for minimum widths,
   oversize/invalid values, edge/side combinations and monitor identity changes.
   Choose and document usable minimums before wiring the editor.
2. Build the topology/native transaction and failure-injection tests. Preserve
   prior file bytes, window region, bounds and style on every failure path.
3. Add isolated opt-in settings and a numeric preview. Keep default two-display
   and equal-half modes unchanged. Editing a pending plan does not resize WoW.
4. Validate on an actual 5120x1440 monitor with a 4080-wide WoW window. Record
   exact client/build, physical and UI dimensions, reserved-app interaction,
   cold launch, reload, restore, hotplug, mixed DPI and Forever recovery.
5. Only after this slice is accepted, introduce schema 2 capability negotiation,
   stable region IDs, primary aliases, placement/migration and multi-region UI.

Schema 2 release testing must also cover older Companion/addon pairings, malformed
topology and missing displays. Current rejection of non-1 schemas as ABSENT is
not proof of an adequate future capability-negotiation contract.
