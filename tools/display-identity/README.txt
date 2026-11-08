OFFHAND MONITOR ID CAPTURE

Version 2026-11-06.3 adds active Windows display paths to the report.
Extract this version into a new folder rather than running the older copy.

This is a diagnostic tool, not a replacement Companion. Extract the entire ZIP
to a folder you can write to. Double-click Capture.cmd and enter a short label.
Each run writes a separate JSON file into the captures subfolder.
No administrator rights are required. No software is installed.

The tool reads Windows monitor identifiers using both the Beta 20 method and
the documented per-monitor interface method. It also queries active source and
target display paths, which may be available when a monitor ID is missing.
If Companion is running, it also tries to read its executable version and
SHA-256. It lists running WoW process
names so we can identify whether a game was open during each capture.

It does not start/close applications, move windows, access Offhand preferences,
change display settings, access accounts/chat, or send anything over the network.
The launcher uses a process-only PowerShell execution-policy option; it does not
change your saved execution policy. Send the JSON files privately because they
contain monitor identifiers. Personal installation paths are not recorded.

PLEASE START WITH ONE CAPTURE

1. Keep the same remote session and display setup where the error occurred.
   Close WoW completely. Exit Companion using Exit Companion if it is running;
   the title-bar X only minimizes it to the tray.
2. Run Capture.cmd and enter a label such as active-paths-wow-closed.
3. Send the resulting JSON file privately. If you use a virtual display driver,
   include its version and the remote access app you use to connect.
