# Offhand v2.1.2 Beta 1

This beta makes the current shared Offhand stability work available to Retail,
Classic Era/Hardcore, TBC Anniversary, progression Classic/MoP and the WoW
Forever beta. It is published as a beta because the exact Forever baseline has
received the most live testing; the other client families have passed static
and automated regression coverage but still need broader in-game validation.

## Highlights

- Replaces combined-resolution guessing with exact display rectangles supplied
  by Companion v2.1.2.
- Supports unequal side-by-side screens, stacked screens, negative desktop
  origins, ultrawide Mainhand displays and an explicit single-screen 32:9/32:10
  split.
- Rejects stale or missing-monitor topology instead of shrinking the game UI.
- Adds safer disconnect, reconnect, cold-launch and off-screen panel recovery.
- Keeps fresh profiles disabled until the setup Wizard enables Offhand.
- Prevents disabled or temporary single-screen profiles from taking ownership
  of tooltip scale or rewriting Blizzard bag anchors during logout.
- Improves map, bags, chat, dropdown and panel persistence, including combat
  deferral where protected UI cannot be changed safely.
- Adds Forever-specific SavedVariables fallback and player-click Edit Mode
  recovery for the current beta client behavior.

## Beta testing requested

Please include the WoW client and build, display arrangement, Companion version,
enabled UI addons, reproduction steps, Lua error text and screenshots when
reporting a problem. The highest-value checks are:

1. Upgrade from Offhand v2.0.0 without deleting SavedVariables.
2. Cold login, span, `/reload`, relog and full client restart.
3. Open, close and reopen map, character, spellbook/talents, bags, chat,
   tooltips, dropdowns, settings and the Offhand panel.
4. Enter and leave combat while checking action, stance/form, pet/possess, XP
   and reputation bars for blocked-action or taint errors.
5. Disconnect and reconnect the saved workspace display and confirm WoW safely
   returns to the surviving Mainhand.

Companion v2.1.2 is required for the current WoW Forever beta and strongly
recommended for every other client. Keep a backup of the existing
`WTF/Account/.../SavedVariables/Offhand.lua` files before beta testing.

This beta does not claim support for more than two selected displays or
guaranteed control of every arbitrary third-party addon frame.
