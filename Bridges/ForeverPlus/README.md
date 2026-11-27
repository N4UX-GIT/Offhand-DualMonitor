# Built-in ForeverPlus Bridge

Built-in Offhand bridge (`Bridges/ForeverPlus/Bridge.lua`) that keeps
**ForeverPlus**'s default warning bars on the game monitor. It is the former
`Core/ForeverPlusWarnings.lua` moved behind the bridge contract, with unchanged
behaviour. The bridge is inert unless the client is Forever.

## What it does

- After ForeverPlus places a warning bar at its own default, the bar follows the
  game rectangle: it keeps its proportional height, and the consumables row
  keeps its fixed clearance above the general row.
- It never touches explicit vendor positions, mover previews, user-placed
  frames, anything in combat, or the vendor's saved profile.
- When popup redirection is off, Offhand is disabled or the game is not
  spanned, bars it still holds go back to the vendor's own anchor.

## How core reaches it

- `IsExternallyOwnedFrame`: generic popup rescue and panel movement leave the
  bars it tracks alone.
- `RefreshTransientFrames("hook" | "position")`: hooks the vendor, and on
  `"position"` re-applies the layout.
- `Refresh` and the geometry callback: hook and re-apply the layout.

It registers on Forever before ForeverPlus exists, so a vendor that loads
after Offhand is still hooked on the next refresh.

## Evidence

Automated tests pass (tests/forever-plus-warnings.lua). The move itself has not been run in a live client.
