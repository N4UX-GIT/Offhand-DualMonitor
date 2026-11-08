# Forever backpack combat reopening fix, 7 November 2026

## Correction

Test15's independent native bag controller skipped every placement correction
during combat. Blizzard's opener can reset an existing root to its bottom-right
anchor, leaving that native location until combat ends. The earlier live run
confirmed restoration afterward, and confirmed that already-open bags could
remain positioned throughout combat.

Private test16 adds a narrow root-anchor correction for a previously initialized,
already-shown native backpack with an existing saved placement. During combat it
requires ordinary explicit native results: not forbidden, not protected, allowed
to change protected state, not anchoring-restricted, and no secret anchoring.
Test17 additionally permits Blizzard's native ContainerFrameContainer parent
directly under UIParent, with the same explicit permissions on that parent.
Test16 allowed only direct UIParent ancestry. Unknown, missing, secret,
failed or restrictive capability reads defer to normal post-combat recovery.

No native opener, visibility operation, drag, chrome write, state capture or
saved-variable update is enabled during combat. No native scripts, child
controls, parent changes, anchor-manager hooks or function replacement are added.
The existing independent poll corrects only the permitted root anchor. A failed
or silently rejected write suspends combat correction until combat ends.

Roots first encountered during combat, absent saved positions, replacement bags
and native Gamepad ownership continue to yield. Close-button redraw behavior in
combat remains separately deferred.

## Research and evidence

Shared knowledge status and SetPoint/IsProtected/IsAnchoringRestricted lookups
consulted. Collected Forever declarations are older 70532, so exact target
1.60.1.70862 primary declarations were checked at revision
9dc84f0d3bbae1768ac3405b3716000bd93eda06:

- [Region security and anchoring queries](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua).
- [Protected geometry methods](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua).

Those declarations support the capability checks, not combat or taint safety by
themselves. Earlier native IsProtected=false on the root likewise did not grant
blanket permission. Actual combat reopening and protected descendant use remain
acceptance requirements.

Expanded production-controller regression fails on test15 and passes this
candidate. Covers workspace/Mainhand restoration, actual lockdown and the
player-combat-only interval, capability denials/missing/secret reads, rejected
and silently ignored writes, suspension/recovery, no grip exposure, no native
opening and no persistence writes. All 99 suites and six source manifests pass.

Test16 native result: FAIL for separate backpack combat reopening on both
workspace and Mainhand. The recorder captured actual hidden/shown transitions,
native bottom-right anchors during combat, and saved placement restored at
+0.2 seconds after combat. Root capabilities were ordinary and permissive.
No new BugGrabber messages/counter changes; the user reported no Lua error using
an item afterward. The retained taint log has no blocked call matching this path,
which does not establish general taint safety. Closed the target normally,
restored 21 state/enablement files and two generated bridges, and removed the
temporary QA addon plus two created state files. Battle.net remains open.

Exact-build native XML declares separate bags under ContainerFrameContainer and
the combined root under UIParent. Test16's fixture modeled only the latter.
Test17 adds native-container ancestry coverage, actual hide/reopen, and denial
for unknown, reparented or protected containers. This new regression fails on
test16 and passes with the parent correction. No parent mutation is added.

## Test17 native acceptance

PASS for the separate native backpack on Forever 1.60.1.70862, keyboard UI,
temporary 50/50 span with workspace left and Mainhand right. Live diagnostics
confirm the root parent is ContainerFrameContainer. Root and parent permission
queries remained ordinary and permissive during combat.

The user explicitly closed and reopened the bag during combat on both sides,
including near combat end, and reported stable placement and no errors after
trying a bag item. The independent 0.1-second observer captured seven complete
hidden/shown reopening cycles on workspace and six on Mainhand during actual
lockdown. Every shown combat sample retained the saved coordinates within 0.01
UI units, with native parent unchanged. Workspace X stayed alpha zero/mouse
disabled; Mainhand X stayed alpha one/mouse enabled. This accepts these observed
backpack paths, not arbitrary native combat mutation or sub-frame flicker timing.

No new BugGrabber messages or counter changes. Preserved the pre-exit and final
taint logs without reloading after combat. No entries matched this bag adapter,
UseContainerItem, SetPassThroughButtons or ClearAllPoints. Seven secret-arithmetic
blocks explicitly name ForeverPlus Core/Util.lua:624 via Modules/BuffExpiry.lua;
these are separate third-party diagnostics, not a clean whole-session taint pass.
Post-combat item use passed by user report; in-combat item use remains untested.

Closed the target client normally, left Battle.net open, restored all 21 backed-up
state/enablement files and two generated bridges byte-for-byte, and removed the
temporary QA addon plus one created SavedVariables file. Test17 remains installed.

Equipped additional bags, combined-mode combat reopening, controller handling,
roots first opened during combat, and the reporter's exact profile are not
accepted by this run. Restricted or unknown capabilities still defer recovery.

Subsequent combined-mode QA accepts six recorded workspace combat reopening
cycles and explicit user confirmation of Mainhand combat reopening, stable
placement and post-combat item use. The Mainhand trace retained open-bag geometry
but missed its hidden interval; keep manual and recorded evidence distinct. No
new Offhand code change was needed. See
[combined-mode live QA](BAG-COMBINED-LIVE-QA-20261107.md).

## Packaging

Private 2.1.2-beta.26-forever-discord.test17 retains prior candidates and the frozen
public Beta20 Companion. Source TOCs remain public Beta26. Test15 ZIPs and an
installed-runtime backup provide rollback. Preserve generated installed bridges.
No public release, Discord message or issue closure is authorized by this work.
The immutable test17 ZIPs were built before native acceptance; their bundled
testing notes correctly describe acceptance as pending at build time. This report
and the external verification manifest record the subsequent live result.
