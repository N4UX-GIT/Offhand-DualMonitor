# Forever HUD mapping between Offhand and EllesmereUI

For the 1.60.1.70862 / EllesmereUI 9.8.4 refinement candidate and its live
validation, see [the 10 November follow-up](FOREVER-ELLESMERE-HUD-REFINEMENT-20261110.md).
The initial inventory below records the earlier implementation and proposals.

Scope is Forever 1.60.1.70790 and EllesmereUI 9.7.8. The current behavior and
candidate mappings below come from source review. The standard import has
been verified in the local client. The visual preview and reverse copy cover
the five entries marked as supported in the initial scope. The rest of this
document describes proposed extensions.

## What Create Mainhand HUD Layout does today

The wizard and Recovery button use the same native layout generator. It
starts from a Blizzard Edit Mode source, uses the native Gamepad preset when
appropriate, and saves a separate Mainhand layout. It carries rows recognized
as externally owned through from the native source without repositioning
them. This check currently covers Action Bars, Status Tracking Bars, Unit
Frames, Party/Raid, Minimap, Chat, Cooldown Viewer, and Quest Tracker under
their respective ownership conditions. The button does not use EllesmereUI's
active profile as a layout source. That profile stays active, so any of its
frames that land off a physical display after spanning still need a placement
step. The existing `/offhand ellesmere import` is a separate action that
copies a small set of Blizzard positions into a new EllesmereUI profile.

## Position mappings

Each native system is classified below. A declared system or index can be
absent from the chosen Forever layout or interface style. Require a matching
row and a registered, available EllesmereUI element before proposing a copy.
The mapping covers position. Bindings, action slots, skins, and widget
behavior stay with the provider that owns them.

| Blizzard Edit Mode system | EllesmereUI counterpart and handling |
| --- | --- |
| `ActionBar.MainBar` | Action Bars `barPositions.MainBar`. The standard Offhand → EllesmereUI path exists. Reverse candidate. It can depend on `MicroMenuContainer` on the native side. |
| `ActionBar.Bar2`, `Bar3`, `RightBar1`, `RightBar2`, `ExtraBar1`, `ExtraBar2`, `ExtraBar3` | Action Bars `barPositions.Bar2` through `Bar8`, respectively. Bidirectional candidates. Map by native bar identity. |
| `ActionBar.StanceBar`, `PetActionBar` | Action Bars `barPositions.StanceBar` and `barPositions.PetBar`. Bidirectional candidates. Verify class and pet visibility and anchoring. |
| `ActionBar.PossessActionBar` and legacy class/totem action-bar variants | Keep the native rows. The current generator preserves the ambiguous legacy Forever ClassBar row. Check `TotemActionBar` separately from the legacy row. |
| `GamepadMainActionBar` | Native radial controls. Keep the Gamepad preset and its position logic. The EllesmereUI numbered bars are a separate visibility choice. |
| `UnitFrame.Player`, `Target`, `Focus` | Unit Frames `positions.player`, `target`, `focus`. The Offhand → EllesmereUI path exists. Reverse candidates. |
| `UnitFrame.Pet`, `Boss`, `Arena` | Unit Frames `positions.pet` and `boss` are candidates for the first two. Verify target-side dimensions and growth before applying. No corresponding Arena mover was identified in the Unit Frames registrations. Keep its native row. |
| `UnitFrame.Party`, `Raid` | Raid Frames `RF_PartyFrames` (`partyUnlockPos`) and `RF_RaidFrames` (`unlockPos`). Candidate block anchors only. Group size, growth, layouts per raid size, and relative anchoring need separate checks. |
| `Minimap` | Minimap `EBS_Minimap` (`minimap.position`). The Offhand → EllesmereUI path exists when the standalone module owns it. Reverse candidate. When the module is disabled, use the native Minimap path. |
| `ChatFrame` | Chat `ECHAT_MainChat` (`chatPosition`). Candidate for the primary chat window only. Retain the intended Mainhand or workspace region. Validate size, tabs, and additional native windows separately. |
| `CastBar` | Resource & Cast Bars `ERB_CastBar` is the candidate player cast bar. The player mini cast bar and the target/focus cast bars are separate EllesmereUI movers. |
| `StatusTrackingBar` | Use the native rows when `useBlizzardDataBars` is enabled. If Action Bars replaces them, XP and Reputation are conditional candidates. Verify row identity and stacking. EllesmereUI DataBars is a different module. |
| `ObjectiveTracker` | With a saved position, `EQT_Tracker` already writes position and height into the active custom Blizzard layout. Let this bridge be the writer. Without an EllesmereUI position, the native row can supply the placement. |
| `MicroMenu`, `Bags`, `EncounterBar` | Blizzard owns position on Forever even when EllesmereUI changes appearance or visibility. Use the native rows. `Bags` is the bag-button bar. The inventory window is a separate workspace panel. |
| `CooldownViewer` | Compare Essential, Utility, Buff Icon, and Buff Bar with the enabled CDM containers before defining any copy. A custom or split CDM layout can have no one-to-one native counterpart. |
| `DamageMeter` | EllesmereUI Damage Meters can replace the native UI and save multiple independent windows. Keep those in the EllesmereUI profile until a specific window pairing is verified. |
| `AuraFrame`, `HudTooltip` | Verify the actual owner and shape. The EllesmereUI tooltip mover has a fixed-position mode. Cursor-follow behavior and separate buff/debuff arrangements cannot be inferred from a native position alone. |
| `ExtraAbilities`, `VehicleLeaveButton`, `MainActionBarEndCap`, `TotemActionBar` | Native or situational controls on this build. Preserve and place the available native rows. The Forever Action Bars module does not expose its Extra Action Button mover. |
| `TalkingHeadFrame`, `LootFrame`, `DurabilityFrame`, `TimerBars`, `VehicleSeatIndicator`, `ArchaeologyBar`, `PersonalResourceDisplay`, `EncounterEvents`, `RaidWarning`, `GroupFinder`, `LossOfControl`, `SwingTimer` | Retain the native layout rows by default. An addon skin, auxiliary mover, or similar label alone does not establish an equivalent position owner. Audit enabled replacement or holder frames per module. |

