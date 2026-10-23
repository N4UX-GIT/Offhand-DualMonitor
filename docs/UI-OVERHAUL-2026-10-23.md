# Visual UI overhaul candidate

Runtime checkpoint: `e480af9` on `codex/addon-ui-overhaul`, based on the completed
structural branch at `b7508d5`. The visual work is a separate commit and branch so
it can be reviewed or rolled back without undoing the structural refactor.

## Implemented

- Five-page sidebar with a persistent, non-color-only selection marker.
- Per-page section shortcuts, ordered by the actual stacked cards. Long pages
  no longer require scrolling through unrelated controls to find a section.
- Independent session scroll positions for each page. Mouse-wheel scrolling and
  section jumps clamp to content and synchronize the native scrollbar range/value.
- A dedicated topology status row that measures wrapped text before positioning
  the setup actions and scrolling content below it.
- Flat, opaque settings surfaces with consistent borders, text fields, buttons,
  hover/press/disabled states, and accent selection. Existing workspace themes,
  trim preferences, and OLED background behaviour remain available.
- A consistent slider thumb and numeric field treatment. Narrow right-column
  sliders place their value controls beside the track, leaving room for titles.
  Existing drag, typed-entry, step-button, and release-commit behaviour is retained.
- Shared styling across settings, calibration, onboarding, and the focus-binding
  capture buttons. Dialogs fit the game viewport when opened, with scale-aware
  centering and a single-screen fallback.
- Localized navigation and section headings across all eleven locale dictionaries.

The settings canvas is 922 by 732 logical units. Its 662-unit content column
retains the existing card layouts rather than introducing an untested rewrite of
every control row. The sidebar occupies the additional width; fitting reduces the
whole dialog when the game viewport is smaller. It is not a fully fluid or
user-resizable layout.

## Boundaries and library decision

The shared control layer is sufficient for this candidate, so no dependency or
external library was added. Only explicitly opted-in addon UI uses the local
frame factory. The global factory and Blizzard frame artwork are not replaced.
Native checkbox/radio semantics, close buttons, color-picker dialogs, and
client-appropriate minimap menus remain native. Existing picker cancellation and
menu compatibility paths have not been rewritten for cosmetic consistency.

No core frame-ownership, polling, protected action, saved-variable schema,
Companion binary, TOC version, or release metadata changes are part of this pass.
Workspace themes still style the workspace; the settings shell deliberately uses
a consistent dark presentation with the selected accent and OLED treatment.

## Evidence

- All 48 Lua suites passed, including new presentation tests and expanded
  navigation/section/scroll-state regressions.
- All six TOCs passed paths, load order, XML, and Lua 5.1 syntax validation.
- Companion preference and release-metadata PowerShell checks passed.
- The frozen Companion SHA-256 remains
  `81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`.
- An isolated addon-only audit package passed. All 72 unpacked files matched
  source by SHA-256, and the unpacked addon passed validation.
- Audit ZIP SHA-256:
  `9921173BF779715E07B26B1167ACBA9340A1FE831AF2E2EF81A080899C7D27F6`.
- Retail and Forever Beta installs match the 70 copied package files. Their two
  generated topology/state bridge files were preserved and verified unchanged.
- Audit package, unpacked verification copy, and recoverable pre-update installs:
  `D:\Games\World of Warcraft\_offhand_deploy_backups\ui-overhaul-e480af9`.

Existing Beta 22 metadata was retained for local audit purposes only. The archive
is not a published release and must not be mistaken for the stable checkpoint.

## Remaining acceptance

No in-game visual, taint, or lifecycle pass is claimed for this candidate. Mocks
establish control contracts and calculated boundaries, not actual font rendering,
translated label clipping, client timing, or protected-action safety.

Use the [combined smoke checklist](REFACTOR-SMOKE-TEST.md) for both the structural
and visual candidates. Especially inspect text wrapping and slider/title spacing
at the UI scales you normally use, scrollbar dragging, native picker cancellation,
and wizard navigation. Any unavailable Forever cases must remain marked untested.
Do not merge or release on the basis of an assumed runtime pass.

Rollback requires restoring the pre-update addon files, not deleting SavedVariables.
The structural candidate remains independently reviewable in PR #34.
