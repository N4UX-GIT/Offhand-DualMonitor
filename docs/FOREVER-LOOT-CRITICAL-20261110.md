# Critical loot-roll visibility follow-up, 2026-11-10

Status: native seam drift reproduced; candidate passes the same private-row
lifecycle with spanning applied. Real-roll and combat acceptance remain pending.
Branch: `codex/critical-loot-roll-visibility`, based on `e61bac1`.
The fix is isolated from the pending EllesmereUI preview and other HUD changes.

## Reporter evidence

The authorized read-only Discord collector re-scanned both requested roots,
including archived threads: 42 threads, 19 archived, 2358 messages and no coverage
gaps. No Discord messages, reactions or statuses were changed.
The latest report says pending items are hidden and time out/pass:
https://discord.com/channels/1491522138371391691/1551335554787057694/1569825510933135452
It has no attachment or new diagnostic. The author previously identified addon
2.1.5, but the exact beta suffix, current build and active UI replacements are
not established by this message. The earlier roll report supplied Forever
1.60.1.70862 and Beta 28 diagnostics. These are separate evidence points.

## Missed native anchor transition

Beta 29 compacts sparse roll arrays, but its container ownership predicate
accepts only an unanchored or UIParent-relative native root. Blizzard's modern
ManagedFrameContainerMixin:UpdateFrame reparents a shown GroupLootContainer to
BottomManagedFrameContainer and lays it out in the column. Its native TOP/TOP
offset changes as other HUD elements change. The old predicate rejects that
native anchor, labels it custom-anchor and disables the row mover. The next
GroupLootContainer_Update, including removal of an earlier roll, then places
the remaining rows back at the native full-canvas/managed-column location.

A production integration regression fails the previous source on that sequence.
The candidate accepts the exact native manager parent and layoutParent, TOP/TOP
point, centered X and finite changing Y. User-placed, other-parent and custom
offset placements retain their existing ownership rules. Native reflow resumes
the correction after a custom placement is released. No Show/Hide, alpha,
parent, item/roll ID, roll-choice or native script changes were added.

This establishes a missed ownership/placement path, not proof that it explains
every disappearing-roll report. The current pending roll must still be shown
by Blizzard; this patch does not force-show cancelled or expired rolls.

## Source evidence

Shared knowledge status/search were consulted first. The search index is stale;
its reviewed Forever source is build 70532, older than the recent 70862 target.
Primary source inspected at immutable revision
`ca8368f2f2380cbe696854f7f2646387c278a61b` in Gethe/wow-ui-source:

- Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua and .xml: native roll add,
  removal, sparse row layout and the BottomManagedFrameTemplate container.
- Blizzard_ManagedFrameSystem/Shared/ManagedFrameSystem.lua and .xml: manager
  registration, reparenting and layoutParent assignment. Lua SHA256:
  `a40799eb48559197437edd0874ad3d6a7d15dbc7b173491c39c75d355a406af6`.

Installed EUI_CDM_Blizzard.lua PlaceLootRolls independently documents and checks
this native parent/TOP anchor, but does not prove that EUI is installed for the
new reporter. Its SHA256 is
`5977cfa0ced2d69a9c8c6485e175056b1552ff1f2f67bbb8649aa07c5c6c8f03`.
No upstream implementation was copied or executed in the addon.

## Validation and private candidate

All 124 Lua suites passed, including two changing native offsets, removal of
the first row with the second remaining shown and centered, custom-offset
ownership and native recovery. Existing sparse-scale, upward/downward stack,
edge clamp, combat and external-row-owner regression cases still pass.
All six manifests, 81 runtime Lua files and XML references pass static validation.
This is simulated lifecycle evidence, not native visibility or taint acceptance.

Private addon-only archive:
`dist/critical-loot-20261110/Offhand-v2.1.5-beta.29-lootfix.1.zip`
SHA256: `9eb718a3506e48771de60d1b908ffeafd7d34c86d4ec086c71b423a695905368`.
It is derived from the frozen Beta 29 archive. Exactly seven entries differ:
HUDTransientFrames.lua and the release labels in six TOCs. Every other entry
is byte-identical, including all existing placeholder bridges. The extracted
candidate also passed manifest/path/XML/Lua 5.1 syntax validation. It does not
include the pending EUI preview, Questie/Social changes, private helper or logs.

## Native comparison and cleanup

The user authorized addon-only testing in the available Forever client.
The client was closed normally, 263 existing addon/WTF files were backed up and
hash-verified, and the authenticated launcher reopened the selected safe test
character. Forever 1.60.1 build 70862 used keyboard UI, Companion 2.1.6 and its
single-display 32:9 split, game RIGHT/workspace LEFT. Span WoW Now was applied
and a normal UI reload settled the viewport before comparison. The private
helper refused to start with active real rolls or combat. It passed three
plain addon-owned dummy frames through the actual GroupLootContainer_AddFrame
and GroupLootContainer_RemoveFrame functions, with no items or roll choices.

The installed build's metadata identified Beta 28 and contained another chat's
region-sizing QA changes/helper. The affected HUDTransientFrames.lua matched
frozen Beta 29 text exactly after normalizing line endings. This is therefore
a controlled comparison of the affected baseline/candidate module in that
installed environment, not acceptance of the complete frozen Beta 29 package.
Only that installed module was replaced for the candidate. EllesmereUI, its
CooldownManager, QoL and BlizzardSkin modules were loaded; DaylightUI and
ForeverPlus were not. The other chat's helper was left untouched.

- Baseline: after three rows were added, native maintenance reparented the
  container to BottomManagedFrameContainer with its centered TOP/TOP anchor.
  Offhand reported rowMoverActive=false, conflict=custom-anchor. Removing the
  first row moved the remaining two from Mainhand to the seam. They remained
  shown/visible with full alpha, but their centers changed from Mainhand X
  2357.143 to full-canvas seam X 1571.429 (UI units). This reproduces a placement
  loss, not a native Hide or roll-decision failure.
- Candidate: the same native reflow and first-row removal retained
  rowMoverActive=true with no conflict. The two remaining rows compacted at
  Mainhand X 2357.143 and remained fully inside its rectangle immediately and
  after maintenance. Visible screenshots and SavedVariables agree. The native
  TOP/TOP transition was observed before Offhand's maintenance re-established
  its normal fallback container point.
- BugGrabber entry count stayed at the existing four throughout both runs.
  This is no increase in recorded error entries, not general taint acceptance.
- Clear removed only the three private rows. The QA client closed normally;
  all 263 original files were restored and hash-verified, four new WTF files
  were archived and only this run's private helper was removed. Battle.net and
  Companion were left open. Original Questie choices and the other chat's
  installation/settings were preserved by the complete restore.

Ignored local evidence is in dist/critical-loot-20261110: baseline-results.lua
(samples 4-7), candidate-results.lua (samples 9-15), check-native.lua and the
before/after rollback captures. The offline check asserts baseline seam drift,
candidate remaining-row visibility and Mainhand bounds, spanning, build and
unchanged error-entry counts. The candidate module SHA256 is
`377b44efb59d5cb660cccc3c159cc2f1f3e790f48962d55e26278f7e09342ff6`.

Real simultaneous loot choices, expiration/queue lifecycle and combat still
need reporter verification. This comparison establishes one reproduced cause
and its correction, not proof that all disappearing-roll reports are resolved.
Daylight testing remains deferred.

The original prepared Beta 29 ZIP is unchanged, SHA256
`004be4e1fe35dba3bc55f6579ba7d6aa5f5676328fe9c495305f18bbdba9694e`.
No release, tag, Companion binary or public artifact was changed.
