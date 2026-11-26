# Built-in EllesmereUI Bridge

Built-in Offhand bridge for the **EllesmereUI** suite. `Bridge.lua` supplies
facts only (ownership roles, guidance, diagnostics segments and the aura-bar
frame rule; its header lists them). `Scale.lua` is the former
`Core/EllesmereScaleCompatibility.lua` moved behind the bridge contract, with
unchanged behaviour.

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

## Evidence

Automated tests pass (tests/ellesmere-scale-compatibility.lua). The move itself
has not been run in a live client.
