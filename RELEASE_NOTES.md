<!-- offhand-companion-version: 2.1.9-beta.2 -->

# Offhand Beta 39

This add-on update works with Windows Companion 2.1.9-beta.2.

### Returning to your workspace

- On Forever, leave your map, backpack and Character panel open on Offhand when you quit. With window restoration enabled, they return when you log in and span WoW again. Panels you closed stay closed.
- **Restore Window** can temporarily hide your Offhand panels. **Span WoW Now** brings the open ones back, even if you reloaded the UI while playing on one screen.
- OpenMap returns to the position and size you chose when you reload with the compact map open on Offhand. Closing it first keeps it closed.

### Bags and the Game Menu on Forever

- Outside combat, if you choose to keep Offhand panels open on Escape, pressing Escape with no target opens the Game Menu. Your Blizzard backpack stays visible and any satchel you closed stays closed. This works with both separate and combined bags. Turn the setting off to let Escape close your backpack.
- If you close the backpack with its X while a separate satchel is open on Offhand, the satchel stays on Offhand. Reload with just the satchel open and it returns to that spot on its own.
- If you use Baganator, its Single and Category views also stay open while you open and close the Game Menu with Escape.

### Manual window setup

- The first-time guide now explains how to move a window controlled by another add-on. If a window won’t move or keeps jumping back, **Help & Setup** has examples for MoveAny and BlizzMove.
- The setup wizard and **Display & HUD** now let you pick an even split with Offhand on the left or right. The stacked choices also tell you where Offhand will appear, above or below the game.
- When calibrating two matching landscape displays, Offhand uses the available window height. If your existing setup leaves a black strip above the game, select **Fit Window Height (Fill)**. You can still choose a fixed aspect ratio or a shorter game view.
- Recalibrating the same manual window remembers which side you picked, where you put the divider and how you sized the game.
- On a single ultrawide display, you can keep a narrow workspace beside the game or explicitly choose a 50/50 split. The new side choices and window-height setting are translated in all supported game languages.

### Appearance and other panels

- Pair **Pitch Black** border trim with the **Pitch Black** canvas for a borderless look. Labels and selected controls stay visible. On the **Classic Warcraft** theme, the settings header now matches the softer trim around the window.
- On Forever, DaylightUI’s Trainer, Spellbook and Talents panels stay within reach when switching between a single window and a span.
- When you finish reading a book and reload, an empty book window no longer opens on its own. Offhand remembers where you placed the reader for the next time you open a book. Turning pages in a multi-page book on Forever still awaits a live check.

### Known issues

- On Forever, reopening a separate Blizzard backpack with B during combat after it was restored can still show a yellow interface warning. The backpack opens at its saved spot. B reopens the backpack only.
- When spanning monitors of different sizes, the loading artwork can appear cropped. Your in-game view returns to its assigned display once loading finishes.
- DaylightUI 2.2.3 can report a Lua error when the window is resized with a trainer list open. The training list stayed visible in our test, and the same error occurred with the Offhand add-on disabled.

### Community thanks

Beta 39 builds on earlier GitHub contributions from these players and developers.

- **@Iceskull7** added the WoW window picker in Companion. [#131](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/131)
- **@bitwize01 (Frosted)** helped Forever use the right HUD when playing with a controller. **@paramboy (Michele)** helped bring Retail’s XP and reputation bars back onto the game screen. [#18](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/18), [#45](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/45)
- **@N4UX-GIT** contributed setup guidance, Wine improvements, map and bag controls, and better window placement during combat. Thanks to **@victormolla14** for reporting the Wine issue and **@bitwize01** for helping check the fix. [#19](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/19), [#100](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/100), [#107](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/107), [#128](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/128), [#129](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/129), [#130](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/130)
- Thanks also to **@dependabot** for maintaining the project’s checks and release tools. [#43](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/43), [#103](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/103), [#104](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/104), [#105](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/105)
