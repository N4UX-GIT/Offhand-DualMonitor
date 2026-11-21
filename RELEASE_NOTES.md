<!-- offhand-companion-version: 2.1.9-beta.1 -->

# Offhand 2.1.5 Pre-Release Beta 37

Offhand Beta 37 pairs the in-game add-on with Windows Companion 2.1.9-beta.1.

### Maps, bags and panels

- Adjust map scale by dragging the slider or using the keyboard. The native map now uses its saved scale on Mainhand and keeps its title reachable when dropped near the top of Offhand.
- Bind the expanded map to return to the compact Offhand map when closed. On Forever, the native map stays closed after login or reload until you press M.
- Choose whether a second map or bag keypress keeps the window open on Offhand outside combat. Escape closes gossip and Inspect before clearing the target while the separate backpack stays in place.
- RestedXP keeps control of its guide position and Escape behavior, including when upgrading from a profile with old guide coordinates. Spoken Places stays with its map.
- On short workspaces, Character and Social fit side by side, including Character's tabs. Collections, Professions, the compact Spellbook and the quest list have better bounds. Chat and its input box stay on Mainhand when assigned there.
- Corrected Gold and Silver settings trim, the party management drawer, and placement of native error text on Mainhand.

### Profiles and Companion

- Choose a personal HUD or a compatible account-wide layout in Profiles. Setup and reset guidance now explain Windows display alignment and which profile data will be cleared.
- Select the running WoW client you want Companion to span. The updated dashboard keeps its section header clear and its client selector border visible. Wine verification and automatic span retries have also been improved.

### GitHub contributors

- **@bitwize01 (Frosted)** contributed active Gamepad UI detection for Forever layout generation and recovery. [PR #18](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/18)
- **@paramboy (Michele)** contributed the Retail default status-bar placement repair. [PR #45](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/45)
- **@Iceskull7** contributed the running-client selector for Companion. [PR #131](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/131)
- **@N4UX-GIT** contributed Wine verification, setup and Help updates, Forever map and invite placement, inventory Escape handling, and combat panel placement. Thanks to **@victormolla14** for the Wine report and **@bitwize01** for confirming the fallback. [PR #19](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/19), [PR #100](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/100), [PR #107](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/107), [PR #128](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/128), [PR #129](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/129), [PR #130](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/130)
- **@dependabot** maintained the Lua, CodeQL and release workflows. [PR #43](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/43), [PR #103](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/103), [PR #104](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/104), [PR #105](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/105)

### Forever testing

On Moonweaver's 1440 × 600 workspace, the native backpack, gossip, Inspect, map, Social, Character and Collections passed their tested interactions. The expanded Spellbook could still fail to open in combat with Offhand disabled. Flight masters, additional bags and Talents remain follow-up checks.
