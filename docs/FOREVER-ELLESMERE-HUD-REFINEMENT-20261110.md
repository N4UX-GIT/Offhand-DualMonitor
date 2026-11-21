# EllesmereUI HUD refinement, 10 November 2026

Candidate branch: `codex/eui-hud-layout-refinement`, based on release preparation
commit `e46ff590a1c41407be4ce69d3bae081734c48ff1`. These changes are separate
from the frozen Beta 29 package and draft release.

## Findings and behavior

The old preview accounted for twelve elements: the main bar, seven extra
action bars, minimap, and player/target/focus. The reported cooldown movers
and Resource Bars cast bar were absent. The preview now includes registered
CDM roots, Resource Bars cast bar, stance/pet bars, supplemental unit frames,
and current-spec tracking bars with inspected position stores. Pages of
twelve keep the diagrams and selection controls readable. Selection and
apply operate across all pages.

Missing mandatory elements report the actual module or required dependency
to install/enable, whether a reload is needed, or whether a loaded provider
needs its configuration checked. No addon is automatically enabled. New
messages exist in all eleven dictionaries.

Fit only changes groups outside Mainhand. New EUI-only placements use an
eight-unit inset to avoid pixel snapping back across the seam. Copy mode
projects EUI-only elements into Mainhand when they lack a native counterpart,
preserves groups and leaves already-fitting roots unchanged. Native fallback
still requires a verified native counterpart.

Imports use EllesmereUI's normal interactive review and a new named profile.
The active profile is not written by preview. Tracking-bar imports include a
full copy of only the affected spec bucket because the vendor importer
replaces incoming spec buckets. Spell assignments, other positions and
unrelated spec settings are preserved; grouped bars share the saved origin.
A spec switch invalidates the pending plan. No vendor source was modified.

## Evidence and validation

Target: Forever 1.60.1.70862, EllesmereUI 9.8.4, Companion 2.1.6 already
installed by the user. Single 2560x1440 display split with Mainhand right and
workspace left. Spanning was explicitly applied for both native runs.

Live observations:

- Regenerating the HUD with the existing Beta 29 generator changes the old
  XP anchors and places visible XP above the main bar. This did not require
  an additional generator patch. XP eligibility/visibility and customized
  source positions are not forced or reset.
- The expanded preview displayed 23 available rows over two pages.
- CDM buffs, cooldowns and utility were offered moves from the seam. The
  interactive import included their module and survived reload.
- An initial exact-boundary placement exposed rounding on cast/pet/stance
  movers. After the inset adjustment and another reviewed import/reload,
  all those rows reported already fitting Mainhand. Repeating fit offered
  no changes. Anchored target/focus cast bars continued to yield.
- The helper reported four existing BugGrabber records before and after
  these imports; historical records are not new failures from this test.
- With Action Bars, Minimap and Unit Frames disabled, the preview named each
  module and displayed the instruction to enable it in AddOns and reload.
  Native testing exposed a Forever incarnation-name mismatch: the explicit
  UnitName enable-state lookup returned 2 while the default-scope lookup
  returned 0 and the loader reported DISABLED. Diagnostics now use the loader
  reason and default scope. The corrected guidance was reloaded and checked.

Automated: all 123 Lua suites passed, including dependency states, pagination
selection, cooldown/cast mappings, empty-root anchor resolution, complete
tracking groups, full-spec preservation, stale-spec rejection, and repeated
copy behavior. All six manifests and 81 runtime Lua files passed syntax and
reference validation.

Current-spec tracking-bar import is source-reviewed and simulated. This
character has no configured tracking bar, so native tracking-bar import,
global tracking groups (`TBBG_`), spec transitions, populated cooldown growth,
and combat/taint behavior are not established by this run. Global tracking
groups are not transferred. Other EUI modules outside the inspected mappings
remain outside this candidate's scope. Daylight was not tested.

## Source provenance

Shared knowledge was consulted first. Its Forever declaration snapshot is
1.60.1.70532 at `ca8368f2f2380cbe696854f7f2646387c278a61b`; this is older than
the runtime target. Full-text search reported a stale index. Structured
lookups for `C_AddOns.GetAddOnDependencies`, `GetAddOnEnableState` and Edit
Mode cooldown/status enums were used only as declaration evidence.

Installed EUI source is authoritative for its profile schemas. Inspected:
`EllesmereUI_Profiles.lua` (SnapshotAllAddons, BuildImportedCDMSpellBucket),
`EUI_CDM_Lifecycle.lua`, `EUI_CDM_Spec.lua`, `EUI_CDM_BuffBarUnlock.lua`,
`EUI_ResourceBars_Anchors.lua`, and unit/action-bar position providers.
Exact hashes, private SavedVariables captures and baseline backups are in
ignored `dist/eui-layout-20261110/`. No account data is included here.
The shared finding is
`wow-addon-knowledge/knowledge/offhand-ellesmere-hud-transfer-20261110.md`.

The prepared addon ZIP remains SHA256
`004be4e1fe35dba3bc55f6579ba7d6aa5f5676328fe9c495305f18bbdba9694e`.
No release artifacts, Companion binaries or publication records were changed.

Cleanup: the target client was closed normally. All 251 pre-existing WTF and
installed Offhand files, including addon flags, profiles, Config.wtf and
generated bridges, were restored and SHA256 verified. Two new private QA
SavedVariables files were archived locally and the helper was removed.
Battle.net and the user's Companion were left open. No Discord messages or
statuses were changed.
