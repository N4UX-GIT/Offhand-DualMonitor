# Built-in ForeverLedger Bridge

Built-in Offhand bridge (`Bridges/ForeverLedger/Bridge.lua`) that keeps
**ForeverLedger**'s windows on the game monitor. ForeverLedger opens them at
UIParent's centre, top or top-right corner, which with Offhand is the seam
between monitors or the far monitor. The bridge is inert (no frame, hook or
timer) unless ForeverLedger is loaded on the Forever client.

## What it does

- **Customers window:** `ForeverLedgerCustomers` (default `TOPRIGHT` on
  UIParent `TOPRIGHT -260,-160`, opens by itself on a trade-chat request) moves
  to the same spot of the game rectangle.
- **Disenchant window:** `ForeverLedgerDisenchant` (default `CENTER 220,0`)
  moves to the game rectangle's centre; its secure child button moves with it,
  never in combat.
- **Session tracker:** `ForeverLedgerSessionTracker` (default `TOP 0,-140`
  when no spot is saved) moves to the game rectangle's top. The session window
  hangs under it until dragged, so it follows.
- **Side panel:** `ForeverLedgerSidePanel` (re-centred with `CENTER 0,0` every
  time it opens away from the auction house) moves to the game rectangle's
  centre, at once when it is shown.

## What it leaves alone

- Any window the player dragged somewhere else, and the side panel while it is
  docked beside the auction house.
- The Ledger tab's row tooltip, whose side is chosen from the whole screen width.
- The opt-in "Scroll anywhere" wheel catcher, which covers all of UIParent.
- Spots ForeverLedger saved before spanning.

## Diagnostics

`/offhand diag` shows `ForeverLedgerAnchors=<moved>/<total>`.

## Origin and evidence

- Contributed by Kintrok (@DCtheGeek).
- Read against ForeverLedger 0.30.0.
- Automated tests pass (tests/bridge-foreverledger.lua). Live Forever QA is pending.
