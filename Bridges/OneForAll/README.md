# Built-in OneForAll Bridge

Built-in Offhand bridge for **OneForAll**'s Move Blizzard windows option. It is
the former OneForAll conflict detection and diagnostics of
`Core/CanvasCompatibility.lua`, moved behind the bridge contract with unchanged
conflict ids, notices and diagnostics text.

## Files

- `Data.lua`: facts only. OneForAll marks each window it can move with
  `frame.ofaMovable = true` and sets `frame.ofaMoving` while dragging one
  (`moverFields`). Core's generic anchor repair (panel anchors, workspace repair,
  the Forever Game Menu) reads those marks.
- `Bridge.lua`: conflicts and diagnostics, while OneForAll is loaded and its
  `OneForAllDB.qol.moveWindows` is not turned off.

## What it reports

- `GetOwnershipConflicts(context)`: `worldmap-mover:OneForAll+<owner>` (order 20)
  when OneForAll moves the World Map of an owner that positions it and that
  owner does not keep the mover in sync (Forever); `window-mover:OneForAll`
  (order 40) for the Offhand roots it moves unmitigated: the World Map without
  a map owner, the combined bags without a bag addon, and on Forever the
  Settings panel and the Cooldown Viewer settings.
- `GetMoverDiagnostics(context)`: `WorldMapMover=OneForAll(synced|conflict)` and
  `OneForAllMover=active` in the full compatibility diagnostics line.

Core words the notices (`COMPAT_CONFLICT_WORLDMAP_MOVER`,
`COMPAT_CONFLICT_WINDOW_MOVER`) and sorts the conflicts with its own. It creates
nothing and hooks nothing, and registers on every client.

## Evidence

Automated tests pass (tests/canvas-compatibility.lua, tests/panel-anchor-flicker-defense.lua). The move
itself has not been run in a live client.
