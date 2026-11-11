# Guide placement recovery, 2026-11-09

The user confirmed that Reload UI had been clicked without applying Span WoW Now.
The disabled confirmation was correct. The defect was presentation:
RefreshPlacementState changed the displayed CONFIRM stage back to RELOAD whenever
SetupStatus was false, while LayoutPage rendered the actual CONFIRM stage. The
body repeatedly requested another reload and the illustration already showed it
complete. Reload success was being confused with valid window placement.

The guide now treats those facts separately. A completed reload with a missing or
mismatched Companion bridge shows the span instructions and an explicit completed-
reload message. The recommended action is Window is positioned. Its actual click
starts a fresh placement acknowledgement and reload checkpoint, without invoking
reload on that acknowledgement. The title and illustration use the same display
phase. Confirm placement requires both the checkpoint and valid current geometry.
The final modal still rechecks geometry, signature, page revision and combat.
A changed signature still requires a new span/reload sequence. Version mismatch,
window-mode, controller/manual reload and other geometry safeguards remain.
No native topology rejection or protection boundary was relaxed.

## Source and simulation

Current source, Core/SetupPlacement.lua, UI/Onboarding.lua, Core/Config.lua and
Core/Viewport.lua are the primary engineering evidence. The shared knowledge ask
for Offhand placement/reload/topology on Forever build 70862 returned an unresolved
routing gap, not a runtime contract. No new native API was introduced.

All 114 source Lua suites pass. Regressions cover a modeled new-session reload
with MISMATCH, completed checkpoint preservation, span guidance replacing reload,
stale confirmation rejection, a new acknowledgement without a reload call,
same-session reload guards, valid confirmation after another module session,
and invalidation when the span is lost. All 11 locales include the new message;
localized recovery text passes the existing guide bounds checks.

## Native evidence

Forever 1.60.1.70862, keyboard/mouse, Noggaholic in Valley of Trials, out of combat.
Companion 2.1.5 was already running. Its existing configuration was used unchanged:
Display 1, 2560x1440, single-display split, Mainhand right, auto-span off.
This is a single-display split test, not physical multi-monitor acceptance.

1. The existing unspanned guide showed the reported Step 2 body and completed
   reload illustration, with topology mismatch and disabled confirmation.
2. Installed UI/Onboarding.lua and 11 locale files, preserving generated bridges.
   Clicked the old guide's actual Reload UI button to load the candidate.
3. The new guide showed Step 1, the completed-reload sentence, highlighted
   Span WoW Now instruction, Window is positioned action and disabled confirmation.
4. Clicked Companion's Span WoW Now. WoW became borderless 2560x1440 with Mainhand
   on the right and workspace on the left. Companion updated its generated bridge
   from the earlier 2.1.4 data to 2.1.5. No manual bridge edits were made.
5. Clicked Window is positioned. The guide changed to Step 2 with Reload UI;
   confirmation remained disabled. Clicked Reload UI and observed a loading screen.
6. On return, Step 3 and Confirm placement were enabled. Clicked it, reviewed the
   owned confirmation modal centered inside Mainhand, and accepted. The guide
   advanced to Calibrate, task 5 of 5. No HUD creation or selection was performed;
   the unrelated existing Restore Saved Layout prompt was left untouched.

The target client was closed normally after evidence capture, with the confirmed
placement checkpoint and calibration resume retained. Companion and Battle.net
were left running. No private helper, raw /run command, debug-chat status, account
reset, addon selection change or Companion preference change was used.

BugGrabber persisted session 37 at exit. Its records were earlier reload failures
(sessions 16/25) and two minimap errors from session 32 at 21:09:14, with stacks in
EllesmereUIMinimap and SexyMap. No current-session guide error was recorded.
The taint log remains stale from November 8, so no fresh taint pass is claimed.
Controller activation, combat transitions, other builds and physical multi-monitor
layouts remain separate verification dimensions.

## Private artifact

beta28-placement-recovery-test1 is packaged and installed. Both source and
packaged runtime pass 114 Lua suites; all six manifests and runtime Lua/XML paths
validate with Lua 5.1. The 90-entry ZIP matches staging byte for byte. Installed
runtime matches the candidate with generated topology/persistence bridges
preserved. No private QA helper or knowledge cache is included.

Artifact: dist/placement-recovery-20261109/Offhand-v2.1.5-beta.28-placement-recovery-test1.zip

SHA-256: 87a4949fdd335a61ed87f64355f06612cff3daa2067fd97e4d72d052a81f80f5
