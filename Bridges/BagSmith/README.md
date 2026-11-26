# Built-in BagSmith Bridge

Built-in Offhand bridge for **BagSmith**. `Bridge.lua` supplies the bag
ownership roles and the catalog entry, with the finder for the hidden,
anonymous `UIParent` child BagSmith parks the native bags under (moved from
`Core/HUDCompatibility.lua`); it shares the finder through the BagSmith bridge
namespace. `Bags.lua` is the former BagSmith bag Escape adapter of
`Core/BagPersistence.lua`, moved behind the bridge contract as a bag provider
with unchanged behaviour.

## What Bags.lua does

- On Forever, out of combat, it replaces the `Hide` method of BagSmith's main
  view once per view. A close that comes from BagSmith's own native bag
  post-hook on the Escape path is skipped while the backpack is open on the
  workspace; every other close runs.
- `BagSmithFrame` leaves `UISpecialFrames` while it is open on the workspace
  and the native bags BagSmith parks are closed; on Mainhand it regains Escape
  handling.
- The generic inventory toggles are kept open while `BagSmithFrame` is on the
  workspace.

## How core reaches it

- `bagProvider.RefreshEscape(services)` at provider order 40 in the Forever
  bag Escape pass, where core called the adapter, so the method replacement is
  installed at the same moment as before.
- `GetToggleFrame()` from the workspace toggle keys.

## Evidence

Automated tests pass (tests/baganator-persistence.lua,
tests/hud-compatibility.lua, tests/bridges-contract.lua). The move itself has
not been run in a live client.
