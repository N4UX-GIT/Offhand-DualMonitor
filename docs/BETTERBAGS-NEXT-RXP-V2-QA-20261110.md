# BetterBags Next and RestedXP V2 follow-up

Continues the fresh BetterBags/RestedXP recurrence with Daylight testing deferred.
The earlier acceptance covered Classic and Next small bags plus RestedXP V1.
This pass targets Next full mode and the anonymous V2 guide root. Exact reporter
versions/profile, auction/vendor gameplay and combat remain separate gates.

## Source finding and correction

Installed source: BetterBags v0.9.2, Camelot Interface 16001; RXPGuides v4.11.35.
The earlier RestedXP native run used v4.11.34. Local vendor source is authority
for these installed versions; no vendor implementation is copied or modified.
First-line knowledge status reports review-due build 70532; the scoped
BetterBags/RestedXP lookup supplies prior authored evidence. The exact
BetterBagsNextBackpack lookup has no match, which is a knowledge gap.

HUDCompatibility's position-owner list contains Classic BetterBags roots but
misses Next's four panel roots. Next's own next/panel.lua StartMove explicitly
clears SetUserPlaced after StartMoving because vendor persistence owns its
position. The native user-placed fallback cannot reliably cover these panels.
Installed next/bag.lua, bank.lua, vendor.lua and guildbank.lua identify
BetterBagsNextBackpack, BetterBagsNextBank, BetterBagsNextVendor and
BetterBagsNextGuildBank. Added only these verified names to the existing policy.
Automatic popup rescue now yields their placement; explicit workspace actions
and vendor position management retain their existing behavior.

The production popup integration regression, extended with those actual root
names and unplaced CENTER anchors, fails before correction on NextBackpack and
passes afterward. It exercises immediate/deferred ShowUIPanel, hook installation
and repeated popup/void recovery. This is simulated attribution, not a natural
native reproduction of the reporter's trigger. Ordinary popup recovery and
Classic/RestedXP V1/V2 ownership checks remain passing.

All 121 frozen Lua suites pass. Six manifests validate 81 runtime files (80 Lua,
one XML) with Lua 5.1. All 103 ZIP entries verify. Previous package SHA-256:
`ddc00aaa1bf9116c768b9af8104f8065acc716c662939e46adc19e5ff4322cde`.
Follow-up package SHA-256:
`b16048fafc3eee228f83b4e559888f329a02564e8941508174d74f1bdf3cb436`.
The runtime delta from the preceding candidate is Core/HUDCompatibility.lua.
Installed after full addon backup; generated bridges preserved.

## Native verification

Passed the limited spanned Forever 1.60.1.70862 run with installed Companion
2.1.5: 2560x1440 single-display split, Mainhand right and workspace left, each
1280x1440. All 32 captured snapshots report spanning true and topology READY.
BetterBags and RXPGuides enabled; EllesmereUI core disabled for isolation.

- Next small's controlled vendor-saved workspace position and scale remain
  identical through native world-map open/close (samples 3-7).
- Next full settles at the vendor's right-edge full-height position. After a
  normal reload and B reopening, its geometry and scale remain identical
  through map open/close (samples 15-19). Mode transitions animate; immediate
  samples are not compared against settled geometry.
- RestedXP V2's anonymous welcome window remains at its controlled workspace
  position through map open/close, then a normal reload (samples 15-25). No
  guide is loaded or advanced. This does not cover a populated V2 guide.
- Returning Next to small restores its saved workspace position. Normal reload
  and B reopening retain identical geometry and scale (samples 21, 24-25).
- Controlled Mainhand placement of Next small and V2 retains identical geometry
  and scale through map open/close (samples 27-31).

The native Next root reports IsUserPlaced=false while visible, confirming why
the fallback alone is insufficient. The bounded offline reader asserts the
comparisons against preserved snapshots. The helper captures geometry and uses
reversible vendor-mode and placement fixtures; it does not load/advance guides,
perform item/NPC actions, send chat, save native layouts or install native hooks.
These checks accept the tested candidate behavior. The failing-before
attribution is the production integration fixture, not a naturally reproduced
reporter failure. Bank/vendor/guildbank panels, auction path, physical dragging,
exact reporter profile/version, populated guides, combat, controller and other
display topologies remain unverified. Daylight remains deferred.

## Cleanup and retained build

Normal client close verified no remaining WoW window. Four historical BugGrabber
records remain unchanged in message/time/counter/stack. All 13 existing scoped
state/source files restored by SHA-256, including vendor settings and addon
flags. Six newly created files moved into private evidence, restoring their
original absence. Original private observer source restored; both IssueProbe
and PerformanceProbe TOCs disabled. No profile reset or native layout save.
All 96 installed non-bridge product files match the frozen package; generated
bridges remain preserved. The private candidate stays installed with its full
pre-install backup. No Discord or public-release changes.

Private ignored evidence: dist/discord-qa-20261110-5, including vendor source
hashes, before/after regression output, frozen subject/package, installation
receipt, 32 native snapshots, comparison assertions, unchanged-error comparison,
cleanup receipt and scoped backups. Account paths and vendor state stay private.
