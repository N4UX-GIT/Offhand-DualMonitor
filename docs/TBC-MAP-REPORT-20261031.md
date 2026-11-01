# TBC Anniversary map missing after spanning

Status: source candidate validated in simulations; reporter retest pending.

Reporter follow-up confirms the map remains completely invisible after pressing
M while spanned. A merely unopened map is excluded by this follow-up.

The supplied screenshot reports WoW 2.5.6 build 70577, interface 20506,
ClientProject 5, Offhand 2.1.2-beta.23 and Companion beta.20 (MATCH).
Enabled=1 and Spanned=1. Mainhand is RIGHT, physical window 3200x1083,
Mainhand=(1280,3 1920x1080), Workspace=(0,0 1280x1024). The screenshot
shows the game on the right and no visible world map. Compatibility diagnostics
report WorldMapOwner=Offhand, LeatrixMaps=absent and OpenMap=absent.
MoveAny presence and actual frame visibility/anchors are not established by
that summary. The Edit Mode stale-geometry warning is a separate observation,
not a demonstrated explanation for the missing map.

## Local source evidence

- `Core/Canvas.lua`, `RestorePersistentFrames`: restores a map from saved
  workspace position and explicit `openWorkspacePanels.WorldMapFrame` intent.
  Spanning does not itself imply that a new map must open.
- `Core/CanvasMapPresentation.lua`, `ConfigureWorldMap`: configures windowed
  map scale and persistent workspace behavior. Maximized maps are left native.
- `Core/CanvasPanelRegistry.lua`, `RequiresNativePanelRegistration`: the map
  lifecycle exemption currently covers Retail, not TBC Anniversary.
- `Core/CanvasPanelLifecycle.lua`, `InstallModality`: other clients can clear
  native map area metadata and use HideUIPanel/direct Show slot eviction.
  This resembles a previously confirmed Retail invisible-map mechanism, but
  is only a hypothesis for this TBC report. Do not port the exemption without
  target-client evidence and Escape/persistence regression coverage.

The report uses beta.23; the current checkout identifies beta.24. Source
inspection describes the current checkout, not verified reporter package bytes.
Installed game files, profiles and Companion artifacts were not changed.

## Required follow-up

1. Retest the source candidate on TBC 2.5.6.70577 after a reload, which rebuilds
   the native panel registration cleared by the old addon session. Open with M,
   minimize/maximize, drag left and test repeated opening/closing.
2. Leave the workspace map open, then check movement, Escape, another panel,
   reload, cold login and combat transitions with fresh error/taint evidence.
   Retaining native registration can affect Escape and simultaneous-panel behavior;
   those runtime checks are required before release acceptance.
3. If still invisible, obtain `/offhand diag full`, any fresh Lua error, and read-only
   WorldMapFrame shown/visible/alpha, anchors, bounds, canvas size and native
   panel-area evidence before choosing a repair. The current full diagnostics
   do not themselves provide all of those map geometry fields.

## Knowledge routing

Read the shared README, research skill and engineering/testing/Offhand guidance.
Ran `scripts/wowkb.ps1 status` and a `WorldMapFrame` search with
`--client classic-anniversary`. Search was blocked by a stale index; an index
rebuild was requested. Direct locked anniversary `version.txt` is
2.5.6.70577 at revision 68e0a2ec559d9761dfc4e7f864c3944f9d758a49.
The selected anniversary cache has no WorldMapFrame/miniWorldMap implementation
hits. This is a source-selection gap, not evidence that the client lacks those
features. No target-client runtime or taint validation was performed.

## Exact-build upstream review and candidate

Fetched the immutable upstream tree and inspected
[TBC WorldMapMixin](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_WorldMap/TBC/Blizzard_WorldMap.lua)
and the shared
[panel manager](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua).
WorldMapMixin.OnLoad registers area=left/maximizePoint=top. Native opening uses
ShowUIPanel; Minimize calls UpdateUIPanelPositions and RestoreUIPanelArea via
SynchronizeDisplayState. ShowUIPanel bypasses native panel placement when area
is absent. This establishes a source-level reason to preserve registration,
but does not establish the reporter's actual anchor state or root cause.

Candidate: `RequiresNativePanelRegistration` now includes WorldMapFrame on
interface 20500..20599, excluding Forever. Existing placement and open-state
persistence remain available; map metadata detachment and synthetic eviction
are skipped. Other client adapters and other TBC panels retain their policy.
No automatic profile reset, frame force-show or generated-state rewrite is added.

Validation: all 71 standalone Lua suites pass, including the new TBC lifecycle
regression covering repeated demodalization, no synthetic eviction, metadata
preservation and client-scope exclusions. All six manifests pass path, XML and
Lua 5.1 syntax checks. No test package was built or deployed. Live behavior,
Escape/simultaneous panels, persistence and taint safety remain pending.

## Test.1 package and local deployment

