# WotLK 3.3.5a Compatibility Test Plan

Offhand's original-Wrath target is experimental until this matrix passes on an
unmodified 3.3.5a client reporting build `12340` and interface `30300`.

## Install

1. Copy the `Offhand` folder directly to `Interface\AddOns\Offhand`.
2. Confirm `Offhand.toc` is directly inside that folder.
3. At the character screen, confirm Offhand is enabled without selecting
   **Load out of date AddOns**.
4. Enable Lua errors with `/console scriptErrors 1`, then restart or `/reload`.

Use manual Windowed-mode spanning for this first test cycle. Companion topology
and automatic window control are outside the initial 3.3.5a compatibility claim.

## Required checks

1. Log in with no Lua error and run `/offhand diag`.
2. Confirm the diagnostic includes:
   `Legacy Wrath diagnostics: Interface=30300 | Timer=compat`.
3. Open `/offhand`, complete the wizard, and reapply the layout.
4. Verify that the 3D world is confined to Mainhand and the workspace canvas is
   confined to Offhand.
5. Open, move, close, and reopen the World Map, Character frame, and every bag.
6. Verify action bars, player/target frames, party frames, chat, minimap, and
   tooltips remain clickable and inside the intended physical monitor.
7. Enter combat, open/close only normally permitted panels, leave combat, and
   confirm deferred layout changes recover without a blocked-action warning.
8. Run `/reload` and repeat the panel-position and `/offhand diag` checks.
9. Log out normally and confirm SavedVariables reload on the next login.

## Reporting

Include the first complete Lua error, the full `/offhand diag` output, window
pixel dimensions, Mainhand dimensions and side, UI scale, and whether the error
occurred on login, `/reload`, opening settings, or opening a specific panel.

Do not treat a successful load alone as full compatibility. The original Wrath
container, map, secure-frame, and rendering behavior must all pass the checks
above before this target is promoted from experimental.
