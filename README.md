<div align="center">
  <img src="https://raw.githubusercontent.com/N4UX-GIT/Offhand-DualMonitor/main/Website/assets/offhand-banner.png" alt="Offhand Logo" width="100%">
  
  # Offhand: Multi-Monitor Setup for World of Warcraft
  
  **Equip your Offhand. Dual wield your monitors.**
  
  Playing WoW stretched across two monitors usually sucks: your character is split by the bezel, and your UI is a mess. Offhand fixes this. It keeps your game centered on your **Mainhand Monitor**, and turns your second screen into a dedicated **Offhand Monitor** for your map, bags, and bulky interface panels.
  
  [![Download on CurseForge](https://img.shields.io/badge/CurseForge-Download-f56e0f?style=for-the-badge&logo=curseforge)](https://www.curseforge.com/wow/addons/offhand)
  [![Get Offhand Companion from Microsoft Store](https://img.shields.io/badge/Get_it_from-Microsoft_Store-0078D4?style=for-the-badge&logo=microsoft)](https://apps.microsoft.com/detail/9PL4PW84Q90W)
  [![Portable, Linux, and manual options](https://img.shields.io/badge/Companion-Portable_%26_manual_options-181717?style=for-the-badge&logo=github)](https://offhand-wow.onrender.com/companion.html)
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

1.  **Install the Addon:** Download the addon from [CurseForge](https://www.curseforge.com/wow/addons/offhand) or install it via your preferred addon manager. For a manual ZIP install, the TOC files must be directly inside `Interface/AddOns/Offhand`; `Interface/AddOns/Offhand/Offhand/Offhand_Forever.toc` is one folder too deep.
2.  **Choose a spanning method:** For Windows, install the Companion from the [Microsoft Store](https://apps.microsoft.com/detail/9PL4PW84Q90W) for a Store-signed package and Microsoft-managed updates. Review the [Companion download and security status](https://offhand-wow.onrender.com/companion.html), or use the [v2.1.2 Beta 20 Companion ZIP from GitHub](https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/download/v2.1.2-beta.20/Offhand-Companion.zip) as the portable and Linux/Wine alternative. Beta 20 adds distribution-aware updates: Microsoft Store installations open the Store product page, while portable installations retain the explicit GitHub release check. Microsoft Security Intelligence reviewed the exact canonical Beta 20 ZIP without finding a positive detection or telemetry indicators; the hash-specific record is documented in [SECURITY.md](SECURITY.md). The unsigned standalone EXE may still produce an Edge **"isn't commonly downloaded"** reputation notice; that notice is not a malware verdict. The [no-executable manual setup](https://offhand-wow.onrender.com/manual-spanning.html) remains available. Companion v2.1.2 Beta 20 remains compatible with protocol 1 and the Beta 19 minimum-version baseline.

Linux users should read [Companion/Linux.md](Companion/Linux.md). The current
binary remains a Windows application; running it under Wine is an experimental
compatibility path, while a native Linux window-control backend is future work.
The Companion must be launched as the same user, in WoW's exact `WINEPREFIX`,
and with the same Wine/Proton runner version as Battle.net/WoW. The Linux guide
includes a Lutris pre-launch example and addon extraction troubleshooting.

### Experimental WotLK 3.3.5a support

The addon now declares the original Wrath `30300` interface and includes a
legacy-only compatibility layer for APIs introduced after 3.3.5a. Use manual
window spanning for the initial test cycle. This target has passed static and
simulated compatibility tests, but it is not considered fully supported until
login, `/reload`, configuration, viewport, bag, map, and combat-lockdown tests
have been completed on a genuine 3.3.5a client. Please include the complete Lua
error and `/offhand diag` output with any report. See the
[3.3.5a test matrix](docs/WOTLK-335A-TESTING.md) for the required validation.

> [!IMPORTANT]
> **Verify the Companion before running it.** Official GitHub releases include SHA-256 checksums. Releases built by GitHub Actions may additionally provide a build-provenance attestation; check the individual release notes rather than assuming one exists. Prefer `Offhand-Companion.zip`. An unsigned EXE may still produce a Windows SmartScreen reputation warning; never bypass any warning for a file obtained from an unofficial source. Follow the verification steps and warning guide in [SECURITY.md](SECURITY.md).

3.  **Set WoW to standard Windowed Mode:** In WoW's Graphics settings, set Display Mode to **Windowed**, not Windowed (Fullscreen). In Windows Display Settings, arrange the monitor rectangles to match their physical left/right and top/bottom edge alignment; an accidental vertical offset creates unreachable canvas space.
4.  **Choose displays and span:** In Companion, select exactly two displays and choose the **Mainhand (game)** display. The other becomes the workspace. Use **Identify Displays** if the Windows display numbers are unclear. For one 32:9/32:10 screen, select only it and explicitly enable **Single-display 32:9 split**. Automatic spanning is disabled by default; launch WoW and click **Span WoW Now** after it starts.
5.  **Finish the setup wizard:** The first-launch guide now records either **Use Companion** or **Configure Manually** and resumes that path across `/reload`. If WoW was already loaded when Companion changed the span, use the guide's **Reload UI** button; manual resizing offers the same button as an optional stabilization step. The guide waits for display geometry to settle before validation. Then complete calibration. On Forever and Retail, the final step is **Create Mainhand HUD Layout**; press it outside combat with Edit Mode closed. If Blizzard's layout limit or an unavailable Edit Mode API prevents creation, **Finish Without HUD Layout** completes onboarding only after an explicit warning and reports the result as a degraded setup. The 3D viewport and ordinary workspace windows still work, and **Recovery & Preview** remains available to repair the protected HUD later.
6.  **Reload the protected HUD when available:** On any client that exposes the required Blizzard Edit Mode layout APIs—including Retail, Forever, and current Classic branches that ship a compatible Edit Mode—reload when prompted. Offhand clones the active Blizzard layout, moves default HUD anchors into the Mainhand rectangle, aligns XP with the Action Button 1/backpack boundaries, and arranges stance, pet, possess, vehicle-exit, encounter, and extra-ability controls above it. Custom-positioned source entries are preserved. **Recovery & Preview** can rebuild the layout later. Clients without those APIs finish after the four-step calibration wizard instead.
7.  **Fine-tune protected HUD frames:** On Forever or Retail, open Blizzard Edit Mode after the reload, adjust the generated `Offhand - Mainhand - <Character>` layout if desired, and save it. On Forever, return to Recovery & Preview and click **Use Current Edit Mode Layout** so that character can recover it after display changes.
8.  **Verify a cold launch:** Exit WoW normally, leave Companion running, and relaunch. Workspace panels, their open state, Blizzard HUD placement, and the Edit Mode options frame should return correctly. A Forever native backpack left open on the Offhand canvas should reopen; one explicitly closed with B or its close button should remain closed.

The final wizard screen and completion message summarize the chosen topology source, Mainhand and workspace dimensions, Mainhand side, aspect/seam calibration, protected-HUD state, and recovery level. A generated Mainhand HUD is **fully ready**; choosing **Finish Without HUD Layout** is intentionally labelled **degraded** until repaired. The cold-launch check is recommended but does not block completion.

The Display tab option **Use raw mouse input while Offhand is spanned** is enabled by default. Keep it enabled if vertical camera movement eventually stops while holding the right mouse button. Offhand remembers the previous `rawMouseEnable` value and restores it when the layout is no longer spanned, Offhand is disabled, or the client logs out.

### Why Forever currently relies on Companion

WoW addon code cannot resize or borderlessly span the Windows game client. The Forever beta also currently writes Offhand's SavedVariables but may fail to restore them reliably on the next client launch. Companion v2.1.2+ solves both sides: it spans the selected displays, removes the window borders, waits until WoW has fully closed, snapshots the newest valid Offhand state, and restores that state before the next cold launch.

This recovery bridge is specific to the current Forever client behavior. The addon remains usable with manual spanning or another window manager on all supported clients, including Forever, but manual Forever setups do not gain reliable cold-launch state recovery.

During a running Forever session, Offhand also keeps a versioned, data-only copy
of its account and character state in registered CVars so `/reload` cannot revert options,
geometry, themes, frame positions, or recovery state. Normal SavedVariables are
still preferred whenever their revision proves that the client loaded the latest
table, so this fallback automatically becomes inactive after a client fix.

### Exact topology and missing-monitor safety

The current Companion passes the addon's exact Mainhand and workspace rectangles instead of making Offhand guess from the combined window resolution. Mixed resolutions and heights, portrait/landscape pairs, stacked displays, negative Windows coordinates, ultrawide Mainhand screens, and the explicit one-screen super-ultrawide split therefore use their native geometry without manual width/height compensation.

For a lower-resolution display, its workspace remains that display's real pixel
rectangle; it is not stretched to the height or scale of the larger monitor.
Windows display arrangement determines any vertical offset or unused part of the
combined canvas. The explicit one-screen 32:9/32:10 mode is currently an equal
50/50 split. While exact Companion topology is active, the in-game seam control
is disabled and cannot resize that split.

A single 21:9 display can use the manual path. Size Windowed WoW to the display,
confirm that the split is intentional at onboarding Step 4, and calibrate the
side and seam. Auto-Configure preserves a 16:9 Mainhand region and assigns the
remaining width to the Offhand workspace. The addon cannot query physical
monitor boundaries, so manual layouts are explicitly confirmed rather than
claimed as automatically detected.

Display choices are persisted by Windows device identity. If a saved display disconnects while WoW is spanned, Companion v2.1.2 restores a bordered WoW window that fills the surviving Mainhand work area. It also refuses another span until the saved topology is available. Offhand ignores the stale topology and restores a normal full-window viewport. On Forever, Blizzard requires protected Edit Mode layout changes to originate from a player click, so Offhand offers **Use Modern** when the workspace disappears and **Restore Offhand** when the exact topology returns. Reconnect the display or review the selection; Offhand will not silently compress a dual-screen profile onto one travel screen.

If a generated Companion topology no longer matches the current window, Offhand
fails safe to the full current window and preserves the saved workspace layout.
An absent topology is the normal packaged state for manual spanning, so Offhand
uses the selected orientation, seam percentage, and aspect-ratio controls. After
**Span WoW Now**, use `/reload` once if WoW was already open so the Companion's
exact rectangles become active.

Addon managers and manual source copies can replace the generated topology file
with the packaged placeholder. While WoW remains exactly spanned, Companion
Beta 19 and later automatically repairs that handoff without moving the window
and records that one `/reload` is required in its activity log.

### Manual Fallback (No Companion App)
Manual spanning remains available on Retail, Classic, and Forever clients, but it does not provide Forever's reliable cold-launch state recovery:

See the complete [manual spanning guide](https://offhand-wow.onrender.com/manual-spanning.html).

1. Set WoW to **Windowed** mode.
2. Grab the edges of the game window and manually drag them across both monitors. For one ultrawide, size WoW to that display instead.
3. At onboarding Step 4, confirm that you deliberately prepared a dual-display or single-ultrawide layout. The calibration wizard then sets the Mainhand side, seam and aspect ratio.

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

During first-time setup, the Wizard's final **Create Mainhand HUD Layout** action clones the active Blizzard layout, preserves custom-positioned entries, moves default HUD anchors into Mainhand, selects the generated layout, and requests a reload. If creation cannot succeed, **Finish Without HUD Layout** records a per-character deferral and completes onboarding without claiming that protected frames were repaired. The normal repair prompt stays suppressed, while **Recovery & Preview** remains available for an explicit later retry. Use Blizzard Edit Mode afterward only for personal fine-tuning. On Forever, click **Use Current Edit Mode Layout** in Recovery & Preview after saving those personal changes. The designation is stored per character rather than in a shared Offhand settings profile. Recovery resolves the saved name before using its numeric slot, so reordered custom layouts cannot select an unrelated profile. If a saved display disappears while Offhand is active, click **Use Modern** in the recovery prompt for a readable single-screen HUD. When the exact topology returns, click **Restore Saved Layout**.

Offhand leaves the Edit Mode manager and protected HUD frames entirely under Blizzard ownership. If its controls are inaccessible after spanning, close Edit Mode, click **Restore Window**, then use **Recovery & Preview → Create Mainhand HUD Layout** outside combat and reload when prompted. Click **Span WoW Now** again if the window was restored. Use **Gather Off-Screen UI** only for ordinary movable panels.


### Slash Commands
| Command | Effect |
| :--- | :--- |
| /offhand or /oh | Opens the configuration dashboard. |
| /offhand wizard | Launches the interactive setup wizard. |
| /offhand gather | Rescues any off-screen windows and pulls them back to your Mainhand Monitor. |
| /offhand diag | Prints a concise support snapshot for topology, combat text, speech bubbles, group loot, Edit Mode, and loaded compatibility addons. |

---

## 🛟 Offhand Monitor Recovery

Drag supported windows by their headers between either monitor freely. 
If you accidentally drag a window off-screen or change your monitor configuration and lose a panel, click the **Gather Off-Screen UI** button in the settings, or type /offhand gather. This instantly moves any eligible open windows with inaccessible title edges safely back to the Mainhand Monitor. 

To return to one monitor, simply disable Offhand's dual-monitor mode in-game, and click **Restore Window** in the Companion App to restore the bordered bounds remembered before the first span. If a saved display disconnects, automatic recovery still fills the surviving Mainhand. The display controls refresh automatically when Windows reports a monitor connection change.

On Forever, exit WoW normally before closing Companion. Companion only refreshes the cold-start recovery snapshot after the WoW process has fully stopped.




