# Discord refresh and vendor QA, 2026-11-10

## Read-only collection

The bot project's documented collector refreshed the Offhand forum, including
archived threads, at 08:47:34 UTC on November 10. Its four collector tests pass.
Only REST GET requests were used; no gateway session, messages, reactions,
statuses, tags, thread joins or archive changes. The snapshot contains 42
threads, including 19 archived, 2,286 history messages and ten referenced
originals, with zero reported collection gaps. Against the November 9 22:21 UTC
snapshot there are two new threads, 31 new history messages and one additional
referenced original. No old message IDs are missing. Two apparent embed edits
change only image URL/proxy URL fields, not report text.

All four newly attached images were downloaded and visually reviewed. They
show a spanned character-selection screen, a health/mana diagnostic, stock
PlayerFrame values, and the previously supplied loot-roll diagnostic. The
character-selection image is outside addon frame ownership. A separate support
reporter explicitly recovered stretched in-world UI by finishing setup; this
does not resolve other topology reports. The loot diagnostic adds no item ID,
remaining-roll state or first-error trace.

Private raw messages, images and hashes remain in ignored
dist/discord-refresh-20261110 and the bot's read-only snapshot directory.

## New reports and recurrence

| Report | Evidence and disposition |
| --- | --- |
| [Health/mana text and Escape with bags](https://discord.com/channels/1491522138371391691/1569545754253594744) | OH-UI-035. Forever 1.60.1 build 70862, beta28, remembered manual dual-landscape placement. Screenshot shows numeric stock player health/mana values. Native spanned positive/negative status-text controls work in the local candidate profile. Bag Escape behavior remains a separate reproduction, not attributed to unit-frame text. |
| [NPC quest window after single-screen restore](https://discord.com/channels/1491522138371391691/1569621972415946834) | OH-UI-036. Read the [linked original](https://discord.com/channels/1491522138371391691/1500958707918438442/1569616957311946783): NPC quest window had been moved to Mainhand, then disappeared after disabling Offhand and restoring the native window. No build/diagnostic or matched NPC interaction capture. Keep QuestFrame separate from the map quest log. No speculative Show or panel-registration changes. |
| [Details and Ellesmere databar recurrence](https://discord.com/channels/1491522138371391691/1551335554787057694/1569524937226715167) | OH-UI-037. Support follow-ups narrow one centering case to Details' main meter and another to Ellesmere's minimap databar. Details source and the controlled native case below establish a missing automatic-popup ownership exemption. The databar remains under existing minimap ownership work. |
| BetterBags / RestedXP | New replies still report those two movers specifically. Continue the [Next/V2 checks](BETTERBAGS-NEXT-RXP-V2-QA-20261110.md) using the vendor NPC made available by the user. |
| ProcDoc | Reporter moved other elements around its fixed center as a workaround. This is not acceptance of the optional adapter. |

## Details correction and evidence

Installed Details version #Details.20261109.15410.172 creates numbered
DetailsBaseFrame roots, owns their placement in instance/LibWindow state and
clears IsUserPlaced during drag completion. The cached shared knowledge source
was supporting evidence; installed vendor files are authoritative for this run.
Their hashes are retained privately. A missing indexed search result was
recorded as a retrieval gap, not evidence of API absence.

The correction exempts only complete names matching DetailsBaseFrame followed
by digits from automatic popup relocation. Configuration dialogs and names
containing an unrelated prefix retain normal recovery. No vendor settings,
handlers, native frame fields or native functions are replaced by the fix.

The production integration regression fails before the correction and passes
afterward through immediate/deferred ShowUIPanel and repeated popup/void
recovery. Negative name cases pass. All 121 frozen Lua suites and six manifest
Lua 5.1 checks pass; 81 runtime references include 80 Lua and one XML file. All
103 ZIP entries are hashed and verified. Private candidate SHA-256:
6f2366120b50eb83bb65b7807f20a08de1d5066a3dee7d7adc1a68556f9ae8ef.

Native baseline: Forever 1.60.1.70862 with Companion 2.1.5, spanning explicitly
applied to the 2560x1440 display, Mainhand right/workspace left, 1280x1440 each.
An actual Details meter physically dragged into the workspace remains through
map transitions and reload in this local profile. That alone does not reproduce
the report. A private source-backed fixture then invokes Details' own position
restore at CENTER 0,0 and clears IsUserPlaced, matching its drag-end state.
The pre-fix runtime relocates it to Mainhand within three seconds: native
snapshots 26-27 change CENTER x=0 to x=785.714 while preservation remains false.
This is a controlled native reproduction, not the reporter's exact profile or
natural trigger. Merchant opening/closing involves no item actions.

Post-fix snapshots 32-33 retain identical CENTER 0,0, rectangle and scale with
IsUserPlaced=false and preservation=true. A real title-bar drag into workspace
then retains geometry through normal reload (samples 35 and 37, within .001 UI
units) and subsequent merchant transitions. The private native checker asserts
these comparisons, the baseline displacement and the text controls. There are
38 refresh captures and 18 vendor captures in the preserved comparison file;
all report spanning true, and every vendor capture reports topology READY.
Logout captures are excluded from geometry comparisons because UI scale is
restored during shutdown.

BetterBags v0.9.2 Next small retains identical saved workspace geometry and
scale through actual merchant open/close and B reopening, both before and after
normal reload. Its native vendor panel opens on the workspace and closes from
its own X. RestedXP v4.11.35 V1 and V2 welcome roots keep identical workspace
geometry through the merchant transitions. No guide is loaded or advanced.
Immediate animation samples are not treated as settled placement. Bank,
guildbank, populated guides and exact reporter profiles remain unverified.
Vendor automation settings were temporarily disabled through vendor settings
for this test; their original SavedVariables are part of the scoped backups.

Error review found four unchanged historical errors plus one additional Details
teardown record (six occurrences). The latter stack reaches the private
observer's PLAYER_LOGOUT geometry read after Details releases its baseframe.
No product correction is attributed to that error. Shutdown geometry reads
were removed from both temporary controls, retaining scalar exit markers.
This limits the original run's clean-error acceptance; the final verification
reload and normal close are recorded with cleanup below.
A syntax error in the first helper-only cleanup edit was caught by Lua 5.1
validation after launch. Both private blocks and the complete helper were
corrected and syntax-checked before the verification reload. This was not a
production change; its load error and matching Lua-warning records are retained
with the QA evidence.

## Health text and remaining limits

On the local spanned profile, statusText=1 with statusTextDisplay=BOTH shows
both health and mana text; statusText=0 with statusTextDisplay=NONE hides them.
Both directions were visually checked and captured. This controls the pair of
CVars, not an acceptance test of the native Settings checkbox. Source search
finds no direct Offhand override of those text preferences. Supporting pinned
[Blizzard TextStatusBar source](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_TextStatusBar/TextStatusBar.lua)
also distinguishes the text enable CVar from formatting and per-bar force/lock
flags. That source predates the observed 70862 runtime.

With the stock workspace backpack and merchant target, Escape closed the
merchant and opened the menu; a second Escape closed the menu and restored the
bag while the target remained selected. This is a useful symptom capture, not
yet an isolated baseline comparison or a justified target-clearing fix.
Profession/separate bags and the reporter's profile remain unverified.

Exact reporter profiles, genuine group rolls, long item-specific tooltips,
combat/controller paths, NPC quest restore and other physical topologies remain
open where earlier QA has not supplied acceptance. Daylight live testing stays
deferred. No Discord or public release changes.

## Final verification and cleanup

The corrected helper visibly loads both toolbars after normal reload. Its
scalar exit markers are saved; its final startup captures spanning/READY, and
it performs no shutdown geometry reads. All seven error records remain
unchanged through that reload and normal close, including the earlier private
teardown record and two helper syntax/warning records. The four pre-existing
records remain unchanged throughout. Do not generalize this final clean segment
to combat or claim the earlier instrumented run had no errors.

Normal close leaves no WoW window. Battle.net and Companion remain open.
Thirteen original scoped files are restored by SHA-256, including addon flags,
Offhand/vendor settings, Config.wtf and the original observer source. All 22
originally absent paths are absent again; ten newly created files are preserved
in private evidence. Details was installed externally during the session; its
addon folder remains installed, while its scoped state is restored to the
pre-first-reload absence. IssueProbe and PerformanceProbe TOCs are disabled.
No profile reset or native Edit Mode layout save was performed.

All 96 installed non-bridge product files match the frozen private candidate.
Generated bridges were preserved during installation and remain outside source
placeholder comparisons. The pre-install product backup is retained. No public
artifact, release, commit, push or Discord changes.

Private ignored evidence: dist/discord-qa-20261110-6, including frozen package,
before/after regressions, vendor hashes, scoped backups, native comparisons,
error records, corrected-helper verification, cleanup and installation receipts.
