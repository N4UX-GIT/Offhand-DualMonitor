# Built-in BetterBags Bridge

Built-in Offhand bridge for **BetterBags**. `Data.lua` supplies facts only
(bag ownership roles, bag name rules, popup roots and the catalog entries).
`Bags.lua` is the former BetterBags bag Escape adapter of
`Core/BagPersistence.lua`, moved behind the bridge contract as a bag provider
with unchanged behaviour.

## What Bags.lua does

- On Forever, out of combat, it finds the BetterBags addon object once and
  post-hooks its `CloseSpecialWindows`. When Escape queues BetterBags' own
  close for the backpack on the workspace, the request is kept for one frame.
- If the Game Menu toggle, or a PlayerSpells center panel shown inside that
  close, follows, the backpack stays open; an Options transition or leaving the
  world drops the request.
- The backpack (`BetterBagsNextBackpack` or `BetterBagsBagBackpack`) leaves
  `UISpecialFrames` while it is open on the workspace and the native bags
  BetterBags parks are closed; on Mainhand it regains Escape handling.
- The `BETTERBAGS_TOGGLEBAGS` binding, and the generic inventory toggles, are
  kept open while the backpack is on the workspace.

The vendor object and the pending request live in the BetterBags bridge
namespace.

## How core reaches it

- `bagProvider.RefreshEscape(services)` at provider order 30 in the Forever
  bag Escape pass, where core called the adapter, so the vendor hook is
  installed at the same moment as before.
- `PreserveThroughEscape(services)` from Offhand's `ToggleGameMenu` post-hook,
  `PreserveThroughPanelShow(panel, services)` from its `ShowUIPanel`
  post-hook (ahead of the panel transition, as before) and `CancelEscape()`,
  all through `Bridges:NotifyBagProviders`.
- `bagProvider.toggleActions` and `GetToggleFrame(action)` from the workspace
  toggle keys.

## Evidence

Automated tests pass (tests/baganator-persistence.lua,
tests/workspace-toggle-keys.lua, tests/bridges-contract.lua). The move itself
has not been run in a live client.