At the user's request, prepared `2.1.2-beta.24-tbc-test.1` from committed
baseline `09c6f315574b4c9eb7fa8036abec7798a8c3ce1c` plus only the TBC map
registry change. Pending Retail notification edits are excluded. The private
release marker is applied to staged manifests; repository release metadata is
unchanged. All 70 frozen-source Lua suites pass. Packaged and installed six-
manifest path/XML/Lua 5.1 validation passes. All 76 ZIP files match staging;
installed files match except the two deliberately preserved generated bridges.

- Installed: `C:/Games/World of Warcraft/_anniversary_/Interface/AddOns/Offhand`.
  Root `.build.info` identifies Anniversary 2.5.6.70577. The initially considered
  `D:/Games/World of Warcraft/_classic_beta_` is Forever and was not changed.
- Backup, frozen source, extracted ZIP, validation and deployment inventory:
  `C:/Games/World of Warcraft/_offhand_deploy_backups/tbc-map-test1-20261031-221958-970`.
- ZIP: `dist/Offhand-v2.1.2-beta.24-tbc-test.1.zip`.
- SHA256: `0F409537D3866BB96E3DC762EE8055F39F7EDB44A6E3F0CE6FB65CB2C0ACC268`.
- Tester instructions: `dist/Offhand-v2.1.2-beta.24-tbc-test.1-TESTING.txt`.

Existing local Core/CompanionTopology.lua and Core/ForeverState.lua hashes are
preserved. Profiles, WTF/SavedVariables, other addons and Companion binaries
were not modified. Package bridges are inert defaults. No game was launched,
no test result was observed in-game and no package was sent to Discord.

## Reporter full diagnostics, standard beta.24 before test.1

Three additional screenshots explicitly predate installation of the test
package. They identify Offhand 2.1.2-beta.24, WoW 2.5.6.70577/interface 20506,
Companion beta.20 MATCH, enabled/spanned, topology state READY with matching
expected/live 3200x1083. MoveAny=absent and WorldMapOwner=Offhand. Edit Mode
reports Geometry=current, Attention=no and Repair=none/0, unlike the earlier
summary screenshot. The prior stale Edit Mode warning is therefore not a
sufficient explanation for the ongoing map failure.

Panel controller diagnostics report WorldMapFrame=generic/peer-repair#141.
Source interpretation: `NotePanelControllerActivity` stores the latest action
and a shared activity sequence number. 141 is not a per-map retry/failure count.
`RepairShownWorkspacePanels` records this action only after a map exists,
returns true from IsShown, has a saved Mainhand/workspace position, and fails
the saved-placement comparison. It records the action before attempting
RestoreWorkspacePosition. Thus a saved map reached the generic repair path at
some earlier time; the entry does not prove the restore succeeded, that its
anchors were valid, or that it was visible at diagnostic capture time.

The screenshots still do not include map bounds, alpha, native area or canvas
dimensions. They strengthen the need to test the prepared lifecycle candidate
but do not confirm its cause or outcome. Existing test.1 artifact and installed
files are unchanged by this evidence update. Next evidence is the reporter's
result using the explicitly identified beta.24-tbc-test.1 package after reload.

## Test.1 reporter result and click-navigation follow-up

Reporter explicitly confirms beta.24-tbc-test.1: map now shows; left-click
navigation into a map region fails while right-click navigation to the parent
map works. Accept visible map opening as a reporter-observed partial pass only.
Escape, persistence and protected-action checks are not accepted by this result.

Reviewed the same exact-build upstream
[scroll controller](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_MapCanvas/MapCanvas_ScrollContainerMixin.lua)
and [MapCanvas](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_MapCanvas/Blizzard_MapCanvas.lua).
GetCursorPosition returns raw physical pixels. NormalizeUIPosition divides by
the canvas child scale and compares against child-local bounds without dividing
out the scroll container's inherited effective scale. NavigateToCursor uses
those normalized coordinates in GetMapInfoAtPosition; NavigateToParentMap does
not use cursor coordinates. This source-level scaling mismatch fits the report,
but the failing live coordinates were not captured.

Follow-up candidate adds a 205xx-only scroll cursor adapter when Offhand
configures its spanned map. It divides the native cursor result by current
scroll effective scale and leaves native click handlers, navigation flags and
pin behavior in place. Install requires the exact native mixin function identity,
so custom cursor methods are not overwritten. Combat blocks installation;
disabled/external ownership bypasses the conversion. Retail/Forever and other
client adapters are excluded. Regression tests cover scaled position lookup,
dynamic scale, idempotence, ownership, custom handlers and client exclusions.

Test.2 built and deployed locally under the existing test-candidate workflow.
72 workspace Lua suites and 71 frozen-source suites pass. Packaged/installed
six-manifest path, XML and Lua 5.1 checks pass. All 76 archive files hash-match
staging, installed files match apart from preserved generated bridges. Source
is committed beta.24 plus the registry and map-presentation changes, excluding
pending Retail notification work.

