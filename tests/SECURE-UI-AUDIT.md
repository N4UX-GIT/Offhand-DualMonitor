# Secure UI review -- 2026-09-16

## Changes
Regular layout no longer writes uiScale/useUiScale. Root scaling remains guarded
and combat-deferred; legacy CVars can be restored on disable. Map configuration
and Ctrl-wheel scaling stop in combat. CloseAllBags delegates to Blizzard during
combat. Repeated HUD setup retains one scanner and one delayed layout load.

## Forever Edit Mode ownership
Forever action bars, combat frames, the minimap, and Edit Mode windows remain
Blizzard-owned. Offhand does not replace EditModeUtil, attach handlers to the
Forever Edit Mode manager, switch layouts after login, or write legacy UIParent
panel-offset attributes on this client.

Canvas also wraps CloseAllBags, changes UIPanel metadata, and temporarily suppresses
panel scripts when releasing occupied slots. Out-of-combat checks and pcall do not
prove these paths taint-free. These compatibility mechanisms were not removed.

## Live acceptance still required
- Enable/disable, switch profiles, span/unspan and reload; watch idle HUD stability.
- Enter/leave combat, change forms, use pet controls and open bags; inspect errors
  with default and custom Edit Mode layouts.
- Move/reopen map, character, social, spellbook, quests, talents and bags on both
  monitors. Verify map zoom/pins, Ctrl-wheel, tooltip sizing and reload persistence.
- Test Escape persistence and replacement bags/action bars/Leatrix Maps.
- Test companion shortcut conflicts, malformed settings and different launch paths.

The Forever Beta client was manually verified through reload, Edit Mode save and
exit, and persistent action-bar placement without a Lua error. The broader matrix
above remains required for release acceptance.
