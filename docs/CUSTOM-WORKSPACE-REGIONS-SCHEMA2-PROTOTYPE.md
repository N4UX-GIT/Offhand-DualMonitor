# Experimental independent workspaces, Prototype 7

3 November 2026. The user authorized implementation after the third-monitor study
and requested autonomous work while remote until Friday. No question prompts,
physical display changes, combat automation or public promotion are part of this
run. Tests requiring hands-on help remain explicit acceptance gates.

## Implemented scope

Companion version `2.1.3-beta.2`, file/application manifest version `2.1.3.3`,
retains protocol 1. The optional **Multiple workspaces** editor plans one full
game monitor and one or two independent workspace rectangles, each on a different
non-game display. Workspace A/B have separate numeric and movable/resizable visual
selectors; one is primary. Save validates current connected displays and only
stores preferences. Manual Span applies; one reload is required for a loaded UI.
Custom layouts remain excluded from auto-span and graphics-reset recovery.

Existing full-display, equal-half, single-monitor partial and secondary-area modes
retain schema 1. Selecting either older editor disables the multi-region mode.
Disabling multiple workspaces returns its selected game/A pair to a standard
two-display plan. Unused region settings are retained, not erased.

Schema 2 plans require explicit installed-addon metadata
`X-Offhand-Topology-Schemas: 1,2`. An old addon refuses the new handoff before
bridge write or native mutation. All six new TOCs advertise the reader. Plan
preferences contain all selected identities, so an old Companion refuses a
three-display plan instead of silently dropping a workspace. Existing one-region
schema 2 plans use the same two-display compatibility boundary; downgrade to the
explicit schema 1 editor before using an old Companion.

The planner rejects missing or ambiguous identities, reused physical displays,
duplicate region IDs, overlap, invalid dimensions, stale resolution and divergent
selected-monitor lists. A missing saved display is not silently substituted in
the editor. Initial allocation guardrails are 16384 pixels per bounding axis and
four times the game rectangle's area. These conservative prototype limits do not
claim the client's renderer supports every accepted size. Preview distinguishes
visible area from outer surface and reports increasing cost above 2x/3x.

Native clipping is the exact union of game and all workspaces. The existing
transaction still owns topology, bounds, style and HRGN rollback. Shell fullscreen
marking retains the P6 contract. Diagnostics now inspect the scale and color mode
of every participating display rather than reusing the primary workspace result
for a third monitor.

## Addon behavior

`Core/WorkspaceRegions.lua` centralizes strict schema 2 validation, independent
logical/physical metrics, primary aliases, destination selection, region-relative
position data, canvas identity and actual touching seam segments. Invalid/stale
schema 2 falls back to a full-client safe viewport and cannot accidentally adopt
a matching legacy manual calibration under AUTO. An explicit MANUAL preference
keeps its previous contract.

Each workspace receives its own background canvas and shared theme/media.
Primary changes reuse the compatibility root while retiring old extra canvases.
Canvas membership, drag-stop destination, saved positions, map fit, native/custom
bag records, popup owner bounds, missing-only recovery and general rescue evaluate
the independent areas. Native protected/third-party ownership guards remain in
place. No native frame receives region bookkeeping fields.

Positions save a stable region ID and relative coordinates. Successful first
restoration of a legacy workspace record preserves a copy in
`savedWorkspaceRegionLegacyPositions` before publishing its migrated record.
Schema 1 records do not migrate. Missing saved region IDs temporarily resolve to
the primary without discarding their original record. Removing Workspace B in
the editor asks the user to confirm that fallback; it preserves stored settings
and positions for recovery. Forever gains a bounded W5 emergency CVar position
record containing the region ID, while W/W2/W3/W4 remain readable.

The addon options show every workspace's dimensions and the primary selection.
New strings are supplied in all 11 dictionaries. Seam guides are drawn only for
actual game/workspace adjacency, avoiding invented boundaries across gaps.

## Automated evidence

- All 84 Lua suites pass, including new strict-topology, physical/logical
  conversion, destination, holes, relative persistence and missing-ID cases.
- Canvas tests cover independent bounds, shared themes, primary switches and
  hiding every canvas on fallback. W5 tests cover identity reload and invalid
  record preservation. Existing protected-ownership simulations remain green.
- `tests/companion-workspace-regions.ps1`: 309 assertions each on x64/x86, plus
  exact production C# bridge consumption by Lua on each architecture. Covers
  planner rejection, identity reorder, excluded native points, capability/version
  skew, Save preservation, editor settings at 100/125/150/200% fixture scaling,
  missing-display editor refusal, wrapped labels, scrollable content and reachable
  actions at small window sizes, fitting to the available desktop, and four native rollback stages on hidden
  windows. These are not physical three-monitor or live-client tests.
- Existing partial-topology fixtures pass: 64 acceptance/rejection cases,
  32 persistence round trips and secondary metrics at two UI scales.
- Three-connected/two-selected characterization still passes 40 checks per
  architecture; three selected without opting into schema 2 is still refused.
- Existing native rollback/Restore suite passes 3,057 assertions per architecture.
- Preferences/dashboard and color/DPI fixtures pass. The color fixture now uses
  its own in-memory standard mode rather than inheriting user custom settings;
  it measures the three-display diagnostic text at enlarged scales.
