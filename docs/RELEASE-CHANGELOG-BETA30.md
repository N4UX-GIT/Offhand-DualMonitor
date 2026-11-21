## [2.1.5-beta.30] - 2026-11-11

**Loot-roll and UI compatibility hotfix**

- Fixed a case where remaining loot-roll windows could move to the screen seam
  after an earlier roll finished.
- Keeps loot-roll windows in Mainhand when Blizzard rearranges the loot container.
- Expanded EllesmereUI layout transfers to include supported cooldown, utility,
  cast, pet, stance and current-spec tracking bars, while keeping linked groups
  together.
- Clearer EllesmereUI preview guidance for missing or disabled modules,
  dependencies, linked anchors and profile overrides. Empty override stores
  no longer block a transfer.
- Improved Questie tracker and Social/Quick Join button compatibility so
  automatic window recovery preserves their anchors.
- Retail now respects your friendly-player name-text preference instead of
  forcing names on.

Includes the fixes from Beta 29. Existing settings and layouts are preserved.
No Companion update is required.

**Beta feedback:** The placement fix passed spanned Forever testing with private
panels using Blizzard's loot-container functions. Real simultaneous loot choices
and combat behavior still need player verification. Native Retail preference
behavior, active Questie-objective dragging and populated tracking-bar imports
also need player feedback. Report issues with `/offhand diag full`, your
client/build and other UI addons.
