# Beta 39 release checks on Forever

Moonweaver tested the local 2.1.5-beta.39 add-on on Forever 1.60.1.71037 on November 23, 2026, with Store Companion 2.1.9-beta.2 and OneForAll 6.2.13. OpenMap was disabled for the native map checks. Blizzard bags were in separate mode. A private observer recorded frame visibility, positions, targets and current-session BugGrabber counts. The observer is outside the release.

### Restart and span

| Window | Before exiting the spanned client | After logging in on one screen and clicking Span WoW Now |
| --- | --- | --- |
| Native compact map | (12, 1046) to (1085, 1862) | Same bounds on Offhand |
| Backpack | (652.10, 12.00) to (830.10, 317.00) | Same bounds on Offhand |
| Simple Leather Satchel | (652, 325) to (830, 461) | Same bounds on Offhand |

Coordinates are in UIParent units. The prior session disconnected and its client was closed. This run therefore covers relaunch after a disconnect with a saved logout event. All three windows were closed at login and returned on the span without manually opening them. The recorder counted zero errors before exit and after spanning. A separate [normal-quit test with OpenMap, combined bags and Character](FOREVER-BETA38-BAG-MAP-QA-20261121.md) also covered a deliberately closed Social panel.

### Escape with the separate backpack

- At the druid trainer, the first hardware Escape closed real NPC gossip and kept the NPC targeted. The second cleared the target. The backpack stayed on Offhand. BugSack counted zero errors.
- With a nearby player selected, an early-open Inspect window appeared before Blizzard registered it in its usual panel slots. The native inspection request received equipment data. The first Escape closed Inspect and the second cleared the player target. The backpack stayed on Offhand. BugSack counted zero errors.
- In ordinary Inspect, the player opened the equipment window on a nearby character. It appeared in Blizzard’s left panel slot. The first physical Escape hid Inspect with that character still selected. The second cleared the target 2.6 seconds later. Both separate bag windows kept their pre-test coordinates. BugSack counted zero errors.
- With no target or interaction open, Escape opened and dismissed the Game Menu while the backpack remained on Offhand.

### What’s New

The English notice displayed both feature highlights and all three buttons in Moonweaver’s single-window login. The automated notice tests cover version selection and the feature-only message. Other translations were checked by the Lua suites.
