# Built-in ItemRack Bridge

Built-in Offhand bridge (`Bridges/ItemRack/Bridge.lua`) that keeps **ItemRack**'s
Options window and its slot flyout on the game monitor. It is the former ItemRack
part of the addon options window fitting in `Core/PopupBounds.lua`, moved behind
the bridge contract with unchanged behaviour. The bridge is inert unless the
client is Forever.

## What it does

- `ItemRackOptFrame` has no parent and renders relative to the whole canvas
  height. While Offhand is enabled and spanned it is scaled from ItemRack's own
  preset to the game display (and down further if it would not fit), and moved
  onto Mainhand when it overlaps the seam. The preset in `ItemRackUser.OptScale`
  is never written.
- The slot flyout (`ItemRackMenuFrame` on an `ItemRackOptInv<n>` slot) is
  mirrored around the slot, with its item buttons, when it faces the seam, and
  scaled down as a unit when ItemRack's wrapped menu is still larger than the
  display. Closing the flyout gives its scale back.
- When the span ends or Offhand is disabled, the owned scale and anchor go back
  to ItemRack's own; a window the player dragged keeps its place. Nothing is
  changed in combat.

## How core reaches it

- `InitializePopupWindows()`: once when the popup bounds handling initializes,
  it hooks `ItemRackOpt.ReflectOptScale` and `ItemRack.BuildMenu`,
  `ReflectMenuScale` and `MenuOnHide`, and again on `ItemRackOptions`'
  `ADDON_LOADED` (ItemRackOptions loads on demand).
- `RefreshAddonOptions(getMetrics)`: every popup layout pass and after combat.
- The fitting helpers (`FitAddonOptions` and friends) stay in core and are read
  through `Offhand.API.GetOptionsWindowHelpers()`.

It registers on Forever before ItemRack exists.

## Evidence

Automated tests pass (tests/addon-options-bounds.lua). The move itself has not been run in a live client;
flyout scaling is only verifiable live.
