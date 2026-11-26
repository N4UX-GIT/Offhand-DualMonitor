# Built-in OpenMap Bridge

Built-in Offhand bridge for **OpenMap**'s world map. `Recovery.lua` is the
former `Core/OpenMapRecovery.lua`, and `Contract.lua` and `Map.lua` hold the
OpenMap parts of `Core/CanvasCompatibility.lua`, `Core/CanvasForeverMap.lua`,
`Core/MapScale.lua`, `Core/ExpandedMap.lua`, `Core/MainhandGamepad.lua`,
`UI/Options.lua` and the slash handler, all moved behind the bridge contract
with unchanged behaviour. OpenMap keeps its own geometry, scale and saved
window; Offhand reads its reviewed contract (`OpenMapAPI.major == 1`,
version 4 or later, the `OpenMapDB.worldmap` schema) and stands down when it
breaks.

## What it does

- Camera follow: a centered OpenMap camera follows the player while the map is
  on the workspace; browsing away pauses it until the player centers it again.
- Movement fade: while OpenMap's world map module is active its own `moveFade`
  is held opaque on the workspace map and restored afterwards, and its fader is
  re-enabled through the vendor when the map stays open.
- Map Scale: the setting uses OpenMap's `windowScale` option (range 0.5 to 1.6,
  step 0.05) on Forever, and the card shows "(OpenMap)", the OpenMap help, the
  workspace help and the two recovery buttons.
- Recovery: **Recover** and **Place on workspace** (and `/offhand recovermap`,
  `/offhand recovermap offhand`) move the windowed map back into Mainhand or the
  workspace by writing OpenMap's own saved anchor first; the expanded map hotkey
  uses the same recovery, shrinking the scale when the map does not fit.
- A user drag through another title surface is saved in OpenMap's settings.
- In standard UI on Forever, Offhand fits OpenMap's fullscreen map to Mainhand;
  under the Gamepad UI OpenMap's fallback leaves Blizzard's map to Offhand.
- A breaking OpenMap update is one chat notice (`openmap-contract:<reason>`), and
  with a supported contract a window mover's writes are no conflict.
- The Forever compatibility line adds `OpenMap=<version> | MapFPSCap= | maxFPS= |
  OpenMapWindow= | OpenMapContract=`.

## How core reaches it

- `mapProvider` through `Bridges:CallMap("OpenMap", method, ...)` while OpenMap is
  the World Map owner: `UpdateFollow`, `GetScaleRange`, `ReadScaleOption`,
  `HandlesExpandedMap`, `CanRecover`, `Recover`, `ReportRecoveryFailure`,
  `ObserveUserDrag`, `HandlesFullscreen`, `GetContractConflict`,
  `FormatConflict`, `SyncsWorldMapMover`, `GetOwnerDiagnostics`.
- `data`: the `map.fade` entry (order 10) with its reader; `Data.lua` holds the
  `map.owner` facts, the `map.cameraOwner` role, the map integration entry, the
  compact diagnostics segment and the catalog.
- `slashCommands.recovermap` and `GetSettingsContributions` for the slots
  `mapScaleTitle`, `mapDescription` and `map`.

It registers on every client (id `OpenMap`) and reads OpenMap when asked, so an
OpenMap that loads after Offhand is still handled.

## Evidence

Automated tests pass (tests/openmap-recovery.lua, tests/forever-openmap-follow.lua,
tests/map-scale-settings.lua, tests/expanded-map.lua, tests/mainhand-placement.lua,
tests/canvas-compatibility.lua, tests/bridges-contract.lua). The move itself has
not been run in a live client.
