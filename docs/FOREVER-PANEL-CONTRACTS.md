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

## Evidence levels

- `static`: Lua parses, manifests validate, and no forbidden API pattern is found.
- `simulated`: repository tests reproduce the interaction and pass.
- `live candidate`: static and simulated evidence pass, but live client testing is pending.
- `live verified`: the exact interaction matrix has passed in the supported client.

Mock tests cannot promote a protected UI change beyond `live candidate`.
