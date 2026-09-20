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
*   **The Companion App:** A tiny, open-source tool that removes the Windows title bar and stretches the game across your screens with one click.

---

## 🛠️ Installation & Setup

1.  **Install the Addon:** Download the addon from [CurseForge](https://www.curseforge.com/wow/addons/offhand) or install it via your preferred addon manager.
2.  **Get the Companion App (Highly Recommended):** Download the Offhand.exe Companion App from the [GitHub Releases page](https://github.com/N4UX-GIT/Offhand-DualMonitor/releases) and run it alongside WoW.

> [!NOTE]
> **Windows SmartScreen:** Because the Companion App is an independent, open-source executable, Windows Defender SmartScreen may flag it as an "unrecognized app" on first launch. This is completely normal. Simply click **"More info" -> "Run anyway"**.

3.  **Set WoW to Windowed Mode:** In WoW's Graphics settings, set Display Mode to **Windowed**. 
4.  **Span Your Window:** If using the Companion App, click **Span Now** (or press Ctrl+Alt+S). The app will instantly strip the borders and stretch your game seamlessly across both monitors.
5.  **Run the Wizard:** Type /offhand wizard in-game. The automated setup will detect your monitors, adjust the seam, and scale your UI perfectly in 4 easy steps.

### Manual Fallback (No Companion App)
The Companion App is highly recommended for a clean, borderless experience, but it's totally optional. If you don't want to run external apps, you can do it manually:

1. Set WoW to **Windowed** mode.
2. Grab the edges of the game window and manually drag them across both of your monitors.
3. The Offhand addon will instantly notice the massive new window size and split your UI automatically.

**Note:** If you do it manually, you'll still have the standard Windows Title Bar across the top of your game. The Companion App exists purely to hide that bar and automate the stretching for you.

---

## ⚙️ Configuration & Commands

Type /offhand (or /oh) to open the main configuration dashboard.

*   **Display:** Swap which monitor is your Mainhand/Offhand, adjust aspect ratio, tweak the seam boundary, and configure global UI scale.
*   **Offhand Monitor:** Customize the map size, toggle independent panel persistence, and set up automatic routing for bags and UI frames.
*   **Themes:** Choose from various Warcraft-style presets and custom colors for your Offhand Monitor background and border accents.
*   **Profiles:** Create, load, and copy settings profiles across your characters.

### Forever Beta: Action Bars and Combat Frames

Forever Beta uses Blizzard Edit Mode as the owner of action bars and combat frames. Offhand deliberately does not move those protected HUD frames because doing so can taint Edit Mode and break party or raid frame updates.

While outside combat, open Blizzard Edit Mode, move your action bars and combat frames onto the Mainhand Monitor, save the layout with the exact name **Offhand**, and select it there. Offhand does not switch Edit Mode layouts automatically because delayed layout changes can move or hide protected frames. Select your normal layout again when returning to one monitor.

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

To return to one monitor, simply disable Offhand's dual-monitor mode in-game, and click **Restore Window** in the Companion App (or press Ctrl+Alt+R) to snap WoW back to a single screen.




