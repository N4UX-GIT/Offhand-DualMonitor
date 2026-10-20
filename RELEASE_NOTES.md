# Next Offhand addon release: Unreleased

Auction House, Flight Map, merchant, bank, mail, trainer, and other
interaction-bound panels now keep Blizzard's active UIPanel transaction when
moved to Offhand. Offhand saves and restores their monitor position without
performing the hide/direct-show slot eviction used for ordinary menus. This
fixes the case where reopening an Auction House played the auctioneer bell but
displayed no window after the frame had previously been moved to Offhand.

Replacement bag addons now remain the sole owners of their Gamepad window
movement. Offhand no longer displays native bag mover handles while Bagnon,
Baganator, or another supported replacement is active. Social window discovery
also covers Forever's alternate Friends roots so the visible Social window can
receive the same isolated, addon-owned mover as other supported destinations.

The Controller window focus button now opens the **Gamepad (Alpha)** settings
page, not keyboard Keybindings. From there, open Controller Configuration and
assign **Toggle gameplay and window focus** to a controller button or chord.
The settings text now calls out the safety boundary: Gamepad Back and keyboard
Escape remain Blizzard-owned dismissal actions and may close native windows.
The assigned focus action is the controller-only route that returns to gameplay
without asking Offhand to intercept or replay protected Escape behavior.

The binding category now supplies both header names used by supported clients,
so Forever no longer displays the `HEADER_OFFHAND` placeholder.

Forever now treats native Gamepad interface changes as a protected transition.
Offhand hides its addon-owned movers and performs no radial or destination-root
anchor work until the interface style has remained stable for one second. Once
stable, observation resumes at a bounded rate rather than every rendered frame.
Visible protected panels are not restored during the keyboard transition and
return to their captured native anchor only after they hide. This addresses the
highest-risk addon activity associated with the reported client crash while
toggling Gamepad mode; the native crash dump itself contained no Lua stack.

The hidden Professions compatibility card can no longer strand an upgraded
installation with movement disabled. A one-time account migration enables the
isolated Professions motion adapter, including the existing reload persistence
path, while preserving the internal emergency-disable API for future builds.

Social and Guild & Communities now observe their load-on-demand toggle paths.
Opening either panel repairs every shown panel with an explicit saved Mainhand
or Offhand placement in the same UI turn, before Blizzard's shared left-panel
reflow is rendered.

Forever no longer restores another character's Edit Mode preference from the
account-global same-session `/reload` fallback. The fallback now identifies its
owning character before applying per-character data. If an older snapshot has
already left foreign Mainhand provenance behind, creating the HUD rejects that
foreign target, rebuilds from its safe Modern or Classic preset, and creates the
correct normal or Gamepad layout for the current character.

Forever's **Repair HUD** action now repairs the Party or Raid Edit Mode entry
that was actually detected outside the physical displays. This covers
system-relative group-frame anchors that the general Mainhand translation could
not move. Offhand now refuses to report success when the matching layout entry
is unavailable, preventing the repeated repair, reload, and repair prompt loop.
Ordinary layout generation continues to preserve customized group-frame
positions unless the player explicitly invokes recovery. `/offhand diag` now
reports group-frame bounds and the protected-HUD candidate to make any remaining
client-specific layout variation identifiable.

Thanks to **WhoAmI** for reporting the recurring Forever Party Frame recovery
failure and supplying the exact topology and diagnostic output.

Bagnon's one-bag inventory now receives the same independent Offhand workspace
behavior as other supported replacement bags. Escape leaves the bag open while
opening or closing the Game Menu, reload restoration uses Bagnon's public frame
manager, and the bag key or Bagnon close button still closes it normally.
Offhand no longer installs visibility scripts on Bagnon's root. This keeps
Bagnon outside Offhand's execution ancestry when Forever's Gamepad focus manager
performs protected work. While Gamepad UI is active, Offhand retains the saved
workspace intent but does not inspect, reopen, reanchor or alter Bagnon's window
or close-button chrome.

Outside native Gamepad focus, opening or closing Professions and Options now
preserves a tracked Offhand Bagnon inventory. Recovery runs after Blizzard's
panel transaction through Bagnon's public frame manager and adds no scripts to
the Bagnon frame. Professions also re-vacates a reclaimed Blizzard panel slot,
so keyboard and mouse Escape no longer closes a Professions window parked on
Offhand. Native Gamepad Back and focus switching remain Blizzard-owned.

Leatrix Maps now retains exclusive ownership of World Map scale and anchors.
Offhand continues to own only the workspace map's open-state behavior, including
Escape protection, simultaneous-panel detachment and reload reopening. This
removes the competing anchor writes seen when opening Professions while keeping
the persistent Offhand workflow intact.

The combat, healing and XP text fine-tune now remains active on equal-height
spans. A 50% setting therefore applies a 0.50 multiplier to the native world-text
CVar instead of being discarded by the equal-height topology shortcut.

Thanks to **Kruse** for reporting the Bagnon, Leatrix Maps and equal-height
world-text regressions and for isolating the relevant addon combinations.

Forever's native Gamepad UI now retains ownership of window visibility, focus,
and Escape handling. Offhand no longer automatically reopens workspace panels
or bags, evicts player-opened windows from Blizzard's panel slots, or rewrites
the Escape-frame registry while Gamepad UI is active. Windows opened by the
player still return to their saved Offhand positions. This also retains the
stricter protection that prevents Offhand drag controls and broad popup scanning
from touching SmartNavigation-managed windows.

