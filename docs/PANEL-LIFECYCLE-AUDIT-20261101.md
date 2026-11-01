# Panel lifecycle audit, 1 November 2026

The tester reports that beta.24-tbc-test.4 resolves the map/spellbook issue.
Record this as reporter acceptance of the reported visibility/coexistence
problem on TBC Anniversary 2.5.6.70577, not completion of the full combat,
taint, Escape, addon compatibility or cold-login matrix.

The audit found four additional contract gaps. They are reproducible in local
source/model probes; none is represented as a newly observed in-game failure.
The initial audit did not change addon behavior or installed files. The user
subsequently authorized remediation; see the test.5 implementation record
below. Pending Retail work was left alone.

## Scope and evidence

Reviewed shared Canvas registration, demodalization, slot eviction, Escape,
workspace persistence, load-on-demand restoration, recovery eligibility and
the TBC coexistence adapter. Reviewed the Retail/Forever exclusions as source
boundaries. This is not a certification of every panel on every supported client.

Target source is TBC Anniversary 2.5.6.70577, pinned upstream revision
`68e0a2ec559d9761dfc4e7f864c3944f9d758a49`. Thirteen source files were fetched
as data; no upstream scripts were executed. URLs, paths and SHA256 hashes,
plus probe output, are retained outside the addon at:
`D:/Tools/Code/N4UXADDONS/wow-addon-knowledge/.cache/offhand-panel-audit-20261101`.

Shared knowledge status and an Anniversary protected-ownership/persistence
query were run first. The query returned authored guidance only, with no
client implementation evidence. Exact-build upstream supplied that evidence.
Existing source selection/index gaps remain explicit; no API absence was inferred.

## Findings

### 1. P1: Classic NPC windows are classified as independent menus

Location: `Core/CanvasPanelRegistry.lua`, `contextBoundPanelNames` and
`IsContextBoundPanel`; `Core/CanvasPanelLifecycle.lua`, `DemodalizePanel`.

The exclusion table contains AuctionHouseFrame, StableFrame and FlightMapFrame,
but omits TBC's AuctionFrame, PetStableFrame and TaxiFrame. It also omits
GossipFrame and the NPC QuestFrame (distinct from the standalone QuestLogFrame).
The local probe confirms that all five are accepted as base persistence
candidates and their panel registrations are deleted by generic demodalization.
They are not protected by Canvas's non-movable-system-panel list either.

These windows require an active world interaction. The exact-build auction
XML OnHide closes the auction session, PetStable XML OnHide closes stables,
GossipFrameSharedMixin.OnHide calls CloseGossip, and QuestFrame_OnHide calls
CloseQuest. Generic slot eviction can therefore close the interaction before
directly showing its shell again. Generic Escape persistence and reload intent
also apply the wrong ownership policy. The local classification/deletion is
confirmed; actual NPC/session breakage requires target-client reproduction.

Repair direction: add the actual Classic root names to interaction ownership,
preserve native registration/closure, and exclude their saved open intent from
standalone restoration. Keep positional records without deleting user profiles.
Do not classify QuestLogFrame as interaction-bound merely because QuestFrame is.

### 2. P2: TBC Escape can still hide and directly re-show the protected pair

Location: `Core/CanvasPanelLifecycle.lua`, legacy CloseAllWindows wrapper,
especially temporary registry-area stripping and the final failsafe Show loop.

The wrapper clears UIPanelWindows[name].area to prevent native closing. Once
native UIPanelLayout attributes are materialized, however, the exact-build
CloseWindows closes native left/right/fullscreen/doublewide slots independently
of that registry edit. A center slot with cached area=left is also closed even
when ignoreCenter=true. Map/book now deliberately retain native registration
and slots, so this route is relevant to test.4.

Running the actual local wrapper against a bounded model of that slot behavior
produces two native hides followed by two direct Shows for the saved workspace
pair. The final screenshot could look correct while callbacks and providers
were needlessly torn down/recreated. This defeats the lifecycle preservation
that motivated the visibility fixes. No specific taint or callback failure is
claimed from this model.

