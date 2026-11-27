# Built-in MapWise Bridge

Built-in Offhand bridge for **MapWise**'s compact world map on the Forever
client. `Bridge.lua` holds the MapWise parts of `Core/CanvasForeverMap.lua`,
moved behind the bridge contract with unchanged behaviour. Offhand keeps the
World Map's placement while MapWise is loaded; MapWise keeps its own window,
move, resize and reset paths.

## What it does

- Reads only MapWise's reviewed contract: `MapWiseAPI` major version 2, MapWise
  loaded, `MapWiseAPI.db` being `MapWiseAtlasDB` and its integration on the
  native map. Any other version stands down.
- Movement fade: MapWise's `fadeMapWhileMoving` is held off while the map is on
  the workspace and restored afterwards.
- Position guard: MapWise replays its passive compact anchor after its own
  layout, including tab switches with identical dimensions. While Offhand is
  enabled, spanned and owns a saved map position, that replay is skipped and
  the map is fitted on Offhand's independent observer instead, outside the
  click or native map stack.
- While MapWise is loaded, Offhand's combat anchor repair of the compact map
  stands aside.

## How core reaches it

- `mapProvider` (owner `MapWise`) through `Bridges:CallMap`: the Forever map
  observer calls `InstallPositionGuard(map, state, services)` while MapWiseAPI
  exists (role `map.layoutGuard`) and the guard is not installed, and
  `UpdateLayout(map, state, shown, maximized, services)` once it is. The map
  state fields `layoutGuard`, `layoutOpened`, `layoutPending` and
  `layoutPlacement` are shared with the observer.
- `data`: the `map.fade` entry (order 30) with its reader; `Data.lua` holds the
  map integration entry and the `map.layoutGuard` and
  `map.blocksCombatAnchorRepair` roles.

It registers on every client (id `MapWise`) and reads MapWise when asked.

## Evidence

Automated tests pass (tests/forever-map-escape.lua, tests/mainhand-placement.lua,
tests/bridges-contract.lua). The move itself has not been run in a live client.
