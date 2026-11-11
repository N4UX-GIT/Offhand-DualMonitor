# Companion span rollback source and synthetic evidence

1 November 2026. Scope: local native-window snapshots and temporary files.
No WoW window was located or operated on by the automated suite.

The source study found that a failed span left the newly generated topology
in place and cleared any previous clipping region. `SpanRollback` now captures
file bytes, window ownership, bounds, style, placement and an independent copy
of the region before the span writes or moves anything. The topology writer
returns the exact bytes it wrote, so rollback compares against those bytes
before restoring the previous file. A missing original file is removed after
failure; a detected external edit or deletion is preserved and reported.

Native rollback checks the window still belongs to the captured process,
restores style/bounds/placement, then reapplies the prior region. Successful
region assignment transfers ownership to Windows; other snapshot handles are
released. Window and file restoration are attempted independently, and failures
are logged rather than treated as successful rollback. File comparison is a
best-effort conflict guard, not a filesystem transaction spanning other programs;
another writer can race between the comparison and replacement.

## API evidence

- [GetWindowRgn](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowrgn): obtains a copy; ERROR denotes either no explicit region or an error. The source resets/checks last error and fails before mutation when an error is surfaced. This API ambiguity is not proof of universally reliable no-region detection.
- [SetWindowRgn](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowrgn): successful calls transfer ownership; coordinates are window-relative.
- [GetWindowPlacement](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowplacement) and [WINDOWPLACEMENT](https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-windowplacement): preserve show/placement state using a length-initialized structure. Placement coordinates are passed back only to SetWindowPlacement.
- Local Windows SDK `10.0.19041.0/um/WinUser.h`, lines 3236-3246: desktop structure is 44 bytes. The extra `rcDevice` field shown by the web page is guarded by `_MAC` in this SDK. x64/x86 tests assert the desktop layout size.

## Automated results

`tests/companion-span-rollback.ps1` passes 113 assertions on x64 and 113 on
x86. Ten failure cases cover exceptions after topology writing, style changes,
clipping, resize and verification, with both no prior explicit region and an
L-shaped complex region. Tests compare complete region shape, exact outer
bounds/style and raw file bytes, and verify synthetic windows remain hidden.
Additional cases cover absent original files, external edits, commit, idempotent
rollback, locked-file errors, invalid HWND and cleanup of temporary files.
Preference tests also verify the topology writer returns its actual file bytes.

## Remaining acceptance

Synthetic success does not establish real WoW behavior, asynchronous renderer
recovery, cross-process privilege behavior, minimized/maximized transitions,
mixed-DPI restoration, disconnected-monitor clamping or Wine compatibility.
Verify the candidate artifact using COMPANION-PRODUCTION-RECOVERY-QA.md before
promotion. This work does not enable custom regions or modify existing geometry.
