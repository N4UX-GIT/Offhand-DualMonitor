<div align="center">
  <img src="https://raw.githubusercontent.com/N4UX-GIT/Offhand-DualMonitor/main/Website/assets/offhand-banner.png" alt="Offhand Logo" width="100%">
  
  # Offhand: Multi-Monitor Setup for World of Warcraft
  
  **Equip your Offhand. Dual wield your monitors.**
  
  Playing WoW stretched across two monitors usually sucks: your character is split by the bezel, and your UI is a mess. Offhand fixes this. It keeps your game centered on your **Mainhand Monitor**, and turns your second screen into a dedicated **Offhand Monitor** for your map, bags, and bulky interface panels.
  
  [![Download on CurseForge](https://img.shields.io/badge/CurseForge-Download-f56e0f?style=for-the-badge&logo=curseforge)](https://www.curseforge.com/wow/addons/offhand)
  [![Companion Downloads](https://img.shields.io/github/downloads/N4UX-GIT/Offhand-DualMonitor/total?style=for-the-badge&color=blue&logo=github)](https://github.com/N4UX-GIT/Offhand-DualMonitor/releases)
  [![Get Companion App](https://img.shields.io/badge/GitHub_Releases-Companion_App-181717?style=for-the-badge&logo=github)](https://github.com/N4UX-GIT/Offhand-DualMonitor/releases)
</div>

---

## 🚀 Features

*   **True Dual-Monitor Support:** No more UI elements split down the middle of your screens. The game stays focused on your main monitor, while your bulky UI panels are routed to your second screen.
*   **Persistent Panels:** Keep your world map, bags, and character sheet open on your second screen without cluttering your game view. They stay open even while you're moving around.
*   **Mix & Match Monitors:** Got a 4K main screen and a 1080p vertical monitor on the side? Offhand handles asymmetrical layouts, mixed resolutions, and different refresh rates naturally.
*   **Hide the Bezel:** Offhand calculates the physical plastic gap between your monitors so the game world flows behind it instead of warping. Streaming? The included OBS guide shows you how to broadcast a clean, gap-free feed.
*   **The Companion App:** A tiny, open-source tool that removes the Windows title bar, spans WoW across selected displays, and restores Forever layouts across cold launches.
*   **Reliable Camera Input:** While spanned, Offhand enables WoW's raw mouse input so repeated right-button camera movement cannot exhaust the hidden cursor against a mixed-height window edge. The player's previous setting is restored outside the span.

---

## 🛠️ Installation & Setup

1.  **Install the Addon:** Download the addon from [CurseForge](https://www.curseforge.com/wow/addons/offhand) or install it via your preferred addon manager.
2.  **Get Companion v2.1.2 or newer:** Download the Companion App from the [GitHub Releases page](https://github.com/N4UX-GIT/Offhand-DualMonitor/releases), extract it, and start it before WoW. It is required for exact-topology setup, safe missing-monitor recovery, and reliable cold-launch restoration on the current Forever beta, and strongly recommended on other clients.

> [!IMPORTANT]
> **Verify the Companion before running it.** Official GitHub releases include SHA-256 checksums and a GitHub build-provenance attestation. An unsigned or low-reputation build may still produce a Windows SmartScreen warning; never bypass a warning for a file obtained from an unofficial source. Follow the verification steps in [SECURITY.md](SECURITY.md).

3.  **Set WoW to standard Windowed Mode:** In WoW's Graphics settings, set Display Mode to **Windowed**, not Windowed (Fullscreen).
4.  **Choose displays and span:** In Companion, select exactly two displays and choose the **Mainhand (game)** display. The other becomes the workspace. For one 32:9/32:10 screen, select only it and explicitly enable **Single-display 32:9 split**. Automatic spanning is disabled by default; launch WoW and click **Span WoW Now** (Ctrl+Alt+S) after it starts.
5.  **Finish the setup wizard:** If WoW was already at the character UI when you spanned it, type `/reload` once. Then type `/offhand wizard` and complete the setup flow.
6.  **Forever only — configure protected HUD frames:** Outside combat, open Blizzard Edit Mode. Move action bars, player/target, stance, pet, party, and raid frames onto the Mainhand Monitor. Save the layout with the exact name **Offhand** and select it.
7.  **Verify a cold launch:** Exit WoW normally, leave Companion running, and relaunch. Workspace panels, their open state, Blizzard HUD placement, and the Edit Mode options frame should return correctly.

The Display tab option **Use raw mouse input while Offhand is spanned** is enabled by default. Keep it enabled if vertical camera movement eventually stops while holding the right mouse button. Offhand remembers the previous `rawMouseEnable` value and restores it when the layout is no longer spanned, Offhand is disabled, or the client logs out.

### Why Forever currently relies on Companion

WoW addon code cannot resize or borderlessly span the Windows game client. The Forever beta also currently writes Offhand's SavedVariables but may fail to restore them reliably on the next client launch. Companion v2.1.2+ solves both sides: it spans the selected displays, removes the window borders, waits until WoW has fully closed, snapshots the newest valid Offhand state, and restores that state before the next cold launch.

This recovery bridge is specific to the current Forever client behavior. The addon remains usable with manual spanning or another window manager on other WoW clients.

During a running Forever session, Offhand also keeps a versioned, data-only copy
of its account and character state in registered CVars so `/reload` cannot revert options,
geometry, themes, frame positions, or recovery state. Normal SavedVariables are
still preferred whenever their revision proves that the client loaded the latest
table, so this fallback automatically becomes inactive after a client fix.

### Exact topology and missing-monitor safety

The current Companion passes the addon's exact Mainhand and workspace rectangles instead of making Offhand guess from the combined window resolution. Mixed resolutions and heights, portrait/landscape pairs, stacked displays, negative Windows coordinates, ultrawide Mainhand screens, and the explicit one-screen super-ultrawide split therefore use their native geometry without manual width/height compensation.

Display choices are persisted by Windows device identity. If a saved display disconnects while WoW is spanned, Companion v2.1.2 restores a bordered WoW window that fills the surviving Mainhand work area. It also refuses another span until the saved topology is available. Offhand ignores the stale topology and restores a normal full-window viewport. On Forever, Blizzard requires protected Edit Mode layout changes to originate from a player click, so Offhand offers **Use Modern** when the workspace disappears and **Restore Offhand** when the exact topology returns. Reconnect the display or review the selection; Offhand will not silently compress a dual-screen profile onto one travel screen.

### Manual Fallback (No Companion App)
Manual spanning remains available on Retail and Classic clients, but it does not provide Forever's reliable cold-launch state recovery:

1. Set WoW to **Windowed** mode.
2. Grab the edges of the game window and manually drag them across both of your monitors.
3. The Offhand addon will instantly notice the massive new window size and split your UI automatically.

**Note:** Manual spanning leaves the Windows title bar visible and must be repeated after launch. On Forever, panel positions and open state may not survive a complete client restart without the Companion recovery bridge.

---

## ⚙️ Configuration & Commands

Type /offhand (or /oh) to open the main configuration dashboard.

*   **Display:** Swap which monitor is your Mainhand/Offhand, adjust aspect ratio, tweak the seam boundary, and configure global UI scale.
*   **Offhand Monitor:** Customize the map size, toggle independent panel persistence, and set up automatic routing for bags and UI frames.
*   **Themes:** Choose from various Warcraft-style presets and custom colors for your Offhand Monitor background and border accents.
*   **Profiles:** Create, load, and copy settings profiles across your characters.

### Forever Beta: Action Bars and Combat Frames

Forever Beta uses Blizzard Edit Mode as the owner of action bars and combat frames. Offhand deliberately does not move those protected HUD frames because doing so can taint Edit Mode and break party or raid frame updates.

While outside combat, open Blizzard Edit Mode, move your action bars and combat frames onto the Mainhand Monitor, save the layout with the exact name **Offhand**, and select it there. During normal spanned operation Offhand leaves layout selection to Blizzard Edit Mode. If a saved display disappears while Offhand is active, click **Use Modern** in Offhand's recovery prompt for a readable single-screen HUD. When the exact topology returns, click **Restore Offhand**. A layout you choose manually is never silently replaced.

Offhand positions the Edit Mode options frame inside the Mainhand viewport after Companion spanning. If controls are inaccessible during recovery, click **Restore Window**, enter Edit Mode, then click **Span WoW Now**. Use **Gather Off-Screen UI** only for ordinary movable panels; protected HUD frames remain owned by Blizzard Edit Mode.

### Slash Commands
| Command | Effect |
| :--- | :--- |
| /offhand or /oh | Opens the configuration dashboard. |
| /offhand wizard | Launches the interactive setup wizard. |
| /offhand gather | Rescues any off-screen windows and pulls them back to your Mainhand Monitor. |
| /offhand diag | Prints detailed viewport diagnostic math to the chat box for debugging. |

---

## 🛟 Offhand Monitor Recovery

Drag supported windows by their headers between either monitor freely. 
If you accidentally drag a window off-screen or change your monitor configuration and lose a panel, click the **Gather Off-Screen UI** button in the settings, or type /offhand gather. This instantly moves any eligible open windows with inaccessible title edges safely back to the Mainhand Monitor. 

To return to one monitor, simply disable Offhand's dual-monitor mode in-game, and click **Restore Window** in the Companion App (or press Ctrl+Alt+R) to fill the selected connected Mainhand with a bordered WoW window. The display controls refresh automatically when Windows reports a monitor connection change.

On Forever, exit WoW normally before closing Companion. Companion only refreshes the cold-start recovery snapshot after the WoW process has fully stopped.




