# Built-in RareScanner Bridge

Built-in Offhand bridge (`Bridges/RareScanner/Bridge.lua`) that keeps
RareScanner's rare-found button, explorer window and dialogs on Offhand's game
monitor, and keeps the button's saved spot there too. With Offhand, UIParent
spans every monitor, so RareScanner's default spots (UIParent's bottom, centre
and top) are on the seam between monitors. The bridge is inert (no frame, hook,
timer or global) unless RareScanner is loaded on the Forever client.

## What it does

- **Rare-found button:** `RARESCANNER_BUTTON`, default
  `BOTTOM -> UIParent BOTTOM 0,128` (a secure button that ignores its parent's
  scale). Moved to the bottom of the game rectangle; never in combat, the next
  refresh after combat does it.
- **Explorer:** `RSExplorerFrame`, default `CENTER`. Moved to the centre of the
  game rectangle, also as it shows.
- **Dialogs:** `LibDialog-1.0RS_Dialog1` to `LibDialog-1.0RS_Dialog4`, the first
  at `TOP -> UIParent TOP 0,-135`; the others hang under it and follow it.
- **Saved button spot:** RareScanner's "Reset position" saves the button's
  spot right after placing it at the default, which would be the seam spot.
  The bridge moves the button and saves the moved spot instead (after combat
  when the reset happened in combat). Once per session it also repairs a spot
  saved earlier that is exactly the old seam default.
- When Offhand is not spanned, moved frames go back to RareScanner's defaults.
- **Seam scan:** declares `RARESCANNER_BUTTON`, `RSExplorerFrame` and the four
  dialogs above in `placedFrames`, so `/offhand scan` reports them as handled.

## What it leaves alone

- Frames the player dragged, including a button dragged to its own spot.
- Map pin tooltips, whose side RareScanner's bundled LibQTip picks from thirds
  of the whole UIParent.
- The chat-link tooltip (centre 0,0), which Offhand's own popup recovery moves.

## Diagnostics

`/offhand diag` shows `RareScannerAnchors=<moved>/<total> RareScannerSaves=<n>`:
the bridged frames currently moved out of how many the bridge knows, and how
many times the bridge saved the button's spot.

## Origin and evidence

- Contributed by Kintrok (@DCtheGeek).
- Read against RareScanner 1.60.1.13 (`RareScanner.lua`,
  `Core/Data/RSGeneralDB.lua`, `Core/Service/RSEventHandler.lua`,
  `RSExplorerTemplate.xml`, `LibDialog-1.0.lua`).
- Automated tests pass (tests/bridge-rarescanner.lua). Live Forever QA is pending.
