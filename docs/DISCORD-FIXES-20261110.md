# Discord report implementations, 10 November 2026

Source candidate on the existing shared checkout. This follows
[the complete read-only report review](DISCORD-REPORT-REVIEW-20261109.md).
No Discord changes, deployment, vendor installation or public release.

The subsequent [visual evidence audit](DISCORD-VISUAL-REVIEW-20261110.md) covers
all forum-linked images/videos and selected original follow-ups. It adds no
runtime patch or acceptance claim, and keeps the keyboard map-growth, minimap
relocation, visibility and native HUD-save reports separate.

## OH-UI-031: Remaining loot rows and screen-edge placement

Two source defects are corrected in `Core/HUDTransientFrames.lua`:

- Native roll removal leaves sparse array slots. The previous baseline scale
  came only from slot 1, falling back to 1 when that roll disappeared. At a
  different row scale this moved the entire remaining stack. The baseline now
  comes from the first remaining native entry.
- Empty slots no longer consume visual spacing. Remaining rolls keep their
  relative order and compact toward the saved first-roll position. The complete
  stack is constrained to Mainhand in both upward/downward directions when it
  fits, including horizontal margins. Saved positions and row sizes are retained.

Unchanged row and secure-container points are no longer rewritten during
maintenance. This reduces proven redundant frame writes, not a measured GPU
utilization claim. The native update post-hook still repairs native resets.
Custom/protected anchors retain the existing yield behavior. No roll IDs,
choices, timers, visibility or parent relationships are changed.

Regression evidence: after removal of the first row, the scaled remaining row
previously received local Y 592 instead of 442 in the production integration
fixture. The revised case passes. Complete stacks at the top-right and
bottom-left fit without altering the saved anchor; native visibility and idle
write counts are checked too. These explain reproducible placement faults but
do not prove that every disappearing-roll report has the same cause.

## OH-UI-031: Mainhand item tooltips and long cards

`Core/PopupBounds.lua` previously applied modern native clamp bounds to world
tooltips, while ordinary Mainhand item owners retained full-span bounds.
On a short Mainhand inside a taller span, that allowed a loot tooltip to extend
into invisible space. Ordinary Mainhand owners now receive physical Mainhand
clamp bounds; workspace owners receive their own physical workspace bounds.
Owner and anchor graphs remain native.

If a known native tooltip card exceeds its destination, temporary proportional
scaling fits its width and height. Only GameTooltip, ItemRefTooltip and known
shopping cards are eligible. Smaller subsequent content and hiding restore the
original scale while still owned. Reentrant size notifications are guarded;
unchanged cards do not generate scale writes. Another scale writer yields
ownership until the next hover. Embedded/forbidden/protected frames, known
tooltip replacements and combat-time mutations remain excluded.

The new production fixture rejects the previous Mainhand behavior. It covers
tall content, content shrinking, hide restoration, external scaling, disabled
state and combat. Classic native-scale and comparison/popup suites still pass.
No font, item text, comparison topology or vendor SavedVariables are changed.

## OH-UI-032: Optional ProcDoc Mainhand center

New `Core/ProcDocCompatibility.lua` is included in all six manifests. Settings
contains **Center ProcDoc alerts on Mainhand** in the persistence card. It is off
by default and translated in all eleven locales.

When enabled and spanned, the adapter translates the public ProcDocAlertFrame's
single native CENTER point from full-window center to Mainhand center, retaining
ProcDoc's own X/Y offsets in the correct frame units. It observes the vendor's
public ApplyCenter method when available, so vendor offset changes remain
relative to Mainhand. A center-only root without that method can still use the
capability-detected path. The pinned author source reviewed is ProcDoc 4.13.0,
commit e0ba2c8a043245473393ba56fcccccb06c9b57e2; older binaries were not installed
or natively verified.

Turning the option or Offhand off, or restoring the window, releases the
still-owned anchor to the latest vendor placement. Failed release retains state
for retry; combat defers until PLAYER_REGEN_ENABLED. A different mover/parent,
protected root or unsupported anchor yields. Vendor files and saved settings,
alerts, visibility and scales are untouched. There is no extra polling ticker
or native Edit Mode hook. Full compatibility diagnostics include ProcDocCenter.

Tests cover opt-in/default behavior, effective-scale conversion, unchanged
refreshes, vendor updates, disable/unspan, failed restoration retry, combat,
external ownership, forbidden/protected roots and malformed opt-in values.

## Validation and remaining evidence

All 120 root Lua suites pass. Six manifests validate 81 runtime files (80 Lua,
one XML) with Lua 5.1 syntax checks. Native WoW appearance, item actions, taint,
actual multi-roll timing and settings layout have not been tested in this run.
No candidate was installed or published.

