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

- All 92 top-level Lua suites and six TOC/load-path/syntax checks pass.
- Eighteen production-path World Map simulations cover centered, stacked and
  corner regions at three physical/UI ratios and two inherited scales. Map fit
  preserves saved preferences and legacy placement backups; combat, maximized
  maps and external map owners retain their guards. These are simulations, not
  protected descendant or native-provider acceptance.
- 239 pure planner checks per x64/x86 architecture pass.
- 45 new document/migration/capability/atomic-save/editor checks per architecture
  pass. Actual C# schema 3 bridges for centered, stacked, offset, two-display
  shared-workspace and three-display plans are consumed by the real Lua reader
  at both architectures. The latter two are fixtures, not physical tests.
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

## Exact private candidate and Retail run

Native source revision f87b352f91f0bc92caf6729bd0d327dfbf4409f9; the source
receipt reports no tracked changes at build time and records all four C# source
hashes plus the manifest and interaction audit. The published Test 2 artifacts
and canonical public executable/archive retain their earlier hashes.

| Artifact | SHA-256 |
| --- | --- |
| Private Beta 6 EXE | F2728EFF59B537FE5D30E637A108B7CB02A05C5AA4E3C337CBA3EF361B4A1A87 |
| Private Companion ZIP | 0C338F5CBA92C205A970557121A8B85F29A3EEADCD3584B498E2CB3D31715100 |

A local report-only custom Defender scan of that candidate directory explicitly
found no threats, exit 0. Platform 4.18.26100.4, engine 1.1.26100.4, definitions
1.463.125.0. Antivirus and real-time protection remained enabled; no exclusions
or security settings changed. The EXE is unsigned. This is evidence for those
exact files and definitions, without a SmartScreen or anti-cheat determination.
Private receipts: dist/workspace-features-native-flex-beta6-20261105-005355 and
dist/defender-flexible-beta6-20261105-005435.

Retail 12.1.5 (70783), Release x64, was tested with the existing idle level-one
QA character. Eighty exact addon runtime files were staged with a prior backup.
The editor displayed and saved the 512 + 1536 + 512 full-height centered plan.
Initial native Apply produced 0,0 / 2560x1440, style 140B0000, region type 2.
The matching addon accepted schema 3: topology READY, isSpanned true, two visible
workspace canvases, and CaptureDiagnostics viewportMatches true for game
512,0 / 1536x1440. The native screenshot and a fresh SavedVariables snapshot
agree. A later UI reload visibly recreated both canvases and preserved that
snapshot. Another disconnect prevented collecting the attempted fresh
post-reload geometry diagnostic, so that separate assertion remains unverified.

The final candidate dashboard correctly reports two workspaces on one physical
display and one physical display's Windows scaling. Native Restore returned
exact original 0,215 / 2560x961 bounds, style 14CF0000 and region type 0. All 13
historical BugGrabber error records were unchanged in a full-record comparison;
no new records appeared across sessions 352 through 356. Several network
disconnects interrupted the run and are not recorded as layout failures.

Both test apps exited normally. All 18 backed-up state files and all 78 original
installed addon files were restored with verified hashes. Battle.net was left
open. HUD onboarding was neither accepted nor dismissed. No media fixture was
installed. Private evidence: dist/live-qa-workspace-features-retail-20261105-004450.

## Follow-up acceptance: map ownership, stacked and corner regions

Source fab9e5a752d5b05aef7665bdec39a378d3b85992 adds separate workspace preview
outlines and A/B labels, with a legend identifying free desktop space. It also
adds the map-fit simulations above. It does not change runtime panel ownership,
map fitting or native mutation declarations. The adjacent stacked workspaces
remain visually distinct in the preview instead of reading as one gold block.

| Artifact | SHA-256 |
| --- | --- |
| Follow-up private Beta 6 EXE | 0540B0FE1DF228153E41742F9AA12C7F79B73701D752B93A0CC269F1ECA86B77 |
| Follow-up private Companion ZIP | FC23E65979620F18262C19BE134DC99442E7A13AE11F25200FA7B5E345A7B49A |

