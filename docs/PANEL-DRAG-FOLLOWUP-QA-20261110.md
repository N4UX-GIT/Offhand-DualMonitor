# Spanned panel drag follow-up, 10 November 2026

Continues the remaining placement reports, especially OH-UI-036. Daylight live
testing remains deferred. No Discord writes, vendor edits or public release.

## Candidate and setup

Forever 1.60.1 build 70862, Companion 2.1.5, explicit Span WoW Now before entry.
One physical 2560x1440 display, right Mainhand and left workspace. The prior
validated panel-release candidate remains installed, SHA256
8cb11cac0150cf09021b38db23916aa4f52b1127be0951ddd19c010207368d94.
All 97 installed non-bridge files match. Offhand and private error/observer
tools are requested enabled. Details also loads, so addon isolation is not
claimed. The same idle character remains beside the authorized merchant.

Fresh scoped backups precede any file/settings change. The observer reads
MerchantFrame and its addon-owned grip, position records and native panel slots.
It does not force a merchant position or invoke a drag handler. All 23 bounded
snapshots report spanning true and topology READY. No item transactions, quest
acceptance or gameplay movement occur.

## Gestures and comparison

Three sky.drag title gestures, including workspace and shorter Mainhand drops,
do not meaningfully move the merchant. A stock backpack title comparison also
does not move it. An addon-owned private frame with ordinary StartMoving and
StopMovingOrSizing handlers does move from the same automation, demonstrating
that drag input works for that control. This does not establish equivalent
native Button/template gesture timing or a product defect.

The visible merchant grip is shown, mouse-enabled and level 511. Full canvas
conversion puts its bounds near physical (1838.55,539.99), 169.43x26.07 pixels,
covering the attempted title point. Do not use effective scale alone as a
physical-pixel conversion. Hidden merchant coordinates are not visible panel
placement evidence.

Normal NPC reopening after two reload checkpoints retains the merchant at
(2189.1428,1105.9286) UI units. The first attempted gesture records that same
Mainhand position; it does not establish successful physical relocation or
workspace persistence. No disappeared window is reproduced.

## Bounded writer trace

A separate instrumented checkpoint observes only MerchantFrame's StartMoving,
StopMovingOrSizing, SetPoint and ClearAllPoints through public post-hooks. It
records at most 100 calls over 90 seconds, skips combat and neither replaces
native handlers nor changes native geometry. Twelve calls are retained.

Native PanelDragBarMixin starts movement, then stops approximately 17 ms later.
The first native StopMovingOrSizing already reports the original coordinates.
There is no intervening SetPoint/ClearAllPoints call in this trace. Offhand's
subsequent persistence calls retain those coordinates. This narrows the observed
gesture but does not establish why native movement made no progress, nor rule
out engine-internal behavior invisible to these hooks. No speculative movement
or repeated-StopMoving correction is made.

Knowledge README/research skill, status and drag-placement searches were
consulted first. The question packet is unknown and the selected Forever cache
lacks the relevant templates; this is a gap, not API absence. Supporting older
[native template source](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua)
defines target StartMoving/StopMovingOrSizing at lines 1559/1583. Lua SHA256
12f9600965f41d0c0ace7b2270c7928f0f4d3229d634e881f1daaf5ef1f03e65;
matching XML SHA256
3ef3c573e14f073c779018da4ca92c06a21648081a1067f966e6b92688a53ff9.
The source is read as data, never executed or copied into the addon. Actual
70862 stack paths match the template's drag method lines. Neither older source,
post-hook observation nor out-of-combat success proves taint/combat safety.

## Refresh, cleanup and remaining gates

GET-only Discord scan at 16:16:10 UTC retains 42 threads, including 19 archived,
2,292 history messages, ten referenced originals and zero collection gaps.
Recursive attachment/embedded URL query normalization finds no added, removed
or changed message/report/image content. No new images require review.

Normal client exit is confirmed before evidence collection/restoration. All 54
fresh scoped originals, including the private helper source, match their hashes;
all 126 original absences are restored. Both helper TOCs are disabled. All four
historical BugGrabber message/time/counter/stack records remain unchanged. The
97-file installed private candidate is unchanged; no new product code or
package is created. Battle.net and Companion remain open.

Exact quest interaction, successful native physical dragging, affected profiles,
combat/controller, genuine multi-roll/tall-item and portrait/4K hardware cases
retain their existing open gates. Private ignored evidence is under
dist/discord-qa-20261110-12, including scoped backups, 23 snapshots, twelve-call
trace, pinned source data, Discord comparison and cleanup receipt.