- ZIP: `dist/Offhand-v2.1.2-beta.24-tbc-test.2.zip`.
- SHA256: `F7EE9469E290CDCA8396C96AD1DD8565333F46FD89D064B5D78E804C1D62B6A4`.
- Instructions: `dist/Offhand-v2.1.2-beta.24-tbc-test.2-TESTING.txt`.
- Backup/source/extracted package/validation inventory:
  `C:/Games/World of Warcraft/_offhand_deploy_backups/tbc-map-test2-20261031-224236-285`.
- Local installation: `C:/Games/World of Warcraft/_anniversary_/Interface/AddOns/Offhand`.

Test.1 package is preserved. Test.2 instructions explicitly require inward
left-click and outward right-click navigation across different map positions
and scales, plus pin tooltips/clicks. No test.2 game interaction was performed;
visible click correction and protected-action safety remain pending.

## Spellbook report after next login, 1 November 2026

Same reporter says that after logging off overnight and logging back in,
neither clicking Spellbook & Abilities nor pressing P opens it. Exact installed
test version and the result with the map closed are requested, not established.
Follow-up confirms the installed version is beta.24-tbc-test.2. The result
with the map closed and read-only spellbook visibility remain pending.
Do not attribute this to test.2 or accept its click-navigation result from this
new report. No fresh Lua error or SpellBookFrame bounds/visibility were supplied.

Exact-build source review at revision 68e0a2ec559d9761dfc4e7f864c3944f9d758a49:

- `Interface/AddOns/Blizzard_UIPanels_Game/Classic/SpellBookFrame.lua`,
  ToggleSpellBook: uses IsShown/bookType to choose HideUIPanel, Update or
  ShowUIPanel. A frame logically shown at an invisible position can therefore
  consume the first P press as a close rather than show visibly.
- `Interface/AddOns/Blizzard_UIPanels_Game/Vanilla/SpellBookFrame.lua`:
  SpellBookFrame registers as a left, unpushable panel.
- `Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua`:
  CanOpenPanels and ShowUIPanel reject ordinary panels while an exclusive
  fullscreen panel occupies the native slot. A normal windowed left-slot map
  alone is not sufficient proof of rejection: the native manager can replace
  a nonpushable left-slot panel.
- Local CanvasPersistence restores positions and can demodalize/evict generic
  saved workspace panels. No specific failure in that path is established.

Next minimum evidence: installed version; close the map then press P outside
combat; report whether the spellbook appears. If still missing, immediately
read SpellBookFrame IsShown/IsVisible and CanOpenPanels, and obtain fresh errors.
No speculative spellbook lifecycle exemption or force-show behavior is added.
Existing test packages and local addon installation are unchanged in this step.

### Shown-but-invisible evidence and test.3 candidate

Reporter confirms P still fails with the map closed. The supplied 8873.png
shows the read-only output `Spellbook: true true CanOpenPanels: true` and no
visible spellbook. This excludes an IsShown=false opening failure, a hidden
parent at that sample, and CanOpenPanels rejection at that sample. It does not
establish alpha, bounds, anchors or native panel registration. The screenshot
itself has the map open again; the map-closed result is reporter testimony.

Source review found a concrete protected-root restoration failure path:
CanvasPersistence.InstallRestore demodalizes a saved workspace book, while
CanvasPanelLifecycle.DemodalizePanel deletes generic UIPanelWindows entries.
The next Canvas.IsUnsafeForPanelMutation rejects a protected root without a
registry entry, so subsequent placement/repair can be skipped. The exact-build
Vanilla SpellBookFrame.xml used by Classic defines spell buttons inheriting
SecureFrameTemplate; native root eligibility must remain intact. This path is
source-supported but actual reporter protection/registration/bounds were not
captured, so it remains a candidate explanation for the observed invisibility.

Test.3 preserves native registration and avoids synthetic eviction specifically
for the 205xx SpellBookFrame, while retaining the test.2 map changes. It keeps
saved workspace/mainhand positions and standalone open intent. Full TBC-only
compatibility diagnostics now read spellbook shown/visible/protected state,
effective alpha, rectangle, scale, anchor count, native area/registration and
saved-position owner. No recursive traversal or writes are performed; compact
diagnostics omit this inspection and combat defers it. No forced show, alpha
rewrite, profile deletion or secure spell-button mutation is added.

New regression covers native registration retention across repeated workspace
demodalization/eviction attempts, protected-root placement eligibility, client
scope and full diagnostic missing-geometry/error/combat behavior.

