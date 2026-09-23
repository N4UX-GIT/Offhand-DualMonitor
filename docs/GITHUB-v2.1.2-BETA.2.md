# Offhand v2.1.2 Beta 2

This beta contains the latest all-client addon and a rebuilt Companion. Forever
remains the primary validation target; Retail, Classic Era/Hardcore, TBC
Anniversary and progression clients retain the shared stability fixes and need
broader live coverage.

## Fixes since Beta 1

- Forever now fails safe to the current full WoW window when exact Companion
  topology is absent, including after **Restore Window**. It no longer applies
  the legacy percentage split that could leave the minimap or HUD in black void.
- Single-screen recovery preserves saved Offhand panel positions and offers the
  player-click **Use Modern** / **Restore Offhand** Edit Mode handoff.
- Protected player, party and action UI remains Blizzard-owned, covering the
  reported `CompactUnitFrame` and `TextStatusBar` taint paths.
- Locked or docked chat frames are no longer forced through `StartMoving()`.
- The `Offhand` Edit Mode layout name is matched without case sensitivity and
  safely follows the named layout if its numeric custom slot changes.
- Companion display-plan and activity-log text now wraps instead of overflowing.

## Simple retest

1. Close WoW and the old Companion. Back up your existing Offhand SavedVariables,
   but do **not** delete your `WTF` or saved settings.
2. Replace the existing `Interface/AddOns/Offhand` folder with the folder from
   `Offhand-v2.1.2-beta.2.zip`. Run the new `Offhand.exe` from this release.
3. Use standard **Windowed** mode. In Companion select exactly two adjacent
   displays, choose Mainhand, and click **Span WoW Now**. If WoW was already at
   the character UI, type `/reload` once.
4. Open and close Character and Blizzard Edit Mode with party frames visible.
   Confirm action bars and menu buttons stay correctly placed and no Lua taint
   error appears.
5. Lock or dock the General chat frame, interact with its tab, and confirm there
   is no `ChatFrame1:StartMoving(): Frame is not movable` error.
6. Click Companion **Restore Window**. After the short recovery delay, confirm
   the world fills the window and the minimap is visible; click **Use Modern** if
   prompted. Then click **Span WoW Now**, `/reload`, and click **Restore Offhand**
   if prompted. Confirm saved map, bag, character and chat positions return.
7. If practical, disconnect and reconnect the workspace display once. Confirm
   the Companion status/log text remains readable and WoW safely returns to the
   surviving Mainhand.

When reporting a failure, include the WoW client/build, Windows display layout,
which two displays were selected, Companion log text, enabled addons, exact Lua
error, and full-screen screenshots before and after the failing action.

## Known limits

- Select one Mainhand and one workspace display. Two independent workspace
  displays or a three-display WoW span are not supported in this beta.
- A single-display 32:9/32:10 split remains fixed at 50/50.
- Tooltip placement and unusual GPU shadow artifacts remain validation items;
  reproduce them under a supported exact two-display topology before reporting
  them as separate defects.

The Companion executable is unsigned. Download it only from this official
release and verify it against `checksums-sha256.txt`.
