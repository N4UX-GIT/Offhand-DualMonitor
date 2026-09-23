# Offhand v2.1.2 — Forever Missing-Monitor Recovery

Offhand 2.1 replaces combined-resolution guessing with exact display rectangles
provided by Companion 2.1.2. Select exactly two screens and choose the Mainhand,
or explicitly split one 32:9/32:10 super-ultrawide. Mixed resolutions and
heights, stacked screens, portrait/landscape pairs, negative desktop
coordinates, and ultrawide Mainhand displays now retain native geometry.

If a saved workspace display disconnects while WoW is spanned, Companion now
restores a bordered WoW window that fills the surviving Mainhand work area and
refuses to reuse the stale span. The addon rejects the stale topology and keeps
ordinary workspace panels reachable without erasing their saved dual-screen
positions.

Forever only accepts protected Edit Mode layout changes from a player action.
Offhand therefore offers a **Use Modern** recovery prompt when the workspace
disappears and a **Restore Offhand** prompt when the exact topology returns.
Manual layout choices take precedence. A consumed Forever recovery bridge also
no longer overwrites newer SavedVariables during `/reload`.
Offhand's account and character state now have a versioned, data-only session fallback for
Forever's reported SavedVariables reload fault. A matching or newer revision in
the ordinary SavedVariables table always wins, allowing Blizzard's eventual fix
to take effect without removing or reversing Offhand's recovery code.
Fresh profiles remain inert until the setup wizard is completed. Existing
Forever recovery, workspace persistence, and Blizzard Edit Mode ownership are
preserved.

This beta also tightens Forever's secure-UI boundary after user reports from
Beta 1. Offhand no longer replaces Blizzard's global close functions, changes
secure panel-manager metadata, or reanchors the Edit Mode manager, Game Menu,
Cooldown Viewer and other Blizzard-managed Edit Mode frames. This targets the
reported `CompactUnitFrame`, `TextStatusBar` and Cooldown Viewer taint errors.
On Forever, native Escape and panel behavior now takes precedence over forcing
every Blizzard panel to remain open on the workspace. Escape may therefore
close a Blizzard map, character or bag panel before opening the Game Menu; the
saved Offhand position remains available when the panel reopens. Offhand also
no longer force-centers the Edit Mode manager. If its native controls land in a
mixed-height black void, use Companion **Restore Window**, edit the layout in
the normal window, then span again.

Use standard Windowed mode. Start Companion 2.1.2 before WoW, select the displays
and Mainhand, then click **Span WoW Now**. If WoW already loaded the character
UI, use `/reload` once before completing `/offhand wizard`.

---

# Offhand v1.0.0 ? Multi-Monitor Workspace for World of Warcraft

**Equip your Offhand. Dual wield your monitors.**

Offhand transforms dual displays into an expansive, calibrated gaming workstation for World of Warcraft. It locks your 3D world and combat HUD natively to your primary gaming screen while converting your secondary screen into a persistent workspace for your bags, map, quest log, and interface panels.

---

### What's New in v1.0.0

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

#### ??? External Addon Compatibility & Combat Guards
* Generic popup recentering aligns third-party addon alerts and dialogs to the center of your 3D gaming monitor without maintaining hardcoded addon lists.
* Layout operations use combat guards; protected-frame and taint behavior still require live-client verification.

#### ??? Native Windows Companion (`Offhand.exe`)
* Standalone Win32 executable compiled with C# and DPI-awareness.
* Borderless-spans your World of Warcraft window across your virtual desktop in a single click.
* Minimizes silently to the Windows notification tray with quick actions and auto-launch detection.
* Fully open-source and audit-friendly using the Windows .NET Framework.

---

### Downloads & Assets

| Asset | Description |
| --- | --- |
| **`Offhand.exe`** | Standalone Windows desktop companion (Recommended) |
| **`Offhand-Companion-v1.0.0.zip`** | Companion bundle with `.exe`, batch scripts, and PowerShell alternatives |
| **`Offhand-v1.0.0.zip`** | In-game add-on package for manual installation |
| **`checksums-sha256.txt`** | SHA-256 verification hashes for all release artifacts |

### Installation Quick-Start
1. Extract `Offhand-v1.0.0.zip` into `World of Warcraft\_classic_era_\Interface\AddOns\`.
2. Set World of Warcraft Display Mode to **Windowed** (<kbd>Alt</kbd> + <kbd>Enter</kbd>).
3. Run **`Offhand.exe`** and click **Span WoW Window Now**.
4. In-game, type `/offhand` to open the configuration wizard.
