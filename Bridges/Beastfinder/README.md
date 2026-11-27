# Built-in Beastfinder Bridge

Built-in Offhand bridge (`Bridges/Beastfinder/Bridge.lua`) that keeps
Beastfinder's "new beast found" card on Offhand's game monitor. With Offhand,
UIParent spans every monitor, so Beastfinder's default spot for the card (the
top of UIParent) is the top of the seam between monitors. The bridge is inert
(no frame, hook, timer or global) unless Beastfinder is loaded on the Forever
client.

## What it does

- **New beast card:** `BeastfinderNewBeastCard`, default
  `TOP -> UIParent TOP 0,-170`, placed there by Beastfinder every time it
  paints the card. While the card sits at that default (or where the bridge
  last put it), the bridge moves it to the top of the game rectangle, when it
  shows and on every refresh. When Offhand is not spanned, the card goes back
  to Beastfinder's own default.

## What it leaves alone

- A card the player dragged: Beastfinder saves it as a TOPLEFT/BOTTOMLEFT
  anchor, which the bridge never touches.
- Windows the player drags onto another monitor, and every other Beastfinder
  window (Beastfinder remembers where the player put them).

## Diagnostics

`/offhand diag` shows `BeastfinderAnchors=<moved>/<total>`: how many of the
bridged frames are currently moved, out of how many the bridge knows.

## Origin and evidence

- Contributed by Kintrok (@DCtheGeek).
- Read against Beastfinder 2.3.0 (`UI/NewBeastAlert.lua`, `UI/Look.lua`).
- Automated tests pass (tests/bridge-beastfinder.lua). Live Forever QA is pending.
