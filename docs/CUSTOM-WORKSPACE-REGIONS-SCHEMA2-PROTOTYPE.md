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
