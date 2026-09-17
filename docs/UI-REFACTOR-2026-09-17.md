# Settings and Companion usability checkpoint

Rollback: `checkpoint/2026-09-17-before-ui-refactor` (`995ec12`). This preserves the
Antigravity source and executable before this iteration.

## Implemented

- Shared card stacking derives tab scroll heights from the actual card heights.
  Display cards no longer overlap, scale help stays inside its card, and Profiles
  no longer exceeds its scroll content.
- Settings and wizard have an opaque backing while retaining Warcraft borders.
  Workspace background opacity remains independent.
- Checkbox labels are clickable. Selected palette and wizard buttons remain
  enabled and use persistent selection highlighting.
- Bezel compensation is in Display; recovery and preview have a separate
  Workspace card. Help is split into four task-oriented cards.
- Settings explain immediate application, profile updates and disk-save timing.
  Footer actions are Close and Reapply Layout.
- Profile names have a field label; list height follows the profile count. The
  active profile is marked. Copy, delete and reset require an in-game confirmation.
- Wizard shows one of four steps at a time, provides Back/Next, includes vertical
  alignment, and shows the seam guide only during alignment. Applying suggested
  settings does not mark setup complete or claim physical calibration is finished.
- All explicit Gather entry points share recovery logic. Reachable windows are
  preserved; protected/forbidden frames and combat are excluded. Coordinate checks
  account for frame scale and either monitor orientation. Failed moves do not count.
- Native Companion Restore remembers original window bounds, fits an available
  work area, verifies the move and prevents immediate auto-respanning. Ctrl+Alt+R
  works independently of the configured span shortcut and reports conflicts.
- Standard packaging rebuilds with embedded assets and verifies archive parity.

## Verification and limitations

Automated checks cover Lua load/syntax and existing layout behavior, card boundaries,
wizard navigation, recovery coordinate conversion, profile confirmation deferral,
Companion preference parsing, restore geometry and packaged file parity.

Desktop control was unavailable in this Codex session. These checks do not establish
in-game visual correctness, combat safety or successful native Win32 operation.

## Live acceptance checks

1. Run `/reload`, then `/offhand`; inspect every tab and scroll to the bottom.
   Check text wrapping, radio rows, checkbox labels and footer controls at the
   smallest and largest UI scale you normally use.
2. Run `/offhand wizard`; step forward/back, apply recommendations, adjust seam
   and bottom offset, and finish. Verify only one page shows and the seam guide
   disappears on exit. Confirm closing midway does not mark first setup complete.
3. In a disposable profile, test create/load, cancel and accept copy/reset/delete.
   Verify the destination profile is named correctly and cancellation changes nothing.
4. Gather with one visible game window, one visible workspace window and one
   misplaced window. Verify only the misplaced window moves. Repeat with the
   workspace on the right and with combat lockdown active.
5. In the rebuilt Companion, enable auto-span, span and restore. Wait through
   several watcher ticks: the restored client should remain single-monitor.
   Repeat with a nondefault span hotkey and Ctrl+Alt+R. Check a smaller monitor,
   monitor removal, and mixed DPI. Resume with Span Now.

Future work can replace remaining manually sized control rows with reusable field
components and add a monitor diagram to the wizard. Those visual enhancements
should follow live feedback on this iteration.

## Speech-bubble follow-up

User visual feedback confirmed the settings changes and identified oversized native
speech bubbles. `Core/ChatBubbles.lua` now applies the UIParent scale baseline to
bubbles outside that hierarchy, preserving their relative scale. It neither scales
WorldFrame nor changes bubble anchors/fonts. A single 100ms watcher picks up newly
created/reused bubbles and avoids writes while the scale is already correct.
Protected/forbidden bubbles are skipped. Disabling Offhand restores the prior scale
unless another addon has since changed it.

API reference: [Classic Era ChatBubbles documentation](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatBubblesDocumentation.lua).
The API excludes forbidden bubbles by default and exposes no creation event.

All 15 Lua regression suites and addon validation pass, including tests for new and
pooled bubbles, UIParent inheritance, relative scale, repeated updates, restricted
frames and restoration. Live check: reload, observe a speech bubble, adjust Global
UI Size and observe another; then toggle Offhand off/on to check restoration.

## Native chat follow-up

Native default chat previously stayed on the workspace because its current location
was mistaken for an intentional workspace placement. Classic default chat now
anchors inside the game viewport, while explicit workspace and game-view drags
remain persistent. Active native drags and combat defer placement changes.

The tab drag handler now saves its associated chat window instead of the tab's
parent (which can be GeneralDockManager). Invalid saved dock-container positions
are removed. The native dock is reattached above ChatFrame1 and its tabs refreshed
once, preserving Blizzard's normal hover fading. Popup recovery excludes native
chat components so it cannot independently relocate the dock or tabs.

Validation: all 15 Lua suites and addon validation pass. The expanded chat test
covers default positioning, tab restoration, dock-parent persistence, drag guards,
workspace reload restoration, deliberate game-view placement and combat deferral.
Live verification remains outstanding: with only Offhand enabled, reload, leave
Edit Mode, hover and right-click General, switch Combat Log, drag chat to each
display and reload again. Confirm custom Edit Mode layouts retain their placement.
