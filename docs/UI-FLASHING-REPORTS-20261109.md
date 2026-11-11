# Aura and DaylightUI map flashing reports, 9 November 2026

These are two separate ownership conflicts reported in the same Discord thread.
Neither report is evidence that a single ultrawide split is unsupported.

## Ellesmere / Naowh aura flash

Reporter environment: Forever 1.60.1 build 70790, interface 16001,
Offhand 2.1.2-beta.26, EllesmereUI and Naowh Forever. Single ultrawide,
manual split, windowed fullscreen, no Companion. Diagnostics report viewport
PASS, remembered manual canvas MATCH, Mainhand RIGHT and generated layout
Offhand active/matching. The physical canvas is 7540x2126; the submitted video
is encoded at 2560x724. Companion unavailable is expected for this manual setup.

The reporter says disabling "Reroute popups & dialogs away from center bezel"
stops the flash. This is a reporter-observed workaround, not a recommendation
to disable all routing permanently or change display configuration.

All 274 decoded video frames were inspected through upper-HUD comparison and
selected full frames. A visible aura icon leaves its upper position for one
encoded frame at approximately 1.104, 3.112, 5.129 and 9.137 seconds, appearing
lower beside the quest/HUD area before returning. The encoded clip supports
the transient movement; it does not expose the frame name or caller stack.
Clip SHA256: `91f9cf45c5aebb0a12fbc8b62e5c9bd7dbfeaec81f22b24f114d4d42f87127ea`.

Current source already excludes `EllesmereUIPlayerAuraBars_Buffs` and
`EllesmereUIPlayerAuraBars_Debuffs` through
`HUDCompatibility.IsExternallyOwnedHUDFrame`. The general UIParent popup scan
in SeamRedirect checks that policy before moving a child; Canvas also yields
these roots. The scan's two-second cadence is consistent with the clip, but
does not identify the caller by itself. Installed EllesmereUIUnitFrames 9.8.2
creates both named roots in EUI_PlayerAuraBars_Bars.lua. The reporter's precise
Ellesmere/Naowh versions and flashing root remain unknown.

Existing source/simulated coverage passes:

- `tests/hud-compatibility.lua`: ownership policy and native aura fallback.
- `tests/party-editmode-and-void-rescue.lua`: actual generic popup and Canvas
  paths leave both external aura roots untouched, including offscreen movement.

Status: relevant correction already exists in current source; exact reporter
acceptance remains open. Do not add guessed Naowh frame exclusions or claim
the supplied clip has been reproduced on the current candidate.

Retest the current candidate with the original manual split and profiles,
rerouting enabled, and repeated buff changes for at least 15 seconds. If it
still flashes, capture `/fstack` over the moving icon and the two addon versions
before extending ownership detection. Keep the manual canvas and profiles.

## DaylightUI world-map flash

Second reporter: Offhand 2.1.2-beta.26, Companion beta.20, DaylightUI 1.6.0.1,
Forever 1.60.1 interface 16001 (exact build not supplied), two 2560x1440 screens,
Mainhand LEFT and persistent world map on RIGHT. Closing loot, flight map or
PvP results reportedly moves the map to DaylightUI's smaller Mainhand position
for one frame, then Offhand restores its workspace position.

The reporter identifies DaylightUI_Skins/MapMove.lua and a HideUIPanel call
stack, and reports an in-game bridge eliminating the blink. Those runtime
results are reporter evidence; the bridge/probe code was not supplied here.

Current Offhand `CanvasCompatibility.GetWorldMapExternalOwner` recognizes
MoveAny/MoveAnything, ClassicUIForever, OpenMap and Leatrix Maps. It has no
DaylightUI branch. Merely adding a broad yield would give DaylightUI the map
and stop Offhand's intended workspace placement, rather than preserve it.

The author's [Wago distribution](https://addons.wago.io/addons/daylightui)
provided 1.6.5.2 on the investigation date. Its advertised GitHub source
returned 404. The inspected version is newer than the reported 1.6.0.1 and
must not be described as that exact source.

In the downloaded author package, MapMove.Apply still:

- runs after ShowUIPanel, HideUIPanel and UpdateUIPanelPositions, and at map
  show/maximize/minimize lifecycle points;
- reapplies its own bounded 0.6-1.4 scale;
- reapplies a private configured top-left position when one is saved;
- owns a separate resize grip and title strip;
- explicitly stands down for OpenMap, with no equivalent Offhand check.

That source corroborates competing geometry writers. It does not independently
verify the reported one-frame ordering in the native client.

