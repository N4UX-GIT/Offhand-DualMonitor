# Built-in Bagnon Bridge

Built-in Offhand bridge for **Bagnon**. `Bridge.lua` supplies facts only (bag
ownership roles, bag name rules and the catalog entry). `Bags.lua` is a bag
provider for the workspace toggle keys. The rest of Bagnon's bag persistence
(its inventory root, Escape restore and parked native bags) is still in
`Core/BagPersistence.lua`.

## What Bags.lua does

- The `BAGNON_TOGGLE` binding is kept open while the inventory window of
  Bagnon's frame manager (`Bagnon.Frames:Get("inventory")`) is on the
  workspace, as core did before.

## How core reaches it

- `bagProvider.toggleActions` and `GetToggleFrame(action)` from the workspace
  toggle keys, inside their existing pcall.

## Evidence

Automated tests pass (tests/workspace-toggle-keys.lua,
tests/bridges-contract.lua). Not run in a live client.
