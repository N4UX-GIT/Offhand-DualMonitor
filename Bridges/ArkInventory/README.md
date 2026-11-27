# Built-in ArkInventory Bridge

Built-in Offhand bridge for **ArkInventory**. `Bridge.lua` supplies facts only
(bag ownership roles, bag name rules and the catalog entry; its header lists
them). `Bags.lua` is the former ArkInventory bag Escape adapter of
`Core/BagPersistence.lua`, moved behind the bridge contract as a bag provider
with unchanged behaviour.

## What Bags.lua does

- On Forever, while its bag inventory `ARKINV_Frame1` is open on the
  workspace, the frame leaves `UISpecialFrames`, so Escape reaches its target
  and the inventory stays open; on Mainhand it regains Escape handling.
- The `ARKINV_TOGGLE_BAG` binding, and the generic inventory toggles, are kept
  open while `ARKINV_Frame1` is on the workspace.

## How core reaches it

- `bagProvider.RefreshEscape(services)` at provider order 10, first in the
  Forever bag Escape pass, where core called the adapter.
- `bagProvider.toggleActions` and `GetToggleFrame(action)` from the workspace
  toggle keys.

It registers on every client before ArkInventory exists and reads the
addon's globals on each pass.

## Evidence

Automated tests pass (tests/baganator-persistence.lua,
tests/workspace-toggle-keys.lua, tests/bridges-contract.lua). The move itself
has not been run in a live client.
