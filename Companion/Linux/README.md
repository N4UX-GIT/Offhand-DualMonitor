# Offhand Linux placement test 0.1.0

This standalone x86-64 Linux tool tests whether your desktop lets Offhand place and restore an ordinary WoW window. The first trial keeps the title bar and leaves a small margin around the two screens. It uses X11 and can see XWayland games when the compositor exposes them. Native Wayland, Hyprland, single-screen and unusual layouts are all welcome for inspection.

## Inspect your setup

Download the archive and checksum from the maintainer. Start WoW with your usual launcher and enter a quiet area. Choose **Windowed** in the graphics settings and put the game on one screen. Close the Windows Companion if you use it. Your existing addon is fine. The probe does not write game or addon files.

Open a terminal in the download folder. Continue after the checksum says **OK**.

```sh
sha256sum -c offhand-linux-probe-0.1.0-linux-amd64.tar.gz.sha256
tar -xzf offhand-linux-probe-0.1.0-linux-amd64.tar.gz
cd offhand-linux-probe-0.1.0-linux-amd64
./offhand-linux-probe inspect | tee inspect.txt
```

Inspection is read-only. It lists output names and bounds, recognized WoW windows and whether the manager advertises move/resize. Zero windows or an unsupported setup is a useful report. On Wayland a recognized X11 game window is visible through XWayland. Zero matches alone cannot identify the game's driver. On ARM, report your architecture and skip this x86-64 build.

## Try a 15-second span (optional)

Use **one** visible, unmaximized WoW window entirely on a single screen. On a tiling desktop, manually float WoW first. Choose two side-by-side, touching outputs. Different heights are fine if the displays share enough vertical space.

```sh
./offhand-linux-probe plan
./offhand-linux-probe trial | tee trial.txt
```

With three or more outputs, append the same two names from inspection to both commands, for example `./offhand-linux-probe plan DP-1 HDMI-1` and `./offhand-linux-probe trial DP-1 HDMI-1 | tee trial.txt`. Substitute your actual output names. The order does not assign a gameplay screen in this test.

Read the requested and original bounds. Type **SPAN** and press Enter. Check whether WoW visibly crosses the physical seam. Click a harmless UI element on each side if one is available and record any offset or untested side. Keep the terminal open, the window in place and the displays connected. After 15 seconds the probe requests the original bounds and checks the result. Ctrl+C in the terminal ends the timer early and enters the same restore path. A refused request may finish immediately.

If the window stays displaced, use your desktop's normal Move/Resize controls or WoW's Windowed setting to return it to the original screen. Use the size and position printed before the trial. A changed window identity, monitor arrangement or intervening move can require manual recovery. End the test and report the last output line.

## Reply in the Linux testing thread

Attach the reviewed `inspect.txt` and, if available, `trial.txt`. The probe prints locally and `tee` saves local copies. Omit account or character names, personal paths, credentials and full game logs. If a command stops early, the last message and your setup are enough.

```text
Probe version and distro:
Desktop/compositor and version (GNOME, KDE Plasma, Hyprland, Xfce, etc.):
Session (X11 / Wayland / unknown):
Launcher and Wine/Proton runner + version:
WoW flavor and build; Offhand addon version if installed:
Displays (left/right, resolution, scaling, rotation):
Did /offhand guide open, if the addon was installed?
Did the game visibly span both screens?
Clicks on left / right (correct, offset, or untested):
Did the original screen, size and position return?
Anything you had to recover manually?
```

The in-game workspace split and saved-layout recovery belong to a later tester build.
