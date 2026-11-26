# Built-in DialogueUI Bridge

Built-in Offhand bridge (`Bridges/DialogueUI/Bridge.lua`) that keeps
**Dialogue UI**'s quest, book and settings frames on the game monitor. It is the
former `Core/DialogueUICompat.lua` moved behind the bridge contract, with
unchanged behaviour. It is not limited to the Forever client, and it registers
before Dialogue UI exists: the core module always kept a loader waiting for the
vendor's `ADDON_LOADED`, so a Dialogue UI that loads after Offhand is still
attached. Until then it hooks nothing.

## What it does

- While Offhand is enabled and spanned, Dialogue UI's own anchors on `UIParent`
  are moved to the Mainhand frame with their offsets unchanged. Child-to-owner
  anchors, protected and forbidden frames are left alone.
- The quest, book and settings roots are scaled by Mainhand's pixel-height
  ratio from their first native scale, and a live Frame Size change is
  finished at Dialogue UI's own target size.
- Dialogue UI's anonymous reward tooltip is queued for Offhand's popup bounds
  pass whenever it is shown, anchored or laid out.
- When Offhand is disabled or not spanned, the anchors and scales it changed go
  back to Dialogue UI's own.

## How core reaches it

- It registers as `DialogueUI` with one callback, `GetDebugDiagnostics`. Its refreshes stay its own
  `ADDON_LOADED`, `PLAYER_ENTERING_WORLD`, `DISPLAY_SIZE_CHANGED` and
  `UI_SCALE_CHANGED` events and its hooks on Dialogue UI's frames.
- Services: `GetGameRect` (enabled and spanned), `GetMainhandFrame`,
  `GetMainhandPixelHeightRatio` and `QueuePopupBounds`.
- Its detailed report is not part of the compact `/offhand diag` line. The
  `Dialogue UI diagnostics` line of `/offhand diag debug` now comes from the
  bridge through `Bridges:GetDebugDiagnostics()`, with the same text.

## Evidence

Automated tests pass (tests/dialogue-ui-compat.lua). The move itself has not been run in a live client.