The other side of the inventory starts with all registered EllesmereUI
movers for the current profile and mode. Give each one a result in preview.
Preserve anchored children and size relationships with the profile. List
unavailable or unclassified movers explicitly so the preview can account
for the whole layout even where a mover lacks a native equivalent.

| EllesmereUI modules | Handling for remaining elements |
| --- | --- |
| Action Bars, Unit Frames, Raid Frames, Resource & Cast Bars | Keep extra bars 9–10, target-of-target, focus-target, unit-frame cast bars, class resources, healer mana, and other supplemental movers with their profile. |
| Chat, Minimap, Quest Tracker | Transfer only the matched main element. Keep chat toast, minimap attachments, and tracker presentation with the addon that owns them. |
| Cooldown Manager, AuraBuff Reminders, Damage Meters, DataBars | Keep custom bars, reminders, window sets, and information displays in their profile. |
| Forever Essentials, QoL, Blizzard Skin | Keep addon-only widgets with EllesmereUI. Inspect native-frame holders individually for shared ownership, including tooltip, loot, and alert placement. |
| Bags | Inventory is a workspace window. EllesmereUI saves `bagsPosition`; Offhand tracks workspace visibility and restores it when appropriate. |
| Nameplates, Quickdraw, Friends, Group Finder, Mythic Timer | Keep these module settings and any extra movers with EllesmereUI. A module named after a native panel does not by itself establish a placement match. Detect client availability. |
| Core, Options, Locales | Keep profile, UI settings, and language state with EllesmereUI. Report any registered movers individually. |

Map, character, inventory, and other workspace windows follow their own
position and open-state rules. Keep their reload and Escape behavior separate
from the HUD transfer. The Game Menu, settings, and Unlock Mode toolbar are
also separate from the profile-to-layout mapping.

## Proposed setup flow