Native acceptance order:

The new reporter diagnostic identifies Forever 70862 / beta28, a short
1920x1080 Mainhand beside a tall 1080x1920 portrait workspace, with combat active.
This narrows OH-UI-031's client/topology gap. It does not identify the failing
item/roll, input mode or tooltip replacement. Prioritize the short-display fit
and deferred combat-restoration paths; a synthetic preview does not establish
real roll lifecycle or combat acceptance. Exact fields and image provenance are
in the updated [report review](DISCORD-REPORT-REVIEW-20261109.md).

1. Forever 1.60.1.70862, keyboard: three simultaneous rolls, remove the first
   and a middle row, both stack directions near display edges, then combat,
   completion and reload. Check actual remaining choices and fresh errors.
2. Long set-item tooltip and comparisons on short Mainhand/tall workspace and
   a stacked layout. Reuse a tooltip for a shorter item, hide/reopen, disable,
   and repeat with the player's tooltip replacement. Verify native anchoring,
   readability, restoration and actual item interaction. Repeat affected Retail.
3. ProcDoc: default off, enable centering, adjust its own offsets, change profile,
   restore/span, reload, toggle Offhand and enter/leave combat. Confirm the vendor
   profile is unchanged and another mover takes precedence. Test the localized
   checkbox and compatibility text in the native settings panel.
4. Prior Retail friendly-name correction, detached minimap ownership and exact
   BetterBags/RestedXP recurrence retain their existing acceptance checklists.

OH-UI-030 combat-window shifts, OH-UI-033 contradictory-client viewport offset,
OH-UI-034 serialized HUD persistence and OH-PERF-002 GPU saturation remain open
investigations. Their source review did not identify a safe attributable repair;
the exact captures listed in the previous review are still needed. Existing
chat, controller, cutscene, DPI and recovery solutions remain intact. Daylight
native testing remains deferred as requested.

Follow-up: the frozen private bundle now passes 121 Lua suites and was installed
with user approval and a complete addon-folder backup. Forever 70862 passed
limited unspanned load/options/reload smoke checks. Spanning was paused because
the current window mismatches saved topology; report-specific native acceptance
remains pending. Exact hashes, captures, commands and cleanup:
[Private candidate native QA](DISCORD-NATIVE-QA-20261110.md).

Second pass applied actual single-display spanning on Forever 70862 with READY
topology and a verified 1280x1440 game viewport in the right half of 2560x1440.
Native, SexyMap and EUI Minimap were tested separately. Panel closures retained
visibility; SexyMap's own drag and EUI's center/save control retained seam
placement through reload. Native anchors match across reloads. Native/EUI drag,
affected profiles, physical multi-monitor and combat acceptance remain open.
Profiles/enable flags restored, client closed, helpers disabled. Exact results:
[Spanned minimap QA](DISCORD-SPANNED-QA-20261110.md).

Further spanned QA found the Init tooltip normalizer undoing PopupBounds' fit.
The normalizer now respects active/completed fit ownership and yielded scale
owners. The integrated callback regression fails before and passes after the
fix; all 121 frozen suites and six-manifest validation pass. A backed-up private
follow-up passed synthetic native tall/short/hide checks on Forever 70862.
Native minimap keyboard Save/reload also retained exact saved anchors; the test
movement was reversed. Real-item/roll, combat and affected-profile gates remain.
[Follow-up results and artifact provenance](DISCORD-FOLLOWUP-QA-20261110.md).

Continued spanned native QA retained Chat/Buffs/Action Bar 3 saved anchors through
reload, verified both Game Menu opening paths, preserved contained Cooldown
Settings placement and exercised deliberate seam recovery. Cached Worn Mace and
synthetic tall/short tooltip checks passed their bounded cases. No further
runtime defect was reproduced. The new combat-active 1080-high loot diagnostic
is recorded separately; real rolls/items and the affected topology remain open.
Temporary settings/helpers restored and client closed. Daylight stays deferred.
[Remaining-report QA and limits](DISCORD-REMAINING-QA-20261110.md).

Stock-chat/backpack continuation reproduced two Forever combined-bag defects:
Chat Settings retired saved workspace open intent, and native X closure lost
mouse focus before Offhand classified it. The existing panel list now includes
ChatConfigFrame; a guarded read-only IsMouseOver fallback recognizes explicit
X closure. Final spanned Forever 70862 checks pass restoration at the same
geometry and closed-state reload. All 121 frozen suites and manifests pass.
Stock chat overlap was not reproduced. Separate/replacement bags, Retail,
physical drag, old profiles and combat remain open; Daylight stays deferred.
[Native comparison, cleanup and package hashes](FOREVER-CHAT-BACKPACK-QA-20261110.md).
