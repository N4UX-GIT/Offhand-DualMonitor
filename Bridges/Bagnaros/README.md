# Built-in Bagnaros Bridge

Built-in Offhand bridge for **Bagnaros**. `Bridge.lua` supplies facts only
(bag ownership roles and the catalog entry). `Bags.lua` is the former Bagnaros
bag Escape adapter of `Core/BagPersistence.lua`, moved behind the bridge
contract as a bag provider with unchanged behaviour.

## What Bags.lua does

- On Forever, while its verified main inventory `BagnarosInventoryFrame` is
  open on the workspace, the frame leaves `UISpecialFrames`; on Mainhand it
  regains its native close. A name match alone never claims the frame.

## How core reaches it

- `bagProvider.RefreshEscape(services)` at provider order 20 in the Forever
  bag Escape pass, where core called the adapter.

It registers on every client before Bagnaros exists and reads the addon's
globals on each pass.

## Evidence

Automated tests pass (tests/baganator-persistence.lua,
tests/bridges-contract.lua). The move itself has not been run in a live
client.
