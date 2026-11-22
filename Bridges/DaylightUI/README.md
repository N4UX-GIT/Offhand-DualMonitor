# Offhand_DaylightUI

A bridge addon that keeps DaylightUI on Offhand's game monitor. It loads only
when both Offhand and DaylightUI are enabled. It changes no file of either
addon. The bridge contract it uses is described in
[docs/BRIDGES.md](../../docs/BRIDGES.md).

DaylightUI places its frames against `UIParent`. With Offhand spanning WoW
across several monitors, `UIParent` covers all of them, so DaylightUI's bars,
windows and banners land in the middle of the whole span. The bridge moves
DaylightUI's work onto Offhand's game rectangle (the Mainhand monitor). With
Offhand off, or WoW on one screen, the game rectangle is the whole screen and
nothing changes.

## What it does

- **Anchor area and mover defaults.** A frame of the bridge's covers the game
  rectangle. Frames DaylightUI places itself, including its movers' default
  positions, are anchored to it. A position the player has dragged a frame to
  is kept as it is; DaylightUI saves those in plain screen terms.
- **Edit Mode layout.** Frames the game places (action bars, cooldown viewers
  and so on) live in DaylightUI's Edit Mode layout. Their screen-edge offsets
  are shifted onto the game rectangle when the layout is written. When the
  saved layout no longer matches the game rectangle, the bridge asks with an
  "Apply and reload" prompt; nothing is rewritten without that confirmation.
- **DaylightUI windows and pop-ups** open on the game monitor.
- **Top banners:** zone title, level-up and reputation banners appear at the
  top of the game monitor.
- **AFK screen** covers the game monitor.
- **"Welcome back"** text is centred on the game monitor.
- **Unlock mode:** the Lock button stays on the game monitor.
- **Fishing and crafting scene** is placed on the game monitor.
- **Campfire and sleeping-bag scene** is placed on the game monitor.
- **Data bar** width matches the game monitor.
- **Loot-roll cards** use Offhand's group loot spot unless the player has
  placed DaylightUI's roll handle.
- **Vendor and trainer windows** open on the game monitor.
- **World map:** while Offhand places the compact world map itself, DaylightUI's
  map mover stands down, so the two do not fight over the map.
- **Bags:** on Forever, a DaylightUI bag sitting on Offhand stays open when
  Escape is pressed for something else, using Offhand's bag Escape services.

## Commands

- `/ohdaylight` prints the game area, whether DaylightUI's layout is in place
  or needs moving, who owns the world map, and where loot rolls appear.
- `/ohdaylight apply` rebuilds DaylightUI's Edit Mode layout for the game area
  and reloads the UI, after confirmation.

## Saved variables

`OffhandDaylightUIDB` (account-wide). It records the game rectangle the
DaylightUI layout was last written for. If it is empty and the old
`DaylightOffhandDB` is present, that rectangle is taken over once. The bridge
writes DaylightUI's Edit Mode layout only through the "Apply and reload" step
above.

## Origin

The layout half is ported from "DaylightOffhand", a personal addon by Kintrok.
The world map and bag pieces moved here from Offhand's core, where they lived
in `Core/DaylightMapCompatibility.lua` and `Core/BagPersistence.lua`.

### Moving from DaylightOffhand

Disable or delete `DaylightOffhand`. Both addons shift the same DaylightUI
functions, so running both would shift everything twice. While the old addon
is loaded, this bridge stands its layout half down and says so at login and in
`/ohdaylight`. The map and bag pieces still run.

## Evidence

- The layout behaviours above were observed live by the author in the personal
  DaylightOffhand addon on Forever 1.60.1 with DaylightUI 2.2.1 and Offhand
  2.1.5 beta.38. The trainer window was not checked separately.
- The world map adapter's live history is in
  [docs/DAYLIGHT-MAP-NATIVE-QA-20261110.md](../../docs/DAYLIGHT-MAP-NATIVE-QA-20261110.md).
  The DaylightUI Bags row in [docs/COMPATIBILITY.md](../../docs/COMPATIBILITY.md)
  was recorded while that handling was part of Offhand's core.
- This packaged bridge (its own load order, the contract calls, the renamed
  saved variables) has automated tests only (`tests/bridge-daylightui-*.lua`,
  `tests/bridges-contract.lua`). It has not been run in a game client yet.

## Known gaps

Left alone for now:

- the quest breadcrumb trail;
- the NPC scene inset;
- the centre line of the unlock grid;
- DaylightUI's tour and installer.

The bridge depends on DaylightUI internals. Check it again whenever DaylightUI
updates; pieces whose internals no longer match stand down rather than guess.
