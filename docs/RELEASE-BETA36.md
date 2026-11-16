<!-- offhand-companion-version: 2.1.8 -->

# Offhand v2.1.5 Pre-Release Beta 36

- Fixed an Offhand shutdown issue that could freeze WoW before the loading bar after `/reload`. In a WoW Forever test with the reported 4480×1440 layout, OpenMap and Leatrix Maps, the loading screen appeared in about four seconds with the fix, compared with about seven seconds on Beta 35.
- Preserve Baganator backpack placement and open state through merchant interactions.
- Restore normal Escape behavior after moving the Baganator backpack to Mainhand.
- Recover an off-screen RestedXP V2 guide to Mainhand while leaving the arrow in place.
- On Forever, keep unplaced Professions, Spellbook, Character, and Collections
  on Mainhand when opening or closing another panel.
- Preserve newer settings when an older Companion recovery snapshot is present.
  Show missing-span recovery before release notes, and offer manual placement on macOS.
- Extend the windowed OpenMap placement and movement fade adapters to
  v0.8.8 and v0.8.9 on Forever.
- Keep the windowed MapWise map on the chosen display when opening the map,
  toggling its sidebar, or switching sidebar tabs on Forever.
- Keep inventory tooltips on the appropriate display. Respect supported
  chat addon ownership during Gather and identify it in chat diagnostics.
- Fit Questie Options and ItemRack Universal options and gear flyouts within
  Mainhand. Respect the workspace Escape setting for Leveldon Options.
- Preserve Leveldon guide and DonMap arrow ownership during Escape and
  vendor panel interactions.
- Center the stock Game Menu with ConsolePort, preserve the native gamepad
  reticle's vertical position, and repair the old centered XP bar anchor when
  rebuilding the Forever HUD.

This beta updates the in-game addon. It remains paired with Companion 2.1.8.

The addon ZIP is `Offhand-v2.1.5-beta.36.zip`. It contains the `Offhand` folder for WoW's `Interface/AddOns` directory.
