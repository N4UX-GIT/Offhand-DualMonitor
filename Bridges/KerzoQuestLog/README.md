# Built-in Kerzo Classic Quest Log Bridge

Built-in Offhand bridge (`Bridges/KerzoQuestLog/Bridge.lua`) for **Kerzo
Classic Quest Log** (written against Kerzo 6.1.4). It is the former
`Core/CanvasKerzoQuestLog.lua` moved behind the bridge contract, with unchanged
behaviour. Kerzo keeps its own geometry, visibility and modal Escape order.

## What it does

- On the Forever client, while the quest log root `KerzosQuestLog` is open on
  the workspace (Offhand enabled, workspace panels kept open, spanned, no
  controller owner, no geometry transition), Escape leaves it open: the root's
  `UISpecialFrames` entry is removed. Kerzo's own modal entries are never
  touched; when the root leaves the workspace Kerzo is asked to recompute its
  Escape state.
- It hooks Kerzo's `ActualizarEstadoEscapeModal`, `MemorizarPosicion` and
  `CalibrarCabeceraYCierre`, so a vendor redraw or drag is followed at once and
  the workspace close buttons refresh with it.
- With reload restore on, a quest log left open on the workspace is reopened
  through Kerzo's own opener after a reload, within 15 seconds of entering the
  world. Closing it clears that intent. Nothing is done in combat.

## How core reaches it

- `Refresh("persistence")` and `Refresh("tick")` (skipped during a geometry
  transition): the Escape and reload pass. Other reasons are ignored.
- `PrepareTransition()`: stops sampling the open state before teardown hides the
  root. `BeginSession()`: resumes sampling, and on the first world entry reads
  the saved intent.
- `data.catalogs`: the `Kerzo Classic Quest Log` addon window catalog entry.
- `data.frameRules.workspaceChrome`: `KerzosQuestLog` for the workspace close
  button handling.
- `data.settings`: the character setting `kerzoQuestLogOpen`, stored under the
  same key in `OffhandCharDB` as before and cleared on a character change.

It registers on every client before Kerzo exists and looks the root up on each
refresh, so a Kerzo that loads after Offhand is still handled.

## Evidence

Automated tests pass (tests/kerzo-quest-log.lua, tests/kerzo-quest-log-reload.lua,
tests/forever-addon-window-timing.lua, tests/workspace-close-buttons.lua). The
move itself has not been run in a live client.
