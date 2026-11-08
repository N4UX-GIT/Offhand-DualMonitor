# Mainhand selection and add-on refresh report, 2026-11-07

## Supplied evidence

A Discord user reports the game on their second monitor despite selecting the
primary monitor as Mainhand. A follow-up says disabling and re-enabling the
add-on appeared to resolve it. They do not specify whether this used WoW's
add-on manager with a reload or Offhand's in-game enable toggle.

The Companion screenshot identifies Beta 20 and installed addon Beta 26 in the
Forever client directory. Both 1920 x 1080 displays are checked, Display 1 is
primary and selected as Mainhand, and single-display split is off. The disabled
Game side selector reads Right; that setting only affects a single-display
split and is not an instruction to put a two-display game on the right.

The log shows successful topology writes and 3840 x 1081 spans followed by
Restore, unlike the prior report that refused a span after two selected
identities collapsed to one. The game screenshot shows a black area with UI
elements. It does not identify its desktop coordinates or show the other
monitor. Windows monitor positions, exact client build, loaded add-on geometry
source, generated bridge and saved preferences were not supplied.

## Source findings

- `CompanionTopologyBridge.TryWrite` writes the selected Mainhand rectangle to
  `Core/CompanionTopology.lua`. WoW loads that file through the TOC. The running
  Lua global is not updated merely because Companion replaces the disk file.
- `Viewport:GetMetrics` honors an accepted Companion game rectangle ahead of
  the profile's saved left/right position in AUTO/EXACT modes. Explicit MANUAL
  geometry intentionally follows the add-on's remembered/manual setup instead.
- An old bridge with the opposite game side can remain dimensionally valid
  after swapping roles on two identical-resolution monitors. Reapplying the
  same loaded table continues to use that old side. Loading the newly written
  bridge corrects the selected side.
- Offhand's in-game enable toggle does not load the bridge from disk. It calls
  layout application, which resets/reapplies WorldFrame anchors. It can repair
  stale anchors if the loaded geometry is already correct. A manager disable/
  enable sequence that reloads the UI can instead load the new disk bridge.

These are source-backed mechanisms, not a confirmed reconstruction of this
user's exact sequence. The distinction between the two toggle workflows matters.

## Executed checks

Evidence is in `dist/mainhand-selection-report-20261107/`.

- Reflection executed the actual frozen Beta 20 executable and the exact
  published Revision 4 executable, without running their entry points or
  touching user preferences. Each generated eight synthetic planner/bridge
  cases: primary display physically left/right, either Mainhand choice, and
  both values of the inactive single-display side setting. All wrote the
  selected game rectangle; all rejected the opposite-role bridge as current.
- The actual generated Lua bridges were consumed by the Beta 26 baseline
  `Viewport.lua` at `9c7e83c9757901f262d568941db56a7bf7272b6f` and the Revision 4
  source at `5a71a02c2da3e434195c4163a4edd982045302ad`. Each of the four writer/
  consumer combinations passed 48 checks, including stale single-monitor
  physical-size reports, opposite saved profile side, stale loaded bridge,
  in-game toggle, loading the new bridge and explicit manual-mode precedence.
- Existing `companion-topology.lua`, `geometry.lua` and `lifecycle.lua` pass.

The synthetic pair is 3840 x 1080. The screenshot's 1081 span height and exact
desktop arrangement are not reproduced or explained by these checks. This is
simulated native planning/file generation and Lua viewport execution, not live
WoW, affected-hardware, rendering or protected-action acceptance.

## Disposition and support guidance

Record the disable/re-enable workaround as reporter-observed, with its mechanism
unknown. No permanent incorrect Mainhand mapping was reproduced. The report
does not establish a second instance of the monitor-ID collision defect, and
Revision 4's ID lookup does not remove the reload requirement.

The first recovery step is to select the intended Mainhand, click Span WoW Now
and use `/reload` once after the span. Verify the add-on's Window Setup is set
to Use Companion if exact Companion geometry is intended. The disabled Game
side control should be left alone for a normal two-monitor span. Do not delete
settings or repeatedly reinstall the add-on for this symptom.

If it recurs after that sequence, capture `/offhand diag full` while wrong,
Companion Display Diagnostics, the generated `Core/CompanionTopology.lua`, the
Windows display arrangement and the exact meaning of disable/re-enable. Those
separate loaded geometry, manual override, stale anchors and native identity
mapping without guessing from equal resolutions.

There is a UX improvement to consider separately: put the `/reload` instruction
in the immediate successful-span notification. Revision 4 currently logs it,
but the ordinary tray balloon only reports that exact geometry was saved and
that the user may exit Companion. Avoid claiming that the add-on has consumed
a new layout, because there is no live acknowledgement of a UI reload.

No production source or published package was changed for the initial
investigation.

## Messaging follow-up

The owner then requested clearer instructions after spanning or changing
Mainhand. Pending Companion source now reuses two explicit instructions:

- System Status and the Mainhand tooltip: after changing Mainhand or layout,
  click Span WoW Now, then type `/reload` in WoW. The existing enabled-addon
  reminder is preserved.
- Successful-span notification: **Span applied: type /reload in WoW**, with
  body text explaining that it loads the selected Mainhand and workspace layout.
  Remote Desktop retains the instruction to keep Companion open for Restore.
- Ordinary/Remote Desktop span logs, custom-layout logs and profile-save logs
  name the same slash command. Custom layout no longer says reload only if
  needed. Experimental graphics-test notifications retain their separate
  stable-span instructions.

The existing dashboard space is used. There is no new modal, configuration
hint row, saved preference or pending-reload state. Companion cannot confirm
that the player has reloaded, so it does not present an acknowledgement or an
unclear attention warning. A notification may be suppressed by Windows; the
dashboard and log retain the instructions.

The preferences/dashboard suite passed, including working-area fit at
100/125/150/175/200 percent scaling. The rendered dashboard was inspected for
wrapping and spacing. Evidence: `dist/reload-messaging-20261107/`.
Published Revision 4 remains unchanged; this copy update is for a subsequent
Companion build.
