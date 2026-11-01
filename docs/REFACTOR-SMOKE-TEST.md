# Combined refactor and visual UI manual smoke test

Current installed runtime checkpoint: `3fe93da` on `codex/addon-ui-overhaul`, draft PR #35. This includes the completed structural refactor from PR #34 plus the separately committed [visual UI candidate](UI-OVERHAUL-2026-10-23.md), interaction/geometry-input hardening, decimal-comma entry, localized bottom-offset actions, profile control synchronization, measured text layouts, and setup/calibration spacing. The independently preserved structural runtime checkpoint is `8335480`. Documentation commits may follow without changing the runtime.

Run on Retail and Forever if available. Use the same normal spanned topology and compatibility addons you ordinarily use. Actual results remain pending.

## Before starting

1. Note the client version/build, character, monitor orientation, and relevant addons such as MoveAny, Leatrix Maps, Chattynator, or a bag replacement.
2. Reload after the latest deployed files are installed. Run `/offhand diag` and retain the output.
3. Note your original scale, lock, persistence, and layout settings so temporary changes can be restored.
4. Distinguish errors generated during this test from historical BugGrabber/BugSack entries.

## Priority pass

1. Open Offhand settings. Visit all five sidebar pages, use a section shortcut, scroll to the end, switch pages and return. Confirm the previous page's scroll position returns, the scrollbar matches the content, and the footer stays visible. Drag the scrollbar as well as using the wheel. Reopen the panel and check that displayed settings agree with the saved profile.
2. Test a percentage slider by dragging, typing a value, and using both step buttons. Check immediate visual application and the final value after mouse release. Restore the original setting.
3. Open the World Map, bags, and Character. Move each to the workspace, close and reopen it, and confirm position and scale. Move each back to Mainhand and confirm that its previous workspace position does not pull it back.
4. With persistence enabled, leave the workspace map and one ordinary panel open, then `/reload`. Check visibility, placement, usability, and absence of a client crash. Explicitly close a bag and immediately reload; it should stay closed.
5. On Retail, test the selected-window lock with map, bags, and Character where supported. Close each, observe reopening, then reload with the lock enabled. Record noticeably different reopening delays. On Forever, retain the existing supported availability policy; an unavailable lock control is not a refactor failure.
6. Change Character workspace scale using a drag and typed input. Confirm the whole window reflects the released value without a step-button click. Return it to Mainhand and check restoration of native scale.
7. Maximize and minimize the map. Check windowed placement and the external return control where provided. With your map addon enabled, confirm it remains the map's position/scale owner.
8. Move a detached custom chat window, reload, and check position, visibility, background, and text input. Check that docked tabs and the built-in Combat Log remain under Blizzard's docking/visibility behavior. If using Chattynator, check Enter input and its normal tab behavior.
9. Open Professions, move its supported panel, close/reopen, and reload. Confirm no unexpected Edit Mode opening. Open Settings and the AddOn List while a workspace bag is tracked, then return to play and use an actual bag item.
10. On a character with a pet battle available, start and finish one. Confirm its full presentation fits Mainhand and normal UI returns afterward. Check group-loot placement if a roll is naturally available; otherwise mark it not tested.

## Recovery and protected-input checks

- Open and close Blizzard Edit Mode. Confirm the expected layout remains selected and no unsolicited layout switch occurs. If a genuine offscreen HUD recovery prompt appears, test its player-clicked action and subsequent reload.
- Test a brief combat entry/exit with the normal UI. Check for protected-action errors, lost controls, unexpected movement, and failed actions after leaving combat.
- If you use native Forever Gamepad UI, test switching between keyboard and Gamepad, the radial menu, destination panels, Back/focus behavior, and drag handles. Verify ordinary gameplay controls after switching back.
- If practical, restore to one monitor and span again using your normal workflow. Confirm reachable settings, safe single-screen presentation, and return of saved workspace placements.
- If you use profile switching, select another existing profile and return. Confirm displayed numbers, slider thumbs, bottom-offset value, and window behavior follow the active profile. If the profiles have different scale values, check that the first step-button click starts from the newly displayed value, then undo that step and return to the original profile. Do not alter a profile just to force this test.

