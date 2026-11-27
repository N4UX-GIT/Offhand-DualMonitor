# Built-in ForeverDungeonJournal Bridge

Built-in Offhand bridge (`Bridges/ForeverDungeonJournal/Bridge.lua`) for
**ForeverDungeonJournal**. It holds the journal parts of
`Core/CanvasAddonEscape.lua` and `Core/HUDRecovery.lua`, moved behind the
bridge contract with unchanged behaviour. The journal keeps its own geometry
and visibility.

## What it does

- Escape leaves the journal root `ForeverDungeonJournalFrame` open while it is
  on the workspace and the addon is loaded. The root is known by its name
  alone; its source location is not read.
- Its close button is the root's `closeButton`. The addon window picker may
  remember the journal's placement.
- The minimap visibility report lists its minimap button
  `LibDBIcon10_ForeverDungeonJournal` after the minimap, present or not.

## How core reaches it

- `data.windows`: the sourceless name `ForeverDungeonJournalFrame`, owner
  `ForeverDungeonJournal`.
- `IdentifyWindow(frame, name)`, `GetWindowCloseButtons(frame)`.
- `data.catalogs`: the `ForeverDungeonJournal` catalog entry
  (`learnPlacementFile` `core/journal.lua`, slash opener
  `FOREVERDUNGEONJOURNAL`).
- `data.frameRules.minimapDiagnosticFrame`: the minimap button.

It registers on every client and reads the addon when asked.

## Evidence

Automated tests pass (tests/forever-addon-settings-escape.lua,
tests/learned-addon-windows.lua, tests/bridges-contract.lua). The move itself
has not been run in a live client.
