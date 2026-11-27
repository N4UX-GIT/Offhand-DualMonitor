# Built-in ElvUI Bridge

Built-in Offhand bridge for **ElvUI**. `Bridge.lua` supplies facts only
(HUD, report and bag ownership roles, guidance, bag name rules and the
catalog entry; its header lists them). `Bags.lua` is the former ElvUI bag
Escape adapter of `Core/BagPersistence.lua`, moved behind the bridge contract
as a bag provider with unchanged behaviour.

## What Bags.lua does

- On Forever, out of combat, it finds ElvUI's Bags module once and replaces
  its `CloseAllBags`: a Game Menu or Settings close on the Escape path is
  skipped while the backpack `ElvUI_ContainerFrame` is open on the workspace.
  It post-hooks `ToggleAllBags`, so a press that only looked like an open
  because Offhand cleared the native backpack bit still closes.
- The backpack leaves `UISpecialFrames` while it is open on the workspace and
  the native containers ElvUI disabled but left open are closed; on Mainhand
  it regains Escape handling.
- The generic inventory toggles are kept open while `ElvUI_ContainerFrame` is
  on the workspace.

## How core reaches it

- `bagProvider.RefreshEscape(services)` at provider order 50 in the Forever
  bag Escape pass, where core called the adapter, so the method replacement and
  hook are installed at the same moment as before.
- `GetToggleFrame()` from the workspace toggle keys.

## Evidence

Automated tests pass (tests/baganator-persistence.lua,
tests/bridges-contract.lua). The move itself has not been run in a live
client.