Final test.3 artifact: `dist/Offhand-v2.1.2-beta.24-tbc-test.3.zip`, SHA256
`CB010239D99BD9060F93712B8CD42414A9F406982002520543DF7E06DA410068`.
Instructions: `dist/Offhand-v2.1.2-beta.24-tbc-test.3-TESTING.txt`.
Frozen source baseline remains 09c6f315574b4c9eb7fa8036abec7798a8c3ce1c plus
the TBC-only registry, map cursor and compatibility-diagnostic overlays.
Pending Retail scenario-toast changes are excluded. 72 frozen-source suites
pass; all 76 extracted files hash-match staging. Installed addon files match,
apart from the two preserved generated bridges. Package and installation pass
six-manifest paths/XML/Lua 5.1 validation. Backup, source, extracted package and
deployment evidence:
`C:/Games/World of Warcraft/_offhand_deploy_backups/tbc-spellbook-test3-20261101-144643-665`.
The earlier 144546-591 backup retains the pre-test.3 local installation; the
144643 backup captures the provisional diagnostic build before finalization.
No provisional test.3 package was delivered. Diagnostics read raw frame
attributes rather than invoking panel-manager helpers. No target-client
visibility, relog, secure spell action or taint pass is claimed for test.3.

## Test.3 reporter result and test.4 coexistence candidate

Reporter confirms test.3 restored the spellbook, but now only the spellbook or
map can be open. Accept book visibility as a reporter-observed partial pass.
This does not accept relog, secure spell actions or taint safety.

Exact-build shared UIParentPanelManager.ShowUIPanel replaces a lone left panel
when either window has allowOtherPanels=0, or both have pushable=0. The TBC map
registers both values as 0; the book also has pushable=0. Preserving their native
registrations in test.3 therefore retained this replacement policy. Simply
deleting their registrations again would reintroduce the visibility/restore
failure paths addressed by the earlier candidates.

Test.4 instead temporarily sets pushable=1 and allowOtherPanels=1 on the native
layout attributes of these two saved workspace roots only. Registry defaults,
area, Show/Hide handlers and secure descendants remain untouched. Their native
left/center slots can coexist, and existing post-transaction workspace placement
restores their saved geometry. This is a two-window native-slot adjustment, not
unlimited independent native panel slots or a new policy for other windows.

The policy requires enabled spanned independent/persistent workspace panels,
saved workspace ownership and a windowed native-owned map. Mainhand ownership,
map maximization, external map ownership, disabling the setting or unspanning
restores the original values. Restoration only changes attributes still equal
to Offhand's applied value. Combat defers all writes to later configuration.
State is held in weak side tables, without native bookkeeping fields.

Regression coverage models the exact native two-panel replacement decision in
both opening orders, preserves registration/area and native registry defaults,
and checks idempotence, combat, feature-off, unspan, Mainhand/maximized map,
external ownership, later external attribute edits and other-client exclusions.
75 workspace suites and 73 frozen-source suites pass. Visible coexistence, saved
anchors after native reflow, relog, Escape, spell actions and taint remain live
validation gaps for test.4.

Test.4 ZIP: `dist/Offhand-v2.1.2-beta.24-tbc-test.4.zip`, SHA256
`3B7354CBFC2B5BAF73DD50635A30D9195BF5E4DFC49617CB5E8A8E89F3E726F1`.
Instructions: `dist/Offhand-v2.1.2-beta.24-tbc-test.4-TESTING.txt`.
Backup, source, extracted ZIP and deployment inventory:
`C:/Games/World of Warcraft/_offhand_deploy_backups/tbc-coexistence-test4-20261101-145757-224`.
Snapshot uses the same 09c6f315574b4c9eb7fa8036abec7798a8c3ce1c baseline and TBC
overlays; pending Retail scenario-toast work is excluded. All 76 extracted files
hash-match staging; installed files match except the preserved generated
bridges. Package and installed six-manifest path/XML/Lua 5.1 validation pass.
Earlier tester packages are retained. No in-game test.4 pass is claimed.

## Reporter acceptance and follow-up audit

On 1 November the tester confirms test.4 resolved the reported issue. Accept
the reported map/spellbook visibility and coexistence outcome for this tester
on TBC Anniversary 2.5.6.70577. Individual combat, taint, Escape, compatibility
and lifecycle matrix results were not supplied and remain unverified.

The requested follow-up audit is recorded in
`docs/PANEL-LIFECYCLE-AUDIT-20261101.md`, with a repeatable offline probe in
`tools/audit-panel-contracts.lua`. It identifies four additional source/model
contract gaps. The audit itself does not modify behavior or replace test.4.

The user subsequently authorized remediation. Test.5 implements the four audit
repairs, with zero offline audit detections, 77 workspace/75 frozen-source
passing suites and verified package/local installation. Artifact:
`dist/Offhand-v2.1.2-beta.24-tbc-test.5.zip`. Detailed change, hash, deployment,
rollback and evidence boundaries are in the audit report's test.5 record.
The live acceptance remains test.4's reported map/spellbook result; no live
acceptance of test.5's additional NPC/Escape/Macro/ownership behavior is claimed.

## Game Menu bags and stale closed intent, test.6

New report: entering Game Options through Escape opens independent bag slots,
and previously moved panels closed before reload reopen. Screenshot shows
bag windows and several standalone roots on the workspace; it does not supply
an independent version diagnostic. These are failures in the active TBC test
flow, not acceptance of test.5's full matrix.

