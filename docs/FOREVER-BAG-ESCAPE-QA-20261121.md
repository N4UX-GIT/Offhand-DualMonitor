# Forever native backpack and Escape, November 21, 2026

Moonweaver used the Discord test ZIP from `5a521de` on Forever 1.60.1.71037
with Companion 2.1.9-beta.1, OneForAll 6.2.11, BugGrabber and BugSack. The
separate Blizzard backpack was on the portrait Offhand to the left of
Mainhand. The preflight compared all packaged runtime files with the clean
checkout, excluding the generated Companion topology and Forever state.
ZIP SHA-256 `6ac2cb52d2bc27b7eeb515c2071f09f3652e0888ea7aa8d099000eb06118f921`.

| Interaction | Observed result |
| --- | --- |
| B with the separate backpack | Closed the backpack and reopened it at the same Offhand coordinates. |
| Real NPC gossip | First Escape closed gossip and preserved the NPC target. Second Escape cleared the target. The recorder captured both gossip events. |
| First player-operated inspection | The server sent `INSPECT_READY` and Inspect was visible. The player confirmed pressing Escape cleared the target. At the target-change event Inspect was still visible. It was hidden in the next sample, 72 ms later. The following Escape opened the Game Menu. |
| Controlled inspection through the native Inspect action | First Escape closed Inspect with the player still targeted. Second Escape cleared the target. The recorder saw the Offhand window-close binding before input. |
| Target portrait menu with Character open on Offhand | The equipment panel loaded on Mainhand. First Escape closed Inspect and preserved the target. Second Escape cleared the target. |
| Target portrait menu immediately after the gossip sequence, with Character closed | The same two Escapes closed Inspect and then cleared the target. No chat commands were entered between opening Inspect and pressing Escape. |
| Second player-operated inspection | The player confirmed the first Escape left the player selected and the second deselected them. The independent recorder captured Inspect closing 6.85 seconds before the target cleared. |
| Final gossip and portrait-menu inspection with the corrected observer | Both cases passed. Inspect occupied Blizzard's left panel slot with Offhand's window-close binding active. After it closed, the target binding took over. BugSack recorded zero new errors. |

Across these interactions the backpack stayed visible at the same bounds.
The first inspection captured panel visibility and target changes. Its recorder
did not sample the active binding. The later runs captured the binding and
Blizzard's left panel slot. Seeing the native window-close path in a successful
run cannot establish which handler received the first player's Escape.

### BugGrabber and release status

The temporary diagnostic for the player retry called `MenuUtil.IsAnyMenuOpen`
without checking whether the method existed. BugGrabber grouped 1,629 calls
under one error in session 778. The stack starts in the local QA slash script
(`BD` and `BT`). The production add-on already checks for the method.
The independent visibility and target recorder continued working. A reload
removed the failing timer. The corrected observer checked the method, recorded
the unavailable capability, and captured the final clean run.

Five subsequent inspections passed on `5a521de`, including the player's
retry. The original failing run did not capture the active binding.

### Follow-up on the packaged fix

The QA observer opened Inspect after requesting real player equipment and
before the server's `INSPECT_READY` event. Blizzard's `ShowUIPanel` skips a
frame that is already shown. The equipment loaded, but Inspect did not occupy
a native panel slot. On Mainhand the special-window registration still let
Escape close it. Dragging the frame to Offhand removed that registration.
At that point the old build assigned Escape to its target button. The first
press cleared the player and Inspect hid 38 ms later. This establishes one
reproducible cause of the original symptom. The triggering conditions of
the first player-operated run remain unknown.

On `b46c4b1`, Offhand checks the visible Inspect frame before assigning
target clearing and uses Blizzard's `HideUIPanel` to close that unlisted
frame. On Forever 1.60.1.71037 with Companion 2.1.9-beta.1 the same
early-show case preserved the player target on first Escape and cleared it
on the second. Ordinary inspection via the target portrait menu and NPC
gossip gave the same order. The separate backpack stayed at identical
Offhand bounds; B closed it and reopened it there. BugSack and the
blocked/forbidden event recorder were clear throughout the follow-up.

The candidate ZIP differs from the previous ZIP only in
`Core/CanvasForeverBags.lua`. Its SHA-256 is
`db2a22de6c9d0d5b58ffb807d36ddc2679e563cf0e0b60a6c28078a67d699ee7`.
The scope of the refreshed receipt is the separate backpack and these
out-of-combat interactions. Combat, flight and equipped bags 1–4 remain
deferred.

### Player-driven combat on the short workspace

