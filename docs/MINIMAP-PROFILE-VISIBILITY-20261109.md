# Profile-dependent minimap visibility report, 9 November 2026

## Reporter evidence and status

The initial bot summary describes any window closure with SexyMap enabled.
The reporter's subsequent messages supersede that broad summary:

- The old profile also reproduces with SexyMap disabled and the stock minimap.
- After trying other windows, the reporter narrows the triggers to Game Menu
  and Talents, including opening those windows.
- A fresh default Offhand profile restores normal stock minimap behavior.
  At that intermediate stage SexyMap's minimap is missing when re-enabled.
- Fresh profiles for both addons then work together without further problems.

Status: reporter recovered through fresh profiles; underlying cause unconfirmed.
Do not label this a confirmed SexyMap incompatibility or an Offhand code fix.
No further reset is needed for a reporter whose current profiles work.

Supplied full diagnostics identify Forever 1.60.1 build 70862, interface 16001,
Offhand 2.1.3-beta.27, Companion writer/paired 2.1.3, protocol 1 MATCH. Both old
and working captures report viewport PASS and the same stacked vertical span,
Mainhand TOP, topology READY and matching generated Edit Mode layout. They show
physical 3840x2161, logical screen/canvas 3900x2195, effective scale about 0.350,
Mainhand (632,1081 2560x1080) and workspace (0,0 1920x1080).

Those checks describe layout state. They do not measure minimap visibility,
parent ownership or the writer that changed it. The old full diagnostics omit
Minimap/MinimapCluster entirely. Profile revision differences do not identify
which preference caused the problem. The failing profile exports, exact SexyMap
version and visibility call stack were not supplied.

## Source review

Current source yields custom minimap geometry to SexyMap and other owners in
HUDCompatibility, SeamRedirect and Canvas movement policy. Forever's native
MinimapCluster also retains Edit Mode ownership. No direct Offhand minimap
Hide/Show behavior was found in the inspected paths; generic profile-based
panel/visibility behavior still requires an actual failing state to evaluate.
Source searches alone do not rule out an indirect interaction.

Installed SexyMap is v12.1.7, which is not established as the reporter's version.
Its standard and Classic source roots reparent the visible Minimap to UIParent
independently of MinimapCluster. It has separate visibility paths, such as pet
battle handling and HudMap. Inspecting the ownership container alone would
therefore miss part of its visible state. No vendor source/profile was changed.

Exact-build native study uses Gethe/wow-ui-source revision
`9dc84f0d3bbae1768ac3405b3716000bd93eda06`:

- [Mainline Minimap.lua](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_Minimap/Mainline/Minimap.lua):
  ToggleMinimap changes the visible Minimap child, separately from its container.
  SHA256 `6e84303de842c59548ed8e616705a7ba49f8d60ce660bb1ce90f9879cd5a7398`.
- [Shared UIParentPanelManager.lua](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua):
  inspected panel transactions and minimap clearance calculations. This does not
  identify a caller responsible for the reporter's visibility change.
  SHA256 `aab8401ff78f0ce32087fc6033a36b79a736ccbaf2aaa8b7d2342f6c4c09fbec`.

Shared knowledge status/search were consulted first. The collected Forever
declarations were review-due, and ToggleMinimap/MinimapCluster implementation
queries had no evidence. Exact-build upstream source fills that study gap;
initial guesses without Mainline/Shared path segments returned 404. Raw source
and test results are retained only under ignored dist/minimap-report-20261109.
No reference bytes are added to the addon runtime.

## Diagnostic improvement and next evidence

`Core/HUDRecovery.lua` now includes MinimapCluster and Minimap in the existing
full interaction-visibility snapshot. An additional bounded read-only snapshot
reports each root's shown/visible state, own/effective alpha, parent name and
visibility, user-placement flag, effective scale, saved Offhand workspace or
Mainhand presence, and Escape registration. SexyMap presence is reported too.

The snapshot runs only for explicit full diagnostics, skips combat, guards
forbidden/secret values and performs no hooks, visibility, anchor or profile
writes. It cannot identify a caller stack and is not a repair. Existing normal
placement and hiding behavior are preserved.

If the reporter encounters the old failure again, capture `/offhand diag full`
before and after the same Game Menu or Talents action, with the same profile
and SexyMap state. Retain the failing Offhand/SexyMap profile exports or backups
before making any changes. Record the exact SexyMap version. A controlled
comparison should change one addon profile at a time, and distinguish hidden,
faded, parent-hidden and offscreen states. Keep current working profiles intact.

Validation: all 116 Lua suites pass. The dedicated diagnostic test covers
missing roots, a hidden parent, actual hidden state, SexyMap presence, saved
positions, Escape registration, forbidden roots, secret values and combat
deferral, with mutating methods prohibited by the fixture. Six manifests pass
path/XML and Lua 5.1 syntax checks. No native reproduction, installation or
release occurred. DaylightUI OH-UI-027 live testing remains explicitly deferred
in tests/QA-notes.md at the user's request.


## Follow-up: visible minimap separates from native Edit Mode box

The user's additional screenshot shows SexyMap's visible circular minimap on
an Offhand workspace at the left while the native Minimap Edit Mode selection
box remains at the upper right of Mainhand. The user reports this occurs when
dragging. This is positive evidence of separate visible-map and selection-box
placement. It does not establish the earlier Game Menu/Talents hiding cause.
This screenshot is a horizontal Mainhand-RIGHT arrangement with Offhand v2.1.5
shown in chat, distinct from the earlier reporter's stacked Mainhand-TOP setup.
No exact build or before/after diagnostic snapshot accompanies the new image.

Installed SexyMap v12.1.7 deliberately reparents Minimap to UIParent
(SexyMap.lua:440; SexyMap_Classic.lua:433). Its drag scripts operate on that
Minimap and save its own point/relative point/x/y in its profile
(SexyMap.lua:560-565; SexyMap_Classic.lua:550-555). Both restore that saved
position relative to UIParent. The standard path also reasserts its saved point
when other code changes Minimap anchors. Blizzard's native Edit Mode ownership
container is a different frame, MinimapCluster. Therefore this arrangement is
consistent with the vendor's independent position ownership, not proof that
Offhand dragged the native selection box incorrectly. Do not force the child
back under MinimapCluster or write another native anchor to synchronize them.

Verified exact-build source: Interface/AddOns/Blizzard_Minimap/Mainline/Minimap.xml
at Gethe revision 9dc84f0d3bbae1768ac3405b3716000bd93eda06. Line 3 gives
MinimapCluster the EditModeMinimapSystemTemplate; line 56 declares its original
visible Minimap descendant, which SexyMap later reparents. SHA256
e9eb053e60aeffe7d1ca8e8a7b19a5948e246af396b84450cc2f823009cec8dc.
Downloaded source stays in ignored dist/minimap-report-20261109. No runtime
patch or live interaction was added in this follow-up.

Use SexyMap's position/unlock controls while it owns the minimap. The native
Edit Mode selection box describes Blizzard's container; it is not evidence of
SexyMap's saved position. If actual minimap placement fails to persist after
closing Edit Mode or reloading, capture that sequence as a placement/persistence
issue, with the visible root and container snapshots already added to full
diagnostics. Keep this separate from the earlier visibility report.
