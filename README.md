<div align="center">
  <img src="https://raw.githubusercontent.com/N4UX-GIT/Offhand-DualMonitor/main/Website/assets/offhand-banner.png" alt="Offhand Logo" width="100%">
  
  # Offhand: Multi-Monitor Setup for World of Warcraft
  
  **Equip your Offhand. Dual wield your monitors.**
  
  Offhand transforms dual displays into a dedicated 3D gaming viewport and a persistent secondary utility space. It locks your 3D gameplay to your **Mainhand Monitor** while turning your secondary screen into a highly customizable **Offhand Monitor** for your map, bags, character sheets, and other UI panels.
  
  [![Download on CurseForge](https://img.shields.io/badge/CurseForge-Download-f56e0f?style=for-the-badge&logo=curseforge)](https://www.curseforge.com/wow/addons/offhand)
  [![Get Companion App](https://img.shields.io/badge/GitHub_Releases-Companion_App-181717?style=for-the-badge&logo=github)](https://github.com/N4UX-GIT/Offhand-DualMonitor/releases)
</div>

---

## 🚀 Features

*   **Flawless Dual-Monitor Topology:** Instantly splits your screen real estate. The **Mainhand Monitor** renders the 3D game world perfectly centered and scaled, while the **Offhand Monitor** is dedicated entirely to your UI panels.
*   **Persistent Offhand Monitor:** Keep your map, bags, spellbook, and character pane open simultaneously on your Offhand Monitor without them closing when you press Escape or enter combat.
*   **Fully Dynamic Layout Engine:** Supports any monitor arrangement (e.g., standard 16:9 Landscape next to a vertical 9:16 Portrait, or dual Ultrawides).
*   **Bezel Compensation & OBS Support:** Hide the physical bezel gap between your monitors perfectly. Included OBS instructions allow you to stream without the gap visible to viewers.
*   **The Companion App:** A lightweight, optional C# executable that automatically strips the Windows title borders and spans your game window flawlessly across multiple monitors on launch.

---

## 🛠️ Installation & Setup

1.  **Install the Addon:** Download the addon from [CurseForge](https://www.curseforge.com/wow/addons/offhand) or install it via your preferred addon manager.
2.  **Get the Companion App (Highly Recommended):** Download the Offhand.exe Companion App from the [GitHub Releases page](https://github.com/N4UX-GIT/Offhand-DualMonitor/releases) and run it alongside WoW.
3.  **Set WoW to Windowed Mode:** In WoW's Graphics settings, set Display Mode to **Windowed**. 
4.  **Span Your Window:** If using the Companion App, click **Span Now** (or press Ctrl+Alt+S). The app will instantly strip the borders and stretch your game seamlessly across both monitors.
5.  **Run the Wizard:** Type /offhand wizard in-game. The automated setup will detect your monitors, adjust the seam, and scale your UI perfectly in 4 easy steps.

### Manual Fallback (No Companion App)
While highly recommended for a borderless, automated experience, the Companion App is strictly optional. The Offhand layout engine automatically recalculates all math based on the physical pixel dimensions of the game window, regardless of how it gets sized. If you prefer not to run external applications, you can achieve the same result manually:

1. Open WoW's Graphics settings and set Display Mode to **Windowed**.
2. Manually grab the edges of the game window and stretch them completely across both of your monitors.
3. Because the window now encompasses your entire desk, the Offhand addon will instantly detect the massive new dimensions and seamlessly split your UI onto the Offhand Monitor, and the 3D Game View onto the Mainhand Monitor.

**Note:** If you use this manual method, you will see the standard Windows Title Bar stretching across the top of your game. The Companion App's primary purpose is to simply strip that title bar off and automate the spanning process for you perfectly.

---

## ⚙️ Configuration & Commands

Type /offhand (or /oh) to open the main configuration dashboard.

*   **Display:** Swap which monitor is your Mainhand/Offhand, adjust aspect ratio, tweak the seam boundary, and configure global UI scale.
*   **Offhand Monitor:** Customize the map size, toggle independent panel persistence, and set up automatic routing for bags and UI frames.
*   **Themes:** Choose from various Warcraft-style presets and custom colors for your Offhand Monitor background and border accents.
*   **Profiles:** Create, load, and copy settings profiles across your characters.

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
