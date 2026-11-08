# Offhand Discord bug report audit, 7 November 2026

Test12 follow-up: Mort's settings-window Escape and Kerzo X reports are addressed
by specific adapters, with main-root keyboard acceptance on Forever 70862. See
[addon Escape follow-up](ADDON-ESCAPE-FOLLOWUP-20261107.md) for installed versions,
reload evidence, simulation/native boundaries and remaining limits.

Read-only refresh of the [bug forum](https://discord.com/channels/1491522138371391691/1555614339371769896):
30 reports and one template, including active and public archived threads.
The archive response has no further page. This refresh reads each starter and
up to 15 most recent messages, supplementing the earlier investigation. No
Discord messages, tags or thread states were changed.

Discord currently marks 18 reports Fixed and leaves 12 New/Confirmed. These
tags are workflow history. A promised next-release fix is weaker evidence than
a reporter retest. Candidate tests and local client observations below apply
only to their recorded client, build and steps.

## Reports and next actions

| Report | Discord tag | Review status and next action |
| --- | --- | --- |
| [Mismatched monitor heights and unreachable HUD](https://discord.com/channels/1491522138371391691/1555707584915439646) | Fixed | Historical recovery guidance shipped. Protected Edit Mode frames require the supported recovery/layout path. Retest only if current frames remain unreachable; capture actual monitor rectangles. |
| [Map does not refocus after changing zones](https://discord.com/channels/1491522138371391691/1556723227634573334) | Fixed | Maintainer identifies Beta 21 correction. No newer failure in reviewed replies. Retain closed historical status; a new failure needs current build, map owner and zone transition steps. |
| [Preferred druid Edit Mode layout replaced at login](https://discord.com/channels/1491522138371391691/1556723456282861741) | Fixed | Historical layout-ownership correction. No reporter acceptance in reviewed latest replies. Current preferences must remain character-specific and external layouts must retain ownership. See OH-EM-001/OH-FOR-003. |
| [Level-up map taint capture](https://discord.com/channels/1491522138371391691/1556770591531475004) | Fixed | Historical correction linked to quest/map-pin updates. A current regression requires first fresh taint stack and map owner; old beta captures do not establish a test5 failure. See OH-FOR-001. |
| [Battleground score at top cannot move](https://discord.com/channels/1491522138371391691/1556979426648924202) | New, Confirmed | Maintainer announced Beta 19 correction, then requested confirmation without a reply. Source includes dedicated battleground widget handling. Needs a real battleground retest before closing. Do not automate queueing/gameplay. |
| [Unspecified error during combat](https://discord.com/channels/1491522138371391691/1557080522025340998) | Fixed | Attachment-only historical error, no acceptance reply. Keep tagged historical status separate from verified resolution. A recurrence needs the first current error and exact trigger. |
| [Secondary chat windows reset on reload](https://discord.com/channels/1491522138371391691/1557094374200840274) | Fixed | Historical correction plus current detached-window settlement/ownership handling. Retest detached Mainhand and workspace windows through reload and zoning if symptoms persist. See OH-UI-002. |
| [Quest bag item use blocked](https://discord.com/channels/1491522138371391691/1557139720675262555) | Fixed | Historical UseContainerItem taint correction; action-bar workaround is not bag acceptance. Real bag item use and combat/taint require a manual tester. See OH-FOR-006. |
| [Secret aura access during combat](https://discord.com/channels/1491522138371391691/1557142877060993146) | Fixed | Historical Beta 18 stack. Current native aura ownership guards have automated coverage, but load/reload checks do not establish combat safety. See OH-FOR-005. |
| [Earlier Companion Windows scaling issues](https://discord.com/channels/1491522138371391691/1557457561039409253) | Fixed | Historical Beta 20 correction. Keep separate from the later confirmed 175% clipping report below. |
| [Beta 19 combat/map error](https://discord.com/channels/1491522138371391691/1557467476663468123) | Fixed | Maintainer explicitly records map-pin cause and confirmed fix. No newer failure in reviewed replies. Current recurrence needs fresh errors. |
| [Oversized combat/XP text](https://discord.com/channels/1491522138371391691/1557468806195060921) | Fixed | Historical engine-text scaling correction. Current source separates engine text from speech-bubble visuals. Keep distinct from the Ellesmere ownership conflict below. |
| [HUD frames missing while spanned](https://discord.com/channels/1491522138371391691/1557761233464197313) | Fixed | Historical Edit Mode recovery correction announced. No native reporter retest in this thread. If recurring, capture generated layout, external owners and frame bounds before rebuilding. |
| [M and L bindings fail with MoveAny](https://discord.com/channels/1491522138371391691/1557777525760073828) | Fixed | Reporter isolated MoveAny; maintainer added ownership yielding. No newer failure in reviewed replies. Retest with exact MoveAny version if recurring. |
| [Linux focus/unspan and HUD arrangement](https://discord.com/channels/1491522138371391691/1557837307820904600) | Fixed | Partial workaround and announced HUD correction. Native Wayland/Proton-Wineland focus behavior is not verified by Windows checks. Keep the runner/compositor investigation open despite the tag. |
| [Floating combat text over chat and button-side changes](https://discord.com/channels/1491522138371391691/1558483840542974094) | New | Current source explicitly yields docked Combat Log visibility and primary button side to Blizzard. Related correction exists; exact Better Forever Chat/native reproduction needs retest through Edit Mode, reload and incoming messages. See Core/CanvasChat.lua and OH-UI-002. |
| [Native controller support freezes reload](https://discord.com/channels/1491522138371391691/1559806807239696546) | Fixed | Maintainer links fortified controller support. No reporter retest in reviewed replies. Current keyboard reload pass does not cover switching native Gamepad mode. |
| [French guidance and span mismatch](https://discord.com/channels/1491522138371391691/1560316087269335082) | New | Test10 completes EFIGS dictionaries and passes the French main-settings dictionary preview, following test5's 138 setup/recovery/calibration/character keys. Full native-language/all-page acceptance remains open. The original topology mismatch is separate and requires full diagnostics. |
| [Flight master map off screen](https://discord.com/channels/1491522138371391691/1560973672364122195) | Fixed | Maintainer records correction. No current recurrence in reviewed replies. Native taxi interaction is outside this smoke test and needs a manual tester if reopened. |
| [Repair HUD repeats without Party Frames](https://discord.com/channels/1491522138371391691/1561755296504746058) | Fixed | Historical recovery correction announced. No reporter confirmation in reviewed replies. Preserve external party-frame ownership and capture layout provenance before a rebuild. See OH-FOR-007. |
| [Cutscene skip and contextual UI placement](https://discord.com/channels/1491522138371391691/1566101794562515045) | Fixed | Original scope has historical corrections. Later bag closure through Chat Settings/Edit Mode remains a separate follow-up. With workspace lock off, native panel closure is intentional in current source; define restoration expectations and identify bag owner before changing that contract. |
| [Guild invite, Chat Settings and controller map size](https://discord.com/channels/1491522138371391691/1567906926648631316) | New | Test5 translates eligible native dialog roots after native transactions and preserves stack links/ownership. Test11 passes Chat Settings placement, native reopening after spanned reload, Restore and tab navigation on 70862. Real guild accept/decline and controller behavior remain pending. |
| [ForeverPlus warning window](https://discord.com/channels/1491522138371391691/1567909191803347006) | New | Test6 adds a source-backed adapter for ForeverPlus 1.0.6 default warning bars after its PlaceAsBar transaction. Saved placements and mover/input ownership are preserved. Test11 preserves fixed row clearance and passes native vendor-transaction previews at 48/128-unit sizes and reroute off/on. Real warning/Gamepad/combat acceptance remains pending. See DISCORD-SOURCE-FOLLOWUP-20261107.md. |
| [Whisper Messenger random blocked action](https://discord.com/channels/1491522138371391691/1567914589495234641) | New | Image names WhisperMessenger as blocked but supplies no function stack. Installed v2.1.4 opens with /wmsg and closes with Escape on 70862 in the unspanned keyboard path. Incoming-message/controller triggers still need a fresh stack and Offhand-disabled comparison. No test messages sent. |
| [Stacked controller Map Back warning/enlargement](https://discord.com/channels/1491522138371391691/1567984437009055764) | New | Combined test5 contains the earlier map/controller candidates. Latest reply supplies a development package, not acceptance. Physical Back, Map then Spellbook, focused LB and fresh errors remain required. See OH-FOR-019/OH-FOR-020. |
| [Ellesmere bubble/overhead-text scaling conflict](https://discord.com/channels/1491522138371391691/1568021119393603627) | New | Existing bubble-owner guards are source-backed. Separate bubble visuals from engine damage/XP text and confirm Ellesmere's enabled profile. Test11 corrects a recurring shared-font reset, with a live external-font fixture pass. Ellesmere bubble customization was off in that run, so the report still does not establish which writer conflicts in its enabled profile. |
| [Zygor arrow and Ellesmere unlock toolbar disappear](https://discord.com/channels/1491522138371391691/1568022210801565781) | New | Zygor remains unverified; test5 has bounded read-only guide diagnostics. Test11 refits the Ellesmere toolbar after span geometry settles; native bounds then fit the portrait workspace. Zygor needs its own source/frame evidence. Capture exact vendor versions and the failing state. See OH-UI-022 and EXTERNAL-ADDON-REPORTS-20261105.md. |
| [Action bar Edit Mode screenshot](https://discord.com/channels/1491522138371391691/1568072216019468329) | New | Linked original image was inspected. It shows Action Bars 2/3 in Edit Mode; the thread has no written trigger or acceptance. Related OH-FOR-022 candidate separates generated secondary rows and has owner-reported provisional success elsewhere. Preserve that attribution boundary. |
| [Mainhand/Delay controls clipped at 175%](https://discord.com/channels/1491522138371391691/1568241793823154206) | New | Reporter confirms 175% and successful 150% workaround. Active Companion has dynamic layout; enlarged 175% simulation passes. Native dashboard and Span/Restore pass locally at 100%, not at reporter DPI. Store/reporter acceptance remains open. See OH-COMP-004. |
| [Aura window flashing under manual ultrawide split](https://discord.com/channels/1491522138371391691/1568299430090903602) | New | Reporter identifies reroute-popups option as trigger. Test5 excludes named Ellesmere aura roots and native aura ownership fallbacks. Exact flashing frame/Naowh profile remains unknown. Bot misread numeric span/UI scale; deterministic parser fix is pushed, deployment unverified. |

## Execution order

Additional supplied report: Kerzo Classic Quest Log's separate window closes
on Escape on Forever. Test8 adds a specific adapter for installed Kerzo 6.1.4,
preserving modal ordering, vendor placement and explicit close behavior. Current
source/simulated checks and [live keyboard Escape QA](KERZO-LIVE-QA-20261107.md)
pass in a single-display split on Forever 70862. Physical multi-monitor,
quest-item, combat and controller coverage remains open.
See [Kerzo Escape support](KERZO-QUEST-LOG-20261107.md).
Test9 also adds [reload restoration](KERZO-RELOAD-20261107.md). Live checks pass
automatic workspace reopening, Escape afterward and staying closed after an
explicit close/reload. Both existing persistence preferences gate restoration.

Additional supplied report: Dy's Beta 26 Forever screenshot shows repeated
EncounterBar Repair HUD prompts after reload. Test7 addresses a missing targeted
custom-anchor repair and an empty-root false positive. Test10 passes a controlled
native reproduction on Forever 70862 in the actual mixed-height monitor gap:
one repaired entry, unrelated entries preserved at save time and no repeated
prompt after reload. An external action-bar recovery ownership conflict found
live is also corrected. The reporter's exact saved layout and real encounter,
combat and controller actions remain separate acceptance items.
See [EncounterBar investigation](ENCOUNTERBAR-REPAIR-20261107.md).

1. Test11 completes the available keyboard Chat Settings placement/lifecycle and
   vendor-transaction warning previews on Forever 70862. See
   [noncombat follow-up](NONCOMBAT-FOLLOWUP-20261107.md) for three new corrections,
   native evidence and the remaining real-trigger and reporter-specific gaps.
2. Use a manual tester for actual guild invitation, Gamepad Back/LB and bag item
   actions, saving first fresh errors before reload.
3. Retest named external owners separately: aura flashing, bubble visuals,
   Zygor, Ellesmere toolbar and native/Better Forever Chat.
4. Verify the 175% Store restart on the affected monitor and connected-TV
   identity case on reporter hardware. Local two-monitor success does not
   establish either.
5. Check Linux native Wayland on the reporter's runner/compositor. Verify the
   bot's deployed commit once its Railway service or health target is known.

Implementation details and constraints remain in `docs/ISSUES.md`.
Local package/client evidence is in `docs/FOREVER-DISCORD-TEST5-20261107.md`.
