# Offhand 2.1.5 Beta 29: placement and recovery hotfix

This is an addon-only beta update. No Companion update is required for these
fixes. Existing settings and layouts are retained.

- Preserve EllesmereUI and SexyMap minimap placement during automatic window
  recovery, including detached minimaps and their crop frames.
- Keep EllesmereUI scaling consistent with the spanned layout and preserve
  scale choices made by another UI addon when Offhand releases control.
- Keep open native Forever NPC panels reachable after disabling Offhand or
  restoring the game window.
- Fix Forever backpack restoration after Chat Settings closes, native close
  button handling, and Escape priority when a target is selected.
- Preserve Details, BetterBags Next and RestedXP window placement during
  automatic recovery.
- Fix setup reload-button handling and guidance when the window is not yet
  spanned. Preserve progress through a manual reload.
- Compact remaining loot-roll windows after earlier rolls finish, and keep the
  stack within Mainhand. Fit oversized native item tooltips to their display
  and restore their scale when the content changes or the tooltip closes.
- Add optional Mainhand centering for ProcDoc alerts while retaining its own
  offsets. Preserve its anchor when centering is disabled.
- Keep DaylightUI's world map at its saved Offhand placement while owned by
  Offhand, and restore DaylightUI placement and controls when released.
- Improve minimap compatibility diagnostics and release Offhand's temporary
  owned UI scale during normal logout outside combat.

Validation includes automated regressions and controlled spanned Forever
1.60.1.70862 checks. Real simultaneous loot rolls and their combat lifecycle
could not be tested locally. Their corrections are included for beta feedback;
please report any remaining disappearance, unusable roll choices or tooltip
overflow with `/offhand diag full`, the client build and other UI addons.

Old-profile minimap hiding, exact reporter HUD-save failures and physical
portrait/4K placement reports remain under investigation. This update does not
add SexyMap synchronization with Blizzard's Edit Mode selection box or change
Companion display-identity handling. The separate Retail friendly-name
preference correction is deferred pending native Retail verification.