Repair direction: review a TBC-specific native cleanup filter with correct
context/ignore semantics, or explicitly retain native Escape closure until it
is verified. Do not solve it by deleting map/book registration again or by
unconditionally copying Retail's protected-input handling.

### 3. P2: Unloaded TBC menus cannot restore their saved open state

Location: `Core/Canvas.lua`, `RequestPersistentPanelLoad`, initial family gate.

The restore loop calls RequestPersistentPanelLoad for an absent frame with
saved workspace/open intent, but the method immediately rejects every client
except Forever and two explicitly listed Retail roots. TBC therefore never
loads the owner, despite the shared panel registry having a MacroFrame seed.
The exact-build Blizzard_MacroUI_Classic.toc declares LoadOnDemand: 1.

The probe executes the exact method extracted from local Canvas with explicit
saved/open MacroFrame state: on TBC it returns false with zero load attempts.
The same fixture with Forever identity loads once, providing a positive
control. This is a restoration gap, not evidence that manually opening Macros
fails. It primarily affects reload/cold login when the owning addon is unloaded.

Repair direction: define a client-capability/owner policy for safe standalone
menus and test loading, initialization settlement, combat, cancelled intent
and reopen timing. Avoid simply removing the family gate for all unknown or
interaction-bound panels.

### 4. P2: Active coexistence synchronization overwrites later layout writers

Location: `Core/CanvasPanelLifecycle.lua`, UpdateTBCWorkspacePanelSlots,
workspace branch setting pushable and allowOtherPanels to 1.

The cleanup path preserves an attribute that no longer equals Offhand's last
value, but the active path unconditionally sets every differing value back to 1.
The probe applies the policy, simulates a later native/addon pushable=5, then
calls synchronization again: the later value is overwritten with 1.

Existing tests only checked an external change immediately followed by policy
cleanup, missing this active-state case. Named external map ownership already
yields correctly; this finding concerns later attribute writers that do not
activate that ownership detector. A specific conflicting addon is not claimed.

Repair direction: detect divergence from the values Offhand last applied and
yield for the current ownership session, with deliberate reacquisition after a
fresh workspace transition. Define whether native reset and external takeover
can be distinguished before automatically reapplying.

## Reproduction and validation

Run `lua tools/audit-panel-contracts.lua` from the project root. It executes
local code in isolated fixtures and prints NPC-LIFECYCLE, ESCAPE-LIFECYCLE,
TBC-LOAD-RESTORE and ACTIVE-OWNERSHIP. Exit 1 intentionally reports detected
contract gaps. The Escape fixture models the pinned native decision; it does
not run native code or establish client timing/protected-action safety.

All 75 existing Lua regression suites pass, as do Lua 5.1 syntax for the new
audit probe and git diff whitespace checks. Passing existing tests does not
invalidate the four additional audit detections. No broader live matrix or
new package acceptance was performed.

Prioritize NPC ownership and Escape lifecycle before expanding panel support.
Then address standalone reload support and active ownership arbitration.
For the next candidate, test Auction House, stablemaster (hunter), taxi,
gossip/quest offer and reward dialogs, plus the standalone quest log, character,
spellbook, map and Macros. Cover dragging, both opening orders, X/key/Escape,
repeated NPC interactions, reload/cold login and fresh combat/taint evidence.
Test a fourth native window separately: test.4 only enables two-window native
coexistence and does not provide unlimited panel slots.

## Primary source locations

- [Pinned native panel manager](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua)
- [Classic registered panel names](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_UIParentPanelManager/Classic/UIPanelWindows.lua)
- [Auction root and OnHide](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_AuctionUI/Classic/Blizzard_AuctionUI.xml)
- [Stable root and OnHide](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_UIPanels_Game/Classic/PetStable.xml)
- [Taxi lifecycle](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_UIPanels_Game/Classic/TaxiFrame.lua)
- [Gossip lifecycle](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_UIPanels_Game/Shared/GossipFrameShared.lua)
- [NPC quest lifecycle](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_UIPanels_Game/Classic/QuestFrame.lua)
- [Macro load-on-demand manifest](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_MacroUI/Blizzard_MacroUI_Classic.toc)