1. At setup or regeneration, preview the active EllesmereUI profile and
   Blizzard source alongside the current span and input mode. Use the actual
   mover, native row, and provider setting to determine who owns a position.
2. With an existing EllesmereUI layout, default to **Keep my EllesmereUI
   layout** and create the Mainhand layout for native controls. If any saved
   positions need adapting, offer **Adapt a copy for this span**. Use the
   EllesmereUI placements as the source for its own frames and apply the copy
   through its normal profile confirmation. Keep already reachable positions
   and intentional workspace placements. Capture the original display
   geometry before spanning when available. If the client is already spanned
   and the profile's original geometry is unknown, require review for moves
   whose intended display cannot be established.
3. With an existing Offhand layout and a new EllesmereUI setup, offer
   **Copy Offhand positions to EllesmereUI**. Start with the reviewed native
   anchors and apply only the selected mappings to a new EllesmereUI profile.
   If both sides have custom positions, show both and let the user choose
   which side supplies the selected positions.
4. Offer **Create Blizzard fallback from EllesmereUI** separately. Read the
   selected EllesmereUI placements and copy only verified counterparts into a
   separate Blizzard layout. Use native settings and positions for the rest.
   Keep that fallback inactive while the replacement modules own the HUD.
5. Store the source and destination identity, mode, and geometry for generated
   layouts. Convert source offsets through a common physical display-relative
   position and then into the target's units. Apply the translation once.
   Resolve relationships only where both endpoints and their anchors are
   understood. A preview can mark a linked or override-specific mover as
   kept, unavailable, or requiring review. Do not flatten it automatically.

Use the same reviewed unit and minimap positions across standard and Gamepad
when both use the same profile and placement. Offer a separate EllesmereUI
profile copy if the player wants different placements. Review numbered bar
visibility independently of the native radial layout. Recheck the active
profile, style, geometry, and module ownership before applying a preview.

Step 5 creates or confirms a matching native HUD. Step 6 offers the read-only
preview once that layout is ready. The wizard resumes there after the reload
for a newly created or newly selected layout. When EllesmereUI takes over
frames on an already active matching character layout, character setup opens
Step 6 directly and starts on Copy. If ownership returns to Blizzard,
refresh the native layout. Preview and import review take the place of the
wizard while open. The wizard offers a reload after the imported EllesmereUI
profile becomes active. Recovery & Preview also offers Fit independently. Copy in
either direction requires an Offhand layout verified for the current span
and input mode. The reverse path saves an inactive native copy, and its
diagram shows anchors because native frames can have different dimensions.
Extend the map after ownership and placement checks for each new group.

Acceptance covers both install orders, an existing customized layout, a
mixed-height span, both input modes, and repeated create or reload. Verify
that a declined import preserves the current profile, switching modes keeps
the native Gamepad controls, a fallback works after disabling the mapped
EllesmereUI module, and Unlock Mode and workspace Escape still work. Keep
out-of-combat placement checks separate from protected-action testing.

## Source references

- [Offhand ownership checks](../Core/HUDCompatibility.lua), [layout generator](../Core/MainhandEditMode.lua), and [current transfer](../Core/ForeverEllesmereLayout.lua).
- [Forever Edit Mode enums](https://github.com/Gethe/wow-ui-source/blob/eac30af597e5aaa43a60f6675ef5fdcea100375f/Interface/AddOns/Blizzard_APIDocumentationGenerated/EditModeManagerConstantsDocumentation.lua) and [layout structures](https://github.com/Gethe/wow-ui-source/blob/eac30af597e5aaa43a60f6675ef5fdcea100375f/Interface/AddOns/Blizzard_APIDocumentationGenerated/EditModeManagerDocumentation.lua).
- EllesmereUI 9.7.8 installed source, especially `EllesmereUIActionBars.lua`, `EUI_ActionBars_ExtraBars.lua`, `EUI_UnitFrames_Unlock.lua`, `EUI_RaidFrames_PartyLayout.lua`, `EllesmereUIQuestTracker_Position.lua`, and `EllesmereUI_Profiles.lua`.