Moonweaver used the same packaged add-on and portable Companion on Forever
1.60.1.71037 with a 1440 × 600 workspace. The first fight lasted 42.425
seconds between regeneration events. Within 0.10 seconds of combat entry
the map, bag and Escape bindings yielded to Blizzard. M closed the map and
B closed the separate backpack. After combat both reopened at their
pre-fight bounds and the keep-open bindings returned before reload.

BugSack session 774 recorded one new entry for
`OhBagQA: Button:SetPassThroughButtons()` from Blizzard's quest-pin
acquisition during the native map toggle. The event observer saw 14 blocked
notifications at the same instant. The temporary QA add-on had opened the
map from Lua before the fight. This run does not establish whether the same
error occurs when the player opens the map with its ordinary binding.

Character was already open at combat entry. C closed it before O opened
Social. Social's top reached 687.0 UI units on a workspace ending at 457.1.
It stayed clipped for over 42 seconds after combat, then refitted to 445.1
when the map reopened. The follow-up candidate checks the native-size Social
rectangle during combat and restores a visible saved Social panel to its
workspace at combat exit. A regression exercises a 675-unit Social panel on
a 457-unit workspace.

The player-operated control on `1ea7c2b` failed on the same Forever build
and Companion. The installed files matched the candidate and the QA helper
contained no executable code. The map had reopened automatically after
reload. With M and B pressed once each in combat, BugSack session 776
recorded one `ADDON_ACTION_BLOCKED` attributed to **Offhand**. The stack
ends at Blizzard's `TOGGLEWORLDMAP` binding and reaches
`Button:SetPassThroughButtons()` while acquiring a quest pin. No separate
backpack error was recorded. The player opened Social then Character and
reported both titles and both close buttons unreachable through combat exit.
Both panels were inside the workspace in the screenshot following reload.
The candidate therefore remains held for the map error and panel placement.

A subsequent source change prepares loaded, hidden Character and Social
roots at their saved workspace size outside combat. It recognizes Social
returning to its native scale, preserves distinct external scale choices,
and checks both visible panels on the next frame after combat. This passed
the candidate's 140 Lua suites and ten checker tests. It was not installed
for the native-M comparison, which must keep the same runtime as session 776.

In session 778 on the same installed `1ea7c2b`, the map and backpack were
closed at login. The ordinary M binding opened the map before combat. The
player then pressed M once during combat, left B untouched and opened Social
and Character. The BugSack occurrence count did not increase from session 776
through session 778. In the player's combat screenshot (02:35:01), Character's
title and close button were above Offhand and Social had opened on Mainhand.
At 02:36:04, before any further UI input or reload, both panels were back on
Offhand with their titles and close buttons visible. Session 776 and 778 differed
in both map opening method and backpack state.

For the next comparison, the installed addon matched `30f92c7` in the
compatibility checker. On Moonweaver's 1440 × 600 Offhand workspace with
Companion 2.1.9-beta.1, the 02:39:52 screenshot confirmed that the compact
map reopened after reload with the backpack, Social and Character closed.
The combat check uses the same M, O and C sequence as session 778.

On `30f92c7`, session 780 reproduced the blocked map close with the backpack
closed. BugSack's occurrence count increased by one (the grouped entry now
has two). At 02:41:40 the native taint log attributes blocked quest pin
passthrough writes to Offhand during the M binding's HideUIPanel call. At
02:41:52 Character's title and close button were above the physical Offhand
display and Character obscured Social. At 02:42:45, before further panel
input, the two panels were back side by side with both close buttons visible.
The post-combat recovery passed this run. In-combat access remains open.

The agreed Forever behavior is to leave the native map closed after login
and reload, including when its old open marker is present. M opens it at
the saved geometry. Addon-owned restore and late panel registration should
both respect that rule. Other clients retain their existing reopen behavior.

Packaged `d5bf3e3` passed 140 Lua suites and ten compatibility checker tests.
The installed runtime matched the clean candidate. With Companion
2.1.9-beta.1 applying the 1440 × 600 workspace, Moonweaver left the compact
map open during reload. The read-only QA recorder measured the map at left
12.0, top 445.1, width 839.5 and height 433.1 in UIParent units just before
reload. The map stayed closed after reload and the first native M opened it
in the same visible rectangle. BugSack's counter did not increase in session
781. This verifies reload and first open. The combat close requires its own
BugSack check.

The native M combat close passed in session 782. The map closed 4.295
seconds after combat entry at its saved scale of 0.811. BugSack recorded
zero new occurrences. The native taint file still ended at the prior failed
fight and supplied no independent trace for this run.