Local source paths explain both symptoms. The legacy CloseAllBags/ToggleGameMenu
pair uses ToggleAllBags/OpenAllBags to recover a single tracked backpack. A stale
open marker can therefore open closed individual bag windows. Anniversary now
uses native bag-preserving closure and should not install this broad fallback.
Also, the explicit-toggle observer omitted ToggleSpellBook, sent ToggleQuestLog
to WorldMapFrame on TBC, and native HideUIPanel did not update protected-root
open intent. The transition snapshot only added visible roots, leaving stale
true entries for known closed frames.

Test.6 excludes TBC from broad Game Menu bag recovery; it does not change the
other client adapters. It observes P and the actual TBC QuestLogFrame, uses an
idempotent external HideUIPanel post-hook to record real closures (ignoring
synthetic slot eviction), and samples logical IsShown for known saved roots
at Init's existing once-per-transition capture. Positions are retained.
Shown roots with a hidden UIParent retain open intent; missing/disabled or
unspanned recovery does not overwrite the saved snapshot. Unloaded roots are
left unknown instead of being declared closed. Interaction-bound roots lose
only standalone open intent.

New `tests/tbc-closed-panel-intent.lua` runs real Canvas hook installation and
restoration using the shared fixture setup. It covers Game Menu with stale
backpack state and closed bags, an open backpack without opening a second bag,
P/L/X/native hide, synthetic eviction, stale flags for known closed roots,
restore after capture, retained geometry, hidden-parent teardown and recovery/
disabled boundaries. All 79 workspace and 76 frozen-source suites pass; the
four-contract audit still reports zero detections. Package and local install
pass six-manifest paths/XML/Lua 5.1 validation. All 76 ZIP files match staging;
installed files match apart from preserved generated bridges.

- ZIP: `dist/Offhand-v2.1.2-beta.24-tbc-test.6.zip`.
- SHA256: `7ED5BBBAE3A5F6B4B07EB68F7A01E48FB14467AD0A24B24D33B22D4F230F4540`.
- Instructions: `dist/Offhand-v2.1.2-beta.24-tbc-test.6-TESTING.txt`.
- Source, extracted package, validation and pre-update backup:
  `C:/Games/World of Warcraft/_offhand_deploy_backups/tbc-open-state-test6-20261101-160224-769`.
- Updated local `_anniversary_/Interface/AddOns/Offhand` to test.6.

The frozen Init is baseline 09c6f315574b4c9eb7fa8036abec7798a8c3ce1c with only
the TBC capture hook inserted. Pending Retail Init, toast, fullscreen, transient
and pet-battle edits are excluded, including the unrelated Canvas PetBattleFrame
policy line. Earlier packages, Companion, profiles and WTF are preserved.
No live test.6 visibility, reload, combat or protected-action pass is claimed.

## Test.6 bag reload failure and test.7 bag identities

User confirms closing every bag on test.6 still reopens both Backpack and
equipped bags after reload. Test.6 is not accepted for bag reload persistence.
The previous two-root fixture did not model pooled frame allocation or absent
legacy frame records, so its passing result did not establish this behavior.

Exact-build source now reviewed directly: Blizzard_UIPanels_Game_Classic.toc
loads Vanilla/ContainerFrame.lua for vanilla/tbc and Classic/ContainerFrame_Shared.lua.
The shared source allocates the next available ContainerFrame, sets its bag ID,
and IsBagOpen(id) returns the allocated frame index. ContainerFrame1 is not a
stable backpack identity. OpenAllBags explicitly opens IDs 0 through 4. Local
generic restoration could still reach that bulk opener from one stale frame
record, including records for frames absent in the new session.

Test.7 removes native Anniversary bags from the generic bulk restore route.
An authoritative versioned `tbcWorkspaceBagSnapshot` records visible workspace
bags by stable bag IDs 0..4, with copied positions. An empty snapshot means
closed; old ambiguous frame-name intent never triggers a native bag open.
Positions are preserved. Native OpenBag(id)/IsBagOpen(id) restore only explicit
snapshot IDs and follow allocation to each new pooled root. Bank/keyring and
replacement bags do not enter this path. Deferred requests recheck generation,
settings/topology and combat. Settled bag API activity updates the snapshot and
invalidates older requests; transition sampling records final open/closed IDs.

Full compatibility diagnostics add `TBCBags=` with snapshot IDs and restore
status, including legacy intent ignored or requested count. The first load
of test.7 ignores old frame-name open markers; a fresh test.7 session establishes
the new snapshot. No SavedVariables deletion or profile reset is required.

New `tests/tbc-bag-id-persistence.lua` models equipped bag ID 3 initially using
frame 1 and later using frame 2, a closed backpack, bank/Mainhand exclusions,
an authoritative empty snapshot with stale/missing/false legacy flags, an old
snapshot with no valid ID data, backpack-only restoration, close-hook deadline
cancellation, combat/settings/topology and custom-client boundaries. The full
Canvas fixture also includes absent legacy native roots with stale flags.
80 workspace and 77 frozen-source suites pass; the four-contract audit reports
zero. Package/install six-manifest paths/XML/Lua 5.1 validation passes. All 76
archive files hash-match staging; installed files match except preserved
generated bridges.

