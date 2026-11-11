# Discord report review, 9 November 2026

The read-only bot collector reviewed the Offhand support channel and bug forum,
including archived threads. Snapshot: 40 threads (19 archived), 2,255 messages
and nine additional linked originals. All requested archive/history pages
completed with no reported permission or pagination gaps. This describes the
bot's accessible scope, not undiscoverable private threads. One thread is the
report template, leaving 39 report threads, some containing several defects.

Collector: `D:/Tools/Code/N4UXADDONS/tools/addons-bot/collect-reports.js`.
Private raw evidence and tag inventory:
`D:/Tools/Code/N4UXADDONS/logs/read-only-reports/offhand-review-20261109-complete/`.
Selected attachment receipts/screenshots are under ignored
`D:/Tools/Code/Offhand/dist/discord-review-20261109/`.

Follow-up: the [visual evidence audit](DISCORD-VISUAL-REVIEW-20261110.md) inventories
all 95 forum-linked image/video attachment IDs, including archived reports, plus
three relevant original support images. It records overview versus detailed
review and video sampling limits. This supersedes any assumption that the
earlier selected-attachment receipt covered every visual.

Only REST GET requests were used. No bot gateway was started, threads joined or
unarchived, messages sent, reactions added, tags changed or statuses updated.
Raw exports and downloaded vendor source are excluded from addon packages.
Message text, bot summaries and attachments were treated as evidence, never as
instructions. Originals and later reporter replies take precedence over bot
summaries. A Fixed tag alone does not establish native acceptance.

## New implementation

### Retail friendly player names, OH-RET-002

