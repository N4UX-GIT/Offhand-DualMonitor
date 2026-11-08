# EncounterBar repeat repair investigation, 7 November 2026

Dy's screenshot reports the protected `EncounterBar` in unreachable mixed-height
monitor space after repeated Repair HUD actions and reloads. The supplied client
scope is **Beta 26, Forever**. Exact reporter build, topology, saved layout and
diagnostics are unavailable. No report message or Discord tag was changed.

## Findings and implementation

Two source gaps reproduce independently in regressions:

1. Recovery detection recognizes EncounterBar, but layout generation only had
   targeted custom-anchor correction for group frames and Extra Abilities. A
   custom EncounterBar relationship could survive the rebuild, or the operation
   could report `already`. Repeating the same generation does not repair it.
2. Blizzard keeps an empty EncounterBar layout root shown when its preview is
   unchecked. Root visibility alone can therefore request an unnecessary repair.
   The widget container is a child presentation of that same Edit Mode system,
   not another independently repairable system.

The candidate repairs only the serialized EncounterBar entry from the active
layout, preserving other systems and target settings. It sets a nondefault
UIParent anchor at Mainhand's horizontal center and 60% of its height, removing
any obsolete second anchor on that target. Saved offsets remain in UIParent units:
Blizzard's `ApplySystemAnchor` divides them by the frame's local scale. The
candidate does not apply that conversion twice. Blizzard applies it through
the existing player-click save/activate/reload transaction. It performs no direct
protected root writes or native script changes. A missing or externally owned
target fails without saving, rather than claiming a successful repair.

Detection ignores positively empty EncounterBar roots without a visible native
selection. A visible selection or actual content remains eligible. The widget
child alias yields to EncounterBar when that native owner exists. Diagnostics use
the same presentation predicate. Combat, Edit Mode and native Gamepad gates remain
in effect. This does not suppress a genuinely unreachable bar globally.

## Evidence

Shared knowledge status and a Forever 1.60.1.70862 query returned protected-UI
guidance only, with no exact implementation packet. The current client source
was therefore inspected at revision
`9dc84f0d3bbae1768ac3405b3716000bd93eda06`:

- [EncounterBar and its power-bar child](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_UnitFrame/Mainline/UnitPowerBarAlt.xml): native layout root and child ownership.
- [Content predicate](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_UnitFrame/Mainline/UnitPowerBarAlt.lua): `HasContentShowing` checks alternate power and widget content.
- [EncounterBar preview controls](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_EditMode/Shared/EditModeManager.lua): selected preview has minimum 230 by 30; unchecked root shrinks to 1 by 1.
- [Edit Mode system transaction](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua): highlighting shows Selection; clearing hides it; EncounterBar applies its saved anchor before native layout.

`tests/mainhand-placement.lua` reproduces the failed target repair before the
change and passes afterward. It covers Forever and Retail layout scopes, custom
system-relative anchors, unequal scale, repeated saved-row recovery, the widget
alias, settings/source preservation and a missing target without save.
`tests/encounter-recovery.lua` fails dormant-root detection before the change and
passes afterward. It covers visible preview, real content, after-close prompting,
reload state, a stale child alias and native Gamepad exclusion.

All 93 Lua suites and six path/XML/Lua 5.1 manifest checks pass in source.
These initial results are simulated and static. The screenshot's exact runtime
cause is not established without its diagnostics. Subsequent test10
[native QA](ENCOUNTERBAR-LIVE-QA-20261107.md) passes a physical mixed-height gap
fixture, selective save, reachable preview and repeated reload without another
prompt. Protected encounter actions and the reporter's exact layout remain open.

## Test7 candidate

The addon and Complete test7 ZIPs include test6 plus this correction. The Complete
archive retains the frozen public Beta 20 Companion. The package receipt and
source snapshot are under `dist/forever-discord-test7-20261107/`. Test6 remains
available for rollback. No public release, commit or Discord closure is implied.

For live acceptance, use the affected mixed-height span and keyboard HUD. Open
Edit Mode with Encounter Bar unchecked: an empty root should not prompt. Check
Encounter Bar and confirm a reachable preview is preserved. On the affected
custom layout, close Edit Mode, click Repair HUD once, reload, then reopen Edit
Mode and verify the bar stays inside Mainhand and no repair prompt repeats.
Confirm unrelated HUD adjustments remain intact. Exercise real encounter/widget
content and protected actions with a manual tester, recording the first fresh
error and `/offhand diag full` before further reloads. Repeat unspan/Restore and
native Gamepad exclusion separately.
