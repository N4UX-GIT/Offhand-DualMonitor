# Forever NPC panel release QA, 2026-11-10

Continued the remaining Discord reports with explicit Companion spanning.
Daylight live testing remains deferred. No Discord messages, statuses or report
tags changed. Exact NPC QuestFrame acceptance remains open.

## Report and initial lifecycle check

[OH-UI-036](https://discord.com/channels/1491522138371391691/1569621972415946834)
reports an NPC quest window missing after moving it from workspace to Mainhand,
disabling Offhand and restoring the single-screen client. The authorized local
character is beside a merchant, so the test uses the real MerchantFrame as a
shared interaction-lifecycle check, without quest acceptance or item actions.

Forever 1.60.1.70862, Companion 2.1.5, one 2560x1440 display split into right
Mainhand and left workspace. The installed private baseline is archive SHA-256
dba0e873a99ec65ccc93391eb8803a646e723e2c8c0428a339095ad8b55a4773.
All 97 installed non-bridge product files match it. Addon enable flags request
Offhand, private observer and error tools; Details also loads, so no clean
addon-isolation claim is made.

The first pass uses controlled saved positions and production
RestoreWorkspacePosition, not a successful physical drag. Merchant workspace
placement (400,1300 UI units), native X closure and NPC reopening succeed.
Moving the saved placement to Mainhand (2000,1300) retains the active native
panel slot. Disable restores root scale from 0.4344242513 to 0.6399999857 and
leaves the still-open panel partly clipped. Companion Restore Window returns
it to native TOPLEFT (16,1084), and it reopens after normal /reload with Offhand
disabled. No disappeared quest-window reproduction is claimed.

Initial handle displacement inference was incorrect: GetEffectiveScale alone
does not convert this client's logical canvas coordinates to physical pixels.
UIParent canvas dimensions and physical window dimensions must also be used.
The corrected comparison aligns the title and handle. Two attempted drags do
not meaningfully move the panel; physical dragging remains unaccepted.

The temporary observer initially calls tostring with zero values while a hidden
merchant has no coordinates. Its one new BugGrabber record has 81 occurrences;
the four historical product/vendor records are unchanged. This is a private
helper error, not a product defect or an error-free run. The helper now assigns
optional coordinates to locals before tostring; a hidden-coordinate fixture
and Lua 5.1 compilation pass. The next native baseline has no new errors.

## Natural disable defect and native control

A second cold launch with the corrected observer opens the merchant normally,
with no saved-position fixture. Its native slot is left and shown=true, at
(2189.1428,1105.9286) UI units while spanned. Disabling Offhand restores root
0.64 but leaves those coordinates unchanged, moving the merchant completely
outside the visible client. Calling native UpdateUIPanelPositions restores
the same still-open registered panel to (16,1084), visibly inside the canvas.
No hide/show, ShowUIPanel, interaction close or item action is used.

Knowledge README/research skill/status and QuestFrame/panel-release searches
were consulted first. Forever cache is review-due and predates 70862. It lacks
the shared panel implementation in its selected files. Supporting pinned
[panel manager source](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua)
defines the native update wrapper and slot reflow; private source SHA-256 is
aab8401ff78f0ce32087fc6033a36b79a736ccbaf2aaa8b7d2342f6c4c09fbec.
It was read as data, never executed or copied into the addon. The observed
70862 comparison, not this older mirror alone, establishes the local repair.

## Candidate

Viewport now requests native panel reflow after it actually changes the root
back during Forever disable or loss of span. It leaves native visibility and
registration intact, yields to later external scale choices, skips combat and
does not repeat the reflow on inactive layout passes. Other client adapters
and logout cleanup are unchanged.

The production regression fails before and passes after. All 123 frozen Lua
suites, six manifest Lua 5.1 checks (81 Lua, one XML) and 104 archive entry hashes
pass. Only Core/Viewport.lua changes at runtime relative to the prior validated
candidate. Private archive SHA-256:
8cb11cac0150cf09021b38db23916aa4f52b1127be0951ddd19c010207368d94.
Original installed product is backed up; generated bridges are preserved.

## Corrected native acceptance

Cold launch of that exact installed candidate retains explicit Companion
spanning. Normal NPC opening, without saved-position fixtures, places the
merchant at (2189.1428,1105.9286). Both disable cycles automatically return the
same shown MerchantFrame to (16,1084) at restored root 0.6399999857. Its native
left slot and registration remain intact. Re-enable returns the still-open
interaction to Mainhand; the native X then closes it normally and releases its
slot. No manual UpdateUIPanelPositions call is used in the corrected run.

The bounded observer records 16 samples: 15 spanned/READY, followed by one
intentional unspanned/MISMATCH after Companion Restore Window. No new
BugGrabber errors: all four historical records, messages, timestamps, counters
and stacks remain unchanged. This demonstrates the out-of-combat merchant
release repair, not combat/taint safety, physical dragging or exact QuestFrame
acceptance. No item transaction, quest acceptance or gameplay movement occurs.

Normal client exit is confirmed before evidence collection and restoration.
All 53 fresh pre-run scoped files match their original hashes, all 126 original
absences are restored, and both private helper TOCs are disabled. All 97
installed non-bridge product files still match the corrected candidate. The
private build remains installed; Battle.net remains open.

## Read-only Discord refresh

15:44:51 UTC scan retains 42 threads (19 archived), 2,292 messages, ten referenced
originals and zero gaps. No new/edited report or image content. All differences
normalize away as attachment or embedded-image URL query strings. Existing
report images remain reviewed in the preceding report ledger.

Private evidence is under ignored dist/discord-qa-20261110-10 and -11. The first
pass's 20 samples include the intentional transition to unspanned/MISMATCH;
do not describe them all as spanned acceptance. Each cleanup restores 53 fresh
pre-run files by hash and 126 original absences, with new files retained
privately. No public release or commit.
