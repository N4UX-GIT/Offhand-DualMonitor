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
3. Install **Offhand Companion v2.0.0 or newer** and start it before WoW.
4. In the Companion, select the monitors to span and enable automatic spanning. Click **Span WoW Now** for the initial setup.
5. In WoW, type `/oh`, select **Launch Setup Wizard**, and complete every step.
6. On WoW Forever, open Blizzard **Edit Mode**, select the **Offhand** layout, position protected action bars and combat frames inside the Mainhand game view, and save. If Edit Mode controls are missing, use **Gather Off-Screen UI** in `/oh`.
7. Exit WoW normally while leaving the Companion running. Relaunch WoW and confirm that the window spans and the layout returns automatically.

The first-run welcome is only an introduction. Clicking either welcome button acknowledges it; completing the Wizard records setup completion separately. You can reopen the Wizard and the full FAQ at any time with `/oh`.

## Everyday use

- Start the Companion before WoW and leave it running in the system tray.
- Let automatic spanning finish before opening workspace panels.
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
