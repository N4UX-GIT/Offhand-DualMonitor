# Forever party flyout, 20 November 2026

The Discord screenshot shows Blizzard’s party management drawer (marker icons and group controls) and the separate Edit Mode party portraits. On the Discord Beta 36 package the drawer opened over the far-left Offhand while the portraits were correctly placed on Mainhand. Installing RestedXP 4.11.37 produced the same result.

## What changed

Forever’s `CompactRaidFrameManager` reapplies its full-window top-left anchor when folded or expanded. Offhand docks this native anchor to the Mainhand rectangle and clips the folded body at its edge. The clip draws above Edit Mode’s party and raid selection overlays so that both arrows work. Leaving the span restores Blizzard’s normal parent and anchor. Offhand yields to a custom anchor. The fix does not edit the party portraits, guide positions or saved HUD layouts.

## Live evidence

Moonweaver, Forever 1.60.1.71037, Windows, keyboard and mouse. Base addon `178bf64`, Companion 2.1.9-beta.1 from the Discord test package. Compared the base and fixed addon with the official RXPGuides v4.11.37 loaded and with its directory physically absent on cold launch. An in-session request to disable the guide left it loaded and was counted as a guide-enabled run.

| Scenario | Observation |
| --- | --- |
| Portrait Offhand on the left, shorter Mainhand on the right | On the base build, the expanded drawer started at x=0, top=1810. On the fixed build it started at x=1097, top=962, against Mainhand's left edge and 140 UI units below its top. |
| Folded and expanded with both previews enabled | Clicked the physical forward and back arrows. Both worked, including over the raid preview. The folded body was clipped at the seam. A mouse-focus check just inside Offhand returned no part of the drawer. |
| Party preview only, raid preview only, both, neither | The first three showed the manager. Turning both off hid it. Exiting Edit Mode while solo hid it again. |
| Guide placement and portrait ownership | In the right-Mainhand span the guide retained x=0, top=1073 through open and close. The party preview retained x=1121, top=937. |
| Map and Character open on Offhand | The expanded drawer remained on Mainhand. |
| Left portrait chosen as Mainhand | The drawer and tab followed the left game view after loading the new topology. Opened with and without the guide. |
| Window restored, then re-spanned with drawer open | Normal Blizzard anchors returned, x=0 expanded and x=-200 folded. Re-spanning reattached the expanded drawer to Mainhand. |
| Reload, cold launch and custom anchor | Dock reapplied after reload and startup. A custom CENTER anchor stayed attached to UIParent. |

Positions are in UIParent units. The portrait display was 1440 × 2560 and the landscape display 2560 × 1440. BugGrabber’s saved counters were compared at reload and exit boundaries using the existing BugSack history. No new occurrences were recorded.

## Verification boundary

The isolated candidate passed 140 Lua suites, all six manifests and ten checker tests. Installed-source comparison returned zero differences. The new regression suite also covers late module load, scaled fractional offsets, protected combat deferral, forbidden frames and relinquishing a custom position. Combat coverage in that suite is simulated.

Actual party and raid membership, role-specific actions, join/leave and in-combat toggling still require participants. Physical controller input and reporter acceptance are also outstanding. The existing native bag Escape release check belongs to a different scope.

The addon-only QA archive replaces `Offhand/Core/Mainhand.lua` in the original Discord addon ZIP. All other entries match. SHA-256 is `c6f3e5ed04e1e9b16b63186e5e11c08c929066433a97a5a88a5de5070dea8a5d`.