## Authorized remediation, test.5

All four findings now have source candidates and regression coverage:

- NPC root aliases are interaction-bound. Native registration/closure is
  preserved; new or stale standalone open intent is rejected/cleared when
  recorded, while positional records remain intact. QuestLogFrame remains a
  standalone menu.
- Anniversary uses the native CloseAllWindows dispatcher and a targeted
  CloseWindows cleanup filter. Workspace standalone roots are kept without
  synthetic Hide/Show or registry edits. NPC interactions, explicit context or
  ignored-frame transactions, reserved input, combat and unspanned/disabled
  states retain native cleanup. Maximized/external map ownership stays native.
  If required APIs are absent, TBC falls back to native closure rather than
  installing the old hide/show failsafe. Other clients keep their prior route.
- TBC standalone loading initially allows only MacroFrame from the verified
  Blizzard_MacroUI owner. Learned names cannot expand that pair. Requests are
  coalesced/deferred in combat and revalidate open intent, enabled/persistence/
  reload settings and span state before owner loading. The existing delayed
  restore rechecks again before showing the initialized frame. Existing
  Forever and explicit Retail standalone policies remain available.
- Coexistence tracks the values it applied. Active divergence yields for the
  current workspace ownership session, preserves the changed value, and restores
  only other attributes it still owns. A fresh ownership transition permits
  reacquisition. Combat still blocks attribute writes.

Tests added: `tests/tbc-npc-and-escape.lua`, `tests/tbc-macro-reload.lua`.
`tests/tbc-workspace-panel-slots.lua` now covers active divergence and session
yield, and the standalone audit fixture has a real dynamic cleanup lookup.
The audit now reports zero detections, exit 0. All 77 workspace Lua suites and
75 frozen-source suites pass. Packaged and installed six-manifest paths/XML/
Lua 5.1 validation passes; all 76 ZIP files hash-match staging and installed
files match except the deliberately preserved generated bridges.

Artifact: `dist/Offhand-v2.1.2-beta.24-tbc-test.5.zip`.
SHA256: `7D6560F4CFA2B6938A6816886FBE951C17FC13A725418C4F03C90B6D8D915326`.
Instructions: `dist/Offhand-v2.1.2-beta.24-tbc-test.5-TESTING.txt`.
Source/extracted package/audit output/validation/deployment inventory:
`C:/Games/World of Warcraft/_offhand_deploy_backups/tbc-panel-audit-test5-20261101-153442-118`.
The earlier `tbc-panel-audit-test5-20261101-153314-470/installed-before` backup
retains the accepted pre-test.5 local installation; the final backup records
the provisional diagnostic iteration. No provisional test.5 was delivered.

Snapshot uses committed baseline 09c6f315574b4c9eb7fa8036abec7798a8c3ce1c plus
the TBC overlays. Pending Retail toast/pet-battle changes are excluded, including
the unrelated new Canvas PetBattleFrame policy line. Earlier test packages,
profiles, WTF/SavedVariables and Companion executables are preserved. Installed
candidate is under `C:/Games/World of Warcraft/_anniversary_/Interface/AddOns/Offhand`.

No in-game test.5 session was run. Native interaction continuity, Escape's
actual secure execution, Macro reload/cold login and combat/taint behavior
remain pending. Test.4 reporter acceptance does not validate these additions.

Test.6 follow-up: new Game Menu bag-opening and closed-before-reload failures
showed limits beyond the original four audit probes. Anniversary is now
excluded from legacy whole-bag Escape recovery, P/L/native-hide closures are
tracked correctly, and its transition snapshot replaces stale known-frame
open flags without deleting geometry. Detailed evidence, regression scope and
artifact hash are in `docs/TBC-MAP-REPORT-20261031.md`. The audit's zero result
only covers its named contracts; it is not a claim that all UI paths are safe.
