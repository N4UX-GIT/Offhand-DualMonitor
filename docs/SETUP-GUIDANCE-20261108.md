# Clearer setup actions and guarded placement, 2026-11-08

Status: source candidate. Automated acceptance only; not packaged, installed,
live visually verified or published during this investigation. Native Companion
artifacts are unchanged. This checkout retains other pending investigations.

## Report and resulting flow

Users found the preparation guide and calibration wizard unclear about the next
button. Guide placement previously offered Reload UI and Confirm placement at
once, with no proof that the reload happened. Manual/FancyZones confirmation
could also occur before a reload. A geometry check alone cannot prove that a
new UI session has loaded the span data.

The guide keeps existing saved page IDs and five visible tasks. Placement task
4 now has three sequential substeps:

1. Position WoW using the selected method, then click Window is positioned.
   Companion instructions explicitly name Span WoW Now. WoW itself cannot
   reliably prove physical display coverage for manual/FancyZones windows;
   this first action is an honest player acknowledgement.
2. Click Reload UI. Confirm placement is disabled until the checkpoint is seen
   in a new Lua/UI session. Clicking Reload UI cannot unlock it in the current
   session. The guide resumes task 4 without marking setup complete.
3. Review the reloaded placement and click Confirm placement. A confirmation
   dialog asks whether the intended displays/ultrawide region and game area are
   visible. Acceptance rechecks geometry, setup method, current stage, combat,
   guide visibility and page visit. Manual placement uses the fresh preview.
   Only a successful review unlocks the calibration handoff.

A missing or mismatched Companion topology keeps the confirmation unavailable
and presents the existing readiness reason. Changed method/canvas dimensions
invalidate the checkpoint. Changing methods through the guide resets the old
workflow while preserving calibration values. A guide reload clears an obsolete
wizard recovery request so that it cannot skip the placement review.

## Recommended action

Shared addon-owned button styling now supports an accent border/text and visible
edge mark for the recommended action. Guide refresh selects one enabled next
action, including the current placement substep. If Windowed mode is lost, Back
is recommended to return to that preparation task. Calibration highlights Apply
recommendations on discovery, then its Next/Finish/recovery action on later steps.
Its progress area also says Next: followed by the exact button label. Buttons
remain usable through their existing input paths; no animated pulse or native
frame hooks were added.

All 11 locales have translated stage copy and the next-action caption. Stage
instructions insert the actual localized button labels rather than separately
translating a button name. Existing paragraph and dialog fitting measures the
new content and expanded progress caption.

## Persistence and validation boundaries

Core/SetupPlacement.lua owns the small state machine. The checkpoint is a
versioned string V1|METHOD|PHYSICAL_WIDTH|PHYSICAL_HEIGHT|R_OR_C. R records a reload
request and C records accepted placement review. A session-local issued value
prevents an R written now from counting as a completed reload now. A cold login
also creates a fresh UI context and can resume an outstanding review.

Core/Config.lua stores it in per-character placementCheckpoint and, on Forever,
the existing-style registered offhandPlacementCheckpoint CVar fallback. Normal
clients use SavedVariables only. The prior onboarding CVar format is unchanged.
Unknown records fail closed. No native window operation, protected Blizzard root,
world interaction, credential or native Companion artifact is part of this code.

Automated matrix:

- Actual guide callbacks: span acknowledgement, reload request, locked same-session
  confirmation, resumed review, final Companion/manual dialogs and calibration
  handoff. Existing Back, settings detours and later wizard reload paths retained.
- Modal races: page navigation, display transition, physical resize and entering
  combat cannot accept a stale placement snapshot.
- Actual Config persistence: ordinary SavedVariables on Retail/Classic/Wrath and
  Forever fallback with normal SavedVariables removed; reset, unknown schema,
  changed method and changed canvas dimensions.
- All 11 dictionaries: stage instructions name the displayed button, recommend
  the right enabled action, and modeled guide/wizard bounds do not overlap.
- All 102 standalone Lua suites pass. All six manifests pass Lua 5.1 syntax,
  runtime paths and XML references. Logs: dist/setup-flow-20261108/suite-results.json.

These are source and synthetic frame tests, not native rendering, CVar persistence
or reload acceptance. Target Forever reference is 1.60.1.70862; report only names
Beta 27 and does not establish the reporters' client build. The shared KB first-line
onboarding query supplied supporting local guidance; cached Forever declarations
are 70532/review-due, not a runtime acceptance claim for 70862.

Pending live matrix: fresh and resumed Companion, manual and FancyZones flows;
real UI reload and cold login; Restore Window/span and missing topology; combat
button disabling; final dialog cancellation and stale acceptance; supported UI
scales and translated text; controller/keyboard focus if used. Packaging must
preserve public Beta 27 WorkspaceRegions integration already absent from this
older branch. Public README/website/store instructions and screenshots need to
be reconciled with the accepted candidate during release promotion; existing
manual-reload-is-optional copy describes the older flow.
