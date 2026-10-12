**Offhand - Dual-Screen and Multi-Monitor UI | v2.1.2 PRE-RELEASE (BETA 21)**

![Offhand Logo](https://raw.githubusercontent.com/N4UX-GIT/Offhand-DualMonitor/main/Website/assets/offhand-logo.png)

## Equip Your Offhand. Dual-Wield Your Monitors.

**Have you ever wanted to keep your bags, map, character screen, chat, and meters open without burying the world underneath your UI?**

World of Warcraft was designed around one centered screen. Stretch the game across two monitors and the normal result is a character divided by the bezel, a distorted view, and interface panels that still open in the wrong place. Keep WoW on one monitor instead, and the second display becomes little more than a place for a browser.

Blizzard's native UI tools can move frames, but they cannot move the 3D rendering viewport away from the center of a spanned game window.

**Offhand was built to solve that exact frustration.**

Offhand turns your displays into a coordinated play surface. Your **Mainhand** is where the action stays: the 3D world, your character, and your targeting reticle remain properly centered. Your **Offhand** becomes a dedicated workspace for the map, bags, character panels, chat, meters, and other supported interface elements.

The result is not simply a wider game window. It is a dual-screen World of Warcraft layout designed around how two monitors are actually used:

* Keep the game world clean and unobstructed on Mainhand.
* Leave useful panels open on Offhand without covering combat or exploration.
* Avoid placing your character or camera across the physical bezel.
* Use two separate displays or divide one 32:9/32:10 super-ultrawide into game and workspace halves.

**Equip your Offhand. Dual-Wield Your Monitors.**

![Offhand Desk Setup](https://raw.githubusercontent.com/N4UX-GIT/Offhand-DualMonitor/main/Website/assets/offhand-irl.jpg)

_The complete Offhand setup on a real desk: unobstructed gameplay on Mainhand, with maps, bags, character panels, and other UI safely available on the Offhand display._

![Offhand In-Game Screenshot](https://raw.githubusercontent.com/N4UX-GIT/Offhand-DualMonitor/main/Website/assets/offhand-screenshot.jpg)

_What WoW actually renders across the combined play surface. The 3D world remains centered on Mainhand while the extended UI canvas uses both displays. Black padding may appear in screenshots when displays have different heights, but that area sits outside the visible physical screens during play._

**Beta 21 is the current public addon release.** It is published as a beta while testing continues across different display arrangements, Windows scaling settings, WoW clients, and third-party UI addons.

***

## Download and Quick Start

### 1. Install the in-game addon

Install Offhand through CurseForge, WowUp, or manually place the `Offhand` folder in `Interface\AddOns`.

The CurseForge addon contains Lua addon code only. It does **not** contain the separate Windows Companion application.

### 2. Choose how to span WoW

#### Recommended for Windows

[![Get Offhand Companion from the Microsoft Store](https://img.shields.io/badge/Get_it_from-Microsoft_Store-0078D4?style=for-the-badge&logo=microsoft)](https://apps.microsoft.com/detail/9PL4PW84Q90W)

The Microsoft Store provides a signed, managed installation and handles future Companion updates. The certified Beta 20 Companion is now available through the Store.

#### Portable, Linux/Wine, or direct download

[![Download the reviewed Beta 20 Companion ZIP](https://img.shields.io/badge/Download-Beta_20_Companion_ZIP-2EA44F?style=for-the-badge&logo=github)](https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/download/v2.1.2-beta.20/Offhand-Companion.zip)

The portable ZIP is hosted on the official Offhand GitHub release, not by CurseForge. Only obtain the Companion from the Microsoft Store or the official Offhand GitHub repository.

[View the Companion Beta 20 GitHub release and checksums](https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/tag/v2.1.2-beta.20)

You can also span the WoW window manually or use NVIDIA Surround, AMD Eyefinity, or a suitable operating-system window manager. The Companion is optional on most clients, but the current WoW Forever beta requires it for reliable layout recovery across complete client restarts.

### 3. Configure Offhand

1. Set WoW to standard **Windowed** mode, not Windowed (Fullscreen).
2. Start the Companion before WoW. For the initial setup, leave **Auto-span WoW on launch** disabled.
3. Launch WoW, select your character, and wait until that character has fully entered the game world. The **Welcome to Offhand** first-launch guide should open automatically. Do not span WoW from the login or character-selection screen because addons are not loaded there and the unadjusted interface can appear stretched or misplaced.
4. Follow the numbered first-launch guide. In the Companion, select exactly two displays and choose the Mainhand display, then click **Span WoW Now**. For one 32:9/32:10 super-ultrawide, select that display and enable **Single-display 32:9 split** before spanning.
5. Return to the first-launch guide in WoW and click **Reload UI**. After the reload, continue the guide. It verifies the Companion topology and then hands you directly into the display calibration wizard.
6. Complete the calibration wizard and move supported maps, bags, character panels, and chat windows onto the Offhand workspace.

If the first-launch guide was closed or does not appear, type `/offhand guide` to reopen it. Use `/offhand wizard` only when you need to open the calibration wizard directly.

On Forever and Retail, use the Wizard's player-initiated **Create Mainhand HUD Layout** action for protected Blizzard HUD frames. Press it outside combat with Blizzard Edit Mode closed, then reload when prompted.

[Full Companion instructions, manual setup, source code, and troubleshooting](https://offhand-wow.onrender.com/companion.html)

***

## Understanding the Companion App

![Offhand Companion App](https://i.imgur.com/FfxY8yO.png)

### Why does Offhand have a separate application?

World of Warcraft addons run inside Blizzard's restricted Lua environment. An addon can arrange the in-game interface, but it cannot resize the Windows game window, remove its ordinary title bar and borders, identify the physical monitors behind a combined game window, or restore the desktop window after a display changes.

The Companion handles those Windows-level tasks. The addon then uses the display topology supplied by the Companion to keep the 3D game view on Mainhand and place supported interface panels on the Offhand workspace.

The two parts have deliberately separate responsibilities:

* **The Companion manages the Windows game window and display geometry.**
* **The addon manages the World of Warcraft viewport and supported UI panels.**

### What happens when the Companion runs?

The Companion:

1. Looks only for allowlisted World of Warcraft processes and identifies the visible top-level WoW window.
2. Reads the display rectangles reported by Windows and uses the displays and Mainhand selected by the user.
3. Removes the ordinary Windows border and positions the WoW window across the selected desktop area when the user clicks **Span WoW Now**.
4. Writes Offhand-owned topology data containing the selected Mainhand and workspace coordinates. The addon reads that data after `/reload` and adjusts the in-game viewport.
5. Can restore WoW to a normal bordered window, identify displays, pause monitoring, and remain available in the Windows notification area.
6. On WoW Forever, waits until WoW has fully closed before refreshing Offhand's own recovery snapshot for the next cold launch.

The Companion does not move your in-game frames itself. It gives the addon the reliable physical geometry needed to place them correctly.

### Is the Companion optional?

For most supported WoW clients, yes. You can manually stretch the standard Windowed-mode WoW client or use NVIDIA Surround, AMD Eyefinity, or another suitable window manager. The addon can then manage the in-game viewport and supported panels.

The Companion is still the recommended method because it provides:

* One-click spanning and one-click window restoration.
* Explicit Mainhand and workspace selection.
* Exact support for mixed resolutions, display heights, orientations, stacked arrangements, and negative Windows coordinates.
* Display identification and missing-monitor protection.
* A dedicated single-display 32:9/32:10 split mode.
* Consistent topology for the setup guide, diagnostics, and recovery tools.

The current WoW Forever beta can write Offhand SavedVariables without reliably restoring them after a full client restart. Companion v2.1.2 Beta 19 or later is therefore required for reliable Forever cold-launch recovery, even though manual spanning can still create a working layout during the current session.

### How is the Companion designed to remain safe?

The Companion is open source and uses normal Windows window-management and display APIs. It changes only the top-level WoW window's border, position, and dimensions and writes Offhand-owned topology and recovery data.

It does **not**:

* Request administrator access.
* Install a service or driver.
* Inject code into WoW or another process.
* Read or modify WoW process memory.
* Simulate keyboard or mouse input.
* Automate gameplay.
* Download and execute programs.
* Collect telemetry.
* Read browser data, passwords, Discord tokens, or account credentials.
* Register global hotkeys or create a legacy Windows Run-key startup entry.

Microsoft Store installations are certified and signed through the Store and receive updates through Microsoft. The Store package can expose an optional Windows-managed startup task, but it is disabled by default and remains under the user's control in **Windows Settings > Apps > Startup**.

Portable installations check the official GitHub Releases API only when the user clicks **Check for Updates**. Complete source code, build instructions, exact release hashes, and Microsoft submission results are publicly available for independent inspection.

No software description can provide an absolute security guarantee. Users should install Offhand only from the Microsoft Store or the official GitHub repository, verify portable-file hashes, keep Windows Security enabled, and report any named detection rather than overriding it.

***

## Public Service Announcement: Companion Security Status

Earlier unsigned Companion builds received browser warnings and generic antivirus machine-learning detections. Those reports were taken seriously and prompted an audit, removal of nonessential behavior, simplified release packaging, hash-specific submissions to security vendors, and publication through the Microsoft Store.

**Current status (October 9, 2026):** Microsoft Security Intelligence reviewed the exact Beta 20 portable ZIP in [submission `ee73ae7c-cd58-4824-bfe5-647ff24c8251`](https://www.microsoft.com/en-us/wdsi/submission/ee73ae7c-cd58-4824-bfe5-647ff24c8251). Its analyst reported no positive detection or telemetry indicators and stated that the submission would be closed with no further action. Both cloud and client protection report **No malware detected**.

The Microsoft Store remains the recommended Windows installation because it is signed and managed through Microsoft's delivery system.

Canonical Beta 20 hashes:

* `Offhand.exe` SHA-256: `81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`
* `Offhand-Companion.zip` SHA-256: `C726444612DD740BE3F923B83704D155E21BC017F7C5FE245379B19DBECC76E3`

Security results apply to exact file hashes. Older VirusTotal results, locally rebuilt files, or differently generated archives do not describe the current frozen Beta 20 artifacts. Independent antivirus vendors may also retain their own cached or heuristic verdicts.

Do not disable Windows Security or override a named malware detection to install Offhand. If a warning names a threat, stop and report the complete warning, download URL, filename, SHA-256, browser, security product, and definition version.

[Read the complete security history, application behavior, verification instructions, and source-build guidance](https://github.com/N4UX-GIT/Offhand-DualMonitor/blob/main/SECURITY.md)

***

## What Offhand Does

### Main features

* **Mainhand-centered gameplay:** Keeps your character, targeting reticle, and game camera away from the bezel.
* **Dedicated UI workspace:** Move supported maps, bags, character panels, chat windows, and meters away from the main game view.
* **Persistent panel placement:** Remembers supported panel positions and open/closed state.
* **Mixed-display support:** Handles unequal resolutions, different display heights, portrait/landscape pairs, stacked displays, and negative Windows coordinates through exact Companion topology.
* **Super-ultrawide support:** Divides one 32:9/32:10 display into equal game and workspace halves.
* **Bag-addon integration:** Supports Baganator, Bagnon, AdiBags, ArkInventory, BetterBags, and ElvUI without replacing their internal opening logic.
* **Recovery tools:** Gathers eligible off-screen panels, restores the WoW window, and protects saved dual-display layouts when a monitor disconnects.
* **Native localization:** English, German, French, Spanish, Portuguese, Italian, Russian, Korean, Simplified Chinese, and Traditional Chinese.

***

## Commands

* `/offhand` or `/oh`: Open the configuration dashboard.
* `/offhand guide`: Reopen the first-launch setup guide.
* `/offhand wizard`: Start the guided display and viewport setup.
* `/offhand gather`: Gather eligible off-screen panels onto Mainhand.
* `/offhand diag`: Print display and viewport diagnostics for troubleshooting.

***

## Compatibility and Limitations

### Supported clients

* **WoW Classic Era / Hardcore / Season of Discovery:** Supported.
* **Burning Crusade Classic Anniversary:** Supported.
* **Wrath of the Lich King Classic:** Supported on declared official client interfaces.
* **Original Wrath 3.3.5a (`30300`):** Experimental; further real-client testing is required.
* **Cataclysm Classic:** Supported.
* **Mists of Pandaria Classic:** Supported.
* **Retail / Mainline:** Supported.
* **WoW Forever:** Supported with the additional recovery guidance below.

### Windowed mode is required

WoW must run in standard **Windowed** mode for desktop spanning. If the client cannot leave Fullscreen, open `WTF\Config.wtf` and ensure it contains:

`SET gxWindow "1"`

### Mac and Linux

The in-game addon can be used on Mac and Linux with manual spanning or a suitable window manager. The Companion is currently a Windows WinForms application.

Wine support is experimental. WoW and Companion must run as the same user, in the same `WINEPREFIX`, and with the same Wine or Proton runner. Native macOS, X11, and general Wayland Companion support is not currently claimed.

### Third-party UI addons

Many UI addons work normally, but complete compatibility cannot be guaranteed. Offhand includes specific support for several bag and chat addons and deliberately leaves protected or addon-owned frames alone where appropriate. Report conflicts with the addon name, WoW client, reproduction steps, and Lua error.

***

## Frequently Asked Questions

**Does this work on one ultrawide monitor?**

Yes. **Single-display 32:9 split** divides a 32:9/32:10 display into equal game and workspace halves.

**Will this lower my FPS?**

Rendering a wider WoW window may require more GPU processing than a single-screen window. The addon itself is designed to keep Lua work bounded and lightweight.

**Is the Companion required?**

Not on most clients. You may resize the WoW window manually or use Surround, Eyefinity, or another window manager. The Companion provides one-click borderless spanning, exact topology, display identification, and recovery. WoW Forever currently needs its recovery bridge for reliable full-restart persistence.

**Is the Companion compliant with Blizzard's Terms of Service?**

The Companion is designed as an operating-system window-management utility. It changes only the top-level WoW window's border, position, and dimensions and writes Offhand-owned topology and recovery files. It does not inject code, read game memory, alter game files, simulate input, or automate gameplay. No third party can guarantee how Blizzard will interpret or enforce its agreements, so users should review the public source and Blizzard's current terms and decide accordingly.

**Can I avoid running an executable?**

Yes. Follow the [no-executable manual spanning guide](https://offhand-wow.onrender.com/manual-spanning.html). Manual spanning must be repeated when needed and does not provide WoW Forever's Companion-backed cold-launch recovery.

***

## WoW Forever Beta

The current WoW Forever beta does not consistently restore addon SavedVariables after a complete client restart. These variables normally contain workspace positions, panel state, and setup completion. The Companion waits until WoW has closed, refreshes Offhand's own recovery bridge, and makes the newest valid state available for the next cold launch.

### First-time Forever setup

1. Install Companion v2.1.2 Beta 19 or later, start it before WoW, and leave **Auto-span WoW on launch** disabled during the initial setup.
2. Set WoW to standard **Windowed** mode, log into a character, and wait until the game world has fully loaded. The **Welcome to Offhand** guide should open automatically.
3. Follow the guide to select the displays and Mainhand in the Companion. Click **Span WoW Now** only after entering the game world.
4. Return to the guide and click **Reload UI**. Continue through the guide into the calibration wizard. If the guide was closed, reopen it with `/offhand guide`.
5. On the calibration wizard's final step, make sure you are outside combat and Blizzard Edit Mode is closed. Press **Create Mainhand HUD Layout**, then reload when prompted.
6. If desired, fine-tune the generated layout in Blizzard Edit Mode. After saving personal changes, open **Recovery & Preview** and click **Use Current Edit Mode Layout**.
7. Arrange supported maps, bags, character panels, and chat windows on the Offhand workspace.
8. Exit WoW normally while leaving the Companion running. Relaunch the client and verify that the span, workspace panels, and Mainhand HUD layout return correctly.

### Everyday Forever use

Start the Companion before WoW and leave it running until the WoW process has fully stopped. For the clearest startup experience, log into the game world before clicking **Span WoW Now**. Automatic spanning is optional, but it can resize the login and character-selection screens before addons have loaded, so those screens may temporarily appear stretched or misplaced.

After moving panels or changing the HUD layout, perform one normal exit and relaunch to confirm that the newest recovery state was captured.

### What Offhand restores

Offhand restores supported ordinary workspace frames such as the World Map, Character frame, backpacks, and chat. Blizzard Edit Mode remains responsible for action bars, player and target frames, stance and pet bars, party and raid frames, and other protected combat UI.

If the layout works after `/reload` but not after restarting WoW, confirm that Companion v2.1.2 Beta 19 or later was running before launch and remained open until the WoW process fully stopped. Check the Companion activity log for confirmation that the Forever recovery snapshot was updated or is current.

***

## Support and Feedback

Report problems through the CurseForge comments or join the Offhand Discord:

[https://discord.gg/3BAVSXBXH](https://discord.gg/3BAVSXBXH)

After joining, select **Offhand** in the **Start Here** channel to access the relevant channels.

Useful reports include the WoW client, Offhand version, display resolutions and arrangement, Windows scaling percentage, Companion version, reproduction steps, Lua errors, and screenshots.

***

## Disclaimer

AI tools and language models were used for development and coding assistance. Project direction, features, testing decisions, and published releases remain the responsibility of the project author.

World of Warcraft is a trademark of Blizzard Entertainment, Inc. Offhand is an independent community project and is not affiliated with or endorsed by Blizzard Entertainment.
