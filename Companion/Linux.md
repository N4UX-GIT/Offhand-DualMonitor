# Linux support

## Current status

`Offhand.exe` is still a Windows .NET Framework/WinForms application. Its
display enumeration, global hotkeys, window discovery, border changes, window
placement, clipping regions, and tray UI all use Win32 APIs. There is no native
Linux executable in this repository yet.

Running the Windows Companion under Wine is an **experimental compatibility
path**, not native Linux support. The Companion now falls back from
`Process.MainModule` to `QueryFullProcessImageName` with limited process access.
That API is provided by Wine and addresses a known executable-path detection
failure. WoW and the Companion must run as the same user and in the same
`WINEPREFIX`; separate prefixes use separate Wine servers and cannot discover
or control one another through the existing Win32 process/window APIs.

The Wine/Proton runner must also match the one currently hosting WoW. A Wine
client from another runner version may refuse the prefix's active wineserver
with a `wine client error: version mismatch` message. In Lutris, check both the
configured Wine prefix and runner version for the Battle.net entry, then use
that runner's `wine` binary for the Companion.

## Running alongside Lutris

Create a launcher such as the following, replacing every example path with the
paths configured on your system:

```bash
#!/usr/bin/env bash
set -euo pipefail

export WINEPREFIX="${HOME}/Games/battlenet"
WINE_BIN="${HOME}/.local/share/Steam/compatibilitytools.d/GE-Proton11-7-x86_64/files/bin/wine"
COMPANION_EXE="${HOME}/Documents/Offhand-Companion/Offhand.exe"

"${WINE_BIN}" "${COMPANION_EXE}" &
```

Make the launcher executable, then either run it before Battle.net or select it
as the Battle.net entry's **Pre-launch script** in Lutris. Leave **Wait for
pre-launch script completion** disabled so Lutris can continue launching
Battle.net while the Companion remains open. The example runner name and paths
are illustrative; copying them verbatim is not expected to work on another
machine.

If Wine reports a version mismatch, close every application using that prefix
and relaunch Battle.net and the Companion with the same Lutris runner. Do not
mix a system `wine` executable with a running GE-Proton wineserver.

The expected addon layout is:

```text
<WoW client>/Interface/AddOns/Offhand/Offhand_Forever.toc
<WoW client>/Interface/AddOns/Offhand/Core/
<WoW client>/Interface/AddOns/Offhand/Locales/
<WoW client>/Interface/AddOns/Offhand/Media/
<WoW client>/Interface/AddOns/Offhand/UI/
```

`.../AddOns/Offhand/Offhand/Offhand_Forever.toc` is an incorrectly nested
manual install. Move the inner `Offhand` directory up one level. The packaged
addon ZIP already has one `Offhand` root directory; the TOCs and their folder
references do not need to be renamed for Linux.

Download the named addon or complete-package asset from the release, rather
than GitHub's automatically generated source archive. Extract it with a ZIP
tool that preserves directories (for example `unzip` or `bsdtar`). Some older
prerelease ZIPs were produced with Windows-style backslash entry separators;
Linux extractors that treated those separators literally created flattened
filenames. Current packages use portable forward-slash entries and should not
require a custom "deflatten" script. Verify the resulting layout above before
starting WoW.

Wine validation should cover process discovery, addon verification, display
enumeration, Span, Restore, both hotkeys, topology generation, a complete WoW
exit, and Forever cold-launch recovery. XWayland/Wine and compositor behavior
can differ, so a successful addon check alone is not proof that window movement
and clipping work.

## Native Linux implementation

Native support requires a Linux application and window-system backends; adding
more `kernel32.dll` imports cannot provide it. The existing monolithic
`Program.cs` should first be separated into:

1. A platform-neutral core for settings, selected-display planning, addon
   layout validation, topology serialization, and Forever state recovery.
2. A Windows backend retaining the current Win32 behavior.
3. A Linux process/path backend using `/proc`, plus an explicit WoW-directory
   chooser for Lutris, Bottles, Steam/Proton, and custom Wine layouts.
4. An X11 backend using monitor geometry and EWMH window operations for
   discovery, borderless placement, restore, and hotkeys.
5. Wayland compositor adapters. Generic Wayland clients do not own global
   window placement, so KDE, wlroots-based compositors, and GNOME may require
   different supported integrations. The UI must report unsupported compositor
   operations instead of claiming a successful span.

Linux settings should use the XDG configuration directory and store a stable
monitor identity plus the user-confirmed WoW root. The Linux backend must emit
the same `Core/CompanionTopology.lua` schema as Windows so no addon-side fork is
needed.

Minimum acceptance criteria for a native build are two-display and one-screen
split selection, explicit Mainhand choice, mixed orientation and negative
coordinates, safe display disconnect, Span/Restore, global shortcuts, addon
layout diagnostics, topology writes, and Forever recovery across a cold
launch. X11 can be the first supported backend; each Wayland compositor should
remain opt-in until its full matrix passes.
