# Visual UI overhaul candidate

Current runtime checkpoint: `3fe93da` on `codex/addon-ui-overhaul`, draft PR #35,
based on the completed structural branch at `b7508d5`. The initial visual pass
was `e480af9`; subsequent increments harden its interaction lifecycle and improve
profile usability, translated text layout, and setup/calibration spacing. The visual work is a separate branch so
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
  capture buttons. Dialogs fit the game viewport when opened and refit after
  addon layout changes. Scale changes preserve the dialog's UIParent-space center.
- Localized navigation and section headings across all eleven locale dictionaries.

The settings canvas is 922 by 732 logical units. Its 662-unit content column
retains the existing card layouts rather than introducing an untested rewrite of
every control row. The sidebar occupies the additional width; fitting reduces the
whole dialog when the game viewport is smaller. It is not a fully fluid or
user-resizable layout.

## Interaction hardening

- Shared slider refresh synchronizes both the number and thumb from the current
  profile without invoking a setting setter or applying layout. A changed source
  cancels stale drag work; the next step starts from the refreshed value.
  Settings also refreshes the bottom-offset field without requiring hide/show.
- Bottom-offset Apply uses all eleven locale dictionaries. Its wider button
  stays within the existing column. The label wraps at a bounded width, action
  height follows button text, and the containing Settings/Calibration cards
  reserve the resulting row height. Offset calculations and explicit Apply,
  Enter, Escape, and one-pixel step actions are unchanged.
- Slider fields accept a decimal comma or dot in both Settings and Calibration.
  For example, `50,5%` no longer becomes `505%` and clamps to the maximum.
  Mixed or repeated separators are rejected and the current value is restored.
  Existing percentage interpretation, bounds, steps, and display format remain.
- Hiding a slider during a drag clears the update handler, cursor origin, and
  deferred-apply state. The last sampled setting is applied once; reopening the
  page cannot resume that old drag. Repeated hide or stale release does not
  double-apply a settings/scale drag.
- Wizard scale release commits its final native thumb value as well as the
  displayed number, matching the shared settings slider's release contract.
- Palette and custom-color text cues survive hover, press, disabled, and theme
  refresh transitions. Numeric focus borders use the selected accent.
- Legacy clients retain the non-color selection marker without requiring
  `SetColorTexture`.
- One addon-owned layout hook refits only registered, visible dialogs. It does
  not poll, alter native frame hooks, or rewrite unchanged scales. These contracts
  have simulated coverage; actual in-game positioning still needs acceptance.
- A geometry-locked seam slider now disables its separate value field and step
  buttons too, in both Settings and Calibration. Locking cancels pending drag
  work before releasing focus; late edits cannot commit a manual seam value.
  Returning to manual geometry restores the controls. This enforces the existing
  Companion-ownership policy and does not change workspace window locks.

## Boundaries and library decision

Calibration now stacks the introduction, progress indicator, active card,
validation message, and footer with measured spacing. Topology recommendations
and the final HUD readiness card expand to their text instead of retaining small
fixed text regions. Validation/layout-creation failures reflow the active page,
and longer footer labels reserve their full button height. The existing topology
checks, four/five-step selection, layout creation, completion, skip confirmation,
and reload workflow are unchanged. Repeated layout derives heights afresh.

Window Setup now derives its body, action-row, status, and window heights from
the current text. It reserves explicit gaps above the footer and between those
regions, refits to the viewport, and reflows when a status message changes.
Single actions are recentered after visiting the three-method page. This replaces
the fixed body/action bounds that could overlap in the original 430-unit dialog.
Page selection, setup-method writes, confirmation, reload, and completion rules
are unchanged. Tests cover all six pages and expanded status text.

Theme choices now use bounded two-column rows sized from the title and
description heights. Each following row clears the tallest item in the previous
row, and card stacking uses the resulting card height. Wrapped Help headings
also reserve space before their body text. Both paths share a text-measurement
helper with a conservative fallback when font metrics are unavailable. Tests
cover measured expansion and fallback layout for all eleven locale dictionaries;
this does not establish actual rendering in those locales.

The choice usability increment adds clickable radio labels, with disabled-state
guards for radio and checkbox label clicks. Disabled media-fit choices keep their
label and control state synchronized.

Profiles now use shared flat rows with a non-color selection marker, separate
name and active-state text, and full-name tooltips. Enter in the name field uses
the existing creation path; Escape only releases focus. New profiles are revealed
with minimal scrolling. List refresh clears stale selection and clamps the
scroll position when profiles are removed. Copy, delete, reset confirmation,
profile storage, and active-profile mutation rules are retained.

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
- Current audit ZIP SHA-256:
  `971F235A82C521C5569977ABCC2BCAFC156187E4A88AD125D9EB36EFC45267B0`.
- Retail and Forever Beta installs match the 70 copied package files. Their two
  generated topology/state bridge files were preserved and verified unchanged.
- Audit package, unpacked verification copy, and recoverable pre-update installs:
  `D:\Games\World of Warcraft\_offhand_deploy_backups\ui-overhaul-3fe93da`.

Earlier visual audit directories and their installed backups remain available
separately. The current pre-update backups contain `76f78d0`, the bottom-offset
presentation candidate, not the structural-only candidate.

Existing Beta 22 metadata was retained for local audit purposes only. The archive
is not a published release and must not be mistaken for the stable checkpoint.

## Remaining acceptance

### Source-readiness review

The current bounded UI source pass is ready for the combined manual smoke test
at runtime checkpoint `3fe93da`. A readiness recheck reran all 48 Lua suites,
six-manifest Lua 5.1 validation, Companion preference checks, and release-metadata
checks successfully. All 72 unpacked files still match source; both client
installs still match the 70 copied package files, and their generated bridges
match the preserved pre-update copies. No runtime code or install was changed
during this review.

The UI branch diff from structural checkpoint `b7508d5` is confined to UI,
locales, tests, and candidate documentation. Core modules, Companion artifacts,
TOCs, bindings, package script, and workflow definitions are unchanged by the
visual pass. GitHub confirms PR #34 remains a draft into `addon/develop` and
PR #35 remains a draft stacked on `codex/addon-architecture-refactor`.
The existing CI triggers do not include the stacked UI base, so local checks
must not be described as a GitHub CI pass for PR #35.

No additional implementation increment is identified for this candidate before
manual acceptance. This is not a claim that every fixed control row has become
fluid, all locale text has been visually accepted, performance has improved, or
all previously recorded defects are resolved. Native picker/menu replacement,
fully resizable layouts, profiling, bootstrap extraction, and the separately
recorded legacy `CloseAllWindows` scope issue are outside this UI pass.

Next, record the actual combined smoke results and address any candidate
regressions. Review integration and release promotion afterward as separate
actions. No merge, version bump, release, or assumed live pass is part of this
source-readiness checkpoint.

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

## User acceptance, 25 October 2026

The user considers the structural/UI refactor, first-time setup, HUD/window
restore/menu placement, Forever Gamepad, Bagnon, Party-frame recovery, Dialogue UI,
pet battles and recorded source defect fixed and resolved. Prior pending checklists
for this scope remain historical rather than new release blockers. No additional
live tests are implied. Linux/Wine is assumed fixed with direct reporter
verification outstanding. Performance investigation is the next active work.