- Six TOCs, 66 runtime references, 65 Lua files and one XML file pass Lua 5.1,
  XML/path validation. Canonical Beta 20 binaries are unchanged.

## Acceptance limits

At this source checkpoint, no new live-client result is claimed. Any subsequent
bounded package run must be appended with exact artifact hashes and context.
The P6 review packet and its evidence remain attached to their original bytes.

Physical three-display apply, excluded-area interaction, cross-workspace dragging
and cold persistence, combat/protected descendant actions, mixed DPI, per-display
hotplug, docks/identical displays, large-panel fit, other exact-artifact clients,
Store and Wine runtime are pending. Native/mocked success does not establish
rendering, input or taint safety. Do not publish or promote this experimental
feature as fully supported until those gates pass.

Knowledge routing: shared README/skill/status and the CompanionThirdMonitor
record were consulted before decisions. The existing source study and Microsoft
region/display/resource contracts are linked in
[the third-monitor study](CUSTOM-WORKSPACE-REGIONS-THIRD-MONITOR-STUDY.md).
Local source and synthetic/native fixtures establish only the scope above.

## Exact Prototype 7 package and bounded Retail run

Built from clean `2e68d73c4e3f9ba1db5964a2ad567942b0a9d747`, following feature
commit `959628e`. Product `2.1.3-beta.2`, file/application version `2.1.3.3`,
protocol 1. Package identities:

| Component | SHA-256 |
| --- | --- |
| Companion executable | `3D7701F0AB46CC6D2357173D9872D7716D35F43C7534970D1C0CDE9EAB1242F7` |
| Original portable runtime ZIP | `8B36FD2EDD18EE1621B9B0F4ADEC30EC25FCD7B1F6B7776C5818033DB7DEDD27` |
| 77-file addon review ZIP | `AD0D92BCE7FA70B199843B9711C125DF1E45CE793E80DE5D1E5E1B5608EBF7B0` |
| Unsigned validation MSIX | `E6DE7319BE2204F54CA723F3B54552953A44E7F631618EBFEC5CE6E7B4A4CC5D` |

The MSIX has exact executable parity and passed file-boundary, identity,
capability and startup-policy checks. It uses the separate validation identity
and `1.0.0.0` package version. It was not installed or submitted. The build-time
candidate.json stays immutable; its original pending field precedes this run.

Retail `12.1.5 / 70688 / Oct 28 2026 / 120105`, Windows x64/enUS, was tested on
an existing idle level-1 character on 3 November, approximately 10:00-10:15 CET.
The installed addon matched all 77 staged review files before launch, with inert
generated placeholders. Existing enabled addons and profile were preserved;
Adventure Plates and the existing error capture were present. No gameplay,
combat, protected descendant action or account/realm selection was automated.

This was **one real workspace on two physical displays**, exercising schema 2;
it is not a physical three-display or two-real-workspace pass. The full game
display was 2560x1440 and the portrait display 1440x2560, both 100% Windows
scaling. The existing custom area was retained: local top-origin
`(9,1108) 1418x1440`, desktop `(-1431,-6) 1418x1440`.

1. Opened the new editor with actual identities. It retained the one-workspace
   plan, numeric area and primary choice. Cancel left the plan unchanged.
2. Captured the ordinary native baseline and read-only Edit Mode layout data.
   Manual Span produced backing `(-1431,-6) 3991x1446`, style `140B0000`, complex
   clipping, and the declared schema 2 bridge with `workspace-a`.
3. Reloaded once to load the generated bridge. Saved diagnostics then reported
   READY, schema 2, one workspace and matching viewport. WorldFrame measured
   bottom-origin `(1431,0) 2560x1440`; workspace `(0,6) 1418x1440`. The visible
   primary canvas matched its logical metrics. Saved map, character and combined
   bag panels reopened visibly within that workspace.
4. Two existing panel positions gained region IDs and relative coordinates;
   two legacy records were preserved. A further reload retained the region
   geometry. This does not verify cross-workspace dragging or cold persistence.
5. Physical samples `(-722,1416)` and `(1280,1415)` hit the WoW root while WoW
   was foreground, covering both taskbar sample points. These are point samples,
   not universal shell behavior or excluded-area interaction acceptance.
6. Native Restore exactly returned `(0,215) 2560x961`, style `14CF0000`, with no
   clip. Captured addon diagnostics returned safe full-client geometry, topology
   MISMATCH and a matching viewport, including after reload.

All four native HUD layout payloads and active ID 1 were deeply unchanged. The
HUD setup prompt was left unanswered; no native row was created, overwritten,
deleted or selected. HUD setup acceptance from P6 must not be attributed to this
P7 run. The user-reported manual Character drag pass was not repeated.

BugGrabber advanced from session 352 to 356, retaining the exact same 13 historical
error records. No new visible Lua error appeared. No combat/taint guarantee is
claimed. Private snapshots, screenshots, paths and logs stay outside the packet.
Both target applications exited normally. All 18 backed-up state files and all
78 original installed-addon files were restored with every hash verified.
Battle.net remains open. Public Beta 20 artifacts and the primary checkout remain
unchanged. Nothing was pushed, published or promoted.
