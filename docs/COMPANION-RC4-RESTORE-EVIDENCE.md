# Revision 4: restore failure rollback

2 November 2026. Source-reviewed fix with synthetic native-window verification;
actual WoW failure rollback acceptance remains pending. A later
[targeted Retail run](COMPANION-RC4-RETAIL-LIVE-20261102.md) passed ordinary
restore and repeated recovery, with a separately recorded server disconnect.

## Problem and change

The previous Restore Window failure handler cleared the native region, restored
the prior style/bounds and did not restore the old clipping shape or placement.
A failed resize could therefore leave the old spanned rectangle without its
display-shaped clipping. It also ignored failure from clearing the region.
This was found by source review, not by reproducing a failed restore in WoW.

`WindowRestore.Apply` now captures a native-only `SpanRollback` snapshot before
any show-state, style, region or bounds change. Failed operations restore exact
prior clipping, style, bounds and placement; incomplete rollback is surfaced
alongside the original failure. Successful restores check region-clear success,
border flags and bounds. Normal restore removes minimized/maximized style flags.
Hidden synthetic windows stay hidden. Native-only snapshots never write topology.

The existing recovery cancellation and success bookkeeping remain outside the
native transaction. No recovery eligibility, topology schema or settings changed.
Custom regions and tooltip scaling are not included.

## Verification

`tests/companion-span-rollback.ps1` now passes **181 assertions per architecture**
on x64 and x86. The production restore helper itself is exercised with injected
failures after style, region removal, bounds and verification. Both absent and
complex prior regions are checked for exact restoration. A successful restore
checks exact target bounds, border style, clipping removal and hidden state.
The previous span rollback cases remain covered.

Preferences/layout checks, 121 production recovery assertions, ordinary color/DPI
checks (228 each on x64/x86), release metadata and `git diff --check` passed.
No Lua runtime sources changed, so the prior Lua evidence remains separate.
Real WoW failure timing, minimized/maximized behavior, display loss, Wine and
mixed-DPI rollback remain live acceptance gates.

## Minimized/maximized failure continuation, 2 November

The unchanged production helper now passes **381 assertions per architecture**
on x64 and x86. Added fixtures create hidden native windows whose `IsIconic`
or `IsZoomed` state is verified before the operation. This differs from the
earlier success test that only supplied minimized/maximized flags in the target
style argument.

For both actual native states, every failure stage (style, clipping, bounds and
verification) is exercised with absent and complex original clipping. Rollback
retains the original exception and restores exact bounds/style/region, hidden
visibility, native minimized/maximized state, normal placement rectangle and
minimum/maximum placement points. All 16 added failure scenarios pass on each
architecture. This is synthetic native evidence; asynchronous WoW window
handling, visible-client show-state acceptance and a successful restore from
those states remain untested here.

No production source or artifact changed, so revision 4 does not require a
rebuild. Microsoft's [GetWindowPlacement contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowplacement)
defines the returned show state and placement; the
[SetWindowPlacement contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowplacement)
also documents possible screen-boundary adjustment. The checks above compare
actual local readbacks, rather than assuming exact placement from an API return
value alone. Shared WoW knowledge routing returned no native rollback evidence;
these Win32 contracts, local source and controlled native tests are the basis.

Later [Retail character-selection testing](COMPANION-RC4-RETAIL-LIVE-20261102.md)
passed successful Restore from actual minimized and maximized ordinary windows,
with exact remembered outer/client/style readbacks and normal placement. That
result applies to the visible successful path only. Still-clipped span
minimization, in-world behavior and actual WoW failure rollback remain open.

## Exact artifact

- Source build revision: `44f1c166c645537bb9553dec70c267a889ed9b00`, clean tracked source at build time.
- Local directory: `dist/companion-2.1.3-beta.1-rc4`.
- Executable SHA-256: `E7F40392C7CD869729485BA56432102B7FCFB46FF45D0B2DD000F843CB685436`.
- Runtime ZIP SHA-256: `F22BFA4F65E144F5C625AFE018E794B5095BF70E196156E9F1CF89EC69339B96`.
- Unsigned validation MSIX SHA-256: `3C33C31347D2154AC8856A10E7276762632AB3EE5FBB9C70C93E5AA00C0898A9`.

The three-entry portable ZIP was verified. The separate validation MSIX identity
`N4UX.OffhandCompanion.Validation`, package `1.0.0.0`, passed structure, startup,
capability and exact embedded-executable parity checks. It was not installed or
submitted and reserves no production Store version. Canonical public Beta 20
bytes and revision 3 artifacts remain unchanged. Revision 3 live acceptance must
not be relabeled as revision 4 acceptance. Both candidates retain public version
`2.1.3-beta.1` and file version `2.1.3.1`; use revision/hash to distinguish them.

## Research and incident limits

Shared knowledge was consulted first; broad native rollback routing returned no
source. Local production source and the synthetic native tests establish this
finding. Microsoft's [SetWindowRgn contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowrgn)
documents clipping behavior, return-value checks and region ownership transfer.
The local Windows SDK `10.0.19041.0/um/WinUser.h` defines WS_MINIMIZE and
WS_MAXIMIZE at lines 2789 and 2794. These are Win32 evidence, not WoW runtime proof.

The Retail disconnect cause was not established. The user subsequently reported
poor Starlink connectivity and requested that network disconnects be ignored;
they are excluded from acceptance blockers. Current connection/graphics logs start
at approximately 00:35:49, after the failed reload session, so they cannot explain
that earlier event. The retry's graphics log records resize to `4000x2560`, return
to `2114x1353`, and successful device destruction during normal shutdown. Private
copies are retained under the ignored revision 3 topology QA evidence directory.
Capture logs before restarting the client on any recurrence, since relaunch
replaced the inspected files. No disconnect cause is assigned from the retry logs.
