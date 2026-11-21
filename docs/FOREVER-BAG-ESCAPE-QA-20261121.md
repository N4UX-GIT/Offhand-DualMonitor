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

Treat the inspection result as intermittent on `5a521de`. Five subsequent
inspections passed, including the player's retry. The initial confirmed failure
keeps the native bag/Escape release check open. Its active binding was not
recorded, so the cause remains unresolved. No production patch or replacement
freshness receipt was issued. Combat, flight and equipped bags 1–4 remain
outside these out-of-combat backpack checks.