Provenance: author ZIP SHA256
`ccb23fa1eff3a61a06bd7cb17442c22bf1b2be8049591b191a3cd38a20c7b734`;
MapMove.lua SHA256
`480458a992f8bd6e105282cee3bd1055cacd52324a05a9bd454a7dc5c2413be4`.
Local read-only evidence is under ignored `dist/private-report-media/`.
No vendor source was executed, installed, edited or added to a deliverable.
The package license permits original plugins using its functions but prohibits
redistributing its code; no implementation was copied into Offhand.

Initial review: source-backed compatibility defect, unresolved at that stage.
The implementation follow-up below supersedes that candidate status. A cooperative,
conditional DaylightUI map-mover stand-down is preferable to an unrestricted
SetPoint/SetScale hook on the native map. The reporter's workaround parks
`mapSpot` and replaces Scale, so shipping it requires additional lifecycle
and persistence work, not just copying the description.

The adapter must preserve skinning and the user's DaylightUI settings, acquire
ownership only for an active Offhand map placement, and release it on Restore,
disable, saved-placement removal, profile changes and native Gamepad ownership.
It must preserve maximized behavior, avoid duplicate hooks and leave intervening
user changes intact. Validate both addon load orders, loot/flight/PvP close,
reload, combat and current errors/taint before claiming resolution. Obtain the
reporter's bridge/probe and the exact 1.6.0.1 source for the remaining comparison.

## Initial review work and limits

Read current source on `addon/forever/gamepad-reports-20261105` at baseline
`dc5e9eb`, preserving unrelated dirty work. Consulted shared knowledge status
and Forever queries before engineering conclusions. Daylight retrieval had no
local evidence; the aura query returned the existing 7 November finding.
The broad exact-build ask returned unknown, not a runtime/API conclusion.

All three targeted suites above, including `tests/canvas-compatibility.lua`,
pass on current source. No runtime code changes, new package, installation,
publication, Discord message or native-client test occurred in this review.

## Implementation follow-up

The user authorized implementation and installed DaylightUI locally. Installed
DaylightUI_Skins is 1.6.5.2; its MapMove.lua hash matches the author package
recorded above. Core.lua exposes GetModule("Skins"); Module.lua passes the
module's DB to MapMove.Start at enable and settings changes. DB.lua repoints
module.db during profile changes. WindowScale explicitly excludes WorldMapFrame.
These installed source contracts are the implementation authority.

`Core/DaylightMapCompatibility.lua` wraps the public mover Start and Scale
functions once per namespace. Only MapMove receives an empty read/write proxy
over its actual config. While Offhand owns a valid saved map placement, the
proxy masks mapSpot and Scale reports the map's current Offhand scale. Retained
Apply callbacks therefore cannot transiently write DaylightUI's anchor or scale.
The module DB and every saved setting retain their original table/value identity;
no setting is parked, cleared, copied or stored in Offhand's SavedVariables.
Explicit vendor Reset and setting writes still reach the real DB.

The vendor drag strip's mouse input is disabled during ownership. The resize
grip is transparent and noninteractive, so its own Apply can toggle visibility
without making the competing grip appear. Skin layout continues normally.
Controls are restored only where their properties still equal Offhand's assigned
values. No native map scripts, geometry methods, fields or events are hooked
or replaced by this adapter, and no vendor source file is edited.

Disable, unspan, removal of both saved map placements, maximized presentation,
native Gamepad UI, a recognized external map owner, module loss or a later
plugin function replacement release the projection. The original settings then
become visible to MapMove again, and the existing refresh cadence replays vendor
placement when appropriate. Control writes and new acquisition defer combat;
post-combat refresh restores pending controls. Profile changes rebind the view
to the current vendor config. Late module readiness is supported. Wrappers
remain installed but delegate while inactive; initialization does not stack them.

Integration runs before map configuration, at canvas layout changes and within
the existing Forever half-second maintenance callback. No extra ticker or
unbounded frame scan is added. All six manifests include the module, and the
existing compatibility diagnostics add `DaylightMap=Offhand` or `DaylightUI`
when the adapter has a supported mover.

Validation: all 115 source Lua suites pass, including a new ownership/lifecycle
fixture and the updated manifest-order contract. Six manifests pass path/XML
and Lua 5.1 syntax checks. The new test also passes when explicitly given the
installed MapMove.lua in a fully mocked Lua runtime; it exercises the actual
vendor functions and retained Apply identity without loading a WoW client.
It first reproduces the conflicting vendor placement without the adapter.
The vendor source is not included in the regression or addon package.

Native acceptance remains pending: original two-monitor loot/flight/PvP panel
closure, vendor skin/title strip and Offhand dragging, maximized/minimized,
reload/cold login, Restore/disable, profile change, Gamepad transitions, combat
and fresh taint/errors. These automated results do not establish native render
timing or combat safety. No package installation or live interaction occurred.
