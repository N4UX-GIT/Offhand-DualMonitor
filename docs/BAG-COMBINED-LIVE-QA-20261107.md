# Combined native bag combat QA, 7 November 2026

## Scope

Offhand private 2.1.2-beta.26-forever-discord.test17, Forever 1.60.1.70862,
keyboard UI, same user-selected test character with only its backpack equipped.
Temporary 50/50 span places Offhand left and Mainhand right. Native combined
mode is confirmed by CVar value 1, the Combined Backpack title, and the recorder's
ContainerFrameCombinedBags identity. Bag replacements are temporarily disabled
in backed-up enablement files. Other existing addons remain enabled.

Shared knowledge status and native bag combat evidence consulted. Collected
70532 source is review-due; combinedBags retrieval returned a gap. Target-client
UI and recorder observations are authoritative for this run. No new production
API decision or code change is needed to prepare the existing test17 path.

Installed runtime hashes match the validated test17 package, excluding the two
preserved generated bridges. The focused native-bag regression passes. The prior
test17 source and extracted-package evidence remains 99 suites and six manifests;
those full checks are not represented as newly run for this unchanged runtime.

## Out-of-combat baseline

Native combined bag opens on Offhand. B visibly closes it and reopens it at the
same position. Hide-close-buttons reversal restores alpha 1/mouse enabled, then
returns to alpha 0/mouse disabled. No visible Lua error during these checks.

For manual combat acceptance, the user is instructed to physically drag
and save a workspace position first, visibly close/pause/reopen several times in
combat, then repeat from a saved central Mainhand position. Post-combat item use
is included. The independent observer samples visibility and root geometry every
0.1 seconds during combat when either changes. No automated combat/gameplay input
is used. No reload is requested after combat, preserving the run's taint log.

## Combat result

Workspace PASS: six actual hidden/shown reopening cycles during lockdown, all
shown samples retaining the saved position within 0.01 UI units. The native root
remains directly parented to UIParent, with ordinary permissive security and
anchoring flags. Workspace X remains alpha 0/mouse disabled.

Mainhand manual PASS: the user explicitly confirmed visible closing and reopening
while combat was still active, stable placement, and no error after item use.
The recorder corroborates combat entry, stable open-bag geometry and post-combat
state, with X alpha 1/mouse enabled. However, the 7.6-second Mainhand combat has
no recorded hidden interval. Actual reopening on this side is accepted from
explicit manual confirmation, not independently established by the trace. The
reason for the missing visibility transition remains unknown.

No new BugGrabber messages or counter changes. Preserved pre-exit and final taint
logs without reloading after combat. Six blocked secret-arithmetic entries name
ForeverPlus Core/Util.lua:624 via its buff-expiry path. None matches the Offhand
bag adapter, UseContainerItem, SetPassThroughButtons or ClearAllPoints. This is
not a clean whole-session taint pass. In-combat item use is not tested.

## Evidence and cleanup

Private diagnostics remain outside addon packages. Before launch, 21 original
state/enablement files and both generated bridges were backed up. Final log and
BugGrabber comparison completed. Closed the target client normally, restored all
21 original state/enablement files and both bridges byte-for-byte, and removed
the QA addon plus one created SavedVariables file. Battle.net is retained.

Result: PASS for tested combined-backpack reopening, with Mainhand reopening
confirmed manually and workspace reopening also corroborated by recorder. No
Offhand defect found requiring a code change. Installed runtime and both test17
ZIP hashes reverified after cleanup. No package rebuild, public release or Discord
message. Equipped extra bags and controller testing are outside this run.
