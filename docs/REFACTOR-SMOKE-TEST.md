# Final structural refactor manual smoke test

Runtime source checkpoint: `8335480` on `codex/addon-architecture-refactor`, draft PR #34. Documentation commits may follow this checkpoint without changing the runtime.

Run on Retail and Forever if available. Use the same normal spanned topology and compatibility addons you ordinarily use. Actual results remain pending.

## Before starting

1. Note the client version/build, character, monitor orientation, and relevant addons such as MoveAny, Leatrix Maps, Chattynator, or a bag replacement.
2. Reload after the latest deployed files are installed. Run `/offhand diag` and retain the output.
3. Note your original scale, lock, persistence, and layout settings so temporary changes can be restored.
4. Distinguish errors generated during this test from historical BugGrabber/BugSack entries.

## Priority pass

1. Open Offhand settings. Visit every tab, scroll to the end, and reopen the panel. Check that displayed settings agree with the saved profile.
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
- If you use profile switching, select another existing profile and return. Confirm displayed controls and window behavior follow the active profile.

Restore temporary settings when finished. Do not delete SavedVariables to obtain a passing result.

## Report

Send the client/build, tested topology, relevant addons, and any failed step. Include the exact action sequence, expected and observed behavior, and a fresh error stack or screenshot when available. Mark unavailable cases as not tested. A result from one client or topology does not establish a pass for another.
