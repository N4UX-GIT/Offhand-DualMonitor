# Offhand v1.0.1 ? Multi-Monitor Workspace for World of Warcraft

**Equip your Offhand. Dual wield your monitors.**

Offhand transforms dual displays into an expansive, calibrated gaming workstation for World of Warcraft. It locks your 3D world and combat HUD natively to your primary gaming screen while converting your secondary screen into a persistent workspace for your bags, map, quest log, and interface panels.

---

### What's New in v1.0.1

#### ?? 3D Viewport Geometry & Aspect Ratio Lock
* Constrain 3D camera rendering strictly to your primary monitor's pixel bounds (16:9 Standard, 21:9 Ultrawide, or Fit Window Height).
* Zero fisheye distortion or camera stretching across monitor bezels.
* 1-Click Auto-Configuration wizard detects display resolution and anchors viewport automatically.

#### ??? Persistent Secondary Display Workspace
* Keep your World Map, bags, Character frame, Quest Log, Spellbook, and Talent panels open simultaneously on your secondary monitor.
* Demodalized panels stay open while moving?zero mutual exclusion or auto-closing when you walk.
* **Chat Frame Persistence**: Drag and dock `ChatFrame1` anywhere on your secondary workspace; coordinates are preserved across `/reload` and client restarts.

#### ?? OBS Streamer Capture Setup
* Dedicated Streamer Setup card in Options calculates exact physical pixel crop values (`Left`, `Right`) for OBS Studio in real time based on your display resolution and bezel seam.
* Easily broadcast dual displays without the black bezel gap appearing on stream.

#### ??? External Addon Compatibility & Taint-Free Safety
* Generic popup recentering aligns third-party addon alerts and dialogs to the center of your 3D gaming monitor without maintaining hardcoded addon lists.
* Fully combat-safe: all protected layout operations and frame changes are queued and deferred during combat lockdown.

#### ??? Native Windows Companion (`Offhand.exe`)
* Standalone Win32 executable compiled with C# and DPI-awareness.
* Borderless-spans your World of Warcraft window across your virtual desktop in a single click.
* Minimizes silently to the Windows notification tray with quick actions and auto-launch detection.
* Fully open-source and audit-friendly with zero external runtime dependencies.

---

### Downloads & Assets

| Asset | Description |
| --- | --- |
| **`Offhand.exe`** | Standalone Windows desktop companion (Recommended) |
| **`Offhand-Companion-v1.0.1.zip`** | Companion bundle with `.exe`, batch scripts, and PowerShell alternatives |
| **`Offhand-v1.0.1.zip`** | In-game add-on package for manual installation |
| **`checksums-sha256.txt`** | SHA-256 verification hashes for all release artifacts |

### Installation Quick-Start
1. Extract `Offhand-v1.0.1.zip` into `World of Warcraft\_classic_era_\Interface\AddOns\`.
2. Set World of Warcraft Display Mode to **Windowed** (<kbd>Alt</kbd> + <kbd>Enter</kbd>).
3. Run **`Offhand.exe`** and click **Span WoW Window Now**.
4. In-game, type `/offhand` to open the configuration wizard.