Restore temporary settings when finished. Do not delete SavedVariables to obtain a passing result.

## Visual checks during the same session

- At your normal UI scale and a smaller game viewport if practical, reopen settings and confirm the complete dialog fits Mainhand. Check narrow slider titles, typed values, section labels, the topology banner, and the fixed footer for clipping or overlap. Restore your original scale.
- Adjust Global UI Size while settings stays open. Confirm the dialog continues to fit rather than requiring a close/reopen. Start another slider drag, switch pages before releasing, then return and move the mouse without pressing. The old drag must not resume. Restore the original value.
- Hover, press, and select buttons. Confirm disabled actions look disabled and cannot be invoked. Selected choices should remain clickable and show a selection marker.
- Click a radio label rather than its circle. Confirm it selects the same setting. An unavailable choice must remain unchanged when its label is clicked.
- If you normally type decimal commas, try a valid comma-decimal value in a slider field and confirm it matches the same dot-decimal value. Mixed separators such as `0,7.5` must restore the current value rather than change the setting. Restore the original value afterward. Displayed values still use the existing dot-decimal format.
- Check the bottom-offset row in Settings and Calibration: the label, pixel steppers and translated Apply button must fit without overlap. You can inspect this without changing the offset.
- If Companion is already supplying exact geometry, confirm the seam rail, typed value field, step buttons, and seam presets are all unavailable in Settings and Calibration. Do not change topology ownership just to force this case. This is a geometry-input lock, separate from the workspace window lock tested above.
- In Themes, choose a trim and cancel a custom color change. Confirm cancellation restores the previous value. Check the OLED option if you use it, then restore your original theme and colors.
- On Themes and Help, check wrapped headings and descriptions. Theme choices must remain within their columns, following rows must clear the longer description, and the next card must start below the expanded content. Help bodies must start below their headings.
- Open calibration and go forward/back without applying a new setup. Close it and reopen settings. If you use Window Setup, inspect its introduction and method-choice page without changing your method, then close the guide. Check that instructions, method buttons, status, and footer do not overlap, and the whole guide remains reachable. Do not reset your existing setup to obtain a visual pass.
- In calibration, inspect the topology recommendation and, if reachable with Next, the final HUD readiness page. Its detailed guidance, status, validation message, and footer must remain separated and readable. Use Back/close to leave without pressing Finish, Create Mainhand HUD Layout, or the skip action solely for this visual check.

For a longer profile check, note the original active profile. Type a unique new
test name in Profiles, press Escape, and confirm no profile is created. Refocus
the field and press Enter. Confirm the new profile is selected, marked active,
and visible in the list. Return to the original profile before deleting only the
new test profile through the existing confirmation. Check that scrolling and the
selection/action states remain sensible after deletion. Skip this extended check
if you do not have time to safely restore the original profile.

If time is extremely limited, prioritize steps 1 through 6 plus a brief combat
transition and the visual checks at your normal scale. This is a triage pass, not
a substitute for the full matrix. Report which cases were omitted rather than
treating them as passed.

## Report

Send the client/build, tested topology, relevant addons, and any failed step. Include the exact action sequence, expected and observed behavior, and a fresh error stack or screenshot when available. Mark unavailable cases as not tested. A result from one client or topology does not establish a pass for another.

## User acceptance, 25 October 2026

The user considers the structural/UI refactor, first-time setup, HUD/window
restore/menu placement, Forever Gamepad, Bagnon, Party-frame recovery, Dialogue UI,
pet battles and recorded source defect fixed and resolved. Prior pending checklists
for this scope remain historical rather than new release blockers. No additional
live tests are implied. Linux/Wine is assumed fixed with direct reporter
verification outstanding. Performance investigation is the next active work.
