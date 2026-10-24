# Offhand Issue Ledger

Stable IDs for reports that require follow-up across test sessions.

## Current acceptance, 25 October 2026

The user explicitly accepts the following as fixed and resolved: addon structural
refactor and UI overhaul; first-time setup; HUD/window restore and menu placement;
Forever Gamepad; Bagnon compatibility; Party-frame recovery; Dialogue UI; pet
battles; and the recorded source defect. This resolution supersedes historical
pending labels for that scope. It is user acceptance, not a claim that every old
QA checklist was performed or that every possible client/topology is verified.

The legacy CloseAllWindows bag-provider scope defect was still present during
source review. It is now corrected with one local decision covering the complete
transaction, plus a regression that failed before the correction and passes now.

Linux/Wine is assumed fixed per user direction, with direct Linux-user
verification still outstanding. Performance is the active investigation. The
original hang/error/chat report and battleground-specific checks are not closed
by this acceptance. Experimental Companion integration and Forever testing remain
under COMPANION-ONGOING-BUILD.md and deferred as instructed.

## Validation summary

This table answers three separate questions: whether source contains a change,
whether the target client has verified it, and whether another gate remains.
The detailed issue section below remains authoritative.

| Work item | Client scope | Source state | Automated or static evidence | Live evidence | Next gate |
| --- | --- | --- | --- | --- | --- |
| [PR #18](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/18) | Forever Gamepad UI | Conflicting draft against `addon/develop` | Contributor tests reported | Contributor live report requires local reconciliation | Compare safe panel handling with PR #21 |
| [PR #21](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/21) | Shared, Retail, Forever, and legacy manifests | Draft checkpoint against `addon/develop` | 31 suites and manifest validation passed | Pending | Review, split if useful, and complete live QA |
| OH-PERF-001 | Forever with bag addons | Implemented on `main` | Automated passed | Pending | Live profiler comparison |
| OH-FOR-001 | Forever | Investigation on `main` | No attributable stack | Inconclusive | Reproducible Offhand taint trace |
| OH-FOR-002 | Forever and modern Retail | Implemented on `main` | Static passed | Pending | Battleground and combat QA |
| OH-EM-001 | Retail | Implemented on `main` | Static passed | Pending | Multi-character Edit Mode QA |
| OH-FOR-003 | Forever | Implemented on `main` | Automated passed | Pending | Layout recovery QA |
| OH-FOR-004 | Forever and Companion | Implemented on `main` | Automated passed | Companion repair passed | In-game reload confirmation |
| OH-FOR-005 | Forever | Boundary implemented on `main` | Automated boundary passed | Pending | Combat and taint-log QA |
| OH-FOR-006 | Forever | Resolved on `main` | Automated passed | Passed | Retain regression coverage |
| OH-FOR-009 | Forever Gamepad UI | Investigation on `addon/develop` working candidate | Existing automated checks pass; no reproduction yet | One reported protected-call block during layout configuration | Fresh taint trace identifying the first Offhand contamination |
| OH-FOR-010 | Forever Gamepad UI | Contextual B retained; Escape/menu adapter withdrawn after OH-FOR-012 | B and dispatcher-isolation regressions passed | Initial reporter acceptance followed by protected Game Menu regression | Verify clean reload; safe Escape-retention replacement pending |
| OH-FOR-011 | Forever Gamepad Edit Mode | Investigation; native Loot preview focus mismatch identified | Source matches supplied line and locals; LootFrame excluded from destination adapter | Moving Loot preview triggers missing `GetSlotIndex` call | Repeat the same Edit Mode move with Offhand disabled after reload |
| OH-FOR-012 | Forever, Gamepad and keyboard UI | Unsafe Escape registration removed in working candidate | Shared-dispatcher mutation rejected by regression | SpellStopCasting forbidden on Game Menu entry in both modes | Reload deployed candidate; verify radial menu and keyboard Escape |
| OH-FOR-014 | Forever 1.60.1 build 70450; shared topology guards | Implemented on `addon/forever/topology-canvas-match`; Discord topology-test1 packaged | 38 Lua suites, six manifest validations, Companion checks and 48-file package verification passed | Reporter confirms candidate resolves span block | Restore/cold-launch checks pending; separate image-quality report under investigation |
| OH-UI-004 | Forever | Base fix on `main` | Automated passed | Base fix passed | Optional movement QA |
| OH-COMP-001 | Shared Companion contract | Implemented on `main` | Automated passed | Pending | Newer Companion pairing QA |
| OH-UI-001 | Forever | Resolved on `main` | Automated passed | Passed | Retain regression coverage |
| OH-UI-002 | Forever | Resolved on `main` | Automated passed | Passed | Retain regression coverage |
| OH-UI-003 | Forever with Chattynator | Compatibility boundary on `main` | Automated passed | Smoke test passed | Full scrolling regression QA |
| OH-UI-007 | Forever with Dialogue UI | Implemented in working source | Automated passed | Pending | Live dialogue, book, and settings QA |

Use the evidence vocabulary and branch policy in
[`ADDON-DEVELOPMENT.md`](ADDON-DEVELOPMENT.md). Update this summary whenever an
issue changes branch, evidence level, candidate, or released version.

## OH-FOR-014: Beta 21 rejects a matching Forever span

- Scope: reported on Forever 1.60.1 build 70450, Interface 16001, addon Beta 21 and Windows Store Companion. The later Companion screenshot identifies Beta 20. The surrounding acceptance and wizard logic is shared by supported clients.
- Source: `addon/forever/topology-canvas-match`; intended release is the next addon beta after Beta 21. Discord candidate `Offhand-v2.1.2-beta.21-discord.topology-test1.zip` built on 2026-10-22 from base `54694e1` plus working changes; no public publication. SHA-256: `D5B62B0F00B917E7474903ED6566F0200421641F11D36F86C6ABA0946D3878B1`. All 48 packaged files matched staging, runtime assets matched source, and all six extracted manifests passed validation. Distinct test metadata is stamped only in staging. The addon-only archive includes test instructions and inert bridge placeholders; it contains no Companion binary or personal state.
- Evidence: expected span `3640x1816`, physical API `2560x1440`, UI canvas `2287x1141`. The UI aspect agrees with the span. Later screenshots show portrait Display 2 (`1080x1816`, left) selected as Mainhand and landscape primary Display 1 (`2560x1440`, right) as workspace; the physical report therefore matches workspace, correcting the initial Mainhand assumption. The Windows alignment has a vertical offset, whose exact pixel value is not established by the image. Forever was explicitly excluded from the existing stale-physical-report fallback.
- Implemented: allow Forever through the same two-signal fallback. Require UI aspect agreement even when physical bounds match exactly. When a selected display and the complete span have indistinguishable aspects, require exact physical bounds rather than treating a possibly restored window as spanned.
- Related defect: wizard detection used raw single-monitor dimensions even after Companion acceptance, producing an incorrect workspace percentage. It now uses the accepted full bounds for both side-by-side and stacked arrangements.
- Automated validated: 38 Lua suites; all six manifest/path/XML/Lua 5.1 validations; Companion preference, topology bridge, restore and scaled-layout checks. New coverage exercises stale reports from either display, restored canvases, exact physical reports with disagreeing canvases, pixel tolerance, offsets, stacked layouts, one-display splits, ambiguous aspects and malformed data.
- Live evidence, 2026-10-22: reporter confirms the Discord candidate resolves the span issue. This accepts the reported span block only; exact post-fix diagnostics, wizard percentages, restore, cold-launch and other-client coverage remain unconfirmed. A subsequent report describes pixelation on the main display and identifies ASUS GlideX as the tablet-display provider. The exact affected display, current Mainhand selection, render settings and baseline comparison are not yet supplied. Treat image quality as a separate investigation; neither the unusual resolution nor GlideX is an established cause. Existing spanned-render softness history is relevant but does not prove the same defect here.
- Follow-up evidence: tablet output is sharp; physical Mainhand UI and 3D world are pixelated only while spanned; Restore Window returns sharpness. Supplied default diagnostics identify topology-test1 and Companion writer Beta 20 with viewport PASS, Mainhand `(1080,0 2560x1440)`, workspace `(0,8 1080x1816)`, full bounds `3640x1824`, screen `2773x1389`, effective scale `0.553`, matching generated Edit Mode layout and current geometry. This supersedes the earlier Mainhand selection and unknown-display state. These logical geometry checks do not measure the actual swap-chain buffer or Windows composition scale. Windows scaling percentages and renderer data remain unknown. The approved Beta 20 Companion tag and executable lack the experimental render-resize handshake present in current source. That experiment is a test candidate, not a verified remedy; do not rebuild the frozen Companion on this addon branch. Distinguish mixed-DPI composition from stale render-surface sizing with controlled scaling and cold-launch comparisons before attributing cause.
- Live pending: span and reload on the reported pair, confirm `READY`, wizard sizes/percentages and correct visible Mainhand/workspace bounds. Restore and confirm recovery, then re-span, reload and cold launch. Repeat the shared resize/restore checks on Classic and Retail. Inspect the selected Edit Mode layout after recovery. If an ambiguous arrangement retains a stale physical API, this guard intentionally remains in recovery because the available signals cannot prove a span.

- Scaling evidence: subsequent Windows settings screenshots show both the tablet (`1080x1816`, portrait flipped) and physical monitor (`2560x1440`, landscape) at 100% scale and their recommended resolutions. Different per-display Windows scale percentages are therefore not supported as the explanation. This does not measure WoW's backbuffer or rule out application/driver scaling. Next comparison: cold-launch with GlideX connected, span at login/character selection before entering the world, then compare with spanning after UI initialization. Record UI and world sharpness separately; no renderer-resize remedy is yet live verified.
- Pre-login span result: reporter says login remains sharp but the physical Mainhand becomes grainy on entering the world. GlideX uses Wi-Fi. A gameplay screenshot accompanies the report; the conversation display resizes it, so do not infer native buffer dimensions or quantify pixelation from the rendered attachment. Spanning before login is not an accepted workaround. This timing does not distinguish world-entry rendering initialization from Offhand's viewport/UI-scale application. Next isolation: retain the native span and GlideX connection, disable only Offhand through the addon list and reload, then compare UI/world sharpness in the same scene; re-enable and reload afterwards. The world filling both displays while Offhand is disabled is expected. If the defect persists, confirm with a cold launch while the addon remains disabled before attributing it to Companion or the client. No Companion handshake fix is established.

- Additional isolation results: reporter says USB and Wi-Fi produce the same graininess; disabling/re-enabling Offhand does not change it, and the requested full restart with Offhand disabled returns no change. This reproduces without active addon layout code and weakens a transport-mode cause; it does not establish that GlideX's display driver or Companion window management is uninvolved. Latest Companion screenshot confirms Beta 20, Mainhand Display 1 `2560x1440`, workspace Display 2 `1080x1816`, successful `3640x1824` spans, auto-span off and single-display split off. Display roles are now correct. Next isolation is an ordinary manually resized bordered WoW window across both displays with Companion exited and addon disabled, compared with Companion's borderless span. This separates a general cross-display/window-size failure from the Companion style/region/resize sequence. The resize handshake remains an unverified experiment.

- Latest reporter evidence: manually resizing the ordinary bordered WoW window across the displays did not appear grainy. This strengthens the association with Companion's span operation, without distinguishing border removal, clipping, resize timing or exact window dimensions. A changed Windows arrangement also produced a reported scrunched layout and persistent graininess, but no corresponding fresh diagnostics establish that arrangement's geometry. The FancyZones comparison was abandoned without a known configured layout or reliable sharpness result and is inconclusive. No further reporter evidence is available. Keep image quality open; do not claim FancyZones failed, a confirmed renderer root cause, or acceptance of the experimental resize handshake. Any future Companion candidate must use its own development/candidate lane and preserve the approved public binary.

- Targeted Companion candidate prepared on isolated `companion/graininess-test` from `companion/develop` `4ae9d386`, without rebuilding the frozen binary on this addon branch. `Offhand-Companion-v2.1.2-beta.20-graininess.test1.zip` offers baseline, extra resize, no clipping and keep-borders modes, all targeting the same measured client area. It logs outer/client bounds and DPI, isolates preferences and disables auto-span. Existing Companion checks, candidate synthetic hidden-window tests and eight-file archive hash verification passed. ZIP SHA-256 `A22FE893456B87BE362334E5F941CFA6D0637219DC5E863E1247A1AC493701A4`; EXE SHA-256 `C8A361E3F4FAA76492D61E7F91E211A10F7992CB65097F4D4BF2DFEE26843087`. Native WoW/GlideX tests remain pending. Border removal is a plausible presentation/client-size trigger, not an established root cause or inherent resolution reduction.

## OH-PERF-001 — Periodic global bag-frame discovery causes micro-stutter

- Status: Fix implemented and automated validation passed; live profiler QA pending.
- Client: Forever 1.60.1, reported with Offhand 2.1.2 Beta 18 and EllesmereUI.
- Symptom: A small frame-time spike occurs approximately once per second. WoW's
  addon profiler attributed 5,198 frames over 5 ms to Offhand in roughly 90
  minutes, while the next-highest addon recorded 253.
- Cause: `BagPersistence` scanned every key in `_G` once per second to find
  dynamically named Baganator roots, even when Baganator was absent. The
  optional workspace-chrome feature performed a similar scan every three seconds.
- Fix: Stable EllesmereUI and persisted root names are resolved directly.
  Baganator receives one lifecycle scan after initialization and reports later
  frame replacements through `BackpackFrameChanged`; workspace chrome consumes
  the resulting small registry. Both recurring `_G` scans have been removed.
- Live QA: Compare `C_AddOnProfiler.CountTimeOver5Ms` before/after during at
  least 15 minutes of idle and normal play, first without Baganator and then
  with it. Open, move, reload, change Baganator view/skin, and verify workspace
  persistence and close-button behavior remain intact.

## OH-FOR-001 — Level-up map-pin protected-action block

- Status: Confirmed once; latest level-up retest did not reproduce Offhand
  attribution, so a reproducible Offhand taint trace is still required.
- Client: Forever Beta, Offhand 2.1.2 Beta 18.
- Symptom: A level-up quest refresh reaches `Button:SetPassThroughButtons()` through
  `QuestDataProvider` and is blocked with Offhand named as the taint source.
- Evidence: The World Map was open and had not been dragged. A later reload did
  not reproduce the failure, and the available `taint.log` contains only
  unrelated slash-command import entries. The 2026-10-06 level-up retest log
  likewise contains no Offhand, MapCanvas, quest-provider, protected-action, or
  `SetPassThroughButtons` entry; it attributes its recorded UI panel taint to
  Chattynator and Baganator.

## OH-FOR-002 — Battleground UI centered on the monitor span

- Status: Fix implemented and static validation passed; live battleground QA pending.
- Client: Forever Beta; the affected Blizzard frames also exist on modern Retail.
- Symptom: The live battleground objective/score widget appears at the top-center
  of the complete span instead of Mainhand.
- Scope: `UIWidgetTopCenterContainerFrame`, `PVPMatchScoreboard`, and
  `PVPMatchResults`.
- Safety: Offhand adopts only Blizzard's stock full-span anchors and positions
  these secret-sensitive trees through a restricted secure handler. Existing
  user/addon placements are left untouched.
- Live QA: Verify objective widgets and scoreboard before/during combat, the
  post-match results screen, `/reload` inside a battleground, and `taintLog 2`.

## OH-EM-001 — Edit Mode layout overridden on login

- Status: Fix implemented and static validation passed; live Retail QA pending.
- Client: Retail 12.1.0.69933, Offhand 2.1.2 Beta 17, Companion 2.1.2 Beta 18.
- Symptom: A druid's selected `druid offhand` Blizzard Edit Mode layout is
  replaced by the account's layout named `Offhand` after each login.
- Cause: Standard-client startup hard-coded `Offhand` as the desired Blizzard
  layout and called `C_EditMode.SetActiveLayout` when another layout was active.
- Fix: Retail and Anniversary now adopt the character's current layout on
  upgrade, remember later explicit selections in `OffhandCharDB`, and restore
  that layout by name only when Blizzard returns a different selection.
- Forever boundary: Ordinary Forever login neither stores nor selects this
  character preference. Its separate layout API calls remain confined to the
  player-click missing-monitor recovery buttons.
- Live QA: Select different layouts on two Retail characters, relog and
  `/reload` each, then rename/delete a remembered layout and confirm the current
  Blizzard selection is adopted safely.

## OH-FOR-003 — Forever Edit Mode layout ownership and recovery

- Status: Fix implemented and automated validation passed; live Forever QA pending.
- Client: Forever Beta.
- Risk: Forever's missing-monitor recovery assumed a custom layout named
  `Offhand`, while its recovery transaction lived in an account-wide Offhand
  settings profile. Characters sharing that profile could therefore inherit a
  stale layout ID or be unable to designate an existing class-specific layout.
- Fix: Forever now remembers a designated custom Blizzard Edit Mode layout per
  character. A healthy exact-span upgrade safely adopts the currently active
  custom layout; otherwise the Recovery card offers **Use Current Edit Mode
  Layout**. Built-in Modern and Classic layouts are never adopted.
- Migration: Existing Blizzard layouts are not renamed, deleted, copied, or
  selected. Legacy profile recovery records are removed from every profile;
  only the current profile's record is staged on the character and retained
  after Blizzard's layout API confirms that its name/ID still matches the
  active recovery transaction. Invalid or stale records are discarded.
- Safety: Forever still makes no ordinary login-time layout selection. Protected
  layout changes remain confined to the existing player-click fallback and
  restoration prompts.
- Control recovery: The read-only off-screen detector now remains active during
  Companion's explicit single-screen `MISMATCH` recovery as well as an active
  mixed-height span. **Bring to Mainhand** centers only shown, unprotected Edit
  Mode control surfaces (including the separate settings dialog) after the
  player's click; it does not move protected HUD systems or alter panel metadata.
  The 2026-10-22 follow-up adds default automatic rescue of these same
  unprotected controls after the existing 0.15-second native-layout settlement.
  The Recovery & Preview preference can disable it and retain the manual
  Bring to Mainhand prompt. Reachable user placement is left intact. This
  automatic path is a new candidate awaiting live control/focus verification.
- Live QA: Upgrade while a class-specific custom layout is active on an exact
  span, verify the Recovery card designation, `/reload` and relog, then exercise
  display disconnect/reconnect and both player-click recovery prompts. Repeat on
  a second character sharing the same Offhand settings profile.

## OH-FOR-004 — Generated topology lost during addon update

- Status: Fix implemented; automated validation and live Companion repair passed.
  In-game `/reload` confirmation remains.
- Symptom: WoW remains physically spanned, but `/reload` reports that Offhand
  could not confirm the current display span.
- Cause: Addon installation replaces Companion's generated
  `Core/CompanionTopology.lua` with the packaged inert placeholder. The Companion
  previously recognized the already-spanned window without repairing that file.
- Fix: While the live window exactly matches the selected display plan, Companion
  now validates the generated topology every polling pass and atomically repairs
  a missing, placeholder, stale-version, or wrong-geometry snapshot. It does not
  move the window and asks for one `/reload` through the activity log.
- Live evidence: With Forever running in the accepted 4000x2560 span, replacing
  the bridge with the packaged placeholder was repaired by the rebuilt Beta 19
  Companion on its next polling pass without moving WoW.

## OH-FOR-005 — Secret aura access attributed to Offhand in combat

- Status: The relevant insecure widget hooks were already removed in current
  Beta 19 source; live combat and taint-log verification pending.
- Client: Forever Beta, Offhand 2.1.2 Beta 18.
- Symptom: `GetAuraDataByIndex()` is rejected as secret while
  `ScenarioObjectiveTracker` evaluates `ShouldShowMawBuffs`, with Offhand named
  as the taint source.
- Evidence boundary: The supplied stack contains no Offhand function and does
  not prove which earlier mutation introduced taint. Beta 18 did reposition
  transient Blizzard UI through ordinary frame writes and event hooks.
- Current boundary: Secret-sensitive battleground widget and score roots are
  adopted only through the restricted secure positioner, receive no Offhand
  `OnShow`/`OnEvent` scripts, and defer repair while combat is locked.
- Live QA: Enter combat in scenario/objective-tracker content with
  `/console taintLog 2`; trigger aura and objective updates, then inspect both
  BugGrabber and `Logs/taint.log` before attributing a recurrence.

## OH-FOR-006 — Native bag item use blocked by Offhand taint

- Status: Resolved and live-verified on Forever Beta.
- Client: Forever Beta, Offhand 2.1.2 Beta 18.
- Symptom: Right-clicking quest-combination items, recipes, and other usable
  native-bag items can block `UseContainerItem()`. `/use` and action-bar use
  still work because they bypass the tainted ContainerFrame click ancestry.
- Cause: Offhand attached persistence handlers to Blizzard bag title/close
  controls and repositioned native ContainerFrame roots. Forever treats that
  tree as an ancestor of protected item actions, so title-only hooks were not a
  sufficient isolation boundary.
- Fix: Forever native bags use a separate `UIParent`-owned title grip whose
  state, scripts and anchors never enter the `ContainerFrame` tree. Offhand no
  longer hooks native titles, close buttons, visibility, bag functions,
  `SetPoint`, or Blizzard's anchor manager. A hardware drag moves only the bag
  root, and an out-of-combat observer restores only that root anchor. Existing
  workspace snapshots and Blizzard-native reload opening are retained. A
  Mainhand drop retires both root-specific and mode-independent workspace state
  before saving its Mainhand position, preventing an immediate snapback.
- Escape and opening flash: Some Forever builds consume Escape by closing the
  bag without opening `GameMenuFrame`. Secure post-hooks therefore observe the
  global close/toggle transaction but perform no native action inside it.
  `ToggleAllBags`/`ToggleBag` and close-button mouse focus mark B/X as explicit;
  `ToggleGameMenu` marks Escape. On the following frame, Offhand applies the
  already-requested Game Menu visibility state directly while the bag is closed,
  then restores the bag through `OpenAllBags`. It must not call
  `ToggleGameMenu` from deferred addon code because Forever enters the protected
  `SpellStopCasting` path. This handles both opening and closing the Game Menu.
  Settings, AddOns and Edit Mode are handled by read-only visibility polling in
  the addon-owned controller because their cleanup can hide bags after the Game
  Menu transition has settled. No handler is attached to those panel trees, and
  B/X still close the bag explicitly while any of them is visible.
  Forever can leave the native bag logically open after hiding its root, causing
  `OpenAllBags` to do nothing. Recovery normalizes that stale logical state
  through Blizzard's toggle/open APIs and then restores the fully initialized
  root without directly showing a shell.
  If a visible modal system panel rejects all bag APIs, the final fallback may
  re-show only the same root already observed initialized and visible before
  that transition. It is unavailable during login/reload construction and does
  not attach a hook or field to the root. Right-click Hearthstone use was
  verified after every system-panel transition without taint.
  A three-second bounded transition window covers Options before its frame is
  discoverable and AddOn List cleanup after its frame becomes hidden. Secure
  post-hooks on Blizzard's Settings-opening APIs classify Options' native
  `ToggleAllBags` cleanup as a panel transition; the native
  `IsOptionFrameOpen()` predicate supplements read-only visibility afterward.
  Builds that bypass both are classified by the same-frame open-to-hidden Game
  Menu transition. An ordinary B/X close outside navigation cancels the window.
  The earlier Settings `OnShow` recovery no longer clears the tracked-open flag
  when the modal panel rejects Blizzard's opener; ownership passes to the
  isolated controller instead.
  No Blizzard function is replaced and no handler enters the bag tree.
  The observer also reanchors a newly opened root every rendered frame before
  Blizzard's default bottom-right position is painted.
- Evidence boundary: Small bag-mover addons demonstrate that the native roots
  can be moved, but their direct native-frame hooks do not prove protection
  from this Forever taint. Offhand therefore adopts the external-drag concept,
  not those native hook paths. Automated tests prove the adapter adds no native
  scripts, mouse registration, drag registration, fields, or global hooks;
  only live testing can validate Forever's runtime propagation rules. Live QA
  passed Escape, AddOn List, Edit Mode and Options entry/exit, Hearthstone use
  after each transition, and switching to Baganator and back to Blizzard bags.
- Live QA: With `/console taintLog 2`, test combined and individual default bag
  modes. Right-click the reported quest item, a recipe, a consumable, and an
  equippable item before and after dragging the bag, after `/reload`, and in
  combat. Confirm position/open restoration and inspect both BugGrabber and
  `Logs/taint.log`. Repeat once with a supported custom bag addon.

## OH-FOR-007: Repair HUD repeats without recovering Party Frames

- Status: Targeted fix implemented and simulated regression passed; exact
  Forever live retest pending.
- Reporter: WhoAmI.
- Client: Forever 1.60.1 build 70450 with Offhand 2.1.2 Beta 21.
- Symptom: The Party Frame remains invisible in Edit Mode after **Repair HUD**
  and `/reload`, then Offhand offers the same repair again when Edit Mode closes.
- Evidence: Diagnostics showed the generated `Offhand - Mainhand` layout was
  active, matched the current stacked topology and was considered current. The
  failure therefore occurred inside the generated payload rather than layout
  selection or topology recovery.
- Cause: The general translator moves only entries anchored directly to
  `UIParent`. Forever can serialize Party and Raid unit-frame entries relative
  to another Edit Mode system. Other entries still moved, so the transaction
  reported success even though the detected group entry was unchanged.
- Fix: The explicit recovery action now identifies the detected Party or Raid
  candidate and rebases its matching `UnitFrame` layout entry to a safe
  Mainhand-relative position. Default system-relative group entries receive the
  same treatment during generation. Customized entries remain unchanged unless
  the player invokes recovery. If no matching layout entry exists, repair stops
  with `repair-system` instead of requesting a misleading reload. Diagnostics
  now expose both group-frame bounds and protected-HUD candidate state.
- Live QA: On the reported 3440x1440 Mainhand below a centered 1920x1200
  workspace, open Edit Mode solo, invoke Repair HUD, `/reload`, and reopen Edit
  Mode. Confirm the Party preview is reachable and no second prompt appears.
  Join a party and raid, verify frames and protected clicks in and out of combat,
  then inspect current BugGrabber and `taintLog 2` evidence.

## OH-FOR-008: Bagnon Escape persistence and Gamepad focus taint

- Status: Revised candidate implemented and simulated regression passed; live
  Forever retest pending.
- Reporter: Kruse.
- Client: Forever with Bagnon 12.1.7 and Offhand 2.1.2 Beta 21 candidate.
- Symptoms: In keyboard and mouse mode, Escape still closes the saved workspace
  Bagnon inventory. In Gamepad mode, closing Blizzard Settings can produce an
  `ADDON_ACTION_FORBIDDEN` attributed to Bagnon when Blizzard calls
  `SetPreferredGamepadInteractTarget` from `FrameControlsManager`.
- Cause: Offhand registered `OnShow` and `OnHide` hooks on Bagnon's top-level
  `UISpecialFrames` root. That callback was also the only mechanism that paired
  a direct Escape hide with the later Game Menu toggle. The hook did not cover
  every live ordering and inserted Offhand code into a frame participating in
  Forever's protected Gamepad focus lifecycle.
- Fix: Bagnon's root is now discovered by a constant-time Offhand-owned observer
  without root scripts or manager callbacks. The secure global Game Menu
  post-transaction recognizes a saved Bagnon root that Escape has just hidden
  and restores it through Bagnon's public manager in keyboard and mouse mode.
  Gamepad mode retains the saved intent but performs no Bagnon inspection,
  visibility change, anchor restore or close-button update.
- Live QA: Start with fresh BugGrabber and `taintLog 2`. In keyboard and mouse
  mode, move the one-bag inventory to Offhand and confirm two Escape presses
  open and close the Game Menu without closing the bag. Confirm B and the close
  button still close it, and `/reload` restores an intentionally open bag. In
  Gamepad mode, open and close Settings and the Game Menu repeatedly, then use
  Bagnon's own controls. Confirm no protected-call attribution and no automatic
  bag reopen. If the error remains with this candidate, repeat once with Offhand
  disabled to distinguish a native Bagnon/Forever incompatibility.

## OH-FOR-009: Gamepad layout configuration blocks preferred interact target

- Status: Reported on 2026-10-22; unresolved, with no reliable reproduction.
- Client: Forever, native Gamepad UI, current Beta 21 working candidate on
  `addon/develop`. The exact client build was not included in this report.
- Symptom: While configuring the Gamepad layout, possibly in Edit Mode or
  while moving panels, BugGrabber recorded one `ADDON_ACTION_FORBIDDEN` naming
  Offhand and `SetPreferredGamepadInteractTarget()`.
- Supplied stack: Blizzard's `Blizzard_GamepadActionBars/MainActionBarFrame.lua`
  calls the protected function at line 325 from a function beginning at line
  307, followed by a tail call. No Offhand function appears in the supplied
  stack. Attribution confirms the block, but does not identify the earlier
  taint source or the exact triggering gesture.
- Source review: Offhand contains no direct call to the protected function.
  Earlier popup and bag focus violations reached the same protected API, so
  the function name alone does not establish recurrence of one of those paths.
  Native Gamepad panel positioning still writes allowlisted root anchors from
  the external adapter; that remains an unconfirmed candidate, not a proven
  cause. No speculative runtime change was made for this report.
- Evidence boundary: The 34 Lua suites and six-manifest validator passed during
  the preceding candidate review. Those checks do not establish live Gamepad
  taint safety and do not reproduce this report.
- Next evidence: Enable `/console taintLog 2`, then `/reload` before a short
  layout-configuration session. Record the exact last action if the block
  recurs, capture the complete error and `/offhand diag`, and retain the fresh
  `Logs/taint.log` for the first Offhand-attributed contamination. Turn logging
  off afterward with `/console taintLog 0`. If reproducible, compare the same
  action after a reload with Offhand disabled.
- Related observation: The reporter also saw intermittent World Map anchoring
  to other panels before a reload. It could no longer be reproduced afterward,
  and panel behavior was reported stable. This is current-session evidence,
  not a completed interaction-matrix pass or evidence that the taint is fixed.

## OH-FOR-010: Gamepad Back/Escape closes workspace panels

- Current scope after OH-FOR-012: Retain contextual B, but remove the Escape
  callback and independent-menu adapter described below. Escape again follows
  Blizzard's normal window-closing behavior. The earlier reporter acceptance
  does not establish safety of the withdrawn approach. A clean reload is
  required to clear the already-mutated native handler list.
- Status: Revised preservation candidate implemented on 2026-10-22; live
  reporter acceptance received later that day. The complete matrix and fresh
  protected-action/taint evidence have not been supplied.
- Client: Forever native Gamepad UI, Beta 21 working candidate.
- Symptom: B and Escape close the panels left open on Offhand when the player
  wants to return control to gameplay. The prior focus guidance directed the
  player to Controller Configuration, which was absent from the shown settings.
- Candidate: Offhand now reads Blizzard's native `TOGGLEUIFOCUS` binding in its
  own binding context and offers direct button assignment with conflict
  confirmation. It saves that native action instead of assigning the addon
  delegate. This corrects the inaccessible configuration workflow.
- Revised candidate: Outside combat, B is temporarily bound directly to
  Blizzard's `TOGGLEUIFOCUS` action only when an actual shown Offhand destination
  has focus. Gameplay B, Mainhand focus, temporary dismiss-on-unfocus frames,
  and Game Menu navigation retain their native bindings. The override belongs
  to an addon-owned secure controller and is cleared by its combat state driver.
- Escape requirement: The player explicitly requested Game Menu opening while
  keeping Offhand panels visible. A native addon-priority Escape handler runs
  after dialogs, menus, casting and Edit Mode but before global panel cleanup.
  It calls the native menu-show function. Because Game Menu's own center-slot
  transaction also closes panels and bags, a restricted handler temporarily
  detaches only its `UIPanelLayout-area` attribute while it is hidden. Native
  ShowUIPanel/focus registration is retained. The original slot is restored
  after the menu closes and ownership ends, unless another owner changed it.
- Boundaries: No native function, panel script, focus-manager field or global
  UIPanelWindows entry is replaced. No workspace frame is reopened. The policy
  follows actual visible placement, not stale open markers. It yields to combat,
  cinematics, ConsolePort, disabled persistence, and external menu ownership.
  In combat, Blizzard's native dismissal behavior applies. Mock success does
  not establish protected-action safety, including OH-FOR-009.
- Live QA: Use the displayed focus button with World Map, Character, Social,
  Communities and bags open on Offhand. Record retained/closed panels and fresh
  errors, verify B returns gameplay control, then verify Escape opens and closes
  Game Menu without hiding peers. Exercise menu navigation and refocus, explicit
  close buttons, Mainhand panel Back, gameplay B, and reload. Check fresh
  BugGrabber and taint evidence. See `tests/QA-notes.md` for the full boundary.

## OH-FOR-011: Loot Edit Mode selection is mistaken for a loot item

- Status: Fresh detailed report on 2026-10-22, matching earlier Loot focus
  reports. The failing native assumption is identified; Offhand involvement
  remains unisolated. No native focus workaround was installed.
- Client: Forever native Gamepad UI, during movement of the Loot Edit Mode
  preview. The supplied root has `isInEditMode=true`,
  `editModeManuallyShown=true`, and `isOpen=false`.
- Exact failure: `LootFrameMixin:FocusGamepad()` takes SmartNavigation's last
  selected button, gets its parent, and calls that parent's `GetSlotIndex()` at
  `Blizzard_UIPanels_Game/Mainline/LootFrame.lua:376`. The supplied last button
  is the Edit Mode `Selection` overlay. Its parent is `LootFrame`, not a loot
  row, so `GetSlotIndex` is nil. The stack and locals identify the mismatched
  object type without establishing who first put it in navigation history.
- Supporting source: The `forever` branch of
  <https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.lua#L364>
  matches this sequence and line number when inspected for this report.
- Offhand boundary: `LootFrame` remains outside the Gamepad destination list
  and position-only protected allowlist. Existing regression verifies that its
  native anchor is untouched by the destination adapter. This error is a nil
  method call, distinct from OH-FOR-009's forbidden protected action.
- Next live evidence: After a reload with Offhand disabled, enter native
  Gamepad Edit Mode and move the Loot Window preview in the same way. Record
  whether the same stack appears. Recurrence would show that Offhand is not
  required for this failure. A non-recurrence alone would not establish a cause.
  Compare with real loot outside Edit Mode separately when convenient.
- Avoid replacing `FocusGamepad`, adding `GetSlotIndex` to the root, or editing
  native SmartNavigation state merely to suppress the exception. Those changes
  would mask the wrong-object condition and enter the protected focus path.

## OH-FOR-012: Game Menu casting handler inherits Offhand taint

- Report: On 2026-10-22, opening Game Menu from the controller radial and in
  standard UI produced `ADDON_ACTION_FORBIDDEN` naming Offhand and
  `SpellStopCasting()`. Both stacks enter the native casting callback at
  `Blizzard_Game/Shared/Game.lua:7` through `Blizzard_GameMenuEsc` lines 101/110,
  before the addon-priority Escape callback would run.
- Attributable source hazard: Offhand registered its callback with
  `RegisterGameMenuEscHandler` on the background Gamepad observer, before
  checking whether Gamepad UI was active. The native function inserts into and
  sorts a private shared handler table. Running that mutation in addon context
  can contaminate dispatch of earlier native callbacks, matching the observed
  cross-mode failure. A fresh taint trace has not independently identified the
  first contaminated table cell.
- Correction candidate: Remove registration entirely, along with the now-unused
  Escape callback and temporary Game Menu panel-layout adapter. Keep contextual
  B routing, reticle centering and XP generation. No native dispatcher function,
  casting API, handler table or menu metadata is patched or bypassed.
- Regression: Background refresh in both Gamepad and keyboard modes must pass
  with registration, native menu invocation and menu-attribute writes set to
  throw. Contextual B, gameplay/Mainhand yielding and secure combat release
  remain covered. Mock success does not establish absence of all native taint.
- Live gate: Reload after installing this correction, then open/close Game Menu
  using the controller radial and keyboard Escape. Check newly timestamped
  BugGrabber entries. Old errors and the already-tainted pre-reload session do
  not validate the corrected candidate. Escape panel retention is intentionally
  unavailable until a safer replacement exists.

## OH-UI-004 — Group loot rolls centered on the monitor seam

- Status: Resolved in live Forever Beta QA. The row-level correction remains in
  position before, during and after combat. An optional position control is now
  implemented in current Beta 21 source; its movement workflow awaits live QA.
- Client: Forever Beta, reproduced with Offhand 2.1.2 Beta 21.
- Symptom: Blizzard's group-loot roll container appears at the full-span center
  or partly off-screen instead of inside Mainhand.
- Cause: `GroupLootContainer` is owned by Blizzard's alert-layout system. Its
  anchor can be recalculated at combat transitions and on later alert updates,
  so moving the container is not durable. The previous secure `OnShow` repair
  still left every roll row parented to that movable container. The similarly
  managed Tracked Buffs system is not the roll's anchor.
- Fix: Offhand retains the container anchor only as a harmless fallback. After
  Blizzard's native `GroupLootContainer_Update`, it now preserves native row
  order and spacing while anchoring each non-protected visible roll directly to
  Mainhand. Subsequent container movement therefore cannot drag rolls to the
  seam. A custom/protected row anchor is treated as another addon's ownership
  and disables Offhand's row mover instead of creating an anchor contest.
- Optional movement: Display settings can show an Offhand-owned drag preview
  outside combat. Its center is stored proportionally within Mainhand, while
  the actual Blizzard frames remain non-interactive and are positioned only by
  the established post-update hook. Reset restores the lower-center default.
  Post-Beta 21 source also lets users retain Blizzard's upward stack or grow
  subsequent rolls downward from the first-roll anchor.
- Live QA: Move the preview, trigger several simultaneous need/greed rolls,
  enter and leave combat, then `/reload` while grouped. Confirm the first roll
  returns to the saved position, later rolls stack upward, the preview hides in
  combat, and no protected-action or secret-value errors occur. Repeat with a
  custom loot-roll mover and confirm Offhand yields ownership.

## OH-UI-005: Pet battle panels split across the monitor seam

- Status: Fix implemented and automated validation passed; live QA pending.
- Client: Reported on a spanned installation; applicable to clients that expose
  Blizzard's load-on-demand `PetBattleFrame`.
- Symptom: The top opponent panel and bottom pet-action panel remain centered
  on the complete spanned canvas, leaving both split between Offhand and
  Mainhand with no obvious setting that moves them together.
- Cause: Blizzard builds the pet-battle interface beneath one full-screen root
  anchored to `UIParent`. Its internal top and bottom controls are correctly
  positioned relative to that root, but the root still covers both monitors.
- Fix: While out of combat, Offhand loads the native pet-battle UI and replaces
  only the pristine root's full-screen bounds with the Mainhand rectangle. All
  Blizzard children, interaction, visibility, and battle updates remain native.
  A user-placed or addon-owned root is treated as a compatibility conflict and
  remains untouched.
- Live QA: Start wild and trainer pet battles on each supported client. Confirm
  the complete top and bottom interface appears inside Mainhand before, during,
  and after combat; leaving battle restores normal UI without errors. Repeat
  with a UI mover that customizes `PetBattleFrame` and confirm Offhand yields.

## OH-UI-006: Retail character properties pane escapes after reload

- Status: Fix implemented and automated validation passed; live QA pending.
- Client: Retail.
- Symptom: If `CharacterFrame` was left open on the Offhand workspace, its
  properties/stat pane could appear outside the character window after login or
  `/reload`. Closing and reopening the window immediately repaired the layout.
- Cause: Reload persistence opened the native UIPanel and its `OnShow` restore
  synchronously evicted it from Blizzard's left-panel slot with a hide/show
  cycle. That re-entered PaperDoll's collapse/expand lifecycle while Blizzard
  was still laying out `CharacterFrameInsetRight`, which owns the stats pane.
- Fix: Retail now detaches the hidden character frame from the UIPanel slot
  before opening Blizzard's native PaperDoll view. After expansion settles,
  Offhand requests Blizzard's own display refresh and restores only the root
  frame's saved workspace anchor; no PaperDoll child anchors are modified.
- Live QA: Leave the Character panel open on the Offhand workspace and test a
  cold login and `/reload` at 75%, 100%, 125%, and 150% Character Window Scale.
  Confirm the stats pane remains inside the frame, then switch among Character,
  Reputation, and Currency and verify close/reopen and Escape persistence.

## OH-COMP-001 — Newer Companion reported as incompatible

- Status: Fix implemented and automated validation passed; live QA pending.
- Symptom: Companion Beta 19 is reported incompatible when the addon declares
  Beta 18 as its minimum.
- Cause: The addon compared the generated Companion version to one expected
  version using string equality.
- Fix: The addon now compares semantic release order against
  `X-Offhand-Companion-Min-Version`. Newer betas and the corresponding stable
  release satisfy an older minimum; older betas still produce the update prompt.
  Unknown future version formats remain non-blocking instead of producing a
  false warning.

## OH-UI-001 — First-login Escape consumed during intro cinematic

- Status: Resolved. Automated validation and live Forever Beta verification
  passed on the exact 4000x2560 mixed-height span.
- Symptom: The Game Menu and Blizzard's “Escape to skip cut-scene” action are not
  available when entering the world on a newly created character.
- Findings: A zero-runtime Offhand manifest reproduced the failure in the spanned
  Forever client, ruling out addon key handling, popups, panel restoration and
  viewport code. Returning keyboard focus to WoW did not help. Removing the
  Companion's non-rectangular window region caused Escape to expose the cursor but
  still produced no visible confirmation dialog. Escape therefore reaches
  Forever's cinematic handler, while the native close dialog is laid out outside
  the visible Mainhand cinematic in the 4000x2560 mixed-height bounding canvas.
- Workaround: On Forever only, Offhand observes the existing native cinematic or
  movie close dialog's `OnShow` and recenters that already-shown dialog in the
  Companion-defined Mainhand rectangle. It does not register for keyboard input,
  consume Escape, show the dialog itself, or invoke either confirmation action.
  `/offhand diag` reports whether the dialog hook attached or performed a move.
- Live evidence: During a newly created character's intro cinematic, Escape
  displayed Blizzard's native confirmation dialog centered on Mainhand and the
  cinematic could be skipped while the client remained spanned.

## OH-UI-002 — Detached Mainhand chat windows stack after reload

- Status: Fixed; automated validation and live Forever retest passed.
- Client: Forever Beta, Offhand 2.1.2, Companion Beta 18.
- Symptom: Individually detached and locked chat windows placed on Mainhand move
  to the full-span center and stack after login, `/reload`, instance entry, or
  other UI reloads. Detached windows placed on the Offhand workspace persist.
- Cause: Offhand recorded explicit Mainhand chat drops in `savedMainPositions`,
  but startup registration restored only `savedWorkspacePositions`. Forever's
  late native chat rebuild could therefore leave each detached Mainhand window
  at its full-canvas anchor until another drag reapplied Blizzard's saved state.
  A later compatibility pass also treated Forever's stale `isDocked` and
  `isStaticDocked` fields as authoritative even when the frame was absent from
  the live dock-membership list, causing the restored position to be discarded.
- Fix: Every detached Blizzard chat frame now restores either its committed
  workspace or Mainhand position during registration and `OnShow`, repeats the
  restore after native layout settles, and rejects a late native save that
  attempts to replace a committed Mainhand position during reload. Re-docking
  a detached tab relinquishes that snapshot and normalizes its dimensions to
  Blizzard's primary dock instead of replaying its detached size. The dock
  manager's current membership list now takes precedence over stale frame flags.
  Reload-time membership is transient, however, so it can no longer delete a
  tracked snapshot: only Blizzard's dock operation during an observed user tab
  drag relinquishes Offhand's position. The earlier one-time Combat Log reopen
  migration was removed after it could show an inactive `ChatFrame2` over
  General and persist it as detached. On Forever, Offhand no longer synthesizes
  visibility, docking or floating presentation for the built-in Combat Log.
  Generic persistent-panel restoration also excludes every Forever secondary
  Blizzard chat frame. A stale `ChatFrame2` workspace record therefore cannot
  call `Show()`, replay its obsolete dimensions, or replace Blizzard's
  dock-relative anchor while the dock is rebuilding. The settlement-gated
  tracked-chat path remains the only route that can restore a secondary frame
  after repeated observations establish that it is genuinely detached.
  Positive native dock or tab-parent evidence instead clears stale Offhand
  placement and hides the inactive frame when another dock tab is selected.
  Blizzard's saved dock bit is repaired only when the removed migration's
  compatibility marker proves that Offhand previously took ownership. A genuinely detached Combat Log must
  already be visible before Offhand restores only its explicit position.
  For custom secondary chat windows, when native fields disagree, Offhand first persists the tracked window as
  shown, then persists its already-observed detached state, clears only the
  stale runtime `isDocked` flag, and reapplies the character's saved chat color
  and opacity through Blizzard's setters before fading in the frame. This order
  lets Blizzard's presentation logic treat it as floating without losing the
  window. An earlier attempt to call `FCF_UnDockFrame` before repairing the
  shown bit was reverted because built-in windows disappeared after reload.
  Recovery also covers custom tracked windows whose legacy dock flags were
  already cleared by that reverted build; live dock membership is sufficient.
  Color-picker and Settings-initialization changes are observed after Blizzard
  applies them—including its `doNotSave` presentation calls—and receive both
  a next-frame appearance refresh and one bounded settlement replay. Because
  Forever can also fade floating chat chrome without calling either setter,
  Offhand's own Forever ticker observes the Chat Settings panel while it is
  open and on close, then reapplies only Blizzard's saved presentation values.
- Presentation boundary: Offhand does not choose chat colors, opacity, textures,
  fade behavior, or lock state; it only reconciles a tracked window's observed
  detached/shown state and reapplies Blizzard's saved presentation values.
  Chattynator intentionally
  attaches the single Blizzard edit box only to its first window; its secondary
  windows are output-only and remain wholly owned by Chattynator.
- Live QA: Place two detached, locked windows at different Mainhand positions
  and one on Offhand. Verify all three after `/reload`, relog, continent travel,
  and instance entry; then unlock and deliberately move each window to confirm
  its new position replaces the prior snapshot without taint or Lua errors.
- Live evidence: The default General and Combat Log tabs remained available,
  independent native chat frames retained their placements, and opening or
  changing Chat Settings preserved each frame's background color and opacity.
- Later reporter evidence: A clean Forever character reproduced a stale
  `ChatFrame2` record immediately after spanning. The healthy 752x537 frame was
  dock-relative and hidden; generic restoration replaced it with the stale
  430x120 size and a direct `UIParent` anchor. The supplied two-guard patch
  prevented the corruption in the reporter's live client. Current source uses
  the stronger form of that boundary for every secondary Forever chat frame.

## OH-UI-003 — ChatFrame2 scroll callback failure with Chattynator

- Status: Fixed compatibility boundary; automated validation and live Forever
  smoke test passed. The original nil callback remains attributable to the
  Blizzard/Chattynator scroll path rather than confirmed as Offhand code.
- Client: Forever Beta with Chattynator enabled.
- Symptom: Blizzard `ScrollUtil.lua:209` repeatedly attempts to call a nil value
  while refreshing the native `ChatFrame2` used for Combat Log.
- Evidence: Chattynator reparents `ChatFrame2` into its custom Combat Log holder,
  gives it two parent-relative anchors, and hides its native chrome. The failing
  frame carried Offhand's native chat hook marker, but the stack contains no
  Offhand function and Offhand does not modify its scroll bar or callbacks.
- Fix boundary: When Chattynator is loaded, Offhand now clears obsolete native
  `ChatFrameN` snapshots and does not hook, clamp, resize, reanchor, or restore
  those borrowed Blizzard frames. Offhand's HUD pass also abstains from the
  complete chat layout and shared `ChatFrame1EditBox`, leaving Chattynator solely
  responsible for its windows, text input, and embedded Combat Log.
- Live QA: Reload with Chattynator enabled, open and scroll its Combat Log, gain
  combat messages, switch tabs repeatedly, and confirm the nil callback does not
  recur. Repeat once with Chattynator disabled to verify native detached-chat
  persistence and re-docking still pass.
- Live evidence: Chattynator was enabled after the native-frame retest and its
  chat windows, input, and embedded Combat Log behaved normally under Offhand's
  compatibility boundary.

## OH-UI-007 — Dialogue UI uses the complete monitor canvas

- Status: Compatibility layer implemented and automated regression passed;
  live Forever verification pending.
- Client: Forever 1.60.1 with Dialogue UI 1.0.6.
- Symptom: Dialogue UI sizes itself from the bounded `WorldFrame`, but anchors
  the quest parchment, tutorial banner, status helpers, book, and settings to
  the complete spanned `UIParent`. On a mixed-height span, those elements are
  offset into the monitor seam or the physical void above Mainhand.
- Fix: While Offhand has an active span, only Dialogue UI-owned anchors that
  target `UIParent` are translated to the addon-owned Mainhand region. The
  quest, book, and settings roots receive the physical-height correction used
  by full-screen presentations. Dialogue UI's anchor offsets remain in their
  native coordinate space. Native animation updates are preserved.
  Dialogue UI keeps ownership of its size preference, camera, interaction,
  input, and saved settings; protected and forbidden frames are skipped.
  After a frame-size rebuild, the quest root is completed at Dialogue UI's own
  `frameHeight` target if its Unfold animation retained the intermediate
  half-height. No replacement dimensions or preset values are introduced.
  Dialogue UI's anonymous custom quest-reward tooltip is
  clamped after its anchor and layout transactions so Shift comparison details
  remain inside the physical game viewport without requiring Blizzard tooltips.
  Disabling Offhand or returning to one screen restores the native anchor owner,
  scale, and offsets.
- Live QA: On Forever, test gossip, quest detail, quest progress, reward choice,
  the first-use settings banner, F1 settings, and a readable book. Repeat with
  Dialogue UI's left/right orientation and each frame-size option, then disable
  Offhand and confirm Dialogue UI returns to its native single-screen layout.
  Hover every reward type with the custom tooltip enabled, hold and release
  Shift for item comparisons, and verify the tooltip remains inside Mainhand.
  Change Large to Medium and back to Large while a quest is open, confirming
  the parchment recovers its original dimensions without `/reload`.

## OH-FOR-013: OpenMap and Leatrix world-map position ownership

- Status: Resolved for the ongoing test package by user acceptance. Local
  Forever Beta checks did not reproduce the issue with neither addon, Leatrix
  alone, OpenMap alone, or both enabled. The user accepted the ownership change
  together with the original testers' workarounds. Exact reporter failure order
  and broader protected-action safety were not established by those checks.
- Scope: Forever, Discord candidate `a484baf`; two testers report map snap-back
  or placement on the wrong display after restart. Supplied versions are
  Leatrix Maps 1.60.25 and OpenMap 0.7.2-beta. Supplied Leatrix settings enable
  Unlock map frame and Scale the map; Use simple map frame is disabled.
- Source evidence: Installed OpenMap `Map/Window.lua` saves its own window
  anchor from its own drag handle. It reapplies that anchor and scale after
  SetPoint/SetScale and native panel layouts. Its drag suppression only covers
  its own handle. Installed Leatrix `Leatrix_Maps.lua` independently saves
  MapPos/MaxMapPos from its drag handler and reapplies them on display-state
  and size changes. OpenMap `Map/Compat.lua` explicitly warns to disable
  Leatrix UnlockMap, ScaleWorldMap and SimpleMapFrame when enabled.
- Offhand defect: OpenMap was absent from geometry ownership detection, so
  Offhand's drag/restore/settlement paths could compete with OpenMap. With
  Leatrix loaded Offhand yielded to Leatrix, while OpenMap still enforced a
  different saved position. Source evidence establishes competing writers;
  it does not establish the exact order of each tester's restart failure.
- Candidate: Detect OpenMap as an external geometry owner, ahead of Leatrix
  but below existing MoveAny/ClassicUIForever ownership. Retain external-map
  open intent and reopening, hide Offhand's map mover and leave map position,
  scale and content refresh to the external owner. Preserve dormant Offhand
  coordinates and third-party settings without changing installed addons.
- Configuration: With OpenMap, disable Leatrix Unlock map frame and Scale the
  map, then reload. Keep Use simple map frame disabled. Move the map using
  OpenMap's title handle so OpenMap saves the new position. Coordinate overlays
  are a separate compatibility setting, not the geometry fix.
- Evidence: New Forever regression fails against `a484baf` and passes against
  the candidate. All 36 Lua suites and six-manifest Lua/XML validation pass.
  Live drag, close/reopen, reload, cold restart, span/restore and protected
  map-pin actions remain pending, both with OpenMap alone and with Leatrix's
  competing options disabled. Magic's diagnostics were unavailable.

### Single-screen retest boundary

The missing-monitor prompt and unavailable detached windows observed while WoW
was deliberately not spanned are the expected safe recovery state, not evidence
for OH-FOR-004 or OH-UI-002. OH-FOR-004 still requires an exact span followed by
the Companion bridge repair and `/reload`; OH-UI-002/003 require the exact span
for their monitor-placement checks. The Beta 19 Companion/addon pairing was
accepted in the reported single-screen session, but OH-COMP-001's newer-than-
minimum comparison still requires a deliberately newer Companion build. The
Forever Edit Mode observation belongs to OH-FOR-003; OH-EM-001 is Retail-only.


## OH-RET-001: Midnight hang, addon-error warning and missing chat

- Report received 2026-10-24. Reporter uses CurseForge addon v2.1.2 Beta 22 and
  Microsoft Store Companion Beta 20. Exact WoW build and other addons unknown.
- User clarified that WoW stopped responding; no Windows restart or blue screen
  was reported. Treat this as an application hang, not a confirmed PC crash.
- Screenshots show Windows reporting WoW unresponsive, followed after restart by
  Blizzard's excessive-addon-errors warning. Reporter says that warning could not
  be clicked/dismissed and chat subsequently disappeared. No first Lua error,
  stack, hang dump or Companion activity log is available.
- These symptoms may be related, but the screenshots do not establish a common
  root cause, Offhand attribution, a GPU/resource cause or a protected-action block.
  Silvermoon location and PC performance are context only.
- Investigation targets: earliest fresh error before the warning; native popup
  ownership and input behavior; ChatFrame1 and third-party chat ownership; actual
  native-window bounds versus UI-canvas geometry after restart.
- Minimal evidence request: exact build, first BugSack/BugGrabber stack (before
  secondary errors), other enabled UI/chat addons, Companion activity log around
  the event, and whether the issue occurs with Offhand alone. Preserve settings.
- No speculative crash/chat fix or Companion binary replacement made. Existing
  local development onboarding fixes are not evidence against the public build.
- Next gate: controlled reproduction on the reported client with fresh errors.

## OH-COMP-002: VSync graphics change reportedly resets an active span

- Same reporter/pairing as OH-RET-001. Changing VSync reportedly returns the
  entire setup to default. Need to establish whether this means native window
  size/style, the game viewport, HUD layout selection or saved addon configuration.
- Verified from the Beta 20 tag: monitoring remembers successfully spanned process
  IDs; launch auto-span skips those IDs. Display-disconnect restoration and bridge
  repair exist, but a later bounds mismatch on the same already-spanned process
  does not trigger automatic re-span. This is a recovery gap consistent with the
  report, not proof that VSync changed the native window in this case.
- Addon v22 debounces display/scale events and safely rejects mismatching canvas
  geometry. It cannot resize the native window or promise that graphics settings
  leave the window untouched. Do not loosen topology validation to hide a mismatch.
- Separate verified source race: an older display callback can already be queued
  behind combat before a newer graphics/display event increments its generation.
  The local candidate rechecks generation inside the queued callback. Regression
  proves superseded work performs no layout apply/restore and does not end the
  newer transition; only the latest queued callback runs.
- Evidence level: source and simulated regression only. This guard is not claimed
  to fix the native-window reset, application hang or disappearing chat.
- Repro plan: record Windowed mode, exact monitor selection and bounds; establish
  a working span; change only VSync and Apply; record window bounds, addon metrics,
  active HUD layout, chat visibility and Companion log. If it changes, use the
  same selected displays and Span WoW Now, then /reload, and record restoration.
  Compare changing VSync before spanning. Avoid simultaneous addon updates/resets.
- Potential Companion recovery design must retain the last explicitly confirmed
  display identities, respect Restore Window/manual moves, skip unresponsive WoW,
  settle graphics changes, bound retries/cooldowns and offer an explicit opt-out.
  Do not repeatedly force a window size or silently select different monitors.
- Native Companion artifacts remain frozen on this addon branch. Implementation
  and packaging require the separate Companion candidate lane and live QA.


### OH-COMP-002: local VSync reproduction, 2026-10-24

- User supplied a working baseline screenshot and a second screenshot immediately
  after changing Vertical Sync from Enabled to Disabled.
- Baseline shows the map, character and bags on portrait Offhand and game/HUD on
  landscape Mainhand. After the change, Offhand exposes another desktop app and
  WoW occupies a smaller region on Mainhand with desktop visible around it.
  Offhand displays its topology-mismatch warning. This establishes loss of the
  combined native-window span, rather than merely a misplaced viewport/HUD.
- Chat is visible in the smaller game window in the second screenshot. This run
  does not reproduce the original reporter's missing-chat symptom or application
  hang. No evidence yet establishes erasure of the saved addon layout.
- The visible warning includes the latest local highlighted-action copy, so this
  evidence must not be labeled an isolated public-v22 reproduction. Exact local
  addon/Companion pairing and client build still need confirmation.
- Next test: keep VSync Disabled and the same monitor selections; click Span WoW
  Now once without reloading first; inspect native span, viewport and workspace.
  Then /reload once and inspect again. This separates native-window recovery from
  addon bridge reload/state recovery. Do not recalibrate or reset the profile.


### OH-COMP-002: re-span and reload results, 2026-10-24

- User reports the post-VSync state is partially transparent, with Options anchored
  at bottom right. Screenshot shows portions of the desktop app visible through/
  alongside the damaged game presentation. Treat the earlier smaller-window
  description as incomplete: this is a window/rendering/UI placement disruption,
  and native bounds/style/render-target details have not yet been measured.
- Clicking Span WoW Now restores the UI before /reload. Supplied second screenshot
  shows the portrait workspace panels and Mainhand game view restored, with VSync
  Disabled and the graphics panel reporting a custom 4000x2560 render area.
- After /reload, the span and workspace remain restored. The displayed popup is
  OFFHAND_HUD_SETUP_REMINDER (display saved, HUD setup pending), not the topology-
  mismatch warning. Prior explicit Finish Anyway testing can explain this saved
  reminder. No evidence shows that VSync erased or newly deferred the HUD record.
- Chat is visible in the restored screenshots. This run still does not reproduce
  the original Midnight reporter's application hang/excessive Lua errors.
- Manual recovery is demonstrated for this local candidate/session. Automatic
  recovery remains unimplemented. Need native bounds/style and Companion log for
  the transition, exact client build and loaded Companion version, and an isolated
  comparison with the addon disabled before assigning the initiating cause.
- Next controlled comparison: with a stable saved setup, disable Offhand through
  the addon list and reload, retain Companion's existing span, then toggle VSync
  once. Record whether the same transparency/window disruption occurs and whether
  Span WoW Now repairs it. Re-enable Offhand afterwards. Preserve saved settings.


### OH-COMP-002: console VSync comparison with addon disabled

- Without Offhand, the Graphics Options panel was inaccessible in the unused
  display-canvas area, preventing repetition of the original GUI interaction.
- Read-only CVar query returned vsync="0"; gxVSync had no returned value.
- User followed console-based enable/span/disable instructions and reported no
  visible change after toggling while spanned. Final screenshot confirms vsync="0"
  and a stable addon-disabled spanning presentation. Intermediate value "1" was
  not captured, so confirm both states in the next controlled comparison.
- This is a negative result for the console path, not a matched GUI reproduction:
  original failing case had addon enabled and used Graphics Options. Do not claim
  addon exoneration or attribution from these differing conditions.
- Next comparison keeps the console method and verifies both states, with Offhand
  enabled. If both console paths are stable, focus investigation on Graphics
  Options apply/window-reset behavior; if only enabled fails, inspect addon event
  handling around the observed transition. No further runtime change made here.


### OH-COMP-002: verified console toggle with Offhand enabled

- User separately queried vsync="1", then changed it to "0" and verified the
  latter value. With Offhand enabled, no corruption was observed: span, viewport,
  map, character panel, bags and chat remained visibly intact in the screenshot.
- Current comparison: Graphics Options Enabled-to-Disabled with addon enabled
  reproduces disruption; console toggle with addon enabled does not; console
  toggle with addon disabled also produced no observed disruption (its enabled
  intermediate state was not captured). Graphics Options with addon disabled
  remains untested because its panel is outside accessible physical regions.
- This narrows the reproduced trigger to the Graphics Options interaction/apply
  path, not merely changing the vsync CVar. It does not prove a particular native
  graphics API cause or clear addon event handling invoked only by that path.
- No further console repeats needed. Next investigation should compare native
  window bounds/style/clipping and relevant graphics CVars before/after the GUI
  action, then design bounded Companion recovery respecting explicit restores.
  Do not infer that the separate application hang or excessive-error warning is
  resolved or reproduced by this result.


### OH-COMP-002: temporary matched capture prepared

- tools/display-capture contains a separate optional probe addon and read-only
  Windows observer. This avoids replacing public Companion or the addon under
  test solely to add diagnostics. README defines the single-GUI-toggle protocol.
- Logs correlate UTC graphics CVar/canvas events with native window/client bounds,
  style, clipping-region count/bounds, layered attributes and hung state.
- One-second observer validation succeeded against the currently running
  WowClassic process. This is not the original reporter's exact Midnight build.
- Temporary probe is not yet installed because WoW is running. Native logs flush
  independently; addon SavedVariables require normal exit and may be unavailable
  after a hang. No claim that these logs diagnose the original hang without it
  being reproduced. Companion executable and window behavior remain unchanged.


### OH-COMP-002: matched native/addon capture confirms stale clipping after GUI reset

- Capture completed on Anniversary 2.5.6 build 70006, interface 20506, WowClassic
  PID 44808, with the local addon candidate. This is not a Midnight reproduction.
- At 18:42:22 UTC the native window and client are 4000x2560 with a complex
  3-rectangle clipping region covering the same 4000x2560 bounds.
- At 18:42:50-51 UTC, the GUI VSync change returns the client to 2114x1353,
  exactly its pre-span size. Window styles gain resize-frame/window-edge bits,
  and the window recenters on Mainhand. The same HWND retains the OLD 4000x2560,
  3-rectangle clipping region. This mismatch persists until capture ends.
- Addon log correlates vsync 1 -> 0 with display/scale events, physical canvas
  4000x2560 -> 2114x1353 and READY -> MISMATCH fallback. hudDeferred remains false.
  No sampled native hung flag. No evidence of saved layout erasure or original
  reporter's hang/excessive errors. No reported layered attributes is not proof
  against renderer/compositor transparency.
- This narrows the confirmed failure to graphics-apply native window/style reset
  retaining obsolete clipping. It does not establish which native call initiates
  the reset or that clipping explains every artifact. Console-only changes were
  stable. The topology guard is behaving as intended.
- Preserved native and addon copies plus detailed analysis are under
  dist/display-captures/analysis-20261024.md. Native SHA-256:
  CB6BCEF5D08A33CB5D380DF9DE621BF901D11EAA51A8183EA2823BC067AB453C.
  Addon log SHA-256:
  60FD296A715B79539841CC9F54E9E027E212E6F6F2C77B913BB5C5253CA25157.
- Next: separate Companion candidate that reconciles confirmed bounds, borderless
  style and clipping together, with bounded recovery and explicit restore/manual
  movement/display-disconnect safeguards. No public binary changed here.

### 2026-10-24: Open Options panel retains span offset after Restore Window

- Retail screenshot shows Graphics Options partly offscreen at the bottom right
  after Companion restores the ordinary window. Treat menu placement separately
  from native span recovery and the original reported client hang.
- Source inspection: menu show hooks center panels on Mainhand, but full layout
  skips SeamRedirect on an unspanned canvas. An already-open menu can retain its
  former CENTER offset after the canvas shrinks.
- Local addon candidate adds MenuPlacement, a side-table owner for ordinary menu
  anchors. Settled layout refreshes those anchors on single-window transitions.
  Hidden menus remain hidden; combat, protected/forbidden frames, invalid geometry
  and external re-anchoring prevent writes. No new native scripts or attributes.
- Automated evidence: 53 Lua suites pass, all six manifests and Lua 5.1 syntax
  validate, and git diff --check passes. Runtime placement and taint verification
  remain pending. Installed Retail release-tag v22 baseline is unchanged.

### 2026-10-25: Retail menu-placement candidate installed for live QA

- User confirms the prior Retail Companion Test 4 steps 1-4 passed, including
  repeat recovery and Pause/Resume/Restore priority. Release-tag baseline testing
  is complete for that sequence and the tested display arrangement.
- With WoW closed, installed the current local development addon (including the
  menu-placement fix) into Retail. All 72 copied files hash verified; both
  generated bridge files preserved; SavedVariables untouched. Other clients and
  Companion binaries unchanged. This installation includes existing pending
  onboarding/HUD development changes, not only the isolated menu fix.
- Prior addon backup: D:/Games/World of Warcraft/_offhand_deploy_backups/
  onboarding-identify-20261025-000349-712-Retail/Offhand.
- Next live check: keep Graphics Options open during Restore Window and manual
  re-span, verify centering and usability after settling, close/reopen Options and
  Escape menu, and inspect new BugSack/protected-action errors.

### 2026-10-25: Retail menu placement live checks passed

- User confirms all five requested checks on the installed development candidate:
  normal span, Graphics Options open during Restore Window, centered/usable
  Options in the restored window, manual re-span with Options open, Options and
  Escape menu close/reopen, and no new BugSack errors reported.
- This accepts visible menu placement for the tested Retail configuration.
  Combat deferral, third-party ownership and broader taint checks remain covered
  only by automated guards or pending live testing; no broader safety claim.
- Companion repeat recovery and cancellation checks were previously confirmed.
  Original tester's client hang/excessive errors remain unreproduced. No public
  addon or Companion release has been published from these candidates.

## Client coverage follow-up

The user's 4 November Forever release milestone now takes priority. See
COMPANION-CLIENT-MATRIX.md for all client families and FOREVER-GRAPHICS-TEST.md
for the next isolated candidate. The previously generated review bundle remains
an immutable earlier snapshot; it does not contain Test 5 or the newer scope
source changes. Do not distribute that snapshot as the final unified rebuild.
Retail and Anniversary live results are retained; Forever Test 5 and Era live
acceptance remain pending. Current three client-scope policy builds pass 104
assertions each. No public binaries or website/download versions changed.

### 2026-10-25: Companion work consolidated in planning; Forever testing deferred

User requests Forever live testing wait until the November 4 release and treats
this recovery work plus the experimental work in Investigate v21 Forever Beta
issue as one ongoing Companion build. Shared record: docs/COMPANION-ONGOING-BUILD.md
in D:/Tools/Code/Offhand. Separate worktrees and accepted artifacts are preserved;
no source merge or publication implied. Reconcile the graininess resize mitigation
with the recovery candidate's deliberate omission of that handshake before making
one final candidate. Other work may proceed meanwhile. No automation scheduled.