- ZIP: `dist/Offhand-v2.1.2-beta.24-tbc-test.7.zip`.
- SHA256: `9BF2010B5833D4CBF2B2D8CDC10D8C30F069A8FECAA51D2C28F875F34CD22E7B`.
- Instructions: `dist/Offhand-v2.1.2-beta.24-tbc-test.7-TESTING.txt`.
- Backup/source/extracted ZIP/deployment evidence:
  `C:/Games/World of Warcraft/_offhand_deploy_backups/tbc-bag-ids-test7-20261101-164154-302`.
- Local Anniversary installation updated to test.7; earlier candidates retained.

Pinned source bytes and SHA256 manifest are outside the addon in the shared
knowledge `.cache/offhand-tbc-bags-20261101` directory. The shared API query
reported unknown declaration coverage, so the exact-build implementation
and manifest supplied source evidence. No upstream code was executed. No live
test.7 bag reload, native timing, combat or taint acceptance is claimed.

### Test.7 follow-up: left-open bags fail to restore

User now reports no bags restore after reload, including those left open.
Test.7 is not accepted for positive bag restoration. Requested the TBCBags=
portion of full diagnostics before reload with the bags open and after the
failed restore. No new behavioral patch or package is issued at this step.

Read-only local SavedVariables inspection (file write 1 November 16:46:19)
found a schema=1 snapshot containing bag ID 0 and a valid workspace position,
alongside nativeBackpackWorkspaceOpen=true. This establishes that capture
succeeded at least once in this local profile, not that the snapshot survived
the reported login or that other IDs were captured. No account/character
metadata or unrelated SavedVariables contents were copied into the report.

Remaining runtime distinctions: a startup bag callback can replace/invalidate
the pending snapshot, generation/topology/input checks can skip restoration,
or native OpenBag can return without opening (the pinned source checks
CanOpenPanels first). Current requested-count diagnostics do not prove a
successful native show. Before changing the lifecycle again, obtain the actual
snapshot/status pair from the failing session. The offline tests do not model
every native login callback or panel-availability transition.

### Paired diagnostics and test.8 startup capture

User clarifies `TBCBags=v1:0,requested=0` was BEFORE reload, then supplies
`TBCBags=v1:none,requested=0` AFTER the failed reload. Snapshot membership is
lost across startup; this is not evidence of OpenBag refusing a request.
Read-only local SV inspection at file write 16:50:35 still finds schema=1/ID 0,
which supports a post-load in-memory overwrite rather than failure to serialize
that local snapshot. The exact offending native callback was not traced live.

The automatic hooks sampled and replaced the snapshot after every bag API,
even if it only cleaned up an already-empty visible set. A fresh UI begins
with hidden bags before delayed restoration, so such a callback could replace
the valid saved set with empty and invalidate the queued request.

Added this sequence to the existing bag-ID regression before the repair: it
fails on test.7. Test.8 initializes a separate observed-state signature without
rewriting saved intent. Automatic capture ignores unchanged visible sets;
actual changes still replace the snapshot and invalidate old requests. Native
restore updates the observed baseline so the next deliberate close is recognized.
Transition capture remains authoritative for final session state. The regression
now passes startup preservation, a real subsequent close, and a following
closed-set restore without resurrection.

Full TBCBags diagnostics now include requested API calls, native shown lookup
count, workspace detection count and capture=recorded/unchanged. These distinguish
saved membership, actual opening and placement instead of treating a requested
count as proof of rendering.

- ZIP: `dist/Offhand-v2.1.2-beta.24-tbc-test.8.zip`.
- SHA256: `BFE874D64EDF5EF073DFA8E77C17B9D49395F1F306DCF0EB07869E5320CA5355`.
- Instructions: `dist/Offhand-v2.1.2-beta.24-tbc-test.8-TESTING.txt`.
- Backup/source/extracted package/deployment evidence:
  `C:/Games/World of Warcraft/_offhand_deploy_backups/tbc-bag-startup-test8-20261101-165557-900`.

80 workspace and 77 frozen-source suites pass. Four-contract audit reports zero;
six-manifest package/install paths/XML/Lua 5.1 checks pass. All 76 ZIP files
match staging; installation matches apart from preserved generated bridges.
Local Anniversary addon is updated. Earlier packages and profiles are retained;
pending Retail work is excluded. No live test.8 acceptance is claimed.

## Test.8 partial acceptance and test.9 equipped bag capture

User confirms Backpack restores when left open and remains hidden when closed.
Equipped bags remain hidden after reload even when left open; closed equipped
bags correctly stay closed. Accept only Backpack positive/negative persistence
and equipped-bag negative persistence from this report. User supplies one
`TBCBags=v1:none,requested=0,shown=0,workspace=0,capture=unchanged` line; it is
not a separately labelled before/after pair for equipped bags.

