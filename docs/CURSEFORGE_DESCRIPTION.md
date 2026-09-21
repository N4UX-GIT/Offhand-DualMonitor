# Offhand — Dual-Monitor Workstation for World of Warcraft

Offhand keeps the 3D game world on your **Mainhand** monitor and moves large interface panels—such as the map, character frame, backpack, and chat—onto your **Offhand** workspace monitor. The result is a clean game view without stretching or fisheye distortion.

## WoW Forever users: Companion v2.0.0+ is required

The current WoW Forever beta does not consistently restore addon SavedVariables across a full client restart. Those variables normally hold panel positions, open/closed state, and setup completion. Without recovery, frames can return to default anchors or change position according to the order in which they are opened.

The Windows Companion solves both halves of the problem:

- It spans the WoW window across the selected monitors before Offhand lays out the UI.
- While WoW is closed, it refreshes Offhand's own recovery bridge so the last valid Forever layout can be restored on the next cold launch.

The Companion does not inspect game memory or automate gameplay. It resizes the desktop window and updates only Offhand's recovery bridge while WoW is closed.

## First-time setup

1. Install the Offhand addon and enable it for your character.
2. Put WoW in standard **Windowed** mode—not Windowed (Fullscreen).
3. Install **Offhand Companion v2.1.0 or newer** and start it before WoW.
4. In the Companion, select the monitors to span and click **Span WoW Now** for the initial setup. Automatic spanning is disabled by default; enable it later only if you want WoW spanned on every launch.
5. In WoW, type `/oh`, select **Launch Setup Wizard**, and complete every step.
6. On WoW Forever, open Blizzard **Edit Mode**, select the **Offhand** layout, position protected action bars and combat frames inside the Mainhand game view, and save. If Edit Mode controls are missing, use **Gather Off-Screen UI** in `/oh`.
7. Exit WoW normally while leaving the Companion running. Relaunch WoW, span it manually (or wait if you deliberately enabled automatic spanning), and confirm that the layout returns.

The first-run welcome is only an introduction. Clicking either welcome button acknowledges it; completing the Wizard records setup completion separately. You can reopen the Wizard and the full FAQ at any time with `/oh`.

## Everyday use

- Start the Companion before WoW and leave it running in the system tray.
- Click **Span WoW Now**, or let spanning finish first if you deliberately enabled automatic spanning, before opening workspace panels.
- Move ordinary workspace panels with Offhand Edit Mode.
- Move protected Forever combat UI with Blizzard Edit Mode.
- Exit WoW normally before closing the Companion so the newest state can be recovered.

## Recovery and troubleshooting

- **Window or UI is in the wrong place:** open `/oh` and run the setup Wizard again.
- **Edit Mode options or another frame is off-screen:** click **Gather Off-Screen UI**, then reopen Edit Mode.
- **Forever layout is correct after `/reload` but wrong after restarting WoW:** confirm Companion v2.0.0+ was running before launch and remained running while WoW exited.
- **Need to return to one screen:** click **Restore Window** in the Companion.
- **Welcome popup repeats:** update to the newest addon version; the acknowledgement is now stored independently from Wizard completion and included in Forever recovery.

## Supported clients

- WoW Forever 1.60.x
- Retail
- Classic Era and Hardcore
- Progression and Anniversary Classic

Download the Companion or complete bundle from the [latest GitHub release](https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/latest).

## Companion safety and verification

The Companion is open source and does not request administrator access, install a service, inject into WoW, collect telemetry, or read browser data or credentials. Its window-management behavior—enumerating WoW processes, resizing a window, registering hotkeys, and remaining in the notification area—can resemble broad antivirus heuristic patterns, especially while a new unsigned build has little reputation.

Some VirusTotal engines currently report the unsigned Companion with generic machine-learning or heuristic labels. No reporting engine has identified a malware family or specific malicious payload. VirusTotal is one input rather than a safety guarantee: review the source and documented behavior, verify the official release checksum and build provenance, and make your own security decision before running it.

Download only from the official GitHub release. Compare the executable's SHA-256 digest with `checksums-sha256.txt`, and verify its GitHub build-provenance attestation when GitHub CLI is available. Update checks are never automatic: the app contacts the official GitHub Releases API only after you click **Check for Updates**. Do not bypass a security warning for a copy obtained elsewhere.

Full behavior, file locations, source-build steps, and verification commands are documented in the [Offhand security guide](https://github.com/N4UX-GIT/Offhand-DualMonitor/blob/main/SECURITY.md).

## Exact display layouts and unusual monitor setups

Current Companion builds no longer ask the addon to infer your monitor layout
from one combined resolution. The Companion records each selected Windows
display rectangle and an explicit **Mainhand (game)** role; the other selected
display becomes the Offhand workspace. This covers:

- Equal or mixed resolutions, including 1440p Mainhand + 1080p workspace.
- Portrait + landscape and landscape + landscape arrangements.
- Vertically stacked monitors and screens with unequal horizontal alignment.
- Ultrawide or 32:9 Mainhand displays paired with a separate workspace screen.
- Negative Windows desktop coordinates and unequal screen heights.
- One 49-inch 32:9/32:10 display divided into equal game/workspace halves with
  the explicit **Single-display 32:9 split** option.

For normal use, select exactly two displays in the Companion and choose the
Mainhand display. For a single super-ultrawide split, select only that display,
enable the split option, and choose the game side. If WoW already reached the
character UI before you clicked **Span WoW Now**, type `/reload` once so Offhand
can read the new exact-topology snapshot.

The missing-monitor guard is deliberate. If a previously selected display is
disconnected, the Companion refuses to span rather than squeezing the game and
UI onto the remaining screen. Use **Restore Window**, reconnect the display, or
review the saved display selection. This makes switching between a home
dual-monitor setup and a travel single-monitor setup recoverable without a
magnifying glass.
