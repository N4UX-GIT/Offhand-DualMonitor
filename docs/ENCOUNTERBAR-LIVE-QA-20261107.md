# EncounterBar native QA, 7 November 2026

Target: Forever 1.60.1.70862, keyboard interface, existing idle QA character.
Installed test9 plus the recorded HUDRecovery ownership correction. EllesmereUI
modules and ForeverPlus 1.0.6 remained enabled. No gameplay, combat, outgoing
messages or custom-script security bypass was used.

## Reproduction and result

A temporary private QA addon supplied hardware-bound buttons, native read-only
diagnostics and an original layout snapshot. Its fixture uses Offhand's existing
selective serialized-layout transaction to change EncounterBar's anchor. It
never directly reanchors the live protected frame. The native Edit Mode preview
is presented through Blizzard's own HighlightSystem method. The client does not
expose its EncounterBar checkbox in the visible settings list in this context.

An anchor outside the whole canvas clamps to an edge on this client and is not
the reporter's condition. The accepted fixture instead uses the actual gap in
the 4000x2560 physical span: 1440x2560 workspace and 2560x1440 Mainhand at y=6.
Its EncounterBar center is approximately 2072,1526 UIParent units, above Mainhand
and outside the workspace. This serialized position survives reload. With no
content and the preview hidden, it does not request repair.

Presenting the native preview detects EncounterBar. After closing Edit Mode,
the normal repair popup appears with the reported frame name. The temporary
hardware button invokes exactly the popup's RepairProtectedHUDLayout action and
captures native layout data before and after it. Repair succeeds, reports one
system moved and requests reload. Every unrelated system is byte-for-byte equal
in the immediate native before/after data. Native reload normalizes some data,
so raw equality across sessions is not claimed.

The repaired anchor is approximately 2072,663 UIParent units, inside Mainhand.
After reload the native preview is visibly reachable. Repeated reload and
Edit Mode entry/presentation do not request another EncounterBar repair.

## Additional fix found live

An Ellesmere-owned native action-bar preview crossing the temporary split seam
could precede EncounterBar in recovery. Layout generation already yields that
system to its replacement addon, making such a repair ineffective. Recovery and
its diagnostics now consult the same existing system-ownership policy. The live
scan stops selecting that preview while retaining detection of lost native
EncounterBar. Regression coverage also retains recovery when the action bar
has no replacement owner. No replacement addon's position or configuration is
changed by this correction.

## Evidence limits and cleanup

This reproduces the failure class using a controlled layout, not Dy's exact
unsupplied saved layout. Real encounter/widget actions, combat, taint-sensitive
descendants and physical controller behavior remain manual acceptance items.
The native session disconnected after the repeat-reload pass while cleanup was
underway; reconnect succeeded. This does not establish an addon-caused disconnect.

Private fixture, backups and native snapshots are in
`dist/encounter-live-20261107/`, excluded from distributions. Final error and
cleanup results are recorded with the package verification receipt.

Cleanup confirms the original active native layout and four original custom
layouts, with zero additional fixture rows. The temporary addon and its two
SavedVariables files were moved into private evidence. Sixteen original addon
and native cache state files, Config.wtf, Companion configuration and both
generated bridges were restored and hash-verified after the client and Companion
closed. Fresh BugGrabber comparison retains the same three historical records,
zero new messages and zero additional historical occurrences. Fresh logs remain
available; no combat/taint safety inference is made from an idle session.
