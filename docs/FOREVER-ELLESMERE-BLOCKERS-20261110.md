# EllesmereUI transfer blockers, 2026-11-10

Candidate: `codex/eui-transfer-blockers`, based on `019110e`.
Target: Windows Forever 1.60.1.70862, Interface 16001, installed EUI 9.8.4.
The reporter's linked-anchor and override warnings were reviewed. Their exact
profile has not been obtained, so this does not establish their full root cause.

## Findings and implementation

The previous HasOverrides predicate treated empty tables as active overrides.
EUI lazily creates stores and nested layout tables. Empty stores and group
metadata without overridden values now pass. Real setting/layout override
data remains blocked both at preview and immediately before import: EUI partial
imports retain recipient override stores, which can reapply over the copied
positions later. The check now also covers unlock-layout, buff/debuff-manager
and override-anchor stores found in the installed vendor importer.

The old linked warning combined several unrelated cases. Rows now distinguish:

- The named parent that owns an element's position, including parents outside
  Offhand's supported transfer mappings.
- Movement with a named parent that the preview can transfer.
- Missing position/size, or the named linked member that cannot be measured.
- Circular, invalid or excessively long anchor chains.
- A linked group too large to fit inside Mainhand.

The planner keeps measurable supported groups together and never removes links
or saves a separate child position. Unsupported/unresolved groups remain under
EUI ownership. Preview opening does not edit profile overrides or anchor links.

The preview has a dedicated full-width explanation area, row tooltips with
actionable steps, and counts for partially transferable layouts. Profile
override guidance points to EUI Profiles & Presets and a separate profile
without overrides. The import control remains disabled when globally blocked.
Rows have bounded text height; full details remain available in tooltips.
All 11 locale dictionaries have matching keys and format arguments. New text
is translated for German, French, Italian and both Spanish locales; the other
existing experimental transfer dictionaries retain English fallback text.

## Validation

The new production-module fixture fails against the previous source on empty
override stores. The candidate passes all 124 Lua suites. Coverage includes
empty/nested stores, harmless group metadata, real override data including false
setting values, import-time rechecks, refreshed blockers, missing group members,
cycles, oversized groups, named parents, linked movement and UI help/disable
state. All six manifests, 81 Lua files and runtime XML references pass static
path and Lua 5.1 syntax checks.

Native QA used the existing idle character with the single-display 32:9 span
applied, Mainhand right and workspace left. The real preview rendered without
an override block. Its profile's inspected override stores were absent, so the
empty-table false blocker was reproduced by the regression fixture, not by
claiming it occurred on this native profile. Controlled presentation fixtures
verified all five failure messages, the named-parent tooltip, wrapped override
guidance and disabled import control. No profile was imported during this pass.
No visible Lua-error dialog appeared; a fresh BugGrabber comparison was not
available. No combat/taint, physical mixed-display or reporter-profile test ran.
Daylight testing remains deferred.

## Source provenance and cleanup

Shared knowledge status/search were consulted first; search reported a stale
index. Its pinned Forever build 70532 is older than the native target. Installed
vendor source and local production code were inspected instead. Key vendor
SHA256 identities:

- EUI_UnlockMode_Anchors.lua: `e339999f7481698bb8fefca536bbde291f4c900b100cefc86b8f925b82ce3aa3`
- EllesmereUI_Profiles.lua: `fbf06fcc82f00d77d5ecd17e7ea75064aa96a4d394ccf2560c669858d9c3f203`
- EUI_SpecOverrides_Harvest.lua: `5062224909d32287b628deef1206c0153c6e0b89f76f24601dbc2bc6bc227a54`

Private helper, backups, captures and test logs remain in ignored
`dist/eui-blockers-20261110/`. Forever closed normally. All 253 pre-existing
WTF/installed-addon files were restored and hash-verified; eight new WTF files
were archived and the helper runtime files removed. Two new Questie.lua files
from this pass were retained separately to preserve the user's requested
Questie Objectives choice. Their variable names are QuestieConfig and
QuestieConfigCharacter, which must not be mistaken for filenames. Privacy
settings remain at the baseline. Final verification covers 255 files.
Battle.net and Companion remain open. No Discord messages/statuses changed.

No release assets or Companion binaries changed. The prepared Beta 29 ZIP
remains SHA256 `004be4e1fe35dba3bc55f6579ba7d6aa5f5676328fe9c495305f18bbdba9694e`.