Concrete local source gap: ReadTBCBagIDs required a saved frame position before
including an open ID. CanvasPersistence's existing grouped bag behavior removes
ContainerFrame2..13 positional records when the backpack root is repositioned.
Thus an equipped bag can be visible on Offhand yet fail snapshot admission.
This source-supported capture failure fits the report; it does not establish
every native timing/placement step in the reported session.

Added the missing-record case to the bag fixture before the repair: test.8
fails because the equipped ID is absent. Test.9 falls back to the visible
native root's real left/top/size/effective scale when no individual record
exists, using the shared workspace-position normalization in UIParent units.
It records the resulting position only inside the bag-ID snapshot, without
rewriting frame anchors/ownership during capture. Mainhand, bank and keyring
exclusions and the no-bulk-open path remain intact.

Regression additionally covers a mixed Backpack/equipped open set, missing
equipped frame records, scaled geometry/canvas metadata and closing only the
equipped bag while retaining Backpack intent. All 80 workspace and 77 frozen-
source suites pass, the four-contract audit reports zero, and six-manifest
package/install paths/XML/Lua 5.1 validation passes. All 76 ZIP files match
staging; installed files match except preserved generated bridges.

- ZIP: `dist/Offhand-v2.1.2-beta.24-tbc-test.9.zip`.
- SHA256: `FD950CBB348CD53277E74C85B4CD9E8C05940259DEFDECDD68BE5C13239F5CEF`.
- Instructions: `dist/Offhand-v2.1.2-beta.24-tbc-test.9-TESTING.txt`.
- Backup/source/extracted package/deployment inventory:
  `C:/Games/World of Warcraft/_offhand_deploy_backups/tbc-equipped-bags-test9-20261101-170401-076`.
- Local Anniversary installation updated; earlier packages/profiles retained.

No live test.9 equipped-bag capture/restoration or taint acceptance is claimed.
The next focused test is one equipped bag alone, then a mixed open/closed set,
with complete TBCBags diagnostics before and after reload if it fails.


### Test.9 bag behavior accepted; test.10 opening flicker candidate (2026-11-01)

User reports default Blizzard bag behavior is now correct. This accepts the
reported open/closed persistence behavior on test.9; it is not blanket taint
or custom-bag acceptance. Remaining report: an equipped bag briefly appears
at the left of Offhand before joining its group. Supplied 11.06-second recording
`_anniversary_ 2026.11.01 - 17.07.15.02.mp4` captures the game monitor, so the
Offhand flash itself cannot be visually confirmed from those pixels.

Shared knowledge status and classic-anniversary ask were consulted. Generated
OnShow declarations remain a gap. Existing pinned 2.5.6.70577 implementation
cache (revision 68e0a2ec559d9761dfc4e7f864c3944f9d758a49), Classic
ContainerFrame_Shared.lua lines 981-990, sets bag ID then calls Show. Local
Canvas generic RestoreSavedPositionAfterShow immediately rescues a pooled bag
without an individual saved record and queues another generic rescue. SeamRedirect
also positions that bag immediately and next frame. These competing owners
provide a source-supported flicker mechanism; the exact displayed frame remains
a live timing gap.

New tests/tbc-bag-show-layout.lua fails before the repair because native TBC
bags enter generic void rescue. The TBC-only native bag path now delegates show
placement to the existing bag group layout, avoiding generic rescue/restore
retries. Group layout still honors individual saved positions. No schema,
alpha masking or SeamRedirect changes were added. Custom bag and other client
routing use the existing path.

81 workspace suites and 78 isolated frozen-source suites pass. Panel audit has
zero findings. Six manifests pass path/XML/Lua 5.1 validation in workspace,
package and installed addon. All 76 archive files match staging; installed
files match except intentionally preserved generated bridges.

- ZIP: `dist/Offhand-v2.1.2-beta.24-tbc-test.10.zip`.
- SHA256: `030A0BF8317D40AC9E46F5F9BDA17C11B57CECCFEF8CE22BBEC9CAD3BAA6D994`.
- Testing: `dist/Offhand-v2.1.2-beta.24-tbc-test.10-TESTING.txt`.
- Backup/source/validation: `C:/Games/World of Warcraft/_offhand_deploy_backups/tbc-bag-layout-test10-20261101-171314-909`.
- Local Anniversary addon updated, profiles and generated bridges preserved.

Pending: Offhand-visible opening recording, individual/reordered bag openings,
Backpack closed/open, reload positive/negative regression, single-screen and
item actions in/out of combat. Simulation does not prove rendering/taint safety.


### Test.11, native bag closing anchor pass (2026-11-01)

User reports flicker is still present when closing bags after test.10. This
rejects visual acceptance of that candidate; default bag persistence remains
accepted from test.9. Exact closing method and which bag flashes are not yet
reported, so both close-button and surviving-bag paths are covered in QA.

