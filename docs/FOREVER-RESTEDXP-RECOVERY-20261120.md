# RestedXP guide recovery on Forever

On Discord Beta 36, Gather could move the named guide, register it in `UISpecialFrames` and record its new coordinates in `savedMainPositions`. When an NPC panel opened, peer repair could replay that record on the visible guide. The reporter found the matching position at (2320.595, 611.072) and confirmed that removing it stopped the jump after reload.

The earlier tests covered popup rescue and the anonymous V2 guide. This regression involved the named V1 `RXPFrame` and the generic saved-panel restore path.

## Behavior after the change

RestedXP owns movement, scale and Escape for `RXPFrame` and `RXPItemFrame`. An explicit Gather can bring a guide onto Mainhand once. It leaves subsequent positioning to RestedXP. Offhand clears obsolete Mainhand, workspace and open-panel entries in every stored profile, including inactive profiles, and ignores legacy Forever CVar entries for those names. Installing the update and reloading rebuilds Blizzard’s in-memory Escape list.

## Verification

Moonweaver ran Forever 1.60.1.71037 with RXPGuides 4.11.37, the Beta 36 party-flyout candidate plus this change, and Companion 2.1.9-beta.1. With the reporter’s exact coordinates seeded, the native merchant panel and peer repair both left the guide at its observed Offhand position. Physical Escape left it visible. Reload removed the stale record.

An explicit Gather moved the guide to Mainhand once and left zero Offhand saved coordinates and zero guide Escape entries. A physical header drag then moved the guide to approximately (2334.31, 793.17). Re-seeding the reporter’s coordinates, opening the native merchant panel and pressing Escape preserved the dragged position. The merchant panel was opened programmatically for this part of the test.

The dragged anchor also survived reload, with the stale Offhand record gone. BugSack recorded zero new occurrences during the guide checks. Later, while looking for a nearby NPC, three errors came from QA slash commands (one truncated command and two invalid camera timer callbacks). This local run ended before a server-backed NPC conversation.

Automated checks exercise both named roots, missing-only and ordinary Gather, peer repair, Escape, inactive profiles and stale Forever fallback records. The NPC repair and migration regressions failed on the preceding build and passed on the patch. All six manifests, 140 isolated candidate Lua suites and ten checker tests passed. The installed candidate matched the isolated source.

## November 21 Discord report

The report was initially attributed to CurseForge Beta 38 (file 9729081). All five supplied line references match the older `Offhand-Forever-Discord-QA-178bf64.zip`. In the CurseForge archive, the Mainhand restore call is at `CanvasPersistence.lua:774` and the guide exclusion is at line 644. The original session's exact version was never captured.

In a Lua simulation, the guide started at (200, 1700) with a stale Mainhand record at (2320.595, 611.072). The test counted calls to the guide's `ClearAllPoints` while opening a simulated `GossipFrame` through `ShowUIPanel`. Each run loaded the add-on files extracted from the indicated archive.

| Add-on tested | Calls on the guide | Guide position after Gossip opened |
| --- | ---: | --- |
| Discord Beta 36 `178bf64` | 1 | (2320.595, 611.072) |
| CurseForge Beta 38 | 0 | (200, 1700) |
| Discord Beta 38 `forever-bag-map-qa1` | 0 | (200, 1700) |

Both Beta 38 archives also passed the panel and saved-profile migration suites.

The public archive's Forever manifest loads the guide exclusion before the placement and repair code. A further simulation against that archive ran three Gossip open/close cycles with stale coordinates, called peer repair explicitly, and called automatic Mainhand placement directly on the guide. There were zero anchor clears.

## November 22 reporter verification

**Closed for Beta 38.** The reporter tested in a separate, clean WoW Forever installation. NPC gossip and looting mobs both left the RestedXP guide in place. These were the two interactions that previously caused it to jump.

With the guide visible, the reporter checked three diagnostics before and after **Gather Safe UI to Mainhand**. Both times the RXP guard returned `true`, the saved-position check returned `false`, and membership in `UISpecialFrames` returned `false`.

For the upgrade case, the reporter inserted `x = 2320.5954589844` and `y = 611.07153320312` into `Offhand.db.savedMainPositions.RXPFrame`, confirmed the entry existed, and ran `/reload`. Both coordinate reads then returned `nil`. This verifies cleanup of the reported stale position on Beta 38.
