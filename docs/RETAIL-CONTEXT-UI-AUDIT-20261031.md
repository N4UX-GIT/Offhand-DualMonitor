# Retail contextual UI audit and local test matrix

## Local Ulduar reproduction and override candidate

Final local follow-up: developer confirms fixed and found the native frame
previews in Advanced Options. Record vehicle-bar placement and unit-frame
configuration resolved locally, without inferring an exhaustive action/taint pass.
Reporter package beta.24-retail-test.2 now includes the override correction alongside
the cinematic and Premade Groups candidates. Frozen snapshot passes 68 Lua suites;
76 extracted files hash-match and six-manifest validation passes. Instructions,
checksum and build inventory are recorded in tests/QA-notes.md. Previous test.1
remains preserved; earlier references below describe its then-current scope.

Post-deployment visual retest: developer reports the override bar appears fixed;
screenshots show it bottom-centered in Mainhand. This is a local user-reported
placement PASS, without fresh actual-ability/exit-action or taint evidence.
The remaining complaint is the vehicle/player unit-frame position, with native
Edit Mode absent from the menu while in a vehicle.

Pinned Blizzard_UnitFrame/Mainline/PlayerFrame.lua explicitly changes PlayerFrame
to unit vehicle and PetFrame to unit player in vehicle art, reversing on exit.
The visible Salvaged Chopper unit frame therefore needs PlayerFrame placement
checked; a PetFrame entry in the /fstack list alone does not identify that visible
vehicle label. The selected /fstack overlay is still TimerTracker. PetFrame.xml
inherits EditModePetFrameSystemTemplate and EditModeManager.lua provides a
ShowPetFrame preview setting. Native configuration can be tested after exiting
the vehicle: Edit Mode, show Pet Frame, position player/pet frames, save, re-enter.
Do not bypass vehicle restrictions or add ordinary dragging to secure unit buttons.
No new unit-frame mutation or additional deployment was made for this follow-up.

The developer supplied an active Salvaged Chopper test in Ulduar on Retail
12.1.5 build 70688, addon Beta 24, combat=0. Physical canvas 4000x2560;
Mainhand RIGHT at 1440,6 with 2560x1440 extent, portrait workspace 1440x2560.
Diag reports OverrideActionBar shown at UIParent rect 1059/0/930/100, overlap=both,
and its first action button shown at 1224/17/45/45. The screenshot visibly places
the full bar near the span center. This establishes a user-observed active
placement failure, upgrading the earlier source-only gap. The /fstack selection
is TimerTracker; its listed stack also contains the override bar/exit frames.
Do not misidentify the selected timer overlay as the bar root.

Candidate in HUDTransientFrames adopts only the Retail stock OverrideActionBar
BOTTOM/UIParent/BOTTOM 0/0 anchor and moves the complete root to Mainhand bottom
center through the existing addon-owned secure anchor writer outside combat.
It preserves native children, buttons, art, scale, size, animation and visibility.
The anchor is prepared even while hidden, so later native vehicle entry does not
require an ordinary insecure OnShow mutation. No scripts or addon fields are
attached to the bar's native ancestry. Custom anchors, alternate parents,
action-bar replacements, controller layouts and managed systems yield.
Owned anchors restore on disable/unspan/feature-off, and combat requests coalesce
and re-evaluate current state afterward. Native action-bar/vehicle events and
the normal viewport lifecycle maintain the policy.

All 68 Lua suites and six-manifest Lua 5.1/path/XML checks pass. New simulation
covers secure snippet execution, hidden preparation, idempotence, mixed topology,
frame-scale conversion, restoration, ownership and combat exclusions. These are
not protected-action or taint-engine passes.

Three modules (HUDTransientFrames, HUDRecovery, Viewport) deployed to local Retail,
hash verified; installed validation passes. Backup and deployment inventory:
`D:/Games/World of Warcraft/_offhand_deploy_backups/retail-override-bar-20261031-182810-376`.
Bridges, SavedVariables, Companion and other clients unchanged. Existing reporter
test.1 archive remains unchanged and does not include this vehicle correction.

Live candidate retest pending: /reload out of combat, inspect the chopper bar and
exit control, exit/re-enter and confirm normal bars return. Repeat on Siege Engine
or Demolisher, then assess actual ability/exit actions, native animation and fresh
Lua/taint evidence. Full diag now includes RetailOverridePlacement=mainhand or a
specific defer/yield state. Earlier source-only findings below predate this candidate.

## Scope and evidence

We can identify the Blizzard frame families and inspect most placement contracts
without additional reporter evidence. A preview or hidden anchor is not proof of
active vehicle rendering, functional protected buttons or combat/taint safety.

Reporter target: Retail 12.1.5 build 70688, equal-height 3840x1080 span, gameplay
on the right. Shared knowledge status and C_ActionBar.HasOverrideActionBar lookup
were consulted. Pinned Blizzard mirror revision
15881d522c44cd106d3d8660106ec9f9d2f44167 identifies 12.1.5.70575, a different build.
Missing modules were inspected as source text via their pinned upstream paths;
upstream code was not executed or packaged. Native target behavior remains authoritative.

