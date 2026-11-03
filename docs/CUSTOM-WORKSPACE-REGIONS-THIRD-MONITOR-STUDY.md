# Third-monitor support study

3 November 2026. Investigated at the user's request after the consolidated P6
Retail/Anniversary checks. Scope is source analysis and characterization tests.
No third workspace, schema 2 reader/writer or new editor is enabled by this work.

## Finding

A third **connected** desktop monitor is compatible with the present design when
only two displays participate in WoW. Either non-game display can be the one
workspace. A third **participating** monitor, giving one game view and two
independent workspaces, requires the multi-region extension in the implementation
plan. The recommendation is to build that bounded one-game/two-workspace slice
first, retaining schema 1 for existing layouts.

This is technically plausible using the current single native WoW window and
rectangular game viewport. It does not require an extra WoW window or another 3D
view. Real three-monitor rendering, interaction and recovery are unverified.

## Current boundaries, traced through source

| Layer | Current contract | Change required for two workspaces |
| --- | --- | --- |
| `Companion/Source/Program.cs`, MonitorSelection.CreatePlan | Refuses more than two selected displays; one WorkspaceIndex and WorkspaceBounds | Region collection with stable IDs, one game rectangle, one primary workspace |
| WorkspaceAreaDialog / WorkspaceAreaOverlay | One freely movable/resizable rectangle tied to one secondary display | Reuse the selection model separately for each workspace; select which monitor/region is being edited |
| VisibleRectangles / SpanClipRegion | Enumerates exactly game plus workspace; ORs their native regions | Enumerate game plus every valid workspace; retain holes and transaction ownership/rollback |
| CompanionTopologyBridge | Writes schema 1 with singular workspace; existing protocol metadata is not a schema 2 capability declaration | Add schema 2 and explicit installed-addon capability check before writing/moving WoW |
| `Core/Viewport.lua` | Accepts schema 1 only; exposes one workspace bound set | Strict schema 2 validation, workspace collection and primary aliases; preserve schema 1 path |
| `Core/Canvas.lua` | One root OffhandCanvasFrame and Offhand.canvas alias | One background per workspace; retain primary alias for compatible consumers |
| CanvasPersistence / panel placement | Saved canvas origin/size, one clamp rectangle | Region ID and region-relative coordinates; copy-preserving opt-in migration |
| PopupBounds / SeamRedirect / recovery / map / bags / chat | Membership and rescue against one workspace | Central region selection helpers; preserve frames in any valid region and clamp to a single destination |
| `Core/Config.lua` Forever W4 records | No workspace identity | Versioned compact extension with W/W2/W3/W4 readers retained; dedicated Forever validation |

Removing the selected-display limit alone would be incorrect. The writer and
canvas would still describe just one workspace, while backing bounds could
include the third display. Using one large workspace bounding rectangle would
also create false workspace membership across the game or reserved desktop holes.

## New characterization evidence

Run `tests/companion-third-monitor.ps1`. It compiles the unchanged production
Program.cs with `CompanionThirdMonitor.cs`, for both x64 and x86. Each architecture
passed 40 checks covering:

- Three connected displays with either left or right workspace selected.
- Stable identity under enumeration reorder.
- Removing an unselected display without invalidating the chosen pair.
- Refusing loss of the selected workspace rather than substituting the spare.
- Production native clipping includes game/workspace sample points and excludes
  unselected-display and reserved-strip sample points.
- A nonparticipating display between the two selected displays remains a hole
  in the native clip, even though it lies inside the outer bounding rectangle.
- Generated schema 1 bridge omits the unselected display.
- Three selected displays and implicit select-all are refused. Rejected custom
  Save leaves the prior preferences bytes intact.

These are synthetic display lists and actual GDI region operations. They do not
resize a window, simulate a third connected device, prove real input pass-through
or establish three-monitor WoW rendering support. Existing preference tests also
cover the explicit three-selection refusal.

## Proposed first implementation

Use one full game monitor and up to two workspace rectangles, each initially on a
different non-game display. Permit full-display presets or custom partial areas.
Keep multiple rectangles on one monitor and arbitrary region counts for later,
while using a collection internally so that extension does not require another
topology redesign.

The Companion should present an optional workspace list with Add workspace,
Edit area, Make primary and Remove actions. Each Edit area opens the familiar
drag/move/resize overlay on that workspace's monitor. Use selection returns to
the editor; Save stores a validated plan; explicit Span applies it and requests
one reload when needed. Editing never silently moves a running WoW window.

Each record needs a stable internal region ID, display identity, monitor-relative
physical rectangle and last validated dimensions/orientation. Names and list
positions must not become persistence keys. Duplicate or ambiguous display
identities must refuse apply and request review. Current DeviceID/DeviceKey
matching handles tested renumbering; port changes, identical monitors and docks
remain an identity gap. Evaluate active display paths and device information
before choosing a stronger identity contract, rather than promising permanent
hardware identity from DISPLAY numbers.

Schema 2 should contain one game rectangle, a nonempty workspaces array and a
primaryWorkspace ID. Validate unique IDs, finite integer coordinates, positive
minimum sizes, containment in selected physical displays, no game/workspace or
workspace/workspace overlap, bounding limits and a resolvable primary. Derive
window-relative top-origin clipping and bottom-origin Lua rectangles from the
same validated desktop geometry. Keep workspaceLeft/Right/Top/Bottom aliases for
the primary workspace only.

