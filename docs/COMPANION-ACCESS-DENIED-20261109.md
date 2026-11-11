# Companion 2.1.3 border-removal access denial

Investigated 9 November 2026. Status: native error identified from the reporter's
screenshot and release source; reporter environment and successful retry pending.

## Report and scope

The user supplied a screenshot of `Could not remove WoW window borders
(Windows error 5)` and identified version 2.1.3. The screenshot also shows the
Companion's workspace controls. The reporter's WoW client/build, Windows build,
Store versus portable installation, launch chain and process elevation are unknown.
Do not substitute the developer's Forever client or local topology for these gaps.

## Findings

Reviewed tag `v2.1.3`, commit
`a2eee0c5dbee7b7f0c331e986f9c453c8f87235b`, rather than the current addon
branch's frozen Beta 20 Companion source.

- `Companion/Source/Program.cs:6721` calls `SetWindowLong` with `GWL_STYLE` to
  remove `WS_CAPTION | WS_THICKFRAME`. It clears last error first and treats a
  zero return plus a nonzero last error as failure. The exception at line 6726
  matches the screenshot. This failure precedes clipping and the requested span
  resize. Earlier preparation and rollback can still touch files/window state.
- `WindowInteropDiagnostics` at line 2258 supplies the privilege guidance in
  the screenshot. The guidance is a diagnosis hint, not a measured comparison
  of process elevation. The source deliberately does not inspect security tokens.
- `Companion/Source/app.manifest` requests `asInvoker`, with `uiAccess=false`.
  The Store template uses `Windows.FullTrustApplication` and `runFullTrust`.
  Store full trust is ordinary desktop permission, not automatic administrator
  elevation. No manifest discrepancy explaining a new regression was found.
- The single-instance mutex at line 6928 rejects a second Companion launch.
  The old tray process must exit before a launch at another privilege level can
  replace it. Hiding/minimizing the dashboard is insufficient.

Microsoft documents failure of the window-style API when the target window's
process is higher in the UIPI hierarchy. The leading explanation is elevated
WoW with an ordinary Companion, potentially inherited from an elevated launcher
or an executable/shortcut compatibility setting. This remains an inference
until the reporter's process state or a successful normal-launch retry confirms it.
The screenshot does not establish a 2.1.3 regression or a Lua/addon failure.

Sources consulted 9 November 2026:

- [Window-style API privilege boundary](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowlongptrw)
- [SetWindowLong return/error contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowlongw)
- [MSIX full-trust permissions](https://learn.microsoft.com/en-us/windows/msix/msix-containerization-overview)

## Reporter retry

1. Close WoW and its launcher. Exit Offhand using **Exit Companion** in its
   Windows notification-area menu.
2. Check the actual WoW executable and launcher/shortcuts for **Run this program
   as an administrator** in Properties > Compatibility, including all-users
   settings if present. Turn off unintended administrator settings.
3. Start the launcher, WoW and Companion normally under the same Windows user.
   Use WoW's standard **Windowed** mode, then click **Span WoW Now**.
4. If WoW intentionally requires elevation, the Companion needs matching
   elevation. Fully exit its existing instance first. Availability of elevated
   launch depends on the installed distribution; do not assume a second launch
   replaced the ordinary instance.

If the error persists, collect the exact Companion version and distribution,
WoW executable/client/build, Windows build, Companion Activity Log for the failed
attempt, and Task Manager > Details > Elevated values for WoW and Offhand.exe.
Include the launcher value where applicable. If both are non-elevated, investigate
the actual session/process integrity and any policy denial before changing code.

## Validation and changes

Exported the five required C# source/test files from the exact release tag to
an isolated temporary directory, compiled with the Windows .NET Framework C#
compiler, and ran `Offhand.Companion.PreferencesTest`. PASS, including existing
error-5 guidance and general Windows-error regressions. This is automated test
evidence, not reproduction of an elevated WoW window or reporter recovery.

No product source, native binary, package, user settings or installed client was
changed. Only this investigation note and shared knowledge evidence were added.

Shared knowledge status and Companion queries were attempted first. The search
index was stale; an initial rebuild encountered a file-in-use error on
`.cache/search.building.sqlite3`. A later rebuild succeeded (48,948 passages),
and `search UIPI --limit 4` retrieved the new shared finding. The exact release
source and Microsoft documentation above supply the investigation evidence.
