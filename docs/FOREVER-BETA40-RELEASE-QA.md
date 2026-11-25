# Beta 40 release checks on Forever

Live QA for Offhand `2.1.5-beta.40` (runtime commit `4b59c0f`, installed parity verified with `--installed`) ran on Forever `1.60.1.71037` on November 24–25, 2026 alongside Companion `2.1.9-beta.3`, DaylightUI `2.2.6` (`DaylightUI_Bags` `2.2.6`), OpenMap `0.8.13`, and OneForAll `6.2.16`.

Earlier Beta 39 baseline results remain archived in [FOREVER-BETA39-RELEASE-QA.md](FOREVER-BETA39-RELEASE-QA.md).

## Live-evidence gate (November 25, 2026)

- **Native separate backpack Escape**: Confirmed resolved on `4b59c0f` (including the native separate backpack slot-overlay regression fix; NPC gossip, player inspection, and Game Menu Escape flows with the separate backpack remaining on Offhand). Deferred scope remains flight paths, in-combat Escape, and equipped bags 1–4.
- **Workspace restart & reload persistence**: Confirmed resolved on `4b59c0f` across both native Blizzard panels/bags and DaylightUI `2.2.6` panels/bags (panels and backpack restore cleanly across reload and client restart after spanning). Deferred scope remains full client restart with span already active at login.

## Additional Beta 40 live checks confirmed (November 24–25, 2026)

- **OpenMap `0.8.13` & outdoor zone following**: Confirmed working on Forever `1.60.1.71037` ([MAP-ZONE-FOLLOW-QA.md](MAP-ZONE-FOLLOW-QA.md)).
- **DaylightUI `2.2.6` HUD & window compatibility**:
  - Unlock bar pill stays anchored in Mainhand and Cooldown Manager opens in Mainhand.
  - Opening overlapping panels on Offhand no longer shunts an existing Offhand panel across the seam into Mainhand.
  - Reload/restart persistence restores DaylightUI replacement windows and `DaylightUIBag` cleanly after startup refresh.
  - Escape protection keeps DaylightUI and WindowMove Offhand panels open when pressing Escape, preserves `DaylightUIBag` when navigating from Game Menu to Blizzard Options (and restores if closed), and supports closing/reopening `DaylightUIBag` with `B` when **"Keep Offhand bags open when I press the bag key again (outside combat)"** is unchecked.
- **In-game What's New notice**: Confirmed updated Beta 40 user-facing copy displays cleanly in-game.
