# Offhand — Dual-Monitor Workstation for World of Warcraft

Offhand keeps the 3D game world on your **Mainhand** monitor and moves large interface panels—such as the map, character frame, backpack, and chat—onto your **Offhand** workspace monitor. The result is a clean game view without stretching or fisheye distortion.

## WoW Forever users: Companion v2.1.2+ is required

The current WoW Forever beta does not consistently restore addon SavedVariables across a full client restart. Those variables normally hold panel positions, open/closed state, and setup completion. Without recovery, frames can return to default anchors or change position according to the order in which they are opened.

The Windows Companion solves both halves of the problem:

- It spans the WoW window across the selected monitors before Offhand lays out the UI.
- While WoW is closed, it refreshes Offhand's own recovery bridge so the last valid Forever layout can be restored on the next cold launch.

The Companion does not inspect game memory or automate gameplay. It resizes the desktop window and updates only Offhand's recovery bridge while WoW is closed.

## First-time setup

1. Install the Offhand addon and enable it for your character.
2. Put WoW in standard **Windowed** mode—not Windowed (Fullscreen).
3. Install **Offhand Companion v2.1.2 or newer** and start it before WoW.
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
- **Forever layout is correct after `/reload` but wrong after restarting WoW:** confirm Companion v2.1.2+ was running before launch and remained running while WoW exited.
- **Need to return to one screen:** click **Restore Window** in the Companion.
- **Welcome popup repeats:** update to the newest addon version; the acknowledgement is now stored independently from Wizard completion and included in Forever recovery.

## Supported clients

- WoW Forever 1.60.x
- Retail
- Classic Era and Hardcore
- Progression and Anniversary Classic

## Public Service Announcement: Companion download and antivirus status

> **Current verified status — October 7, 2026:** Offhand Companion Beta 19 is
> the current portable release. Microsoft Security Intelligence reviewed the
> exact executable and minimal ZIP without retaining a malware detection. Edge
> may still show **"isn't commonly downloaded"** for the direct unsigned EXE;
> that is an application-reputation notice rather than a malware verdict.
> Third-party antivirus vendors control their own independent verdicts.

The in-game addon downloaded from CurseForge contains Lua addon code and does
not contain the Windows Companion executable. The Companion is an optional,
separate Windows utility hosted in the project's official GitHub releases.

We continue to see comments stating that the Companion is a virus or linking to
VirusTotal reports. We understand why those results are concerning. The section
below records what happened, what has changed, what remains unresolved, and how
to verify whether a report refers to the current file.

### What do the previous and ongoing comments mean?

Those users genuinely saw browser and antivirus warnings during earlier
downloads. Chrome and Brave blocked some Companion archives, and Microsoft
Defender reported the generic machine-learning label
`Trojan:Win32/Wacatac.B!ml`. We took those reports seriously, paused normal
distribution work, audited and simplified the Companion, published its complete
source, froze the release artifacts by SHA-256, and submitted the exact files
directly to Microsoft and the remaining reporting vendors.

