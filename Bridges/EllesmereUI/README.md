# Built-in EllesmereUI Bridge

Built-in Offhand bridge for the **EllesmereUI** suite. `Bridge.lua` supplies
facts only (ownership roles, guidance, diagnostics segments and the aura-bar
frame rule, and the EllesmereUIBags bag facts; its header lists them).
`Scale.lua` is the former `Core/EllesmereScaleCompatibility.lua` moved behind
the bridge contract, with unchanged behaviour. `Bags.lua` is the former
EllesmereUI bag Escape adapter of `Core/BagPersistence.lua` and its close
button finder of `Core/WorkspaceChrome.lua`, moved the same way as the
EllesmereUIBags bag provider. The rest of the EllesmereUI bag persistence
(root discovery, restore after Escape and reload) is still in
`Core/BagPersistence.lua`.

## What Scale.lua does

- While Offhand is enabled and the game is spanned (and not in combat),
  EllesmereUI's pixel grid (`EllesmereUI.PP.mult`) follows the live UI root
  Offhand sets, not the scale saved in EllesmereUI's profile. The saved scale
  is never rewritten.
- It hooks `PP.UpdateMult` so every vendor refresh keeps that grid, and
  `PP.SetUIScale` so a scale the player picks in EllesmereUI is followed by one
  full Offhand layout on the next frame that keeps the chosen scale. Several
  slider changes in one frame give one layout; nothing runs in combat, while
  Offhand is disabled or while the game is not spanned.

## How core reaches it

- `RefreshScale()`: called on every full layout pass, right after Offhand
  applies its global UI scale and before the viewport updates, where core
  called the module.
- `Offhand.API.RequestFullLayout(true)`: the layout after the vendor's setter.

It registers on every client before EllesmereUI exists and looks
`EllesmereUI.PP` up on each call, so an EllesmereUI that loads after Offhand is
still hooked.

## What Bags.lua does

- On Forever, while `EUI_MainBagFrame` or `EUI_ReagentBagFrame` is open on the
  workspace, Offhand removes only that root's default registration from
  EllesmereUI's shared Escape proxy and closes the native bags it parks; on
  Mainhand the registration comes back once, and the proxy is shown again if
  the root is open.
- The workspace close button handling finds the backpack's header close
  button (the header child anchored `RIGHT` to `RIGHT`).
- The generic inventory toggles are kept open while `EUI_MainBagFrame` is on
  the workspace.

Core reaches it through `bagProvider.RefreshEscape(services)` at provider
order 70, after the bridges' own `RefreshBags` (where core called the adapter),
`GetCloseButtons(frame)` for the root it lists in `closeButtonRoots`, and
`GetToggleFrame()`. It registers on every client before EllesmereUI exists.

## Evidence

Automated tests pass (tests/ellesmere-scale-compatibility.lua,
tests/baganator-persistence.lua, tests/workspace-close-buttons.lua,
tests/bridges-contract.lua). The moves themselves have not been run in a live
client.
