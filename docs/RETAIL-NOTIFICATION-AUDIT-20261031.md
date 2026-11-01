# Retail contextual notification audit, 31 October 2026

## Result and scope

The reporter confirms Premade Groups now works. The exact package/build used for
that confirmation was not supplied. Together with the developer's cinematic and
vehicle retests, the three named original problems have positive confirmation.
No additional notification has been reported by name, so the findings below are
proactive coverage/timing candidates, not newly reproduced live defects.

Target context: reporter Retail 12.1.5.70688, two equal 1920x1080 displays with
gameplay on the right; local QA also includes a 4000x2560 mixed-height span.
Offhand source at HEAD 2e5c008 plus current uncommitted candidates was inspected.
No runtime code, installed addon, settings, test ZIP or client state was changed
for this audit.

Shared knowledge status was consulted. The search index remains stale, so source
inspection was used rather than drawing conclusions from retrieval absence.
39 pinned source files were retrieved and selected root declarations, anchors,
owners and lifecycle contexts examined. Snapshot revision
15881d522c44cd106d3d8660106ec9f9d2f44167 identifies Retail 12.1.5.70575, not the
reporter's 70688 build. Exact target-client checks are still needed.

Provenance and SHA256 inventory:
`D:/Tools/Code/N4UXADDONS/wow-addon-knowledge/.cache/manual-audits/retail-notifications-15881d522c44/manifest.json`.
Sources were read as text, not executed or copied into addon packages.
Immutable upstream root:
<https://github.com/Gethe/wow-ui-source/tree/15881d522c44cd106d3d8660106ec9f9d2f44167/Interface/AddOns>.

## Priority candidates

| Priority | Player-visible UI and native root | Source evidence | Current coverage and next test |
| --- | --- | --- | --- |
| 1 | Mythic+ keystone insertion/start: ChallengesKeystoneFrame | Blizzard_ChallengesUI/Mainline/Blizzard_ChallengesUI.xml declares UIParent CENTER, y=40. | No explicit Mainhand rule or named contextual exclusion. Generic panel behavior may apply, so absence of a rule alone does not prove it is stranded. Open a dungeon's keystone font without starting a timed run; inspect location, insert/cancel behavior and native ownership. Do not start a key merely to preview this window. |
| 1 | Mythic+ completion banner: ChallengeModeCompleteBanner | Same XML declares UIParent TOP, y=-120. | Separate root from BossBanner and EventToastManagerFrame, neither of which establishes coverage for it. Capture a naturally completed run; an addon-owned simulation can check geometry but cannot verify native lifecycle. |
| 1 | Queued group role selection: LFDRoleCheckPopup | Blizzard_GroupFinder/Mainline/LFDFrame.xml defines a separate UIParent root. LFDFrame.lua calls StaticPopupSpecial_Show on LFG_ROLE_CHECK_SHOW. | Not included in the native-stack adapter, which currently names only the two Premade Groups roots. Test a real group role check and concurrent confirmations. A reporter pass for ordinary dungeon ready UI does not cover every role-check variant. |
| 1 | Additional LFG ready check: LFGReadyCheckPopup | Blizzard_GroupFinder/Shared/LFGReadyCheck.xml and .lua define LFG_READY_CHECK_SHOW/HIDE and StaticPopupSpecial_Show. | Distinct from ReadyCheckFrame and LFGDungeonReadyPopup. No named handling. Reproduce the native ready-check flow and inspect its first/root and linked-stack positions. |
| 2 | PvP ready confirmation: PVPReadyPopup | Blizzard_GroupFinder/Mainline/PvpPopup.xml declares UIParent CENTER, y=150; .lua opens it through StaticPopupSpecial_Show. | Not in the two-root adapter. Queue/confirm manually in an agreed test; no automated queueing or acceptance. Check timeout, cancel and mixed popup order. |
| 2 | Pet-battle queue confirmation: PetBattleQueueReadyFrame | Blizzard_StaticPopup_Game/Mainline/StaticPopupSpecial.xml defines the standalone confirmation root. | PetBattleFrame confinement covers the battle UI, not necessarily this separate pre-battle dialog. Identify its current ready transaction and inspect a real queue prompt before adopting the root. Its activation callsite was not traced in this pass. |
| 2 | Level-up history/side display: EventToastManagerSideDisplay | Blizzard_FrameXML/EventToastManager.xml declares an independent UIParent root at TOPRIGHT relative to TOP, x=-189,y=-170. EventToastManager.lua DisplayToastsByLevel uses GetLevelUpDisplayToastsFromLevel. | Only EventToastManagerFrame is registered. SideDisplay is a sibling, so parent confinement does not carry across. Open the level-up details/history display in a suitable native context and inspect position. |
| 2 | Event toast reanchoring during display: EventToastManagerFrame | EventToastManager.lua DisplayNextToast calls UpdateAnchor; toast setup may call the parent's UpdateAnchor with texture-kit offsets. UpdateAnchor anchors against UIParent. | Existing TOP handling, OnShow retries and periodic recovery provide coverage, but do not observe the final UpdateAnchor transaction. Test toast refresh while manager remains shown, including custom offsets and several toast types. This is a source-supported ordering risk, not a proven visible flash. |
| 3 | Older LFD/LFR invitation: LFGInvitePopup | Blizzard_GroupFinder/Mainline/LFGFrame.xml declares UIParent root; Shared/LFGFrame.lua defines role, accept and decline logic. | Separate from LFGListInviteDialog. Active show callsite and current 70688 usage remain unresolved; do not expand production handling solely because a legacy declaration exists. |
| 3 | Death recap: DeathRecapFrame | Blizzard_DeathRecap/Blizzard_DeathRecap.xml declares UIParent CENTER. .lua uses ShowUIPanel and native dragging. | No dedicated Mainhand rule, but UIPanel/generic panel handling may already cover it. Inspect ordinary death-recap opening in a safe test, retaining native close/drag behavior. Avoid forcing player death just to test geometry. |