Microsoft Security Intelligence subsequently reviewed the exact Beta 19
executable and minimal archive without retaining a malware detection. Their
exact hashes are published in the [Offhand security
guide](https://github.com/N4UX-GIT/Offhand-DualMonitor/blob/main/SECURITY.md).

This does not mean users were wrong to report what their security software
showed, and it is not a request to ignore future warnings. The earlier comments
are an important record of the problem that prompted this investigation.

However, security results are tied to an exact file hash. Some ongoing comments
link scans of older builds or different files. A VirusTotal link for an older
build, a locally rebuilt executable, or a newly generated archive does not
describe the current canonical Beta 19 files. Compare the report's SHA-256 with
the hashes below before applying its verdict to the current download.

If somebody receives a new named malware detection against one of the exact
canonical hashes, we want that report and will investigate it. It should include
the complete warning, download URL, hash, browser, security product, and
definition version. General claims without the file hash cannot establish which
release was scanned.

### What does the current Edge warning mean?

The Companion is not yet digitally signed. Edge may describe the standalone
`Offhand.exe` as **"isn't commonly downloaded."** Microsoft documents this as a
SmartScreen application-reputation notice for an uncommon or unsigned program;
it is not the same result as **"Virus detected"** or a named malware detection.
The ZIP is therefore the recommended portable download while the executable
builds reputation.

### Why can VirusTotal still show detections?

VirusTotal reports the independent verdicts of many security vendors; it does
not create or remove those verdicts. Some engines have assigned the unsigned
Companion generic machine-learning or heuristic labels. Microsoft's review does
not automatically change the databases of CrowdStrike, Elastic, Malwarebytes,
SecureAge, Trapmine, VIPRE, or other vendors, so older or cached VirusTotal
results may remain visible while separate correction requests are processed.

A low detection count does not prove that a file is safe, and neither a clean
scan nor this PSA is an absolute guarantee. The current status means that
Microsoft did not retain a malware detection for the submitted Beta 19 files;
it does not ask users to suspend normal security precautions. The evidence
available for Beta 19 should be
considered together: immutable hashes, public source and build instructions,
GitHub provenance where provided, Microsoft's completed reviews, and the
documented behavior below.

### What does the Companion actually do?

The Companion is open source. It looks only for allowlisted World of Warcraft
processes, changes the selected WoW window's border and dimensions, reads the
connected display rectangles, remains available in the notification area, and
updates Offhand's own topology or guarded Forever recovery files. These
legitimate window-management behaviors can overlap with broad antivirus
heuristics.

It does not request administrator access, install a service or driver, create a
Windows startup entry, register global hotkeys, inject into WoW, read game
memory, automate gameplay, download and execute programs, collect telemetry, or
read browser data, passwords, or account credentials. It contacts the official
GitHub Releases API only when you click **Check for Updates**.

### Recommended download and verification

Download the official [Offhand Companion v2.1.2 Beta 19
ZIP](https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/download/v2.1.2-beta.19/Offhand-Companion.zip).

- `Offhand.exe` SHA-256:
  `89C065D28D5EB37A3CCBF868DA006C64E7FD403A50417E8799806DF92E46BF52`
- `Offhand-Companion.zip` SHA-256:
  `83EEDFE4DFE96EA4A34E6414E55797CAD4E02181604DAAA2F6E6B3EC57F1576B`

Compare the downloaded file with `checksums-sha256.txt` from the same release.
Do not download the Companion from mirrors, Discord attachments, or re-upload
sites, and do not disable Windows Security. If a warning says **"Virus
detected"**, names a threat, or the checksum does not match, stop and report the
exact download URL, filename, SHA-256, browser, security product and definition
version, and a full screenshot so the specific file can be investigated.

If you prefer not to run an executable, use the [no-executable manual
setup](https://offhand-wow.onrender.com/manual-spanning.html). Full behavior,
source-build steps, Microsoft submission references, and verification commands
are available in the [security
guide](https://github.com/N4UX-GIT/Offhand-DualMonitor/blob/main/SECURITY.md).
Addon-only updates can continue using the byte-identical Beta 19 Companion while
protocol 1 remains compatible.

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

The missing-monitor guard is deliberate. If a previously selected workspace
disconnects while WoW is spanned, Companion v2.1.2 restores a bordered window
that fills the surviving Mainhand work area. It then refuses another span rather
than squeezing the dual-screen layout onto one display. Offhand temporarily makes
ordinary workspace panels reachable without erasing their saved dual-screen
positions.

On Forever, protected HUD layouts can only be changed by a player click. If the
saved **Offhand** layout is active when the workspace disappears, click
**Use Modern** in Offhand's prompt. After reconnecting the exact display topology
and spanning again, click **Restore Offhand**. A different layout you select
manually always takes precedence. You can also use **Restore Window**, reconnect
the display, or review the saved display selection. This makes switching between
a home dual-monitor setup and a travel single-monitor setup recoverable without
a magnifying glass.

### Camera movement on mixed-height displays

On a shaped portrait/landscape span, WoW's hidden cursor can eventually reach a
vertical window edge while the right mouse button remains held, stopping further
up/down camera movement until the button is released. Offhand enables raw mouse
input while its spanned layout is active, which uses movement deltas and avoids
that boundary. The option is visible on the Display tab and enabled by default;
Offhand remembers and restores the player's previous setting outside the span.
