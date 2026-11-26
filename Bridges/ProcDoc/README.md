# Built-in ProcDoc Bridge

Built-in Offhand bridge for **ProcDoc**. `Bridge.lua` is the former
`Core/ProcDocCompatibility.lua` moved behind the bridge contract, with unchanged
behaviour; `Data.lua` beside it supplies the `preservePopup` frame rule for
`ProcDocAlertFrame`.

## What it does

- With **Center ProcDoc alerts on Mainhand** on and the game spanned, ProcDoc's
  one-unit `ProcDocAlertFrame` is re-centred on the game rectangle. ProcDoc's own
  X/Y offsets are kept, converted to the frame's scale, and a later
  `ApplyCenter` from ProcDoc is followed.
- It never moves the frame in combat (the change waits for the end of combat),
  never touches a forbidden or protected frame, and yields to any other anchor
  that replaces its own.
- When the option is off, Offhand is disabled or the game is not spanned, the
  frame goes back to ProcDoc's own anchor if the bridge still holds it.

## How core reaches it

- `Refresh("layout")`: runs the adapter on the layout pass, where core called the
  module. Other reasons are ignored.
- `data.settings`: the opt-in keeps its stored key `centerProcDocOnMainhand`
  (default `false`), so no saved value moves.
- `GetSettingsContributions("alerts")`: the checkbox on the Pop-ups & alerts
  card, shown while ProcDoc is loaded and enabled for the character.
- `data.diagnostics`: `ProcDocCenter=<status>` as the `compat.tail` segment, at
  the end of the compatibility diagnostics as before.

It registers on every client before ProcDoc exists and keeps its own
`ADDON_LOADED` and `PLAYER_REGEN_ENABLED` event frame, so a ProcDoc that loads
after Offhand is still centred.

## Evidence

Automated tests pass (tests/procdoc-compatibility.lua). The move itself has not
been run in a live client.
