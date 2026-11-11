# Detached minimap ownership and recurring jumps, 9 November 2026

## New reporter evidence

Rallina reports an EllesmereUI minimap repeatedly leaving its saved screen-edge
position during play after updating to Offhand 2.1.5-beta.28. A second screenshot
shows it near bottom-center. Moving it back through Ellesmere unlock mode works
temporarily. This is separate from Brin's profile-dependent visibility report
OH-UI-028, though the ownership investigation overlaps.

The attached full text identifies Forever 1.60.1 build 70862, interface 16001,
Offhand 2.1.5-beta.28 and Companion 2.1.5 MATCH. Viewport PASS, topology READY,
physical canvas 4000x2752, Mainhand LEFT (0,0 2560x1440), portrait workspace
(2560,192 1440x2560), effective scale about 0.366. OpenMap owns the world map;
that is distinct from minimap ownership. Native layout geometry is current.
The dump does not include visible Minimap bounds or a relocation call stack.
The exact EllesmereUI module version is not supplied.

The user's additional local test shows EllesmereUI core unlock mode without a
minimap mover, with SexyMap disabled. The screenshot also reports EllesmereUI
Options disabled. The user cannot currently check whether the separate
EllesmereUI Minimap module was enabled because character-selection servers are
unavailable. Do not infer active minimap-module ownership merely from the core
editor or infer module absence merely from missing Options.

## Reproduced Offhand source defect and correction

Generic popup/void recovery in Core/SeamRedirect.lua scans UIParent children
every two seconds. Native ownership policy recognizes MinimapCluster, but the
visible Minimap was not covered by the external HUD policy. Replacement addons
detach that visible frame from the native cluster. An unprotected map which
overhangs Mainhand's top, or has a full-canvas center anchor, can therefore enter
popup repositioning even though its placement belongs to a minimap addon.

The production scanner regression first failed against the previous code:
"popup rescue and Canvas movement must preserve the detached visible minimap".
It reproduces a map near Mainhand's right edge with a small top overhang. A
second case covers Ellesmere's anonymous crop parent. Installed 9.8.2
EUI_Minimap_Apply.lua creates that UIParent child and
EUI_Minimap_Styles.lua DesiredMapParent reparents cropped maps beneath it.

The correction extends HUDCompatibility.IsExternallyOwnedHUDFrame to preserve
the actual Minimap canvas and, for a custom minimap owner, its bounded parent
ancestry. It stops before UIParent/WorldFrame and does not claim unrelated
windows. Existing popup and Canvas guards therefore yield those roots without
introducing another frame hook or writer. The existing OnShow callback also
rechecks ownership if it was installed before ownership changed.

Missing-only recovery now skips externally owned Edit Mode systems before
constructing a native repair request. Otherwise an offscreen empty minimap
container could request a native repair that the layout writer correctly rejects
as external, preventing unrelated recovery in the same transaction.

This proves a source-level ownership defect capable of causing relocation.
It does not prove that every reported jump/hide used this exact path. The
original reporter's configuration still needs native acceptance. It also does
not establish when the defect was introduced; the report's update timing alone
is insufficient to attribute introduction to Beta 28.

## Ellesmere and SexyMap findings

Installed EllesmereUIMinimap 9.8.2 registers `EBS_Minimap` in unlock mode through
EUI_Minimap_Lifecycle.lua:553-600. Its getter returns the visible Minimap, and
savePosition writes its minimap profile position. Apply reparents the visible
map, hides the empty native cluster with alpha zero, and suppresses its native
selection box. A missing mover requires checking the actual Minimap module,
initialization/errors, profile enable state and registration. Using the core
unlock editor alone does not establish those states.

Installed SexyMap v12.1.7 reparents the visible Minimap and saves drag coordinates
in its own profile. The native Edit Mode box belongs to MinimapCluster. Automatic
synchronization is not implemented or recommended as the immediate repair:
it would need a deliberate authority for both profiles, scale conversion,
combat handling and release semantics. It would not prevent a third writer
such as the previously unguarded Offhand popup pass. First preserve the selected
minimap owner's authority and verify persistence.

There is also a separate installed SexyMap source defect: SexyMap.lua:567-571
hooks SetScale but calls the retained SetPoint with a numeric scale argument.
The existing local historical error receipt
dist/placement-recovery-20261109/error-evidence.json contains
`Minimap:SetPoint(): Invalid region point 1.1` and a C stack overflow from the
earlier minimap session. The invalid-point error is consistent with that exact
bad argument. The receipt alone does not attribute the overflow or the external
reporter failures. No vendor source is patched and no historical error is
represented as a fresh failure.

## Diagnostics and remaining tests

Full diagnostics now distinguish Ellesmere core, Minimap and Options presence,
`EBS_Minimap` registration and its profile enabled state, in addition to SexyMap
presence and both native minimap roots' visibility/parent state. They also inspect
the verified `LibDBIcon10_ForeverDungeonJournal` and `LFGMinimapFrame` roots.
The CurseForge report's "dungeon browser minimap button" does not identify which
of these (or another addon) owns its missing icon. Do not reset all settings or
force-show a possibly context-dependent queue button without identifying it.

All 116 source suites pass, including real-scanner, anonymous-parent, legacy
minimap dragging, bounds/cycle, missing-only recovery and read-only diagnostic
coverage. Six manifests pass paths/XML and Lua 5.1 syntax validation. The
ownership regression was observed failing before the fix, then passing after.
Receipts: dist/minimap-ownership-20261109/tests.json.

No native client launch, installation, vendor edit or release occurred. When
service resumes, verify one owner at a time: native minimap, SexyMap, and
EllesmereUI Minimap with module/mover readiness confirmed. Position near the
seam and Mainhand top, observe for several scanner intervals, close Game Menu
and Talents, change buffs, close/save each editor, reload, span/Restore, and
test combat with fresh errors/taint. Capture full diagnostics before/after a
jump. Reposition an already displaced map using its owner's controls once the
candidate is installed; the fix does not overwrite saved vendor positions.

DaylightUI OH-UI-027 remains a separate explicitly deferred live-test item.


Final shared-checkout verification: 117 Lua suites and six-manifest Lua 5.1
validation pass. The additional suite arrived in concurrent Ellesmere work.
Options presence uses the installed folder name EllesmereUIOptions; its targeted
diagnostic regression also passes after that metadata correction.
