# Offhand v2.1.5 Pre-Release Beta 36

This addon update focuses on WoW Forever stability, keeping windows on the display you chose, and preserving your setup through reloads and restarts.

## Stability and setup recovery

- Fixed an Offhand shutdown issue that could stall WoW before the loading screen appeared after `/reload`. In a matched Forever 1.60.1.70938 test with OpenMap and Leatrix Maps, the loading screen appeared in about four seconds, compared with about seven seconds on Beta 35.
- Preserve newer Forever settings when the Companion has an older recovery snapshot. An older snapshot can no longer overwrite newer settings just because it is available at startup.
- When a Companion display layout cannot be confirmed, keep WoW in a usable single-display layout and show the recovery prompt before What's New. Auto Configure also offers recovery rather than guessing a layout based on window dimensions.
- On macOS, setup, display identification, and recovery now point to manual window placement when the addon cannot read an exact display layout.

## World map

- Extend Forever support for placement and movement fade to windowed **OpenMap 0.8.8 and 0.8.9**. A supported map on Offhand stays visible while you move, without a console command. Moving it back to Mainhand restores its regular fade behavior.
- Keep **MapWise** on the chosen display when opening or reopening the map, showing or hiding its sidebar, and switching between Nearby, Search, Quests, and Route. The reporter confirmed the fix.

## Bags, guides, and addon windows

- **Baganator:** Keep the backpack where you placed it on either display when opening or closing a merchant. An Offhand backpack already open before you talk to a merchant stays open afterward. If the merchant opened it for you, it can still close with the merchant.
- **Baganator:** Restore normal Escape behavior as soon as the backpack is dragged from Offhand to Mainhand. No reload is required.
- **Leveldon and DonMap:** Keep the guide and navigation arrow in place through Escape and vendor interactions. The separate Leveldon Options window follows Offhand's workspace Escape setting.
- **RestedXP V2:** **Recover Missing UI** can bring a visible guide back to Mainhand when it is outside the visible displays. The navigation arrow stays where it is, and a guide hidden in RestedXP remains hidden.
- **Questie:** Fit the Options window within Mainhand. This does not change map pin rendering or address the reported Questie and OpenMap performance interaction.
- **ItemRack Universal:** Fit the Options window within Mainhand and keep gear flyouts opened from Options reachable. A flyout can open to the other side or shrink to fit when space is tight.

## Blizzard panels, tooltips, and chat

- **Forever:** Previously unplaced Professions, Spellbook, Character, and Collections panels open on Mainhand. Opening or closing another panel no longer sends an open panel to Offhand. Where space permits, panels can sit side by side. Saved manual placement is preserved.
- **Forever:** Recover the stock Trade window if it would otherwise open off-screen or across a display boundary. Offhand can also retry supported native party invite and quest confirmation placement after combat if the dialog is still open. No frames are moved during combat for this recovery. The placement checks passed in simulation; live Trade and combat verification are still pending.
- Keep inventory tooltips within the display that contains their item or window. Tooltip diagnostics give more detail about which frame owns the tooltip and how it was placed.
- **Gather** respects chat frames managed by EllesmereUIChat or Chattynator. `/offhand diag chat` identifies the chat provider and reports the active dock tab, visibility, and opacity.
- Center the stock Game Menu on Mainhand when using ConsolePort, preserve the native gamepad reticle's vertical position, and repair the old generated XP bar anchor when rebuilding the Forever HUD. Manually placed bars keep their anchors.

## Install and report issues

- This is an **addon-only** beta for use with **Companion 2.1.8**. The separate [Microsoft Store Companion](https://apps.microsoft.com/detail/9PL4PW84Q90W) update, build **2.1.8.2**, improves Custom Span and Restore Window when Windows resizes WoW during a display scaling change.
- Install through your addon manager or extract the ZIP and put its `Offhand` folder in your WoW client's `Interface/AddOns` directory. Keep your existing settings when upgrading.
- Native loading and character selection still use the full spanned window. If a screen is clipped with uneven displays, use Companion's **Restore Window**, then span again once you are in the world.
- Report any remaining issues on [GitHub](https://github.com/N4UX-GIT/Offhand-DualMonitor/issues). Include your WoW client and build, affected addons and versions, reproduction steps, and `/offhand diag full` output.
