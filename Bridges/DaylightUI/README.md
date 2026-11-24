# Built-in DaylightUI Bridge

Built-in Offhand bridge (`Bridges/DaylightUI/*.lua`) that keeps **DaylightUI**
on Offhand's Mainhand (game) monitor on Forever without requiring a second
addon folder, dependency, or separate SavedVariables file.

When DaylightUI is not installed or disabled, the bridge exits immediately on
load with zero frames, hooks, or slash commands. When DaylightUI is enabled,
`Offhand_Forever.toc`'s `## OptionalDeps: DaylightUI` guarantees DaylightUI
loads first, and the bridge activates automatically through `Offhand.API`
([docs/BRIDGES.md](../../docs/BRIDGES.md)).

## What it does

- **Anchor area and mover defaults:** Creates `OffhandDaylightUIArea` over
  Offhand's game rectangle so DaylightUI default movers, windows, pop-ups, top
  banners (`DaylightUIZoneTitle`, `DaylightUILevelUp`, `DaylightUIRepBanner`),
  AFK screen, "Welcome back" text, and Unlock Mode's Lock button stay on the
  game monitor. Positions dragged manually by the player are preserved.
- **Edit Mode layout:** Shifts DaylightUI's Edit Mode layout anchors onto the
  game rectangle when rebuilt. Prompts first with **"Apply and reload"** (or
  `/ohdaylight apply`) and supports both DaylightUI 2.2.3+ (`EditMode.Replace`)
  and 2.2.1 (`EditMode.ImportLayout`).
- **Scenes, DataBar, loot rolls, and followers:** Fits DaylightUI's fishing and
  crafting scene, campfire and sleeping-bag scene, and InfoPanel DataBar to the
  game rectangle; anchors loot rolls to Offhand's Group Loot Rolls spot unless
  placed with DaylightUI's handle; prevents Offhand's placement from hiding
  DaylightUI's vendor/trainer windows.
- **World map & bags:** Stands DaylightUI's map mover aside while Offhand owns
  the compact world map, and keeps `DaylightUIBag` open on Offhand when
  pressing Escape.
- **Learned addon windows:** Excludes `DaylightUI_*` HUD/mover modules from
  Offhand's generic addon window picker, pauses selection while DaylightUI's
  Unlock Mode is active, and allows `DaylightUIOptions` (`options/panel.lua`)
  with native fade-on-Escape preserved.

## Commands and storage

- `/ohdaylight` — shows the game rectangle, layout status, map owner, and loot roll position.
- `/ohdaylight apply` — prompts to rebuild DaylightUI's Edit Mode layout for the game rectangle and reload.
- Stored inside `OffhandDB.bridges.DaylightUI` (account-wide), with one-time
  migration from legacy `DaylightOffhandDB.rect`. If the standalone
  `DaylightOffhand` addon is still enabled, the layout half stands down cleanly
  so offsets are never doubled.

## Origin and evidence

- Layout bridge originally authored by **Kintrok (`@DCtheGeek`)** as
  `DaylightOffhand` and submitted in PR #136; map and bag adapters moved from
  `Core/DaylightMapCompatibility.lua` and `Core/BagPersistence.lua`.
- Automated tests pass (`tests/bridges-contract.lua`,
  `tests/bridge-daylightui-layout.lua`, `tests/bridge-daylightui-map.lua`,
  `tests/learned-addon-windows.lua`, `tests/baganator-persistence.lua`).
  Live Forever QA with DaylightUI 2.2.3 is pending in this packaged form.
