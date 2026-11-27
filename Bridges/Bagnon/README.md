# Built-in Bagnon Bridge

Built-in Offhand bridge for **Bagnon**. `Bridge.lua` supplies facts only (bag
ownership roles, bag name rules and the catalog entry). `Bags.lua` is the bag
provider for the workspace toggle keys and the bag persistence engine: the
former Bagnon branches of `Core/BagPersistence.lua`, moved behind the bridge
contract with unchanged behaviour.

## What Bags.lua does

- The `BAGNON_TOGGLE` binding is kept open while the inventory window of
  Bagnon's frame manager (`Bagnon.Frames:Get("inventory")`) is on the
  workspace, as core did before.
- Its persistent root is that inventory window (a direct `UIParent` child
  with `id == "inventory"`). The root is lazy, but the manager provides a
  constant-time identity lookup after construction, so discovery never scans
  its child regions or depends on skin-generated global names.
- Taint boundary: the root participates in Forever's `UISpecialFrames` and
  Gamepad focus lifecycle, so Offhand installs no scripts on it
  (`hookScripts = false`) and no Bagnon callback (its manager can be in the
  Gamepad focus path). It is observed only from Offhand's own ticker and the
  secure global Escape hooks.
- It keeps its own native Escape registration (second in the escape order,
  Escape observer label `bagnon_toggle_observer`), is preserved through every
  bag-preserving panel, reopens through the manager's `Show("inventory")`, and
  while Offhand protects it the player bags Bagnon parks
  (`Bagnon.Overrides.Disabled`, up to `Bagnon.NumBags`) are closed.

## How core reaches it

- `bagProvider.toggleActions` and `GetToggleFrame(action)` from the workspace
  toggle keys, inside their existing pcall.
- From the bag persistence engine, each in `pcall`: `IsRoot`, `Discover`,
  `InstallCallbacks` (`loadAddon = "Bagnon"`), `IsDirectEscapeRoot`
  (`escapeOrder = 20`, `escapeSource`), `CloseParkedBags`, `Show`,
  `hookScripts` and `panelTransitions = "all"` (docs/BRIDGES.md, section 4).

## Evidence

Automated tests pass (tests/workspace-toggle-keys.lua,
tests/baganator-persistence.lua, tests/bridges-contract.lua). Not run in a
live client.