Introduce an explicit TOC topology-capability field, for example
`X-Offhand-Topology-Schemas: 1,2`, alongside existing protocol/min-version checks.
Absent schema 2 capability must refuse a multi-region apply **before** bridge
write or native mutation. The current addon reports unknown schemas as ABSENT
and can use a confirmed manual canvas, so relying on its parser to rescue a new
Companion would be unsafe. Preserve schema 1 output and existing user preference
behavior for ordinary modes. Test downgraded Companion/config combinations too;
unknown-key preservation alone does not prove safe downgrade behavior.

For frame placement, default unsaved panels to the primary region. At drag stop,
choose the region containing the frame centre, then greatest overlap, then a
deterministic primary fallback. Resolve Mainhand separately. Save the chosen
region ID and relative position only after a valid placement. A frame larger than
the destination needs the existing supported fit policy or an explicit fallback;
never scale protected descendants indiscriminately.

Copy legacy placement records during explicit schema 2 activation; preserve the
original until the migrated placement succeeds. Keep schema 1 profiles untouched.
Removing a workspace must offer a destination for its saved frames. On missing
required hardware, initially restore to Mainhand and retain the entire plan and
positions, following current fail-closed behavior. Reconnection requires explicit
review/apply, not an automatic collapse onto whichever monitor remains.

## Cost and platform limits

The one window still has an outer rectangular surface. Clipping holes does not
establish a smaller swapchain or an FPS improvement. Show both selected visible
pixels and outer-bound pixels before apply. The examples below are arithmetic
for synthetic layouts, not measurements of a running renderer. Mainhand is
2560x1440, and the left workspace is 1440x1440 at `(-1440,0)`.

| Arrangement | Outer bounds | Visible pixels | Outer pixels / game pixels |
| --- | --- | --- | --- |
| Current two-region reference | 4000x1440 | 5,760,000 | 1.56x |
| Extra 1920x1080 workspace immediately right | 5920x1440 | 7,833,600 | 2.31x |
| Extra 1920x1080 workspace immediately above game | 4000x2520 | 7,833,600 | 2.73x |
| Small 480x600 workspace at `(20000,-600)` | 21920x2040 | 6,048,000 | 12.13x |

The existing 32768 planner-axis guard is not a proven WoW rendering limit.
Microsoft documents 16384 Texture2D dimensions for Direct3D 11 feature level 11;
that does not identify this client's swapchain format, renderer path, feature
level or allocation budget. Establish conservative renderer-aware limits and a
pixel budget with real targets. Do not accept a distant region solely because
its selected rectangle is small or GDI can represent it. Proposed 2x/3x/4x warning
thresholds in the main plan remain provisional.

## Delivery order and acceptance

1. Add schema 2 validation, capability gating, central geometry helpers and
   primary aliases behind an inactive feature path. Test schema 1 parity,
   malformed input, version skew and rollback without exposing the editor.
2. Add two workspace canvases and region-aware placement/persistence. Test centre,
   overlap, holes, migration, missing IDs and all primary-only consumers before
   enabling any multi-region apply.
3. Add one-game/two-workspace planning and per-monitor overlays. Keep initial
   custom layouts manual-only. Verify Save against current display identity,
   atomic writes, exact clipping and full native/topology rollback.
4. Use real three-display hardware for apply/reload/cold restart, frame dragging
   and persistence in each workspace, taskbar samples on each participating
   monitor, excluded-area interaction, Restore, per-display disconnect/reconnect,
   DPI/orientation changes and duplicate-monitor identity cases.
5. Exercise protected descendant actions in/out of combat with human input and
   current error/taint evidence on each supported client. Keep Store/Wine claims
   gated by their own packaged/runtime checks.

The current source reconciliation, two-display review candidate and this study
are ready for review. Third-workspace implementation is the next separate scope;
this investigation does not waive the stabilization and release gates in the
existing implementation plan.

## Evidence and references

Local authority: addon integration commit `2898270`; unchanged Companion runtime
source at `4a27ed0`; the source paths above; the new tests; and the separate
[consolidated Retail/Anniversary QA](CUSTOM-WORKSPACE-REGIONS-CONSOLIDATED-QA.md).
No third display is physically connected in this test setup. Shared knowledge
status/ask returned general ownership guidance and an exact-native evidence gap.

Microsoft primary references consulted 3 November 2026:

- [CombineRgn](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-combinergn)
  supports union of region handles, including complex regions.
- [SetWindowRgn](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowrgn)
  defines window-relative coordinates and system ownership after success.
- [CreateRectRgn](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-createrectrgn)
  documents GDI coordinate representation, distinct from renderer limits.
- [QueryDisplayConfig](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-querydisplayconfig)
  and [DisplayConfigGetDeviceInfo](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-displayconfiggetdeviceinfo)
  provide active paths/device information; identity improvements remain a proposal.
- [Direct3D 11 resource limits](https://learn.microsoft.com/en-us/windows/win32/direct3d11/overviews-direct3d-11-resources-limits)
  support the resource-limit caution, not an exact WoW maximum.
