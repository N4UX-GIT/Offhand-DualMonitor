# Diagnostics and native snapping QA

2026-11-10. Owner-authorized WoW test-harness run on Forever 1.60.1 build 70862,
interface 16001. Source branch: addon/forever/gamepad-reports-20261105.

## Subject and scope

The skill diagnostics collector and Computer Use handled the existing launcher,
Companion and preselected idle level-2 test shaman. No credentials, public chat,
movement, targeting, casts, NPC interaction or combat were automated. A delayed
second launch reached a reconnect/login prompt and was closed normally; only
the authenticated client entered the test character.

Companion 2.1.6 applied its existing single-display split: 2560x1440 physical
canvas, right 1280x1440 Mainhand, left workspace. Topology READY and viewport
PASS. This does not reproduce the reporter's stacked 3440x2640 arrangement or
effective scale .355. Native tests used effective scale about .434 after span.
Existing Questie/QuestTrace startup was present; this is not an all-addons-off
claim. Known HUD/tooltip replacement flags were captured privately.

Only the diagnostics command block in installed Init.lua, CanvasChat.lua, and
the optional diagnostic snapshot storage change in Viewport.lua were overlaid.
Other installed modules remained on the private baseline. In particular, the
newer NativeFit diagnostic provider from MainhandEditMode.lua was not installed
again; this run accepts routing/output behavior, not every pending workspace
provider change. A private addon-owned observer captured addon output and
native layout/settings data without capturing chat contents. Its controls were
removed by restoring the original helper and disabled TOC.

## Diagnostics results

| Report | Native lines | Result |
| --- | ---: | --- |
| `diag` | 12 | Compact context retained. |
| `diag full` | 18 | Core support context, relevant chat and hidden-window count. |
| `diag chat` | 22 | All ten existing chat windows, including inactive extras. |
| `diag tooltip` | 16 | Tooltip/backdrop state, without arming capture. |
| `diag panels` | 36 | Panel/interaction state, absent roots counted. |
| `diag debug` | 86 | Raw probes retained, without arming capture. |
| `diag tooltip capture` | 17 | Explicit armed confirmation, then one hover capture. |
| `diag invalid` | 1 | Usage only. |

Counts are logical printed lines in this configuration; native chat wrapping
depends on width, scale, locale and optional modules. The UI visibly displayed
the report output, and the observer retained the complete formatted lines.

All report calls returned successfully and preserved native layouts, account
settings and character state. An actual cached Bent Staff hyperlink and native
comparison manager were used for tooltip checks. A hover after ordinary reports
produced no captured presentation output. An explicitly armed hover produced
exactly one five-frame presentation report, including shown GameTooltip and
ShoppingTooltip1. The following OnEnter/click callbacks did not repeat it.
The existing 30-second timeout and combat refusal were not newly exercised
under actual lockdown in this run.

Two native QA findings were corrected and retested:

- Unescaped pipe separators in the invalid-mode hint disappear in WoW chat.
  The hint now uses commas and is visibly readable in-game.
- CaptureDiagnostics previously stored lastGeometryCheck even for a support
  readout. Diagnostic commands now pass false to an optional storage parameter.
  The final full report leaves the complete saved profile unchanged. Existing
  callers retain the default validation-recording behavior. Regression tests
  cover both paths.

## Snap to Elements findings

A temporary Character layout copied the active custom layout. Both original
custom rows compare unchanged throughout every retained snapshot. Initial
mouse drags selected chat but did not reliably move it through Computer Use;
they are not accepted as drag/magnetism reproduction evidence.

An explicit private control invoked the exact-build native SnapToFrame path
on ChatFrame1 with MainActionBar as its target, only while the temporary layout
and Edit Mode were active. This is a controlled native mechanism test, not
proof of the reporter's mouse-drag sequence.

The native anchor was BOTTOMLEFT to MainActionBar TOPLEFT with offsets 42/46.
Chat remained at approximately (1798.129,93.000) UI units through Save, exit
and reopening, with snapTarget=MainActionBar. No offscreen jump occurred.

The native Snap to Elements checkbox was then cleared. Diagnostics correctly
reported SnapToElements=no while the MainActionBar link and anchor remained.
Selecting chat and pressing Right once through native Edit Mode cleared the
link and stored TOPLEFT relative to UIParent. The resulting position near
(1799.129,93.000) survived Save, exit and reload.

This natively confirms that disabling snapping alone does not detach an existing
link. It supports the existing workaround: turn off snapping, actually reposition
chat, then Save. It does not establish the reporter's offending target, a scale
conversion defect, or the writer causing the reported large displacement.
Automatic setup-only suppression remains unimplemented: it cannot repair saved
links and would not cover ordinary later Edit Mode edits. Do not silently change
the account-wide preference or detach users' existing layouts wholesale.

Next failing-profile evidence: capture `diag full` once and `diag chat` before
the move, while Edit Mode is open after the move, after Save/exit and after
reopening. Compare the named target's layout and live rectangle, particularly
on the stacked topology, and distinguish detached extra chat windows from the
primary Edit Mode frame.

## Restoration and validation

Native restoration returned the selected layout to its original ID, removed
the temporary slot, and restored account snapping/settings and character state.
The retained final native snapshot compares exactly with the baseline for all
layouts, slot count, active selection, account settings and character data.
The helper's separate immediate layout-equality flag was false; the claims here
use the retained complete native snapshots and offline equality check, rather
than treating that immediate flag as a pass.

The target client closed normally. All 66 existing scoped files matched their
backup SHA-256 hashes and all 129 original absences were restored. This includes
the original installed product files, helper, addon flags, SavedVariables,
native local caches, logging configuration and taint log. The generated recovery
bridge was refreshed from hash-verified restored account/character tables and
also matched its original bytes. This run's WoW process/window closed; Battle.net
and Companion were left alone. No release artifact was built or published by
this task.

Restoration passed at 22:49 and was independently rechecked afterward. A later
check found another concurrent QA activity had replaced five installed runtime
files (Init, CanvasChat, Viewport, MainhandEditMode and PopupBounds), with source
timestamps from its 22:40 candidate. Those later files were preserved instead
of undoing another task's work. A subsequent addon-flag change and newly started
WoW process also belong to that separate activity and were left alone. The
original test process, ID 50720, was already closed. Final-state audit is
retained privately; original
file restoration here is a verified point-in-time claim, not a claim that the
other task's later installation was rolled back. Companion was no longer
visible at the final window inventory.

BugGrabber data is identical except its expected session counter, 55 to 59.
The observer recorded no blocked/forbidden action or callback error. The final
taint log contains startup binding-global/Questie traces, without blocked action
or changed diagnostic-module stack evidence. This is not a taint-free or combat
acceptance claim.

All 129 Lua suites pass. Six manifests validate paths, XML and Lua 5.1 syntax
for 84 runtime files (83 Lua, one XML). git diff --check passes.

Private evidence: dist/diagnostics-snap-live-20261110. Final installed test hashes
are in tested-hashes.json; the Init and Viewport test subjects contain scoped
overlays on the installed baseline. Workspace source remains available and the
test overlay is no longer installed.
