# Built-in Leatrix Bridge

Built-in Offhand bridge for **Leatrix Maps**, **Leatrix Plus** and **Leatrix
Sounds**. `Settings.lua` holds the Leatrix parts of `Core/CanvasAddonEscape.lua`,
moved behind the bridge contract with unchanged behaviour. The addons keep
their own geometry and visibility. The Leatrix Maps world map handling stays
in the core for now.

## What it does

- The addons' configuration panels are anonymous roots with random names: an
  `F` and sixteen letters or digits, on the `FULLSCREEN_DIALOG` strata, created
  by the addon's own main file (`Leatrix_Maps.lua`, `Leatrix_Plus.lua`,
  `Leatrix_Sounds.lua`). A panel of the vendor's own shape is a settings window
  that Escape leaves open while it is on the workspace; any other such root,
  and the help and report panels, keep closing with Escape.
- Close buttons: the Sounds panel's `cb`; a Maps or Plus panel's `c`, else its
  helper-made X buttons (30 by 30, at its top-right corner, created by the same
  main file), from its direct children only.

## How core reaches it

- `data.windows`: the panel name pattern, owners `Leatrix_Maps`,
  `Leatrix_Plus` and `Leatrix_Sounds`.
- `IdentifyWindow(frame, name, source)`, `GetWindowCloseButtons(frame, owner)`.
- `data.catalogs`: the three catalogs (slash openers named after the folders,
  and the Leatrix Maps world map entry).

It registers on every client (id `Leatrix`) and reads the addons when asked.

## Evidence

Automated tests pass (tests/forever-addon-settings-escape.lua,
tests/forever-addon-window-timing.lua, tests/bridges-contract.lua). The move
itself has not been run in a live client.
