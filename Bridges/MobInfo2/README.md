# Built-in MobInfo2 Bridge

Built-in Offhand bridge (`Bridges/MobInfo2/Bridge.lua`) that keeps MobInfo2's
movable tooltip anchor, and so the mob tooltip that hangs off it, on Offhand's
game monitor. With Offhand, UIParent spans every monitor, so MobInfo2's default
spot (UIParent's top right corner) is on the far monitor. The bridge is inert
(no frame, hook, timer or global) unless MobInfo2 is loaded on the Forever
client.

## What it does

- **Tooltip anchor:** `MI2_TooltipAnchor` (the small "MI" box), default
  `TOPRIGHT -> UIParent TOPRIGHT -4,-200`, also restored by `/mi2 resetpos`.
  While it sits at that default (or where the bridge last put it), the bridge
  moves it to the top right corner of the game rectangle. When Offhand is not
  spanned, it goes back to MobInfo2's own default.
- MobInfo2 stores whatever spot the anchor has when the mouse leaves it, so
  once the player has hovered the anchor, the bridged spot becomes MobInfo2's
  saved spot and comes back that way at the next login.

## What it leaves alone

- An anchor the player dragged somewhere else.
- The options help tooltip, which MobInfo2 gives Blizzard's default
  GameTooltip anchor.
- Dropdown lists near the seam.

## Diagnostics

`/offhand diag` shows `MobInfo2Anchors=<moved>/<total>`: how many of the
bridged frames are currently moved, out of how many the bridge knows.

## Origin and evidence

- Contributed by Kintrok (@DCtheGeek).
- Read against MobInfo2 12.1.8 (`Frames/MI2_Tooltip.xml`, `MI2_Slash.lua`,
  `MI2_Tooltip.lua`).
- Automated tests pass (tests/bridge-mobinfo2.lua). Live Forever QA is pending.