Offhand dialogs now use addon-owned cards while native Gamepad UI is active.
Setup links, confirmation prompts, recovery choices and reload notices no
longer enter Blizzard's protected `StaticPopupGamepad` focus stack. Keyboard
and mouse mode retains the standard Blizzard popup presentation. These cards
are centered within Mainhand instead of along its upper edge.

Forever's active `Gamepad (Preset)` remains entirely Blizzard-owned. Live
testing showed that refreshing a modified runtime preset from addon code taints
Blizzard Edit Mode and later secret-value reads in `CompactUnitFrame`, even
when the preset application itself fails. The player-clicked Mainhand HUD
action now copies that preset into an Offhand-owned custom Gamepad layout,
translates the copy, and saves and selects it through the public Edit Mode APIs
added to current Forever builds. Offhand never mutates or refreshes the preset
manager. The player is then asked to `/reload` before continuing so the layout
write does not carry addon taint into gameplay. ConsolePort layouts remain
externally owned.

The native Gamepad radial Main Menu opened by Start is also centered within
Mainhand. Because this control surface is outside Edit Mode, Offhand locates
its localized visual container at runtime and adjusts only the unprotected root
anchor. It does not alter the radial buttons, bindings, focus handlers, or
protected children, and restores Blizzard's native anchor when Gamepad mode or
the spanned layout is inactive.

Eligible windows opened from the native radial menu, including Character, Map
and Quest Log, Chat Channels, native bags, Options, AddOns, and Customer
Support, are centered within Mainhand when their roots are available and
unprotected. Protected Player Spells, Professions, quest interactions, and HUD
systems remain untouched. These windows
remain under Blizzard's visibility and controller-focus ownership. Each visible
supported root receives an independent Offhand drag bar, allowing several open
windows to be placed by mouse without adding controls, scripts, or fields to
Blizzard's frame tree. Newly shown roots are settled before the next render to
avoid a visible jump from their native anchor, and completed offsets are saved
per character. The Edit Mode Loot Window remains excluded.

The Gamepad HUD path uses Blizzard's public custom-layout persistence and
activation APIs only from an explicit player action. It does not mutate preset
tables or invoke Edit Mode manager refresh methods. A required `/reload` clears
the one-shot layout transaction before later Edit Mode, party-frame, or logout
work can encounter addon-tainted secret values.

Edit Mode save, rename, import, delete, and unsaved-changes dialogs are now
recovered automatically when Gamepad mode places their unprotected root in the
mixed-height void. Offhand centers only the named dialog root on Mainhand,
outside combat, without changing its buttons or Gamepad focus handlers.

Forever's native chat dock now keeps exclusive control of every secondary chat
frame during startup and `/reload`. Stale Offhand workspace records can no
longer resize, reanchor, or show the docked Combat Log before Blizzard finishes
rebuilding the General and Combat Log tab group. Intentionally detached chat
windows continue through Offhand's settled, tracked-chat restoration path.

Thanks to **Frosted (`bitwize01`)** for diagnosing the protected
`FrameControlsManager` interaction and contributing the initial implementation
in [PR #18](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/18).

Thanks to **Rawbowke** for reporting and isolating the periodic frame-time spike,
and to **Magic** for the clean-character Combat Log reproduction, frame
diagnostics, and independently tested guard proposal.

---

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
Beta 1. Offhand no longer replaces Blizzard's global close functions or changes
secure panel-manager metadata, and it excludes the Game Menu, Cooldown Viewer
and other Blizzard-managed Edit Mode frames from generic dragging and recovery.
This targets the reported `CompactUnitFrame`, `TextStatusBar` and Cooldown
Viewer taint errors.

The dedicated World Map path now detaches a saved workspace map from both of
Blizzard's Escape-close mechanisms: `UISpecialFrames` and the active UI-panel
slot. The map therefore remains open while the first Escape opens the Game Menu
and the second closes only that menu, including after reopening the map or using
Edit Mode. This does not replace Blizzard's global close functions or mutate
secure panel metadata. Character and other native UI panels can still close
when Blizzard owns their active panel slot; native bags use a separate bag-close
path. Saved Offhand positions remain available when those panels reopen.

If Forever places the unprotected Edit Mode control window in mixed-height
black void, Offhand now displays a player-click recovery prompt. **Bring to
Mainhand** moves only that control window to the game view. It does not move
action bars, unit frames or other protected HUD elements. Live acceptance
confirmed clean Edit Mode entry and exit, persistent workspace map behavior,
native Game Menu access and no Lua error.

Use standard Windowed mode. Start Companion 2.1.2 before WoW, select the displays
and Mainhand, then click **Span WoW Now**. If WoW already loaded the character
UI, use `/reload` once before completing `/offhand wizard`.

The post-Beta-3 candidate also corrects a critical display-identity migration.
Windows can reassign `DISPLAY1` and `DISPLAY2` after topology changes, so
Companion now remembers each physical monitor instead. Existing installations
pause automatic spanning once and ask the player to verify Mainhand before the
new identity is saved. The in-game settings panel also refreshes its master
checkbox whenever restored, and exact portrait-plus-landscape geometry is no
longer described as dual landscape.

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
