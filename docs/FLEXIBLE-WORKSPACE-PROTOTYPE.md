# Flexible workspace private prototype

Status: unpublished Companion 2.1.3 Beta 6 / file 2.1.3.7. This is the next
gated increment of the FancyZones gap roadmap, not a supported release claim.

## Implemented contract

The layout chooser has an explicit flexible prototype entry. Its editor places
one rectangular game view and one or two workspaces on one physical display.
Centered, stacked and single-side presets start a draft; numeric monitor-local
physical-pixel rectangles and a preview allow refinement. Save only changes
preferences. Apply and the in-game UI reload remain manual. Automatic recovery
and automatic span are disabled for custom layouts. The later unified visual
grid/freeform editor, undo, proportional sizing and portability UI remain open.

The pure document/planner can resolve one to three physical displays and two
workspaces, including multiple regions on the same display. The private editor
currently authors only one-display plans. Game minimum is 960x600; workspace
minimum is 480x600. Rectangles must fit their assigned display, cannot overlap,
and retain stable region IDs. The backing surface is bounded to 16384 pixels
per axis and four times the game area. These are allocation guardrails, not a
renderer performance or hardware-support guarantee.

Schema 3 is separately negotiated through the installed addon's TOC capability
before a native mutation. It declares bottom-left physical coordinates, full
monitor rectangles and deduplicated selected devices. The addon validates each
region against its physical monitor and the backing surface. Schema 2 retains
its separate-display requirement; schemas 1/2 keep their existing reader paths.
All six TOCs advertise 1,2,3. Advertising a reader does not establish live
acceptance on all six clients.

## Persistence and downgrade

WorkspaceLayoutV1 is a bounded versioned local document. Unknown document
fields, unsupported versions, malformed dimensions and stale display snapshots
refuse Save/Apply without replacing the prior value. An inactive future
document is also preserved. WorkspaceLayoutFallbackV1 snapshots the previous
geometry when entering flexible mode. Disabling the mode restores that snapshot
and leaves the recoverable document present. Disconnected fallback displays
may require reviewing the restored selection before another Apply.

The first flexible profile write copies the existing V1 plans into the separate
WorkspaceProfilesV2 store. The original WorkspaceProfilesV1 bytes are retained.
Profile IDs, names and existing geometry survive migration. A future/corrupt V2
store refuses changes instead of falling back to V1. V2 and V1 are not kept in
two-way synchronization: an older Companion sees only the retained V1 snapshot.
Before downgrade, Restore Window, disable flexible mode and save; preserve a
copy of the full preferences file. Native Restore remains the recovery action
even when a plan cannot be validated.

## Verification ledger

Automated checks on 5 November 2026:

- All 91 top-level Lua suites and six TOC/load-path/syntax checks pass.
- 239 pure planner checks per x64/x86 architecture pass.
- 41 new document/migration/capability/atomic-save/editor checks per architecture
  pass. Actual C# schema 3 bridges for centered, stacked and offset plans are
  consumed by the real Lua reader at both architectures.
- Existing schema 2 geometry/bridge (352), profile (25) and workspace UI (67)
  checks per architecture pass, plus preferences/dashboard checks.
- Native rollback checks pass 3057 assertions per architecture, including 160
  custom-layout failure cases and 60 Restore cases. Taskbar (25), third-monitor
  (40) and partial-layout bridge/clip regressions pass.
- The production interaction audit sees four source files and the existing 36
  native declarations. No process-memory, injection or synthetic-input feature
  was introduced. This textual audit is not vendor or anti-cheat clearance.

A private visible WinForms probe used the production planner, clipping and
Restore functions on a 2560x1440 display. Its two corner workspaces leave desktop
gaps; an exposed witness window was visible and accepted a click after explicit
activation. This does not prove an unactivated click-through path in WoW. Restore
returned exact 700,180 / 900x700 bounds and style 16CF0000 and made the prior gap
points part of the restored client again. A complex Windows region was observed
after restoration even though the original explicit region was absent; the
probe therefore records restored client coverage separately from raw region
identity. The hidden native rollback fixtures still check exact region identity.
The probe is ignored QA tooling and is excluded from all runtime packages.

Exact candidate scan and Retail live results will be appended after their runs.
Mixed-DPI, physical disconnect/reconnect, other client builds, combat/protected
actions, performance, novice usability and the complete editor remain pending.
No GitHub, Store, stable artifact or website is changed by this prototype.