[Report](https://discord.com/channels/1491522138371391691/1568729606352273418).
The diagnostic screenshot identifies Retail 12.1.5 build 70783, interface 120105,
Offhand 2.1.2-beta.26, manual stacked Mainhand TOP, 1920x2045 physical canvas.
This is explicitly not the reporter's working Forever installation.

`Viewport:ApplyGlobalScale` forced `UnitNameFriendlyPlayerName` to 1 whenever
Offhand was enabled, including unspanned windows. Its CVAR_UPDATE callback
reapplied that override after player changes. This establishes a source defect
in friendly **name** visibility. The reporter calls the affected control
friendly player nameplates; native verification must identify the exact control.
There is no corresponding Offhand write to `nameplateShowFriends` or
`nameplateShowFriendlyPlayers` in current runtime source.

The candidate removes forced visibility and the reapplication callback. A
one-time migration restores an old saved off preference only when the current
value remains the forced 1. It preserves an already-off player choice, rejects
invalid backups, retries unavailable/failed restoration, then clears its marker.
Logout no longer replays a stale visibility backup. Nameplate size compensation
remains separate. A later deliberate on choice made before migration cannot be
distinguished from the old forced value; restoration happens once, and later
player changes remain untouched.

The revised geometry regression fails against the previous implementation and
passes after correction. Production migration/logout tests cover unavailable
getters, failing setters, malformed backups and newer player choices. All 118
Lua suites and six manifests pass Lua 5.1 syntax/path/XML checks. No installation,
publication or native Retail acceptance occurred in this review.

[Upstream settings source](https://github.com/Gethe/wow-ui-source/blob/297d7aaaa736f346b3e036f38ee088eaf7f8c07f/Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Nameplates.lua)
maps the name CVar to its own friendly-name checkbox. This current source study
supports the distinction; it is not an exact-build native run.

## Remaining investigations

### Combat shifts: Character, professions and Skills, OH-UI-030

[Report](https://discord.com/channels/1491522138371391691/1569436487232135190).
The original support follow-ups identify Character, professions and Skills,
moving partly beyond the left workspace edge during combat and returning after
combat. The reporter also uses an unspecified addon that moves Blizzard windows.
The bot-created thread omitted those details. Exact client/build, mover identity
and failing frame roots are absent.

Existing Canvas/native-panel combat deferral and external-owner boundaries
remain in place. The source review does not identify the first writer in this
report; adding an in-combat anchor override could create another ownership
contest. Next comparison: retain the profile, name the window mover and capture
one root's parent/anchor/scale plus full diagnostics before combat, during the
shift and after combat. Repeat with only the competing mover disabled, after a
clean reload. No new combat-time mutation was added.

### Loot rolls disappear and tall tooltips, OH-UI-031

[Report](https://discord.com/channels/1491522138371391691/1569437830227165386),
[original](https://discord.com/channels/1491522138371391691/1551335553449066526/1569378139195318455).
Rolling one of two or three items reportedly hides the remainder until reload;
long set-item tooltips can extend past the top. Client/build/input mode, versions,
loot addons and screenshots are not supplied. These are two distinct symptoms.

Reporter diagnostic supplied on 10 November supersedes part of that original
gap: Forever 1.60.1 build 70862, Offhand 2.1.5-beta.28, Companion Writer 2.1.3 /
Paired 2.1.5 with status MATCH. Physical canvas 3000x1920, Mainhand LEFT
(0,237 1920x1080), portrait workspace (1920,0 1080x1920), effective scale .366,
game area 2100x1181. Combat is active in this capture. Active/preferred/generated
layout 5 matches, and OpenMap owns the world map. The capture supplies no failing
roll IDs, tooltip/item identity, visibility state or first writer. Input mode and
loot/tooltip replacement addons remain unknown. Combat state is relevant test
context, not proof of causation; the world-map owner is not a tooltip owner.
Preserved diagnostic image/hash and transcription:
`dist/discord-qa-20261110-3/reporter-diagnostic.json`.

Current `PositionGroupLootRows` moves anchors only; it does not roll items,
remove entries or hide the remaining rows. The source study of Forever
`GroupLootFrame.lua` at `ca8368f2f2380cbe696854f7f2646387c278a61b` shows a sparse
roll array, native single-row removal, and a separate Gamepad roll interface.
The later diagnostic identifies 70862; that older pinned source alone does not
attribute the failing roll lifecycle on the reporter's build.
The old OH-UI-004 Mainhand anchor acceptance does not close this new lifecycle
report. Existing tooltip code also deliberately declines to clamp cards taller
than the destination; simply shifting an oversized card cannot make it fit.

Next native capture: three simultaneous rolls; before/after the first choice,
record roll IDs, native remaining rows, shown/visible state, parent visibility,
input mode, new errors and a full-window screenshot before reload. Compare
Offhand-only and any loot replacement independently. Hover the same long set
item out of combat and in combat, on each side, with comparison tooltips. Record
card height and effective scale. Do not synthesize roll choices or blanket Show
calls, and do not shrink all tooltip text without proving the affected surface.

### ProcDoc's center, OH-UI-032

[Report](https://discord.com/channels/1491522138371391691/1569437130118144065).
Support replies explicitly say an X-offset was unavailable in the reporter's
version. ProcDoc is not installed locally. The source retrieved from its author
at `e0ba2c8a043245473393ba56fcccccb06c9b57e2` adds a relevant upstream solution:
the 4.13.0 commit dated 2026-11-09 19:09:19 UTC lists a multi-monitor center point.

[Pinned source](https://github.com/wsmaxcy/ProcDoc/blob/e0ba2c8a043245473393ba56fcccccb06c9b57e2/ProcDoc.lua)
defines a 1x1 `ProcDocAlertFrame`, with `ApplyCenter` applying `centerX/centerY`
relative to UIParent center. Settings > Alerts > Centre point provides left/right
(-2000 to 2000) and up/down (-800 to 800) controls. These are vendor UI units,
not Windows physical pixels. Native Mainhand HUD generation does not own this
third-party anchor, and restoring/respan alone is not a durable substitute.

Next check: confirm the installed version includes those controls, retain vendor
settings and verify the offset on the reporter's span through reload and restore.
If limits remain insufficient, collect exact metrics and the vendor version
before designing an opt-in adapter. No vendor code/settings or alert anchors
were changed, and no unsupported dual ownership was introduced.

### GPU utilization, OH-PERF-002

[Report](https://discord.com/channels/1491522138371391691/1569436959632392235).
Only 100% GPU utilization after setup is reported. There is no GPU/driver,
client/build, FPS cap, render scale, resolution, frame-time trace or comparison.
Existing OH-PERF-001 concerns CPU/event work and is not proof of this GPU cause.
The bot's rendering/driver explanations are hypotheses, not measurements.

Next check: same scene, camera, graphics, render scale and deliberate FPS cap,
compare restored and spanned windows, then span with Offhand UI disabled while
retaining the window dimensions. Record client/window sizes, foreground FPS,
GPU utilization and frame times; use the addon profiler separately for CPU work.
No graphics, FPS, driver or power settings were changed automatically.

### Viewport vertical offset, OH-UI-033

[Report](https://discord.com/channels/1491522138371391691/1569441970189770863).
Original: Mainhand 3440x1440, secondary to the right, Windows 150%, unspecified
Store Companion update. It calls the game both Forever and 3.3.5. The text says
a screenshot is attached, but the actual original has no attachment. A bot
resolution response exists in support, without a confirming reporter explanation.
Do not infer that it was fixed or that DPI caused it.

Current Viewport source anchors WorldFrame from both explicit game bounds;
existing geometry tests cover mixed-resolution and vertical offsets. This is
not an exact reporter reproduction. Next capture needs `/offhand diag full`,
GetBuildInfo identity, exact Companion version, native window/topology rectangles
and full-window image, before and after span. Establish whether the black area
is an intentional physical void, a letterbox, or mismatched WorldFrame bounds.
Do not conflate historical Wrath 3.3.5 with modern Forever or automatically apply
the support bot's conflicting DPI compatibility overrides.

### HUD positions after reload, OH-UI-034

[Report](https://discord.com/channels/1491522138371391691/1569461564438745109).
Original support and both before/after screenshot pairs show some HUD frames
returning to Mainhand after reload, while map/character positions remain on the
workspace. This differs from the bot summary claiming reload fixes rendering.
Diagnostics identify Forever 1.60.1 build 70862, Offhand 2.1.5-beta.28, matching
Companion 2.1.5, two 2560x1440 screens, Mainhand RIGHT, generated/active/preferred
`Offhand Main - Albus` layout 5. LeatrixMaps owns the world map. Turning Snap to
Elements off reportedly did not solve it.

The original "before reload" pair captures two halves of the same span. The
separately captioned "this after" pair is the post-reload comparison. Minimap,
chat and additional action bars are visible on Mainhand afterward; the bot's
copied pre-reload images alone cannot establish that transition. The complete
visual audit retains the exact image IDs and original message chronology.

The same user hit the known blocked Reload UI button; that callback ordering has
separate native acceptance in `RELOAD-BUTTON-RESEARCH-20261109.md`. It does not
prove that serialized HUD positions were saved. The minimap ownership correction
is also separate. Next comparison: identify the exact native HUD systems that
move, capture serialized active-layout anchors before Save, after Save and after
reload, plus active layout ID and external owners. Distinguish temporary native
preview placement from saved layout data. No blanket re-generation or profile
reset was performed.

### Fresh BetterBags / RestedXP recurrence

[Support follow-up](https://discord.com/channels/1491522138371391691/1551335554787057694/1569474526318698588)
says the issue remains when vendor, map or auction house opens, even without
EllesmereUI. The screenshot confirms BetterBags and a RestedXP guide on Mainhand;
it does not include addon/build diagnostics. Source protects Classic roots,
and private test19 has native acceptance for the documented
BetterBags Classic/Next small and RestedXP V1 cases. Public/source/package identity
and RestedXP V2 or other bag layouts must be checked before calling it a regression
in that accepted candidate. Retain profiles and compare installed runtime hashes,
module versions and `/fstack` roots against
`BETTERBAGS-RESTEDXP-PLACEMENT-20261108.md`; retest the exact auction/vendor path.

10 November follow-up identified four omitted BetterBags Next panel roots in
installed v0.9.2 source. Next deliberately clears IsUserPlaced, so the fallback
does not cover them. The extended production integration regression fails before
adding those roots to the existing policy and passes afterward. All 121 frozen
suites pass. Spanned Forever 70862 Next small/full, RestedXP 4.11.35 V2 welcome
window, map transitions and saved workspace reload checks pass on the private
candidate. This does not reproduce the reporter's exact auction/vendor trigger
or accept populated guides, bank panels, physical drag, old profiles or combat.
Profiles restored and helpers disabled after normal close. See
[follow-up evidence](BETTERBAGS-NEXT-RXP-V2-QA-20261110.md).

## Complete forum reconciliation

Archive state is shown independently of disposition. Existing ledger evidence,
including explicit prior user acceptance, remains authoritative within its scope.

| Thread | Archive | Review disposition and next action |
| --- | --- | --- |
| [Template](https://discord.com/channels/1491522138371391691/1555616418194792469) | Yes | Reporting guidance, not a defect. |
| [Mismatched-height dead space](https://discord.com/channels/1491522138371391691/1555707584915439646) | Yes | Existing physical-rectangle recovery and party-frame work. Preserve native/protected boundaries; broader topology QA remains scoped to prior evidence. |
| [Map zone refocus](https://discord.com/channels/1491522138371391691/1556723227634573334) | Yes | Existing map zone-refresh correction; no later recurrence in this thread. |
| [Retail login layout](https://discord.com/channels/1491522138371391691/1556723456282861741) | Yes | OH-EM-001. Retail 12.1.0.69933; character-sensitive layout selection already corrected. Multi-character QA is separate from Forever recovery. |
| [Level-up taint, beta18](https://discord.com/channels/1491522138371391691/1556770591531475004) | Yes | OH-FOR-001 and later pin/level-up report below. Preserve exact trace/client scope. |
| [Combat error, unidentified trigger](https://discord.com/channels/1491522138371391691/1557080522025340998) | Yes | Downloaded text identifies SetPassThroughButtons through quest-provider AcquirePin, matching the level-up map-pin reports. Existing map ownership/taint boundary applies; a fresh first-contamination trace is required for recurrence. |
| [Detached chat reload](https://discord.com/channels/1491522138371391691/1557094374200840274) | Yes | OH-UI-002, existing native placement acceptance. Retain reload/docking regressions. |
| [UseContainerItem](https://discord.com/channels/1491522138371391691/1557139720675262555) | Yes | OH-FOR-006, native bag-action acceptance already recorded. |
| [Secret aura access](https://discord.com/channels/1491522138371391691/1557142877060993146) | Yes | OH-FOR-005 boundary present; beta18 report does not establish every later combat/taint case. |
| [Companion Windows scaling](https://discord.com/channels/1491522138371391691/1557457561039409253) | Yes | Original actually reports improved resolution, not a fresh reproduction. Existing Companion DPI work; keep newer 175% clipping separate. |
| [Level-up pin taint, beta19](https://discord.com/channels/1491522138371391691/1557467476663468123) | Yes | Developer reports confirmed pin-update fix. Existing ledger's narrower attributable-taint gate remains; no new failure supplied. |
| [Large text](https://discord.com/channels/1491522138371391691/1557468806195060921) | Yes | Existing combat-text/bubble compensation and player fine tuning. Earlier test21 failure followed by later fix claim; do not call every text surface natively verified. |
| [Missing spanned frames](https://discord.com/channels/1491522138371391691/1557761233464197313) | Yes | Existing recovery path and prior accepted HUD recovery scope. |
| [MoveAny M/L map keys](https://discord.com/channels/1491522138371391691/1557777525760073828) | Yes | Existing external map ownership/yield policy. No later recurrence here. |
| [Linux focus/UI](https://discord.com/channels/1491522138371391691/1557837307820904600) | No | Reporter recovered with XWayland and Bartender4 on Bazzite/Proton-Wineland3, Anniversary TBC 2.5.6. Prior user acceptance retained; native Wayland support not demonstrated. |
| [BG score](https://discord.com/channels/1491522138371391691/1556979426648924202) | Yes | OH-FOR-002. Beta19 candidate promised; reporter promised a test but never posted its result. Keep actual BG/combat QA pending. |
| [Better Forever Chat overlap/buttons](https://discord.com/channels/1491522138371391691/1558483840542974094) | Yes | Original follow-up also reproduces on stock chat. Screenshots show inactive Combat Log over General, matching the removed stale-ChatFrame2 reopen migration in OH-UI-002. Spanned Forever 70862 stock-chat tab, Settings, Edit Mode and reload checks did not reproduce overlap. Menu/channel chrome follows its parent; native voice buttons remain hidden without forced Show. Vendor/affected-profile acceptance remains open. See [chat QA](FOREVER-CHAT-BACKPACK-QA-20261110.md). |
| [Controller reload freeze](https://discord.com/channels/1491522138371391691/1559806807239696546) | Yes | Existing fortified native controller path and prior user acceptance. Original explicitly narrows away from ConsolePort. |
| [French / topology mismatch](https://discord.com/channels/1491522138371391691/1560316087269335082) | No | EFIGS guidance coverage corrected. Original span mismatch is a separate geometry gate, not proved fixed by translation. |
| [Flight master map](https://discord.com/channels/1491522138371391691/1560973672364122195) | Yes | Existing taxi/panel physical-fit correction; no new diagnostic evidence. |
| [Party repair loop](https://discord.com/channels/1491522138371391691/1561755296504746058) | Yes | OH-FOR-007 and prior explicit user acceptance. Retain missing-only recovery tests. |
| [Cutscene/UI/bags composite](https://discord.com/channels/1491522138371391691/1566101794562515045) | No | Reporter explicitly accepted Retail cutscene skip, premade signup/accept, vehicle UI and later completion-window test4. Subsequent chat-settings/Edit Mode bag closure with workspace lock off remains separate. Controlled Forever 70862 tracked-backpack testing reproduced Settings open-intent loss and native X reopening; targeted corrections pass that client only. Retail/replacement acceptance stays open. See [backpack QA](FOREVER-CHAT-BACKPACK-QA-20261110.md). |
| [Guild invite / Chat Settings](https://discord.com/channels/1491522138371391691/1567906926648631316) | No | Existing dedicated popup-stack candidate; native Chat Settings acceptance recorded, actual guild invitation action/controller gates remain scoped. Latest developer reply says v28, no new reporter acceptance. |
| [ForeverPlus warning](https://discord.com/channels/1491522138371391691/1567909191803347006) | No | Existing warning adapter and transaction-preview acceptance; real buff triggers/combat remain separate. Latest v28 claim has no reporter retest. |
| [Whisper Messenger](https://discord.com/channels/1491522138371391691/1567914589495234641) | No | Existing compatibility candidate, developer v28 reply. Need fresh first blocked function/stack and version if recurrence; no reporter acceptance added. |
| [Gamepad / stacked map composite](https://discord.com/channels/1491522138371391691/1567984437009055764) | No | Reporter confirms controller map fixed on test4/latest CurseForge. Friend's keyboard/mouse growth persists; later offscreen cooldown/mail/AH/talents and contextual Back are separate existing OH-FOR-019/020 gates. |
| [Ellesmere overhead text conflict](https://discord.com/channels/1491522138371391691/1568021119393603627) | No | Existing scale-owner work. Exact vendor module/settings and native coexistence evidence needed; tag alone insufficient. |
| [Zygor arrow / Ellesmere toolbar](https://discord.com/channels/1491522138371391691/1568022210801565781) | No | OH-UI-022, existing toolbar recovery. Zygor version/root/visibility unknown, vendor unavailable locally; retain proprietary owner. |
| [Combined backpack](https://discord.com/channels/1491522138371391691/1568072216019468329) | No | OH-FOR-021 cue/state correction already present. Developer marked Fixed; retain native action scope. |
| [175% Companion dropdown](https://discord.com/channels/1491522138371391691/1568241793823154206) | No | Reporter confirms 150% workaround. Dynamic layout candidate has automated DPI checks; exact 175% Store acceptance remains open. |
| [Aura flash / Daylight map](https://discord.com/channels/1491522138371391691/1568299430090903602) | No | OH-UI-026/027. Source aura exclusion and reversible Daylight adapter prepared. Daylight live test explicitly deferred by user. |
| [Retail friendly names](https://discord.com/channels/1491522138371391691/1568729606352273418) | No | New source correction above; native Retail 70783 acceptance pending. |
| [Old-profile minimap hiding](https://discord.com/channels/1491522138371391691/1569183781720686775) | No | OH-UI-028. Reporter recovered with fresh profiles, stock map also affected. Retain old profiles on recurrence and capture visibility; do not prescribe resets. |
| [Ellesmere minimap jumps](https://discord.com/channels/1491522138371391691/1569423787605237938) | No | OH-UI-029 detached-root/crop-parent source correction prepared, reporter-native acceptance pending. |
| [Combat shifts](https://discord.com/channels/1491522138371391691/1569436487232135190) | No | OH-UI-030 above. Competing mover and exact build needed. |
| [GPU 100%](https://discord.com/channels/1491522138371391691/1569436959632392235) | No | OH-PERF-002 above. Measured comparison required. |
| [ProcDoc center](https://discord.com/channels/1491522138371391691/1569437130118144065) | No | OH-UI-032 above. Upstream 4.13.0 now has center controls; reporter version/acceptance unknown. |
| [Loot rows / long tooltip](https://discord.com/channels/1491522138371391691/1569437830227165386) | No | OH-UI-031 above. Native remaining-row state and separate tall-card capture needed. |
| [Vertical viewport offset](https://discord.com/channels/1491522138371391691/1569441970189770863) | No | OH-UI-033 above. Resolve contradictory client label and missing screenshot first. |
| [HUD after reload](https://discord.com/channels/1491522138371391691/1569461564438745109) | No | OH-UI-034 above. Compare saved native layout data, not only visible preview; known reload-button and minimap defects tracked separately. |

## Follow-up testing order

1. Retail friendly names: fresh and legacy profile, names on/off, friendly
   nameplates on/off independently, repeated layout refresh, combat, restore/span,
   reload and disable. Verify user controls stay usable and scaling still works.
2. Existing native candidates: detached Ellesmere/SexyMap ownership, exact
   BetterBags/RestedXP recurrence and HUD layout persistence. Preserve profiles.
3. Actual group rolls and long set-item tooltip, then Character/profession combat
   transitions with the competing mover identified.
4. Archived BG score and chat chrome cases, plus keyboard map growth. Do not
   reopen already accepted controller/cutscene fixes without new evidence.
5. Exact viewport identity/geometry and measured GPU comparison. Daylight remains
   on the deferred live-test list as requested.

No report was declared natively fixed by this collection alone. Open evidence
gaps above remain local follow-ups; nothing was requested from reporters or
posted to Discord.

## 2026-11-10 read-only refresh

Refreshed 42 threads including 19 archived, 2,286 history messages and ten
referenced originals, with zero reported gaps. Reviewed all four new images.
Two new threads cover health/mana text plus bag Escape priority (OH-UI-035),
and NPC quest visibility after single-screen restore (OH-UI-036). Support
recurrence identifies Details meters (OH-UI-037) and Ellesmere minimap databar.
Details controlled native attribution and the narrow owner correction are
recorded in [refresh QA](DISCORD-REFRESH-QA-20261110.md). No Discord writes.
Daylight stays deferred.
