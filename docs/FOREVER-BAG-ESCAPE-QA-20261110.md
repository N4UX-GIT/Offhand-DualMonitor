# Forever workspace bag Escape priority, 2026-11-10

## Reproduction and correction

This isolates the bag/target part of
[OH-UI-035](https://discord.com/channels/1491522138371391691/1569545754253594744).
The reporter's health/mana text and profession-bag symptoms remain separate.

Forever 1.60.1 build 70862, Companion 2.1.5, Windows, English. Spanning is
explicitly applied before each world entry to the 2560x1440 single display.
With Offhand active, Mainhand is right and workspace left, each 1280x1440;
every active-addon snapshot reports spanning true/topology READY. The native
control has Offhand disabled in the AddOns list, so it has no addon viewport;
the native window is still spanned by Companion. The user placed the character
next to the merchant. Agent input opens/closes that panel and tests bag/menu
UI only, with no movement, purchases, selling, repairs or item actions.

The isolated native control disables EllesmereUI, BetterBags, RXPGuides and
Details. Its first Escape closes the merchant and combined backpack, leaving
the target selected. The next hardware Escape clears the target without opening
the menu (samples 4-6). With the pre-fix Offhand candidate and a controlled
saved workspace bag, Escape cycles GameMenuFrame on/off/on while the bag is
restored and the target remains selected (samples 12-15). This reproduces a
local cause for the report, rather than merely inferring it from screenshots.

CanvasForeverBags now yields to the native Escape close when a target exists
or target state is unreadable. It clears open intent, retaining saved bag
placement, so a subsequent player Escape can reach native target dismissal.
No ClearTarget call, binding replacement, native frame field or native script
hook is added. Existing no-target workspace preservation and Settings/Chat
Settings navigation remain covered by the regression suite. The production
post-hook still only observes the original native transaction.

The regression fails before correction and passes afterward, including missing
and failing target-query cases and player-driven reopening. All 121 frozen Lua
suites, six manifest Lua 5.1 checks and 103 archive-entry hashes pass. Runtime
delta is Core/CanvasForeverBags.lua. Private candidate SHA-256:
36aa4203bb94a6629bc7f3bd24f77b7c92e55ff38c242f476c66288ebc8f90aa.

## Corrected native verification and cleanup

On the corrected private build, cold entry restores the controlled saved bag
(sample 18). Opening the merchant retains that geometry (20). The first physical
Escape closes the merchant and bag, leaving the target selected and menu closed
(21); the second clears the target without opening the menu (22). A normal
/reload keeps the bag closed and open intent cleared (23/24). B reopens at the
same saved geometry (25). With no target, two physical Escapes toggle the menu
on/off while the bag remains tracked and shown (26/27). B closes it, a second B
reopens it, and a final B closes it again (28-30). Frame visibility snapshots
are taken after transitions settle; immediate screenshots can precede the
deferred restoration. All 24 active-addon samples retain spanning/READY.

Saved geometry is identical within 0.001 frame units across samples
10/12/18/20/25/26/27/29, including effective scale. This is the controlled
position fixture described below, not a physical-drag test. Bounded native
evidence assertions pass. All four historical BugGrabber records retain the
same message, time, counter and stack; no fresh record appears.

Closed the target client normally and preserved final private evidence before
restoring thirteen existing scoped files by SHA-256 and 22 original absences.
No originally absent scoped files were created. Both private observer TOCs
are disabled. All 96 installed non-bridge product files match the frozen
candidate. The verified corrected private build remains installed; Battle.net
and Companion are left open. Local restoration does not assert rollback of
server-side native layout state. No commit, release or Discord mutation.

## Evidence boundaries

Shared knowledge README/skill/status were consulted first. The pinned Forever
UI source predates build 70862 and is review-due. UnitExists has a documented
declaration in that corpus; native observations confirm the local plain boolean
results. The selected cache has no complete ToggleGameMenu implementation;
upstream search supplied no usable exact-client source. Record that as a source
gap, not API absence. Native baseline behavior is authoritative for this case.

The private observer stores only bounded frame geometry and visibility,
target-existence booleans, build and addon state. It installs no native hooks,
reads no unit identity/health, captures no chat and performs no shutdown reads.
The placement button uses Offhand's existing persistence helpers, so the saved
record is a controlled fixture, not a physical-drag acceptance test.

Combat, controller, separate/profession bags, replacement bags, exact reporter
profile and other physical layouts remain unverified. Daylight testing stays
deferred. No Discord or public release changes.
