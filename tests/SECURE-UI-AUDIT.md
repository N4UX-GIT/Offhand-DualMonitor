# Secure UI review — 2026-09-16

## Changes
Regular layout no longer writes uiScale/useUiScale. Root scaling remains guarded
and combat-deferred; legacy CVars can be restored on disable. Map configuration
and Ctrl-wheel scaling stop in combat. CloseAllBags delegates to Blizzard during
combat. Repeated HUD setup retains one scanner and one delayed layout load.

## Retained compatibility surfaces
The EditModeUtil replacements remain because the preceding development used them
to fix an observed nil-offset crash. Blizzard's Classic Era source passes GetPoint
offsets directly to math.abs. Removing the workaround without live reproduction
could restore the crash; replacing these methods can itself affect taint.
Source: https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_EditMode/Shared/EditModeUtil.lua

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

No live client was launched or modified for this stabilization pass.
