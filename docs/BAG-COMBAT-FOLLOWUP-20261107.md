# Native bag combat follow-up, 7 November 2026

Later native evidence is recorded in
[test15 live QA](BAG-TEST15-LIVE-QA-20261107.md). Tested backpack/keyring chrome,
reload and post-combat recovery pass. Combat reopening still reproduces a snap;
the new Lua error is not reproduced. Original source-investigation record follows.

## Report and scope

Mort reports that opening separate default bags during combat puts them at the
far right of Offhand regardless of their previous Mainhand/workspace position.
Additional bag X buttons remain visible with Hide close buttons enabled; the
backpack X sometimes returns after combat reopening. Repeatedly pressing Open
all bags near combat end can trigger a Lua error, often once per reload.

The supplied screenshots contain no error stack. The reporter's exact private
version is requested. The earlier quest-pin SetPassThroughButtons block remains
a separate unresolved attribution until the new error can be compared.
Target source investigation: Forever 1.60.1.70862; no new live run this pass.

## Confirmed source gaps and candidate corrections

- WorkspaceChrome enumerated ContainerFrame1 and the combined root, plus saved
  or externally registered names. Separate native bags without saved positions
  were omitted. It now enumerates ContainerFrame2 through the native frame
  count, bounded at 40 (legacy fallback 13), and applies workspace-only hiding
  independently to each root. Mainhand buttons retain their native state and
  opting out restores each remembered alpha/mouse state. No global scan or
  native button handler is added.
- Chrome and Forever's native bag controller used lockdown alone. They now use
  MainhandGeometry.IsPlayerCombatRestricted, which also checks player combat.
  Placement, position capture, drag entry, chrome writes and addon-driven native
  opening defer while either signal is active. The normal production load order
  supplies that shared policy; isolated legacy fixtures retain a lockdown fallback.
- The public tracked-bag restore preserves its saved intent during this interval.
  Native opener fallbacks recheck combat between calls. If a callback enters
  combat, recovery stops before placement or clearing the saved open intent and
  releases its transient restoring flag. Native opening still uses Blizzard's
  APIs; no raw ContainerFrame Show, replacement anchor manager or secure bypass
  was introduced.

## Native behavior and remaining limits

The exact-build native UpdateContainerFrameAnchors anchors the first shown bag
to its parent's bottom right and stacks subsequent bags relative to that root.
A spanned parent therefore puts newly opened bags at the far edge. Offhand's
isolated bag controller intentionally yields in combat and restores saved
placement afterward. This candidate closes combat-check gaps; it does not
promise saved placement while combat is active.

Likewise Blizzard can redraw/reopen an X button during combat. Chrome must defer
its alpha/mouse writes until combat settles. Additional separate bag X buttons
now participate in normal out-of-combat reconciliation; uninterrupted hidden-X
behavior during combat remains unverified and is not promised.

Primary native source:
[Forever 70862 ContainerFrame.lua](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua).
Source observation establishes the anchor path, not the initial taint source or
the safety of any addon mutation in combat.

## Verification and retest

The new regressions fail against frozen test14 for both the omitted separate
bag X and player-combat-only placement. They pass with the candidate, covering
workspace/Mainhand distinction, reversible X state, zero global discovery scans,
deferred opening, preserved intent, post-combat saved placement, and a native
callback entering combat before a fallback toggle. All 99 Lua suites and six
manifests pass in source. These are simulations and static checks.

Private test15 retains prior candidates. Native acceptance is pending: test
separate and combined modes, Mainhand and workspace saved positions, reopen,
Hide close buttons off/on, reload, and real combat entry/exit. Manually reproduce
the Open all bags timing and collect the complete fresh BugGrabber stack and
taint evidence with the exact candidate version. Exercise actual item use as
well as layout. Do not close the old bag-taint or map-pin report based on mocks.
