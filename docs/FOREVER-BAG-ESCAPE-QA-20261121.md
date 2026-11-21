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
a 457-unit workspace. Player-operated confirmation with the QA helper
disabled is pending.
