# Forever panel contracts

This document defines ownership boundaries for movable panels in the Forever
client. A panel is not considered stable until its contract passes both the
Lua regression suite and the live interaction matrix below.

## Ownership rule

Exactly one controller may write the position of a high-risk panel family.
Visibility, focus, Escape handling, and position are separate responsibilities.
Moving a panel does not grant Offhand ownership of its native visibility or
focus lifecycle.

| Panel family | Position controller | Visibility and focus owner | Reload position | Generic peer repair |
| --- | --- | --- | --- | --- |
| World Map | `forever-world-map` | Blizzard | Saved Offhand or Mainhand position | Excluded |
| Friends, Social, Communities | `forever-social-community` | Blizzard | Saved Offhand or Mainhand position | Excluded |
| Standalone Professions | `forever-professions` when compatibility is enabled | Blizzard, except the bounded Offhand Escape transaction | Saved Offhand or Mainhand position | Excluded |
| Edit Mode and protected HUD systems | Blizzard | Blizzard | Blizzard Edit Mode layout | Excluded |
| Ordinary UIPanels | `generic` | Blizzard | Saved explicit position where supported | Included |
| Context panels such as Flight Map and Auction House | Panel-specific lifecycle with generic geometry only | Blizzard interaction lifecycle | Position only, never forced open | Included only when safe |
| Replacement bag addons | Bag compatibility adapter | Bag addon | Adapter-specific | Excluded from panel handles |

The implementation source of truth is `Canvas:GetPanelController`. The
`/offhand diag` report includes the assigned controller and its most recent
position repair for World Map, Social, Communities, and Professions roots.

## Escape contract

- Blizzard owns ordinary close behavior.
- An Offhand panel remains open on Escape only when its documented workflow
  explicitly requires it.
- Professions uses a bounded transaction: a native Professions hide followed
  immediately by the Game Menu toggle is treated as Escape and restored.
- An explicit Professions close without that paired Game Menu transaction
  remains closed.
- Offhand must not broadly reopen every saved panel after Escape.
- In native Gamepad mode outside combat, a focused Offhand destination uses
  Blizzard's `TOGGLEUIFOCUS` binding for B. Gameplay B and Mainhand-focused
  windows keep their native action. Temporary dismiss-on-unfocus frames yield.
- Escape and Game Menu retain their native dispatcher and panel layout. The
  prior addon-priority registration is withdrawn after OH-FOR-012: sorting the
  shared native handler list from addon context can contaminate earlier
  protected casting callbacks in both Gamepad and keyboard mode. Offhand must
  not register a replacement callback or invoke protected casting to hide it.
- Gamepad B retention remains a candidate with reporter acceptance. Combat
  releases its override. Escape workspace retention is pending a replacement
  that does not mutate the shared dispatcher or native menu metadata. Native
  focus and protected-action safety still require live evidence.

## Drag contract

- A drag writes one final saved position after the drag stops.
- Position repair must not compete with the active drag.
- Replacement bag frames do not receive Offhand panel handles.
- Protected Edit Mode systems do not receive Offhand panel handles.
- A panel with a dedicated controller is never moved by generic peer repair.

## Required interaction matrix

Test each row in standard UI mode and gamepad mode where the client supports
the panel. Repeat with the panel on Mainhand and Offhand.

| Starting panel | Action | Expected result |
| --- | --- | --- |
| World Map | Open and close another UIPanel | Map position does not change |
| Friends or Social | Open and close Professions, Communities, Collections, Character, and Spellbook | Social position does not change |
| Communities | Open and close Friends or another UIPanel | Communities position does not change |
| Professions | Drag, reload, reopen | Position is restored without repeated open audio |
| Professions on Offhand | Press Escape | Professions remains open and Game Menu opens |
| Professions | Use its explicit close control | Professions closes |
| Auction House | Move to Offhand, leave NPC, return, reopen | Frame remains recoverable and visible |
| Flight Map | Reopen at multiple flight masters | Frame remains fully visible |
| Options | Open and close with replacement bags installed | Bag frame does not flicker or play a false open cue |

## Forever 1.60.1.70938 panel inventory

The native manager assigns slots and can reposition an already-visible peer
before rendering the newly opened panel. Recheck the surviving peer after
closing either panel. A native slot replacement can deliberately close a peer,
so verify the resulting slot and visibility before assessing placement.

| Native roots | Coverage and activation |
| --- | --- |
| `PlayerSpellsFrame`, `ProfessionsFrame` | Loaded on demand. The automated test runs both opening and closing orders before delayed repairs. The current candidate passed both live. `SpellBookFrame` is a child on the tested route. |
| `CharacterFrame`, `CollectionsJournal` | The regression checks cover Collections followed by Professions, and Character followed by Collections. Both must remain on Mainhand through native peer open and close. Character can retain its user-placed flag after the native slot manager overwrites its anchor. The test covers that flag and a separate custom anchor. |
| `FriendsFrame` / `SocialUIFrame`, `CommunitiesFrame` | Shared slots with a dedicated Offhand controller. Forever live testing identified `SocialUIFrame` and confirmed these two panels kept their anchors through Spellbook open and close. |
| `PVEFrame`, `PVPUIFrame`, `RaidParentFrame`, `EncounterJournal`, `GuildControlUI`, `ChatConfigFrame` | Simulated as shared-slot peers in the panel regression. The test checks the already-open Spellbook and its native slot. Availability, each peer's placement, and native close rules still need client evidence. Guild permissions and the character's progression can limit which entry points are available. |
| `MerchantFrame`, `TradeFrame`, `MailFrame`, `QuestFrame`, `GossipFrame`, `LootFrame` and load-on-demand bank, auction, trainer and taxi windows | Native interactions control opening and close. Exercise them as peer triggers when available. Keep the interaction, slot and focus intact. Recheck the peer when the interaction ends and when the same interaction reopens. |
| `EditModeManagerFrame`, `GameMenuFrame`, `CinematicFrame`, `PVPMatchScoreboard`, `PVPMatchResults` | Specialized fullscreen or transient routes. Apply each panel's own visibility and focus contract. |

Run `lua tests/party-editmode-and-void-rescue.lua` for the simulated cases.
CI treats the Collections and Character cases as required checks. The pinned [panel
registrations](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_UIParentPanelManager/Mainline/UIPanelWindows.lua)
and [layout implementation](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua#L577-L703)
describe the registered roots and reflow order. Registrations alone cannot
establish character access to the corresponding feature.

## Evidence levels

- `static`: Lua parses, manifests validate, and no forbidden API pattern is found.
- `simulated`: repository tests reproduce the interaction and pass.
- `live candidate`: static and simulated evidence pass, but live client testing is pending.
- `live verified`: the exact interaction matrix has passed in the supported client.

Mock tests cannot promote a protected UI change beyond `live candidate`.