This separate candidate has a clean-source receipt. Its local report-only
Defender custom scan explicitly found no threats, exit 0, with the same engine,
platform and definitions recorded above. Protection stayed enabled, with no
settings or exclusions changed. The EXE remains unsigned. Private candidate and
scan receipts: dist/workspace-features-native-flex-beta6-20261105-084703 and
dist/defender-flexible-beta6-20261105-084708. Earlier candidate receipts are
historical and have not been replaced.

The baseline map overlap is explained by external ownership. The live owner
diagnostic reported OpenMap, actual map scale 0.8 and dormant Offhand preferred
scale 1.1. Offhand deliberately yields map geometry to OpenMap. With only
OpenMap temporarily disabled in the backed-up QA character configuration,
Offhand's existing map fit and restore paths fully contained the map in all
three tested geometries. No runtime override or new map scaling fix was needed.
External map addons retain their own placement and may require adjustment in
their own settings when an Offhand region changes.

Retail GetBuildInfo returned 12.1.5, 70783, Nov 3 2026, interface 120105, with
project ID 1 and locale enUS. The idle level-one QA character was not moved and
no combat or protected descendant actions were performed. Accepted live cases
on the 2560x1440 primary display:

- Centered: game 512,0 / 1536x1440, two full-height 512-pixel workspaces.
- Stacked: game 640,0 / 1920x1440, two 640x720 workspaces at upper/lower left.
- Corner gaps: game 512,0 / 1536x1440, workspace A at top-left 0,0 / 512x640
  and B at top-left 2048,800 / 512x640. Native clipping reported a complex
  region, type 3, and exposed the unused desktop areas.

Fresh SavedVariables diagnostics report schema 3 READY and viewportMatches true
for each layout, plus full World Map containment. Stacked acceptance followed
an actual UI reload. The corner layout and both different background images
also survived reload, followed by a newly captured matching viewport diagnostic.
The separate candidate above ran the corner, media and final Restore checks;
the prior private candidate ran the centered/stacked checks with identical Lua
runtime sources. This does not establish the unactivated desktop-gap input path.

A temporary code-free two-image Studio fixture supplied warm landscape and cool
portrait assets. Region A Fit used the full canvas width at 2:1; region B Fit
used full height at 1:2. Captured dimensions and UV coordinates match the image
content and exclude padded texture pixels. Switching A to Gnomish Tinker theme
hid only A's image; B retained its own image with the expected Fill crop.
Selecting a missing B asset hid its texture and showed the theme fallback,
without silently substituting A's asset. Reselecting the original B asset
recovered its image. Stored asset/fit preferences survived the theme change.
Studio tests also pass 96 producer-to-Lua crop/fit comparisons, two-image
library/routing/profile cases and the offline import/export workflow fixtures.

The existing chat extended into a desktop gap, but the live custom-chat-owner
diagnostic was true and both Chattynator and EllesmereUIChat were enabled.
Offhand intentionally leaves their layout alone. This is a compatibility limit,
not acceptance of native chat placement in small regions; repeat that separate
test with external chat providers disabled before promotion. Character stayed
on Mainhand in this run, without establishing the full oversized-panel matrix.

Native Restore returned exact original bounds 0,215 / 2560x961, style 14CF0000,
region type 0, client rectangle and window placement. A fresh addon snapshot
reported isSpanned false and topology MISMATCH, using the normal recovery path.
All 13 historical BugGrabber records were unchanged in full-record comparison,
session counters 352 through 357. Both QA apps exited normally. The temporary
media fixture was hash-verified and moved into private evidence; all 18 state
files and 78 original addon files were restored with verified hashes. OpenMap
was restored enabled. Battle.net remained open; HUD onboarding was untouched.
Private evidence: dist/live-qa-workspace-features-retail-20261105-081950,
including acceptance-summary.json and native screenshots.

## Remaining gates

Complete native chat placement without external providers, unactivated gap input
and focus/taskbar behavior, profile switching/manual precedence, and the full
oversized/missing-destination recovery matrix for the new flexible geometries.
Mixed-DPI, physical disconnect/reconnect, other client builds, combat/protected
actions, performance, novice usability and the complete editor remain pending.
No GitHub, Store, stable artifact or website is changed by this prototype.
