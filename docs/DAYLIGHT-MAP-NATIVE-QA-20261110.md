# Daylight world-map ownership QA, 10 November 2026

User permits revisiting Daylight testing. Forever 1.60.1 build 70862, project 18,
enUS on Windows, Companion 2.1.6, explicit 2560x1440 equal-halves spanning with
right Mainhand and left workspace. Same idle character; no gameplay, item
transactions, quest acceptance, Discord messages or statuses.

## Source and test setup

Shared knowledge status and Daylight/MapMove search consulted first. Forever
cache ca8368f2f238 remains review-due and predates this build. Installed
DaylightUI/Skins 1.6.6 is authoritative: MapMove.lua SHA256
480458a992f8bd6e105282cee3bd1055cacd52324a05a9bd454a7dc5c2413be4.
The existing public Start/Scale/Apply contract remains intact. Its regression
passes against the actual installed mover in an isolated Lua mock runtime.

Fresh scoped backups include 187 paths and both account/character vendor stores.
An initial setup run did not load Daylight because staging recognized only
numeric addon flags, whereas Forever wrote enabled/disabled. That run was closed
and restored. Corrected staging supports both formats. Baseline still loads
Details/ProcDoc defaults where no explicit inventory entry exists; pure addon
isolation is not claimed. Corrected acceptance explicitly stages every installed
folder's enable flag and captures actual loaded-addon indicators.

Private addon-owned controls save a controlled Offhand workspace map placement
through production persistence, set reversible vendor fixture mapSpot=(19,1141)
and mapScale=0.86 through public Start, and open/close Character. This models
the conflicting saved geometry, not the reporter's imported profile or physical
drag. The skinned map/title and normal UI remain visible. Bounded geometry and
post-panel hooks observe the actual map; they are private QA instrumentation,
not production hooks or a combat/taint proof.

## Native baseline and new failure

Baseline archive SHA256
6c0b83411cce50c10fd98e9eeb6eb24459c3713db61bbf64d05278fb6b4f7d64.
Existing adapter retains scale 1.495100021 and local anchor
(8.026219368,1162.368530273) during Character opening/closure. The post-HideUIPanel
observation already has that geometry in the same call. Vendor settings retain
(19,1141,0.86); bar/grip become noninteractive and grip alpha zero. Disable
restores vendor scale/anchor and mouse/alpha, re-enable returns to Offhand,
and /reload retains the saved placement.

Restore Window releases the adapter and temporarily hides the workspace map.
Reopening it then invokes Canvas:PlaceForSingleScreenRecovery, which replaces
Daylight's restored position with CENTER UIParent CENTER. Calling vendor Apply
restores the saved top-left position, confirming the two competing paths.
This is a distinct release-path defect discovered during native acceptance.
The original loot/flight/PvP one-frame report is not reproduced literally.

## Accepted controlled correction

The adapter now identifies a valid vendor map position for single-screen
recovery only when its inspected module and wrapper identities still match,
the module is enabled, and both saved coordinates are finite numbers.
Canvas's recovery fallback leaves only that verified world-map placement alone.
Other panels and maps without supported vendor placement still recover normally.
The existing workspace acquisition and deferred visibility logic are retained.
No vendor source, stored setting, native handler or recurring task is added.

The new production recovery regression fails before the guard and passes after;
adapter fixtures cover disabled/malformed vendor state, other panels and spanned
ownership. All 123 frozen Lua suites, six manifest Lua 5.1 checks and 104 ZIP
hashes pass. Candidate SHA256:
a6428faafef3b1b8ab1e2e02466d3b1233dc77d830f62190673db2258087868b.
Only runtime deltas versus baseline: DaylightMapCompatibility.lua and
CanvasPanelPlacement.lua. Installed 97 non-bridge files match; bridges retained.
Corrected native acceptance passes: 32 snapshots include 21 active map samples
with unchanged placement and 11 vendor-owned visible samples at the saved
position/scale. Three same-call HideUIPanel post observations preserve Offhand
geometry. The separate panel-post stream contains 21 observations; geometry
logging stops at its 120-entry cap. Character closure, disable/re-enable,
/reload and Restore Window/reopen pass. The reopened unspanned map now stays
at Daylight's saved position without an explicit vendor Apply correction.
Bar/grip mouse state and grip alpha restore while vendor-owned, and yield again
when Offhand reacquires placement. Stored fixture values remain (19,1141,0.86).

Actual loaded-addon flags in all corrected snapshots confirm Daylight core and
Skins loaded, with Details, EllesmereUI core, ProcDoc, OpenMap and Leatrix Maps
not loaded. This is stronger isolation than the baseline, so it does not imply
native acceptance of every combination from the reporter's profile.

Four historical BugGrabber message/time/counter/stack records remain unchanged
through setup, baseline and corrected runs; no new visible/captured Lua error.
Every QA client closed normally, with no WoW window remaining. Restored all 55
existing scoped files by SHA256 and 132 prior absences, including Daylight's
original profile, Offhand settings, local native caches and addon flags. Both
private helper TOCs are disabled. All 97 installed non-bridge product files
still match the candidate. Battle.net and Companion remain open; no release.

Final cleanup also refreshes the generated Forever recovery data bridge from
the hash-verified restored account/character files, using the inspected producer's
existing wrapper and hash format. Companion snapshots once on client exit and
had already captured temporary QA state before local file restoration. Bounded
data comparison now confirms both bridge tables equal restored local state.
The prior generated file is backed up privately; topology/calibration is untouched.
Future QA cleanup must include this generated-state check as well as local
SavedVariables restoration. This data refresh is separate from the 97 product
file comparison and is not a Companion binary change.

GET-only Discord refresh at 17:25:47 UTC covers 42 threads (19 archived), 2293
messages and ten referenced originals with no gaps. One new support report,
OH-UI-040, concerns Companion 2.1.5 missing stable display bindings. Its attached
screenshot was reviewed via the supplied image proxy after CDN access returned
403. No other content/attachment edit, deletion or thread change was found.

Combat, actual loot/flight/PvP closure, profile switching, Gamepad transitions,
maximized/minimized presentation, physical Offhand dragging and the reporter's
two-monitor arrangement remain separate acceptance gates. No performance claim.
Private ignored evidence: dist/discord-qa-20261110-14.
