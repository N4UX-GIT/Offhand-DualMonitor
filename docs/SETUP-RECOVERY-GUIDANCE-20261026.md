# Setup recovery guidance after the Beta 23 Discord report

## Report and scope

User report: addon Beta 23 and Companion Beta 20. At the final calibration step,
HUD creation failed because a span was unconfirmed. The user ran diagnostics,
expecting a repair; reloading resolved the missing geometry. The next attempt hit
Blizzard's custom Edit Mode layout capacity. The user needed help finding Edit
Mode and the layout dropdown. These are two separate recoverable setup blockers.

Candidate branch: `codex/setup-recovery-guidance`, based on `addon/develop`.
No Companion, bridge protocol, layout capacity, automatic deletion or release
metadata changes. Existing unrelated checkout work is excluded.

## Behavior

- Direct wizard entry and each forward/finish action require a confirmed span.
  Companion-selected setup additionally requires its loaded exact topology.
  Confirmed FancyZones/manual canvases can still override an old bridge.
- Missing/mismatched placement replaces the calibration card with instructions
  and explicit Reload UI / Return to window setup actions. It hides normal Next,
  Back and HUD-skip controls until placement is ready. Reload is blocked in combat.
- A reload stores only the current step in character SavedVariables and uses the
  existing guide login handoff. Reopening consumes the marker, revalidates placement
  and resumes that step. A second failed reload remains actionable, without
  pretending the geometry is ready or automatically finishing setup.
- Companion placement guidance explains that maximizing normally fills one monitor
  and does not replace Span WoW Now followed by Reload UI.
- The layout-capacity failure becomes an instructional card: open Blizzard Edit
  Mode, locate its layout dropdown, export an unused custom layout if wanted,
  delete only that unwanted layout, then close Edit Mode and retry HUD creation.
  No fixed layout count is stated. Offhand does not delete or retry automatically.
- Open Blizzard Edit Mode is a hardware-click path using Blizzard's own
  `ShowUIPanel(EditModeManagerFrame)` entry, with capability and combat guards.
  An addon-owned observer checks visibility only while this handoff is active and
  resumes HUD setup after closure. Repeated visits reuse the observer. Explicit
  guide/wizard navigation cancels the return. No native fields/scripts/hooks are
  installed. Unsupported opening offers the manual Escape > Edit Mode path.
- Recovery cards measure wrapped title/body/footer text and use existing dialog
  fitting. All 11 locale dictionaries contain the new keys; non-English recovery
  additions are explicitly English fallback pending translation.

## Validation

All 55 Lua suites pass in the isolated checkout. Six manifests, referenced XML
and 62 runtime Lua files pass Lua 5.1 validation. `git diff --check` passes.

Regression coverage includes direct entry without geometry, no HUD generation
before placement, combat reload prevention, persisted same-step handoff,
repeated failed reload, loaded-geometry resumption, guide return, full-list action,
combat Edit Mode prevention, native opening/closure, observer cancellation and
the absence of addon hooks/fields on the native manager. Existing manual-canvas
and Companion-version mismatch checks remain covered.

The Blizzard game menu uses the same native entry:
https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GameMenu/Shared/GameMenuFrame.lua

## Pending live acceptance

The candidate is installed for Anniversary testing and remains unreleased.
The user confirmed the missing-geometry recovery screen and span/reload handoff.
Retail and the remaining native acceptance checks are still pending. Before
recording the installation video, verify with Companion Beta 20:

1. Open `/offhand wizard` before spanning/reloading. Confirm the placement recovery
   card appears immediately, including when opening HUD setup directly.
2. Span in Companion, use the card's Reload UI button and confirm the same wizard
   step resumes with loaded geometry. Reloading without spanning must keep the
   recovery screen rather than permit HUD creation.
3. Check Return to window setup and the clarified maximizing/spanning instruction.
4. On a test account/profile already at its native custom-layout capacity, attempt
   HUD creation. Confirm the layout-management card appears without clipped text.
   Do not delete a valued layout merely to create this test condition.
5. Open Blizzard Edit Mode, use the native dropdown to remove only an unwanted
   test layout, close Edit Mode and confirm step 5 resumes. Retry HUD creation and
   follow its normal reload prompt. No changes should occur merely from returning.
6. Check combat guards, unavailable/locked Edit Mode fallback, reopening/closing
   the wizard, reload persistence, and the first relevant BugSack/taint result.

Other clients retain capability-based paths, but native Edit Mode execution and
visual/taint safety require their relevant live coverage before a release claim.

## Wizard centering follow-up, 2026-10-27

Anniversary testing exposed wizard position drift when Companion spans or
restores the client while calibration is open. The wizard previously centered
only when opened, so its old absolute anchor survived changes to the canvas.

The wizard now recomputes its center on show, display-size and UI-scale events.
It uses accepted Mainhand geometry when spanned and the current client center
when restored. Two generation-guarded callbacks allow geometry to settle after
the existing display debounce. Hiding cancels pending work. No continuous
polling or native frame changes were added; calibration/recovery state is kept.

All 55 Lua suites and six manifest validations pass. Regression coverage checks
repeated span/restore without accumulating offsets, local fitting scale, delayed
geometry acceptance, cancellation of stale/hidden callbacks and unchanged task
state. Native visual acceptance remains pending: keep the wizard open through
Span WoW Now, Restore Window and a repeated cycle, then verify centering after
Reload UI as well.
