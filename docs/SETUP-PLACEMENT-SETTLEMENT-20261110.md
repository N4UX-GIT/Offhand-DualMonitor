# Setup placement remains disabled after a standard span

Evidence date: 2026-11-10. Source correction, native acceptance pending.

## Reporter evidence

The first screenshot shows placement task 4, step 1, with Window is positioned
and Confirm placement disabled. Its status says geometry is still settling.
The illustration is explicitly an example, not proof of detected display bounds.

The follow-up screenshot shows Companion 2.1.6, both displays checked,
Display 1 (2560x1600, primary) as Mainhand and Display 2 (1080x1920) as workspace.
Single-display split is unchecked. Game side Left is a single-display control
and does not determine roles in this standard two-display layout. The exact
Windows arrangement/offsets and target client/build are not supplied.

The owner relays that Restore Window followed by Span WoW Now allowed the user
to proceed. This is reporter-relayed recovery, not agent-observed reproduction
or acceptance of the source correction. The settings shown are a supported
unequal-height landscape/portrait pair; no Windows realignment is indicated.

## Reproduced source defect

Core/Init.lua sets _displayGeometryTransitionActive on DISPLAY_SIZE_CHANGED or
UI_SCALE_CHANGED, then clears it after the newest 0.75-second debounced layout
pass (or after queued work runs out of combat). The guide handles the initial
event while that flag is true, disables its actions and displays the waiting
message. Its delayed callbacks only recenter the guide. They do not recompute
placement readiness. Core previously did not notify the guide on completion.

Thus the transition can be complete while the visible buttons and waiting text
remain stale until another event or reopening refreshes them. The reported
Restore/Span recovery is consistent with this defect but does not establish
the exact initial event ordering or exclude another reporter-specific issue.

A regression using production core and guide handlers failed before the change:
the core flag became false, but Window is positioned remained disabled after
both guide recenter timers ran. This establishes a simulated UI lifecycle defect,
not a native failure in the reporter's Companion executable.

## Correction

After the newest geometry generation clears its transition flag, Core notifies
Onboarding:RefreshDisplayState. That method updates readiness and placement text
and recenters only an already-visible guide. It does not create or reopen one.
Stale/superseded timers cannot issue the completion refresh. Combat-queued work
notifies only after its generation actually completes, regardless of event order.

No timer, polling loop, topology override or automatic acknowledgement was added.
Window mode, transition, combat, matching geometry, reload checkpoint, signature
and final confirmation checks retain their existing decisions. Restore does not
allow confirmation of mismatched topology. Respan re-enables the acknowledgement
action after settlement but still requires the reload/confirmation sequence.

## Validation and delivery boundary

- All 123 root Lua suites passed under Lua 5.1 with the runtime correction.
- The expanded wizard regression also passes with 2560x1600/1080x1920 geometry,
  representative top-aligned portrait-left/right positions, both event orderings,
  normal and combat-deferred settlement, Restore/Span and a hidden guide.
  The representative coordinates are synthetic, not inferred from the screenshot.
- Lifecycle regressions verify exactly one guide refresh after the current
  generation clears the transition flag, and none from stale queued/timer work.
- All six manifests pass Lua 5.1 syntax, runtime path and XML-reference validation.
- Targeted whitespace checks passed. No new localized text is required.

Changes are in the mutable addon source and tests, preserving unrelated pending
work. No client was launched, installation changed, or artifact rebuilt/released.
The separately frozen Beta 29 release subject is not changed by these edits.
The reporter's completed retry is not acceptance of this uninstalled correction.

## Existing-build recovery

The reporter's Restore Window, then Span WoW Now sequence succeeded. If a settled
window retains this stale guide state, closing the guide and reopening it with
/offhand guide reruns the existing readiness refresh. Continue with Window is
positioned, Reload UI and Confirm placement. If reopening still shows settling,
capture /offhand diag full and fresh Lua errors before assuming the same cause.
