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
