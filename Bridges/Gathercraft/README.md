# Built-in Gathercraft Bridge

Built-in Offhand bridge (`Bridges/Gathercraft/Bridge.lua`) for
**Gathercraft**. Gathercraft's world-map pins pile up as hidden children of
UIParent until `UIParent:GetChildren()` overflows, and its windows open around
UIParent's centre, which with Offhand is the seam between monitors. The bridge
is inert (no frame, hook or timer) unless Gathercraft is loaded on the Forever
client. It replaces the standalone `GathercraftOffhand` addon.

## What it does

- **World-map pins:** every pin Gathercraft hands to HereBeDragons for the
  world map (refs that start with `Gathercraft`) is moved under the holder frame
  `OffhandGathercraftPins`, and moved back there whenever HereBeDragons returns
  it to UIParent. Pins already registered are swept once the library is found;
  new ones are caught by hooks on `AddWorldMapIconMap` and `AddWorldMapIconWorld`.
- **Cards:** `GathercraftWelcome`, `GathercraftWhatsNew`,
  `GathercraftRunSummary` and `GathercraftSkillPlan` (`CENTER 0,120`) move to
  the same spot of the game rectangle.
- **Plan windows:** `GathercraftPlanHint` and `GathercraftPlanGathered`
  (`CENTER 0,140`) and `GathercraftPlanZones` (`CENTER 0,60`) move likewise.
- **Farm panel, arrow and main window:** `GathercraftPanel` (`CENTER 0,200`),
  `GathercraftArrow` (`CENTER 0,300`) and `GathercraftMain` (`CENTER 0,0`)
  move while still at Gathercraft's default.

## What it leaves alone

- Any window the player dragged somewhere else (Gathercraft saves those spots).
- Pins of other addons, and pins while a map holds them.
- Minimap pins that were never near the player and route "head" dots that were
  never shown stay hidden under UIParent (only relevant with Gathercraft's
  minimap pins or route line switched on).

## Diagnostics

`/offhand diag` shows `GathercraftAnchors=<moved>/<total>` and
`GathercraftPins=<pins taken over>`.

## Origin and evidence

- Contributed by Kintrok (@DCtheGeek).
- Read against Gathercraft 0.2.2.
- Automated tests pass (tests/bridge-gathercraft.lua). Live Forever QA is pending.
