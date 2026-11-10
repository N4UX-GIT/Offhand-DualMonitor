# Critical loot-roll visibility follow-up, 2026-11-10

Status: source regression reproduced and corrected; native acceptance pending.
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

Native testing is pending confirmation that the running Forever client is free.
A private dummy-row harness has been prepared for the native container add,
reflow and removal path without actual items or loot choices. Installation
preflight refused to run while WoW was open, before creating backups or changing
installed addon/WTF files. No desktop input was sent and the user's client was
left untouched. Real simultaneous roll choices and combat lifecycle still need
reporter verification even if the dummy-row test passes. Daylight is deferred.

The original prepared Beta 29 ZIP is unchanged, SHA256
`004be4e1fe35dba3bc55f6579ba7d6aa5f5676328fe9c495305f18bbdba9694e`.
No release, tag, Companion binary or public artifact was changed.
