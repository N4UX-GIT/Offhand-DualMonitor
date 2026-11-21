# RestedXP guide recovery on Forever

On Discord Beta 36, Gather could move the named guide, register it in `UISpecialFrames` and record its new coordinates in `savedMainPositions`. When an NPC panel opened, peer repair could replay that record on the visible guide. The reporter found the matching position at (2320.595, 611.072) and confirmed that removing it stopped the jump after reload.

The earlier tests covered popup rescue and the anonymous V2 guide. This regression involved the named V1 `RXPFrame` and the generic saved-panel restore path.

## Behavior after the change

RestedXP owns movement, scale and Escape for `RXPFrame` and `RXPItemFrame`. An explicit Gather can bring a guide onto Mainhand once. It leaves subsequent positioning to RestedXP. Offhand clears obsolete Mainhand, workspace and open-panel entries in every stored profile, including inactive profiles, and ignores legacy Forever CVar entries for those names. Installing the update and reloading rebuilds Blizzard’s in-memory Escape list.

## Verification

Moonweaver ran Forever 1.60.1.71037 with RXPGuides 4.11.37, the Beta 36 party-flyout candidate plus this change, and Companion 2.1.9-beta.1. With the reporter’s exact coordinates seeded, the native merchant panel and peer repair both left the guide at its observed Offhand position. Physical Escape left it visible. Reload removed the stale record.

An explicit Gather moved the guide to Mainhand once and left zero Offhand saved coordinates and zero guide Escape entries. A physical header drag then moved the guide to approximately (2334.31, 793.17). Re-seeding the reporter’s coordinates, opening the native merchant panel and pressing Escape preserved the dragged position. The merchant panel was opened programmatically for this part of the test.

The dragged anchor also survived reload, with the stale Offhand record gone. BugSack recorded zero new occurrences during the guide checks. Later, while looking for a nearby NPC, three errors came from QA slash commands (one truncated command and two invalid camera timer callbacks). The server-backed NPC conversation is deferred until a character is in range.

Automated checks exercise both named roots, missing-only and ordinary Gather, peer repair, Escape, inactive profiles and stale Forever fallback records. The NPC repair and migration regressions failed on the preceding build and passed on the patch. All six manifests, 140 isolated candidate Lua suites and ten checker tests passed. The installed candidate matched the isolated source.