Social opened at its fitted height of 433.1 UI units. Character measured
338 × 424 before C and opened at 631 × 484 at scale 1, placing its top at
496.0 on a workspace ending at 457.1. The Character root and side tabs
covered Social. One second after combat exit both panels measured 433.1
units tall at top 445.1 and no longer overlapped. The pinned Forever source
shows that the first open refreshes Character to its native width and height.
The follow-up applies that size when fitting hidden Character and includes
Character's tabs when resolving a collision for Social during combat.
[Forever CharacterFrameMixin:UpdateSize](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/CharacterFrame.lua#L248-L251)

Session 784 on packaged `df813a6` passed the O-then-C combat placement
check. On Moonweaver's 1440 × 600 Offhand workspace both panels had top
445.1 and height 433.1. Character's side tabs ended at 713.4 and Social
began at 721.3. The recorder observed the same positions at combat exit and
logout. Both titles and close buttons were visible in the combat screenshot.

BugSack recorded one new occurrence at 03:03:10 during client exit.
Blizzard's TAXIMAP_CLOSED handler called HideUIPanel, and Offhand's synchronous
peer repair evicted and re-showed Character. Blizzard's paper doll then passed
a non-finite damage value to BreakUpLargeNumbers. The correction defers peer
repair for that native taxi close and skips it during a world transition.
The regression exercises both teardown and ordinary in-world panel settlement.
[Forever taxi close handler](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_UIPanels_Game/Shared/TaxiFrame.lua#L128-L132)

Packaged `43b419e` matched the installed runtime and passed 140 Lua suites
and ten compatibility checker tests. In session 785, Moonweaver exited with
both panels open on the same spanned workspace using Companion 2.1.9-beta.1.
The recorder observed TAXIMAP_CLOSED, PLAYER_LEAVING_WORLD and PLAYER_LOGOUT
in that order at the same timestamp, with both panel bounds unchanged.
BugSack recorded zero new occurrences. Forever was closed and the temporary
recorder was returned to its inert state. The combat placement result is from
session 784 and the corrected client-exit result is from session 785.

### Final interaction pass on 43b419e

The installed addon matched the packaged candidate and the running portable
Companion 2.1.9-beta.1 matched the test binary (SHA-256
`24547fb66b0b6c2e7aaf8457593f15fc901e286e7fdcfccf7cc78189e5bc62e2`).
On Moonweaver, B opened the separate native backpack on the 1440 × 600
Offhand workspace. With keep-open enabled, a second B left it visible.
Temporarily disabling keep-open let B close the backpack and reopen it at
the identical bounds (789.94, 140.14, 967.94, 445.14 UIParent units).
The current BugSack session had zero occurrences at each checkpoint. The
original keep-open setting was restored with the backpack open.

With the separate backpack open, Moonweaver interacted with a friendly NPC.
The first Escape closed gossip and kept the NPC selected. The second Escape
cleared the target. The game menu stayed closed and the backpack stayed at
the same bounds across both presses. BugSack showed zero occurrences before
the first Escape and after each press.

In the same run, native `/inspect` opened a selected player's equipment on
Mainhand. The server returned `INSPECT_READY`, and the recorder identified
`InspectFrame` in the native left panel slot. The first Escape closed Inspect
with the player still selected. The second cleared the target.

For the early-show regression, the QA helper requested the same player's
equipment and showed Inspect on Offhand before `INSPECT_READY`. With Inspect
visible, all five native slots were empty and `UISpecialFrames` did not contain
`InspectFrame`. Both Escapes behaved as in native Inspect. The backpack bounds
were identical at all checkpoints, the game menu stayed closed, and the
original Inspect positions were restored. BugSack session 786 recorded zero
new occurrences for the interaction run. The trace contained no blocked or
forbidden addon-action events.

### Player-operated combat on 43b419e

In session 787, Moonweaver entered combat with the compact native map and
separate backpack open on Offhand. M closed the map 2.25 seconds after entry.
B closed the backpack at 3.47 seconds. Both stayed closed through combat exit.
This is the native in-combat binding behavior. The keep-open controls were
tested outside combat in session 786.

O opened Social and C opened Character during the same fight. Both titles
and close buttons were visible in the player's combat screenshot. Both panels
had top 445.1 and height 433.1 in UIParent units. Character's side tabs ended
at x = 713.4 and Social began at x = 721.3. Their positions held at combat
exit and at the subsequent UI reload. BugSack's occurrence count was unchanged
from session 786 through 787, with no blocked or forbidden addon actions in
the combat trace.
