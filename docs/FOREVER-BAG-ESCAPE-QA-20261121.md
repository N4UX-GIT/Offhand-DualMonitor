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

In session 788, the expanded Spellbook opened outside combat with P, then
stayed hidden when the player pressed P in combat. BugSack gained one
`ADDON_ACTION_BLOCKED` occurrence attributed to `*** ForceTaint_Strong ***`.
The native `TOGGLESPELLBOOK` binding called `ToggleSpellBookFrame`, then
`TrySetTab`, which attempted `PlayerSpellsFrame:SetAttributeNoHandler()`
through `SetUIPanelAttribute` before showing the window. The trace also
recorded blocked-action events without their arguments, so it cannot identify
the source of each event. The Forever 71037 knowledge query supplied no
build-specific attribution. [Forever Spellbook tab selection](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_PlayerSpells/Blizzard_PlayerSpellsFrame.lua#L211-L226)

Shift+P opened Collections during the same fight. The journal measured
502.5 × 433.1 UI units at left 99.8, top 445.1 on Offhand. Those bounds
held through combat exit and the subsequent reload checkpoint.

In the comparison fight (session 791), the recorder confirmed
`OffhandLoaded=false` at login. P retained its native `TOGGLESPELLBOOK`
binding and opened the expanded book outside combat. From a closed book,
the player pressed P once in combat. The book stayed hidden. At 1.16 seconds
after combat entry the client blocked the same protected attribute write
under the same attribution. BugSack gained one occurrence with the same
stack as session 788. Other addons and the latest portable Companion remained
active in both runs. This reproduces the failure without Offhand on this
setup. Its underlying cause remains open. The Spellbook result does not block
release of the tested pair. Moonweaver's original addon enablement file was
verified after reload, the temporary recorder was deactivated and the
Spellbook returned to compact mode. BugSack gained zero occurrences from
restoration through client exit in session 792.

### Follow-up to Beta 37 — native map and Spellbook visibility

On Forever 1.60.1.71037, Moonweaver tested a local candidate with portable
Companion 2.1.9-beta.1 and the full 1440 × 2560 portrait Offhand. The first
candidate requested the native map through `C_Map.OpenWorldMap()` on UI reload.
The map returned, but the player also saw a previously closed Spellbook return.
Both saved snapshots already contained `openWorkspacePanels.PlayerSpellsFrame = true`,
including the snapshot preceding the map restoration.

The next candidate captured each native root's own shown state at the first
world transition. The player closed the Spellbook with its X and reloaded
with the map open. At logout the recorder saw the map shown and the book
hidden. Six seconds after reload the map was back at left 11.6, top 1831.8,
scale 1.037. The book was hidden and the current BugSack count was zero.

In session 798 the restored map was visible at combat entry. The player
pressed M once and the map closed. The recorder saw it hidden at combat
exit and logout, with zero current-session BugSack occurrences at all three
checkpoints. The player confirmed both panels stayed closed on the next
reload. The subsequent preview produced two BugSack stacks in the temporary
`OhBagQA/combat.lua` recorder. It tried to read unset hidden-map coordinates
and passed the screenshot function directly to a timer. Neither stack passed
through the shipped addon. The player saw the revised What's New on Mainhand.
The recorder was restored to its original inert file. After the next reload,
the client exited normally and BugSack saved session 801 with zero errors.

### Keep-open options in combat, Forever 1.60.1.71037

Moonweaver used the native compact map, separate Blizzard backpack and portable
Companion 2.1.9-beta.1 on the 1440 × 2560 portrait Offhand. Both keep-open
options were enabled. M was bound to the world map and B to the backpack.

| Run | Player observation | Saved diagnostics |
| --- | --- | --- |
| 802, candidate, both open before combat | Both remained visible through repeated M and B and returned after reload. | Both roots stayed shown. BugSack recorded zero occurrences. |
| 803, candidate, both closed before combat | Neither appeared during the fight. The backpack appeared afterward. | BugSack recorded one blocked `OpenWorldMap()` call attributed to Offhand's experimental key handler. The backpack's shown flag changed during combat. |
| 805, original Blizzard combat bindings, both closed | M opened the map partly outside the portrait monitor. B produced an interface warning with no visible backpack. The map moved back after combat. Both were in place after reload. | The map's lower-left changed from (260, 1163) to (12, 1298) in frame coordinates. The shown bag had no screen rectangle in combat. The game screenshot captured the warning. BugSack recorded zero occurrences. |
| 807, original Blizzard combat bindings, backpack only | B produced the same warning. The backpack appeared after combat. | Its rectangle stayed unresolved from the first B until combat ended, then resolved to (747, 1258, 178, 305). BugSack recorded zero occurrences. The taint log still predated this run. |
| 808, Offhand disabled, unspanned | B opened the backpack at the lower right in combat. The player could not see the Escape menu and exited with /quit. | Visible bag with a valid rectangle and zero BugSack occurrences. |
| 810, Offhand disabled, spanned | B again opened the backpack at the lower right during combat. | At 4000 x 2560 the separate bag had one native anchor and a visible rectangle throughout the remainder of combat. BugSack recorded zero occurrences. |
| 812, original Blizzard combat bindings, backpack only | The shown backpack had no rectangle in combat. | Blizzard's FrameControlsManager handled ContainerFrame.OpenBag. Its SmartNavigation SecureHelper emitted the in-game warning. The warning did not add a BugSack occurrence. |
| 814, passive lookup of individual bags | The yellow warning disappeared. The backpack became visible only after combat and returned after reload. | The bag pointed to the bottom right of ContainerFrameContainer. Its parent had one anchor and no rectangle. Zero BugSack occurrences. Both the recorder and addon lookup changed. |
| 816, bag parent excluded from popup recovery | B opened the backpack on Mainhand during combat. It moved to its saved Offhand location after combat. No yellow warning. | The parent retained both native anchors and a rectangle, and the bag remained visible. Zero BugSack occurrences. |
| 818, native M and B with both windows initially closed | Both opened on Offhand during combat. The backpack stayed there. The map shifted right as combat ended. Both reopened at the saved locations after reload. | The map moved from left 11 to 260 at combat exit. The backpack remained at (747, 1258). Zero BugSack occurrences. |
| 820, map settlement following combat exit | The map opened on Offhand but shifted during combat. It returned to its saved spot on its own after combat. The backpack kept its position during and after combat. Both returned after reload. | The map moved from left 11 to 260 within 0.10 seconds of opening. Within one rendered frame of combat exit it was back at left 12. The backpack remained at (747, 1258). Zero BugSack occurrences. |
| 822, final bounded map repair, both open before combat | Both remained on Offhand at combat entry. The player saw a refresh at the same locations, a yellow interface warning and only the backpack reopening during the fight. The satchel reappeared alongside it after reload. | Native M and B closed their windows, then reopened the map at (12, 1262) and backpack at (747, 1258). Slot 1 hid on B and stayed hidden for the remainder of combat. The map recovered from a 0.10-second native reflow at combat exit. Zero BugSack occurrences, one captured interface warning. |

Both roots reported unprotected when inspected by the player. That flag
describes the frames. The in-combat map-open API rejected the experimental
handler. The handler was removed from the checkout and the installation.

Before run 820 the player also saw the Simple Leather Satchel move to the bottom
right of Mainhand when they closed the backpack with X. This was the separate
equipped bag's contents window. The run 820 recorder tracked only the backpack.

The native separate-backpack binding calls `CloseAllBags()` when the backpack
is open and opens only bag ID 0 on the next press. Run 822 followed that
sequence. The warning stack on reopening ran from Blizzard's
`TOGGLEBACKPACK` through `ContainerFrame_OnShow` to SmartNavigation's
`FrameShown` rejection. The stack identifies where the warning was emitted.
Its original source of taint remains undetermined. The restored-open scenario
reproduced it even though the closed-at-reload control in 820 was clean.

Combat key suppression remains unverified as a shippable feature. On the
current candidate, native presses still toggle each window during combat.
The release note and settings describe keep-open as an out-of-combat option.
The diagnostic recorder was restored to its original 55-byte file after the
last run.

### OneForAll Game Menu and backpack retest

Moonweaver used Forever 1.60.1.71037 and the portable Companion with the tab
height correction (SHA-256 `02f3efb72fb7b7d85c519e2cc900b1116f5b7d3573c01f47249fd15172dab813`).
On the original add-on in session 825, the player heard the Game Menu open
in a 1904 × 1041 window but could not see it. The shown menu had a TOPLEFT
anchor at (2229, 1117), exactly matching OneForAll's saved position. Its
installed QoL.lua applies this anchor on show, on the next frame and following
panel updates.

With the menu correction installed (827), each observed open used the native
window center. The player confirmed immediate centering on consecutive opens.
BugSack recorded zero errors and the separate warning observer recorded zero
interface warnings.

On the 4000 × 2560 span (829), the player saw the Game Menu immediately
centered on Mainhand at every open, without jitter. Every visible sample
used the same CENTER-to-BOTTOMLEFT anchor (2072.4, 553.1) in frame
coordinates. Both the warning observer and BugSack remained clear.

In the native separate-backpack gossip test (830), the player saw the first
Escape close the NPC conversation and the second clear the target. BugSack
and the interface warning observer were clear. The bag trace had a brief
hide/show in the same session. This recorder version did not capture gossip
events to establish its timing relative to the key presses.

With both windows restored open on reload (834), entering combat preserved
both positions. M and B closed them, then opened them again in place. B
generated one interface warning from the native ToggleBackpack path through
ContainerFrame_OnShow and SmartNavigation's FrameShown validation. The
current-session BugSack count stayed zero.

The player saw the compact map jitter on opening during that fight. The
backpack reopened without the separate equipped bag; both bag windows and
the map were visible after reload. With both windows closed at reload (836),
M and B opened them on Offhand in combat. The second presses closed them.
This time both BugSack and the interface warning observer were clear.

In session 832 the first Inspect attempt cleared the target while Inspect
was still shown. The player confirmed the first Escape caused the clear.
The recorder read the Offhand window-close binding at that target change.
Two later attempts recorded Inspect closing while the player was still
selected, before the second Escape cleared the target. The separate
backpack stayed visible. No BugSack entry or interface warning was recorded.

In session 837 the standard Inspect window closed on Escape with the player
still selected. A separate dismissal in that session came from a mouse target
change. The attempted `/ohbag early` command did not exercise an early open.

In session 839 the player used `/inspect` on an in-range player. The temporary
recorder showed Inspect 0.30 seconds before the client's first `INSPECT_READY`
event. The first Escape closed Inspect with the player still selected. The
second cleared the target 4.46 seconds later. The native backpack remained
visible at the same Offhand position throughout. BugSack and the warning
observer were clear. This forced timing case passed. The first-Escape failure
in session 832 remains open. The recorder was restored to its original file
and the client exited normally, with zero new BugSack occurrences through
session 840.

### Compact map sizing and combat keys

In run 842, both windows started closed. With the map's opening anchor checked
every rendered frame, M and B opened their windows on Offhand. The map still
changed at combat exit, from a frame-local lower-left of (11, 1208) to
(12, 1262). The backpack stayed at (759, 149). BugSack and the yellow warning
observer were clear.

In run 844 both windows were restored open at login. The native map had
measured 1004 × 689 while hidden, at scale 1.06887. Once open with the quest
list it measured 1035 × 534, at scale 1.03685. It retained that size and
position when reopened in combat. B reopened bag ID 0. The separate satchel
remained closed. The player saw the yellow warning on B, and the recorder
captured one SmartNavigation FrameShown rejection with zero BugSack errors.

In 846 a temporary opt-in test button forwarded the player's native binding
using RunBinding. Neither window opened. BugSack recorded one forbidden
RunBinding error naming OhBagQA. The key test was removed before the following
run. The published addon and the working candidate do not dispatch these
combat bindings from an addon click.

With the hidden compact map fitted for the sidebar it will open with, session
847 held scale 1.03685 and the same Offhand rectangle when the player closed
and reopened both windows in combat. No yellow warning or BugSack occurrence
was recorded. This run entered combat with both windows visible.

In session 849 both windows were closed after reload and at combat entry. The
hidden map already had scale 1.03685. The first native M rendered it at
(12, 1262) in its own coordinates with a 1035 × 534 rectangle. Neither its
scale nor its position changed through combat exit. B opened the backpack at
(759, 149). The player confirmed stable map placement. Zero BugSack
occurrences and zero blocked-action warnings were recorded in this run.

In session 850 the restored separate backpack closed on the first native B
and reopened with the yellow interface warning on the second. BugSack
remained at zero. Two observed initializations of Blizzard's container frame
list came from its combined-bag settings and entering-world handlers.
The verbose taint log did not identify the source of the later warning.

In 851 a startup-only comparison called the native OpenBag function for
separate containers. Its observer confirmed Offhand requested IDs 0 and 1.
The second combat B still produced the same warning and BugSack recorded
zero errors. The comparison was removed from the checkout and installation.

In the matched manual-open control (854) the player opened both the backpack
and the Simple Leather Satchel using the bag bar after a closed reload. B
closed them in combat. The next B opened only the backpack, as expected for
Blizzard's separate-backpack binding. The player saw no yellow warning and
the warning observer and BugSack were both clear.

### Separate bags after login and reload

Moonweaver tested the startup change on Forever 1.60.1.71037 with the
corrected Windows Companion 2.1.9-beta.1. The backpack stayed closed at login
and after spanning (855). The player opened the backpack and Simple Leather
Satchel before reloading (856) and confirmed that both stayed closed (857).
The previous session's Offhand backpack rectangle was 759,149,178,305.

In session 857 the backpack was still closed at combat entry. Three native
B presses opened, closed and reopened it. Both openings and combat exit
had the same Offhand rectangle as before reload. M and B reported their
Blizzard bindings during the fight. The player saw no yellow interface
warning and heard no BugGrabber sound. The warning observer recorded no
blocked-action warning, and BugSack had zero new occurrences in 855 through
857. Three subsequent UI messages said “Another action is in progress.”
The temporary combat recorder was removed after the logs were saved.

### Separate bags restored on reload

The closed-on-reload fallback above was superseded. In session 858,
Moonweaver opened the backpack (bag 0) and Simple Leather Satchel (bag 1)
on Offhand. After reload, session 859 restored both. Their rectangles were
identical to the pre-reload measurements: 759,149,178,305 for the backpack
and 759,462,178,136 for the satchel. The corrected Companion was 2.1.9-beta.1
and Forever was 1.60.1.71037.

With both bags still visible at combat entry, native B closed both and the
second B reopened just the backpack at the same position. The player saw the
yellow interface warning. The observer captured one blocked interface warning
from Blizzard's FrameShown callback. BugSack recorded zero new occurrences in
858 and 859. This candidate passes reload restoration for the two bags and
fails the combat warning check.

The visible-bags cache reported Offhand as its taint owner after automatic
restore. It was secure before restore and in the manual-open comparison in
858. The cache also reported secure when the warning fired, so these readings
alone do not establish its cause. Switching from the previous OpenAllBags and
OpenBag restore paths to ToggleBag for missing saved IDs did not resolve it.

### Forever client report: the second backpack key warns after an addon opens the bags

On Forever 1.60.1.71037, select separate Blizzard bags and use the native B
binding. From a single window, have a test addon open the closed backpack
and an equipped satchel once, out of combat, using ToggleBag for IDs 0 and 1.
Enter combat with both visible. Press B to close them, then B to reopen the
backpack. The backpack appears, but the game displays the yellow interface
action warning. Opening the same bags manually before the fight was clean.

| Moonweaver session | Initial open | Window | Second B | New BugSack errors |
| --- | --- | --- | --- | --- |
| 859 | Offhand reload restore | Spanned | One yellow warning | 0 |
| 866 | No automatic open recorded | Single | No warning | 0 |
| 868 | Independent QA addon, Offhand and OneForAll loaded | Single | One yellow warning | 0 |
| 869 | Independent QA addon, Offhand and OneForAll both unloaded | Single | One yellow warning | 0 |

In 869 the QA addon recorded both addons unloaded, both bags visible at the
native anchor and B bound to TOGGLEBACKPACK. BugGrabber and BugSack were
enabled. The corrected Companion 2.1.9-beta.1 was running. No Offhand
placement, key override or spanning was necessary for the reproduction.
Offhand and OneForAll were enabled again for Moonweaver after exit and the
original QA file was restored.

The captured stack runs from the native backpack binding through
ContainerFrame_OnShow to the ContainerFrame.OpenBag callback and the wrapped
GamepadFrameControlsManagerMixin.FrameShown. For client maintainers, check
whether the bag notification should dispatch gamepad focus work when gamepad
UI is inactive. The function body already checks the input mode, but the
warning fires in its wrapper before the body runs. This is a proposed
client-side investigation. There is no verified addon-side fix in this run.
[Forever build 71037 callback](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_GamepadSharedUtility/FrameControlsManager.lua#L217)

#### Client-side candidate and verification

The [proposed Forever UI patch](patches/forever-71037-gamepad-bag-focus.patch)
checks the current interface style when each bag opens or closes. Keyboard and
mouse mode skips gamepad focus work. Gamepad mode forwards the original frame
to the existing focus handler. Checking at event time accommodates a player
switching interface styles during the session.

The patch applied to UI source revision
`734f065329cff4992835b01a84f210a297db91b6` (1.60.1.71037). The complete
patched Lua file passed a Lua 5.1 syntax check. An isolated test of the two
callbacks switched between keyboard and gamepad twice and checked the target,
order and number of calls to the focus handlers. Reversing the patch restored
the original source byte for byte.

Live verification requires a Forever client containing this change. On
Moonweaver, record the active interface style when the second B is pressed.
In keyboard and mouse mode, confirm that both bags return on Offhand after
reload, native B closes both during combat, and the second B opens the
backpack at its saved position without a yellow warning or a new BugSack
entry. In gamepad mode, verify native focus selection and dismissal on bag
open and close. The previous live traces captured the key binding and the
warning stack, but did not sample the active interface style.