Knowledge status/search/ask were consulted for classic-anniversary 2.5.6.70577.
The retrieval index is stale and generated UpdateContainerFrameAnchors evidence
is unknown. The pinned implementation cache remains the source evidence:
Classic__ContainerFrame_Shared.lua at revision
68e0a2ec559d9761dfc4e7f864c3944f9d758a49, ContainerFrame_OnHide lines 168-218,
collapses the native bag list and calls UpdateContainerFrameAnchors. The native
anchor implementation is at lines 998 onward. No upstream code was executed.

Local finding: SeamRedirect only replaced native anchors when Blizzard Edit
Mode APIs were absent. Anniversary's reported diagnostics expose Edit Mode,
so a direct close can run native layout with no immediate Offhand group pass.
Test.10 only routed generic OnShow recovery and did not cover this OnHide path.

Added tests/tbc-bag-close-layout.lua before the repair. It fails on test.10
because native OnHide leaves surviving bags at native anchors until another
layout trigger. Test.11 installs one TBC-only secure posthook on the native
anchor function and delegates immediately to guarded LayoutBags. Native layout
still executes. TBC skips the older function replacement regardless of Edit
Mode presence. Custom bags, disabled Offhand and combat yield through existing
layout guards. Reinitialization must not duplicate the hook. No new hide/show,
alpha mask, schema migration or bulk bag opener is introduced.

82 workspace and 79 isolated frozen-source suites pass, with zero panel audit
findings. Six manifests pass path/XML/Lua 5.1 validation in source, package and
installation. Archive has 76 verified files. The frozen source includes only
the TBC anchor block from SeamRedirect, excluding unrelated pending Retail
transient changes. Profiles/generated Companion bridges are preserved.

- ZIP: `dist/Offhand-v2.1.2-beta.24-tbc-test.11.zip`.
- SHA256: `58DE5F227CBA586712EFDB6D0FE9C5A023A66C19FA7FC019B06E893521213345`.
- Instructions: `dist/Offhand-v2.1.2-beta.24-tbc-test.11-TESTING.txt`.
- Backup/source/validation: `C:/Games/World of Warcraft/_offhand_deploy_backups/tbc-bag-close-test11-20261101-171843-886`.
- Local Anniversary addon updated. Earlier candidates retained.

Live rendering remains pending: close individual bags using X/slot buttons,
close the first pooled root while others survive, close all, reopen, and repeat
positive/negative reload checks. Also check Mainhand/single-screen and actual
item actions in/out of combat. Mock success does not establish taint safety.


### Default bags accepted; replacement-bag QA prepared (2026-11-01)

User confirmed test.11 resolves closing flicker. Together with the earlier
persistence acceptance, the reported default Blizzard bag cases are accepted.
This does not cover third-party bags or untested taint scenarios.

Next scope is Baganator and Bagnon, independently on test.11. Existing adapters
in Core/BagPersistence.lua discover Baganator roots through its callbacks and
Bagnon inventory through its public frame manager. Native TBC bag-ID restoration
and LayoutBags yield to replacements. No new product change or build was made.
The native-close regression now checks both Baganator and Bagnon yield guards.

Local inventory: Baganator 826 and Syndicator 281, manifest includes 20506.
Installed Baganator ViewManagement/Initialize.lua confirms the root names and
BackpackFrameChanged/BagShow callbacks used by Offhand. No Bagnon is installed
in Anniversary. The Bagnon 10.0.6 copy in _classic_ targets 30400 (Wrath), so
it is not a valid target-client test dependency. Upstream Bagnon manifest
https://github.com/Jaliborc/Bagnon/blob/master/Bagnon.toc inspected on 2026-11-01
reports 12.1.7, Interface 20506 and BagBrother dependency. These are source
observations, not an installed/live acceptance. The actual tested versions must
be recorded in the result sheet.

Checklist: dist/Offhand-TBC-Baganator-Bagnon-TESTING.txt. Covers isolated baseline,
positioning, open/closed reload and cold login, menu/system panels, item controls,
scale, bank, combat, unspan, replacement-specific modes and return to defaults.
Both replacements must pass separately before compatibility is accepted.
No game was launched or controlled and no dependency/settings were modified.


### Baganator and Bagnon reported acceptance (2026-11-01)

User reports both Baganator and Bagnon look good on the current test.11
candidate. For each replacement, inventory restores after reload when left
open, remains hidden after reload when deliberately closed, and respects
Escape. These are accepted live results reported by the user, not agent-run QA.

| Replacement | Open before reload restores | Closed before reload stays hidden | Escape |
| --- | --- | --- | --- |
| Baganator | PASS, user report | PASS, user report | PASS, user report |
| Bagnon | PASS, user report | PASS, user report | PASS, user report |

No further code or package change is needed for these reported cases. Test.11
remains the accepted candidate for the reported default/replacement bag cases.
Exact tested replacement/dependency versions, Baganator view/skin and Bagnon
mode were not supplied; the local inventory and upstream versions above must
not be substituted for those missing runtime details. Cold login, bank, combat
item actions/taint and other matrix dimensions were not separately confirmed
in this message. Do not expand this acceptance into a full compatibility matrix.