Source root:
<https://github.com/Gethe/wow-ui-source/tree/15881d522c44cd106d3d8660106ec9f9d2f44167/Interface/AddOns>.

## Frame inventory

| UI family | Native roots | Source contract and Offhand coverage |
| --- | --- | --- |
| Vehicle with a special/skinned bar | OverrideActionBar, OverrideActionBarButton1, OverrideActionBarLeaveFrame | Blizzard_OverrideActionBar/OverrideActionBar.xml declares a 1000x100 root at BOTTOM of UIParent, offset 0/0. Offhand excludes it from generic dragging but has no dedicated placement rule. Candidate coverage gap; active local reproduction pending. |
| Vehicle without a special skin, temporary action override | MainActionBar | Blizzard_ActionBarController/ActionBarController.lua selects the main action bar and vehicle/override page for unskinned states. Existing Mainhand Edit Mode layout covers the main bar. Test native action-page changes, not just position. |
| Vehicle leave button | MainMenuBarVehicleLeaveButton | Blizzard_ActionBar/Shared/VehicleLeaveButton.xml parents it to MainActionBar and uses an Edit Mode vehicle-leave template. Offhand has separate serialized layout refinement. The leave control is not the full vehicle bar. |
| Possession controls | PossessActionBar | Blizzard_ActionBar/Mainline/PossessActionBar.xml uses EditModeActionBarTemplate and protected button templates. Offhand refines its ActionBar system index in generated layouts. |
| Extra quest/encounter action | ExtraAbilityContainer, ExtraActionBarFrame, ExtraActionButton1 | Blizzard_UIPanels_Game/Shared/ExtraAbilityContainer.xml makes the container an Edit Mode Extra Abilities system. Native child registration/layout owns button placement. Offhand generates/repairs that system rather than force-showing the action. |
| Zone/context ability | ZoneAbilityFrame | Blizzard_ZoneAbility/ZoneAbility.xml uses the extraAbilities roleset. It shares container ownership, and is not an independent freely movable popup. |
| Encounter resource and contextual widget displays | EncounterBar, UIWidgetPowerBarContainerFrame, UIWidgetTopCenterContainerFrame | Separate frame families already appear in Offhand's protected-HUD or transient policies. Audit the actual root before applying action-bar handling to them. Not exhaustively source-reviewed in this pass. |

The native ActionBarController distinguishes skinned override bars from unskinned
MainActionBar page replacement. Testing only one does not cover the other.

## Diagnostics added

Current source `/offhand diag full` now includes main/possess/vehicle-exit/override
roots in interaction visibility and ownership output. Ownership reads parent,
anchor and protected/managed status even while the root is hidden. Capability
lines separately report native vehicle, override and temporary-action availability.
Missing APIs remain unsupported, failed reads unavailable, and combat reads defer.
No native frame is shown, moved, reparented, scripted or clicked by diagnostics.

All 67 Lua suites pass after the diagnostic extension, including hidden protected
root, capability-failure and combat exclusions. This changes diagnostics only;
no new vehicle placement correction has been implemented or claimed.
The existing reporter retail-test.1 ZIP remains unchanged and lacks this extension.

## Repeatable local verification

1. Use the local Retail test character in a safe state. Record exact running build,
   installed file hashes, display topology, current Edit Mode layout and any bar
   replacement addons. Preserve the source layout and user settings.
2. Collect `/offhand diag full` before entering a vehicle. Hidden anchor evidence
   can reveal the stock full-window BOTTOM root even without an active action.
   Treat this as source/geometry evidence, not an active runtime pass.
3. Use Blizzard Edit Mode to inspect systems it actually exposes, such as Extra
   Abilities and vehicle leave. A preview may not include the separate skinned
   OverrideActionBar. Any simulated overlay should use addon-owned, noninteractive
   frames and never fake native secure visibility/state.
4. Have a tester enter a suitable real vehicle/quest interaction manually when
   necessary. Agent QA can then inspect layout and collect evidence without
   automating travel, progression, combat or repeated gameplay.
5. Cover skinned override, unskinned main-action replacement, vehicle leave,
   Extra Abilities and zone ability independently. Confirm usable button bounds,
   tooltips/keybindings, native exit and return to normal bars. Inspect fresh Lua
   errors and taint. Exercise combat transitions manually where needed.
6. Repeat relevant geometry cases: right and left gameplay, equal-height span,
   mixed-height or portrait span, supported scale extremes, disable/unspan and
   resize. Verify reload/persistence and replacement-addon ownership.

For a confirmed override-root defect, prepare an isolated stock-anchor adapter
outside combat, preserving secure descendants, native show/hide/animations, custom
owners and disable/unspan restoration. Do not graft it onto generic panel dragging
or force a repair through protected UI at vehicle-entry time.

## Local client observation

The WoW test-harness and computer-use skills were consulted. An existing Retail
process was found at D:/Games/World of Warcraft/_retail_/Wow.exe. An initial
read-only screenshot showed the Trading Post, not an active vehicle. A subsequent
capture was inconsistent with the target window (displayed another application),
so no keyboard/mouse inputs or character tests were attempted. No GUI was launched,
no character was selected, and the user's existing client was left open. No native
vehicle action or visible position pass is established by this session.