## Covered, inherited or ownership-sensitive families

| Family | Why it is not an automatic new gap | Verification still useful |
| --- | --- | --- |
| Premade Groups application and invitation | Explicit native-stack adapter; reporter now confirms working. | Keep simultaneous dialogs, note entry and future native layout changes in regression coverage. |
| Cinematic, movie, subtitles, skip confirmation | Dedicated Retail presentation and skip-dialog recovery; local cinematic visual pass. | Standalone movie, exit/lifecycle and taint coverage remain distinct from the intro pass. |
| Skinned vehicle override bar | Dedicated stock-root secure anchor preparation; local user confirms correction. | Other vehicle skins, actual actions and combat transitions. |
| Dungeon ready, ordinary ready check, role poll | LFGDungeonReadyPopup, ReadyCheckFrame and RolePollPopup have explicit transient policy. | Native shared-stack reanchoring and mixed confirmations. Role poll's native show also uses StaticPopupSpecial_Show; the existing individual anchor writer may interact with shared stacking. |
| Ordinary confirmations: resurrection, summon, group invites, quest share and similar messages | StaticPopup1..4 exist in the pinned GameDialog.xml and Offhand repositions those four roots. They are not absent merely because each message lacks its own named handler. | Confirm each current message maps to that pool. Test several simultaneous ordinary/special dialogs: Offhand currently anchors ordinary roots individually, while Blizzard manages a linked stack. Do not assume mixed-stack behavior from a single-dialog pass. |
| Achievement, loot, world-quest, dungeon/scenario completion reward alerts | Mainline/AlertFrameSystems.lua registers many sub-systems beneath the handled AlertFrame. Each toast name does not need an independent movement rule. | Verify final alert-stack placement, unusually large rewards and native anchoring changes. Do not conflate DungeonCompletionAlertSystem with the separate Mythic+ completion banner. |
| Zone/subzone text | Explicit ZoneTextFrame/SubZoneTextFrame handling. UIWidgetSubZoneTextContainerFrame anchors to SubZoneTextFrame. | Widget text width and native parent/anchor changes. |
| Ghost return-to-graveyard button | GhostFrame.lua attaches it TOP-to-UIWidgetTopCenterContainerFrame-BOTTOM after the widget module loads; the top-center widget root is explicitly handled. GhostFrame uses a secure mixin. | Confirm real ghost-state behavior and module load order; do not add ordinary drag/scripts to this secure button just because its name is absent from Offhand. |
| Raid warnings, boss messages and UI errors | UIErrorsFrame/RaidWarningFrame are positioned by SeamRedirect. PrivateRaidBossEmoteFrameAnchor is linked to RaidWarningFrame in pinned RaidWarning.xml. | Retail now gives RaidWarningFrame native Edit Mode ownership. Check customized layouts, secret-sensitive boss-message descendants and current restrictions before adding hooks. |
| Talking Head narrative dialog | TalkingHeadFrame inherits EditModeTalkingHeadFrameSystemTemplate and BottomManagedFrameTemplate. Mainhand layout generation translates eligible UIParent anchors generically. Alert placement also has native ownership relationships. | Verify actual serialized system and custom/external ownership. Missing a dedicated named rule does not establish failure. |
| Breath/fatigue timer bars | MirrorTimerContainer inherits EditModeTimerBarsSystemTemplate. This is distinct from the already bounded TimerTracker countdown root. | Inspect native Edit Mode preview, then a normal timer encounter. Avoid treating TimerTracker as coverage for MirrorTimerContainer. |
| Vehicle-seat indicator | Native RightManagedFrameTemplate and EditModeVehicleSeatIndicatorSystemTemplate. | Actual vehicle preview/seat changes, native managed anchors and serialized layout. Do not attach generic workspace drag/persistence. |
| Queue status hover panel | QueueStatusFrame anchors to QueueStatusButton, which is parented to MicroMenuContainer; .lua repositions relative to the button. | Inspect where the micro menu/button actually lives and its overflow policy. Screen-edge overflow is different from an independent centered notification. |
| Quest session/sync dialogs | QuestSessionManager contains template-created dialogs, rather than one plainly anchored full-screen notification. | Trace actual allocation/anchor path before listing a new root or changing template children. Not fully traced in this pass. |

## Recommended implementation order

1. Reproduce and characterize the keystone start window and completion banner,
   plus the additional LFG role/ready roots. These are closest to the original
   dungeon/Mythic+ report. Include generic panel discovery and mixed-popup stacks.
2. Extend the existing native-stack adapter only for roots whose live/source
   ownership is reviewed. Preserve all native links, including hidden ancestors,
   visibility, buttons, focus/notes, timeouts and cancellation. Do not simply center
   each dialog independently or rewrite the shared native popup table.
3. Study native EventToastManager.UpdateAnchor as a completed transaction, retaining
   texture-kit offsets. Review the independent side display separately.
4. Run local QA before offering another reporter build. Keep the confirmed fixes
   stable; leave retail-test.2 immutable and give any expanded candidate a new label.

For each candidate use both reporter-like equal-height and local mixed-height
geometry; verify visible placement, native actions, combat deferral, reload,
disable/unspan restoration and fresh Lua/taint evidence. Use addon-owned overlays
for harmless layout previews where useful. Do not force-show protected native
trees or invoke queue acceptance, keystone activation, death or other gameplay
to fabricate a visual pass. No live tests or new placement fixes were performed
in this source audit.
