# Offhand Issue Ledger

Stable IDs for reports that require follow-up across test sessions.

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
- Live QA: Move the preview, trigger several simultaneous need/greed rolls,
  enter and leave combat, then `/reload` while grouped. Confirm the first roll
  returns to the saved position, later rolls stack upward, the preview hides in
  combat, and no protected-action or secret-value errors occur. Repeat with a
  custom loot-roll mover and confirm Offhand yields ownership.

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

### Single-screen retest boundary

The missing-monitor prompt and unavailable detached windows observed while WoW
was deliberately not spanned are the expected safe recovery state, not evidence
for OH-FOR-004 or OH-UI-002. OH-FOR-004 still requires an exact span followed by
the Companion bridge repair and `/reload`; OH-UI-002/003 require the exact span
for their monitor-placement checks. The Beta 19 Companion/addon pairing was
accepted in the reported single-screen session, but OH-COMP-001's newer-than-
minimum comparison still requires a deliberately newer Companion build. The
Forever Edit Mode observation belongs to OH-FOR-003; OH-EM-001 is Retail-only.


## OH-COMP-002: Classic Graphics Options reset recovery candidate

- Retail has not been tested. Original Midnight hang/error report remains separate.
- Anniversary 2.5.6 build 70006 capture established that GUI VSync Enabled to
  Disabled returns the client from 4000x2560 to its pre-span 2114x1353 size while
  retaining the old 4000x2560 complex clipping region and restoring frame styles.
- Source: codex/classic-graphics-recovery, based on companion/develop at 4ae9d38.
  Separate worktree; addon development changes and public binary remain untouched.
- Recovery implementation is compiled only into the explicitly named test build.
  Manual span arms one exact-signature attempt for Era/Anniversary. Same HWND,
  original client size, stale clipping, resize-frame style, stable unchanged
  display identities/roles/rectangles and usable window are required. At least
  two seconds of stable observations precede the attempt. Unrecognized settled
  geometry consumes the arm. Restore Window and Pause Monitor cancel it.
- Recovery reuses Span WoW Now with fresh process/window/plan validation and verifies
  client dimensions, clipping bounds and borderless style after applying. No
  automatic retry loop or renderer hooks. A new manual span can explicitly re-arm.
- Candidate launch auto-span is disabled. Retail/Forever cannot be spanned by this
  candidate. Test settings are separate from the public INI; UTC activity log is
  written beside the test executable. Beta 20 bridge metadata remains compatible.
- Automated: 24 pure policy checks and existing preference, identity/topology,
  restore, packaging-boundary and DPI layout regressions pass. Native recovery is
  live pending. Candidate ZIP executable bytes verified against build hash.
- Candidate binary SHA-256:
  EB7DF7CFDA00A937FB22E5C3876FAA031E39A5A2CD8BB0F4F0432F3ECC2C3F14.
  Frozen public SHA-256 unchanged:
  81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB.
- Test and rollback instructions: docs/CLASSIC-GRAPHICS-TEST.md. Start with
  Anniversary. Resolution requires observed single automatic recovery and
  Restore Window/no-retry behavior. Do not progress to Retail before Classic
  acceptance. Do not attribute the original application hang to this issue.


### Classic candidate 1 rejected; initial span must pass first

- User reports the initial manual span collects at top-left of portrait display
  and a subsequent span falls back to the ordinary window. Recovery not accepted.
- Candidate activity log has manual spans at 19:19:32 and 19:21:26 UTC. There is no
  graphics-reset recovery attempt logged. Do not label the second manual failure
  as an automatic recovery failure.
- Native capture window-20261024-212016-357.jsonl starts after the first failure,
  with outer size 2114x1353, client 2100x1339 and stale 4000x2560 region at span origin.
  During the second manual span it records 4000x2560, then the inherited one-pixel
  4000x2559 resize, then 4000x2560, followed by the saved-size reset. The manual
  verification fails and rollback removes the explicit region. No hung sample.
- The separate companion/develop base included an experimental renderer-resize
  handshake absent from the public Store baseline. Including it in this candidate
  introduced a confound. Candidate 2 excludes that handshake for Classic testing;
  no renderer-cause claim is made before the new initial-span test passes.
- Candidate 1 could arm after a transient successful readback, before the span
  remained valid. Candidate 2 requires healthy outer/client/region/style observations
  separated by at least two seconds. Failed initial spans cannot arm recovery.
- Candidate 2 recognizes the observed outer-size fallback as well as client-size
  fallback, accommodating the 14px nonclient border accounting seen in capture.
  Same-window, confirmed plan, stale region and frame-style guards remain.
- Candidate 2 has an explicit CLASSIC TEST 2 window title, richer readback logging
  and pending-versus-stable messages. Initial span must be visually correct and
  stable-armed before the user continues to the VSync test. No Retail testing.
- Automated: 51 guard assertions plus existing Companion regressions pass. Candidate
  2 built/ZIP hash verified; frozen public EXE unchanged. Live initial span and
  automatic recovery remain pending. See docs/CLASSIC-GRAPHICS-TEST.md.


### Classic candidate 2 initial span accepted, recovery test pending

- User reports the in-game initial span looks correct on Anniversary. Screenshot
  identifies CLASSIC TEST 2, WowClassic PID 26156, expected display roles and sizes.
- Activity log at 21:35:27 local shows outer (-1440,-1114) 4000x2560, client
  4000x2560, region (0,0) 4000x2560 and borderless style 0x140B0000.
- At 21:35:29 the monitor reports Classic span verified stable and one graphics-
  reset recovery armed. This is live acceptance of the initial span only.
- Next: capture one GUI VSync Enabled-to-Disabled transition without manual Span;
  allow up to ten seconds and inspect the automatic recovery log and final UI.
  Retail remains untested. Original Midnight hang is still a separate report.


### Classic candidate 2 automatic recovery live verified once on Anniversary

- Candidate log and independent native observer correlate on WowClassic PID 26156,
  HWND 210439774. The original healthy span started at 19:35:27 UTC and was armed
  after stable verification at 19:35:29.
- Native observer records the GUI-reset signature at 19:38:05.873 UTC: outer
  2114x1353 at the old span origin, client 2100x1339, stale 4000x2560 region and
  resize-frame styles. It settles to client 2114x1353 on Mainhand at 19:38:06.930.
- At 19:38:11.715, Companion detects the signature and starts one recovery. At
  19:38:12.090 it logs restored bounds/style/clipping. The native observer
  independently shows outer and client 4000x2560, original span origin, borderless
  style and matching complex region at 19:38:12.270, remaining stable until the
  capture stops at 19:38:18.432. No sampled hung flag.
- User screenshot shows working game/HUD and map/character/bags workspace after
  capture. A later manual span at 19:38:34 re-arms recovery, but occurred after the
  automatic restoration and native capture, so it is not the cause of this success.
- Evidence preserved in dist/display-captures/window-20261024-213518-175.jsonl and
  classic-test2-20261024-1938-companion.log in the primary D:/Tools/Code/Offhand tree.
  Addon SavedVariables were not yet flushed at analysis time; do not reuse an older
  addon log as evidence for this run.
- State: initial span and one automatic recovery live verified for this Anniversary
  configuration. Remaining Classic acceptance: explicit Restore Window stays
  restored, paused monitoring stays paused, no repeated forced resizing, and
  re-arm behavior. Era and Retail remain untested. Original Midnight hang remains
  unresolved. Do not promote the candidate/public binary yet.


### Classic candidate 2 explicit Restore Window guard accepted

- User confirms Restore Window returns WoW to its normal window and Companion
  does not force it back into a span after the requested ten-second wait.
- This establishes live acceptance of the explicit restore cancellation guard on
  the current Anniversary setup, in addition to initial span and one automatic
  graphics-reset recovery. It is not a Retail or Era result.
- Next Classic gate: Pause Monitor prevents graphics-reset recovery and resuming
  monitoring does not silently revive the cancelled arm. A new manual span should
  be required to arm recovery again. Public binaries remain unchanged.


### Classic candidate 2 Anniversary acceptance sequence completed

- User confirms every step of the final safety test: stable manual span, Pause
  Monitor, GUI VSync Enabled-to-Disabled, no recovery during ten seconds paused,
  Resume Monitor followed by ten seconds with no unsolicited recovery, and manual
  Span WoW Now restoring/re-arming the setup.
- Combined live acceptance on this Anniversary configuration now covers initial
  stable span, one automatic graphics-reset recovery, explicit Restore Window
  priority, pause cancellation, resume without reviving the cancelled arm, and
  manual re-arm. No oscillation or repeated forced resize was reported.
- Candidate remains Beta 20 CLASSIC GRAPHICS TEST 2, SHA-256:
  4A4E9082FF147A2AF1C6EB49E2A2FE1F4BEA1345359E64BD37ED6D9D1A211532.
- State: targeted VSync-reset recovery and cancellation behavior live verified
  for the tested Anniversary setup. This is not broad Classic-client approval:
  Era has not been tested, other display arrangements remain unverified, and
  Retail/Midnight has not been tested. The original hang/excessive-error report
  remains a separate unresolved issue.
- No Store/public release, binary replacement, merge or Retail scope enablement
  occurred. Retain candidate and captured evidence for review before promotion.


### OH-COMP-002 product direction confirmed

- User requests automatic graphics-reset recovery as default behavior after a
  confirmed span while Companion monitors, with no separate recovery checkbox.
- Current Classic candidate already arms recovery after stable manual spanning;
  no runtime change is needed to remove an option because none was introduced.
- Preserve Restore Window and Pause Monitor cancellation, unchanged-display and
  window-identity guards, responsiveness checks and bounded attempts.
- Current one-attempt-per-manual-arm limitation remains; do not describe this
  candidate as unlimited persistent recovery or claim other settings/client
  coverage from the VSync test. No public release or Retail enablement here.


### Classic candidate 3: bounded repeated recovery implemented, live pending

- User authorized automatic re-arm after successful recovery. No optional feature
  checkbox is introduced; recovery remains default behavior while monitoring.
- Same ownership and captured-reset signature guards apply. After a native recovery
  passes immediate verification, no new attempt may run until continuously observed
  healthy geometry lasts four seconds and ten seconds have elapsed since completion.
  Post-verification has a twenty-second deadline. Failure stops, without a retry.
- A rolling queue permits at most three attempts per five minutes. A fourth eligible
  reset latches recovery off and gives a tray/activity notice. Explicit manual span
  is required to reset a limit/failure latch. Old timestamps expire from the queue.
- Restore Window/Pause Monitor still cancel during cooldown. Resume Monitor does
  not revive an arm. Identity/plan changes cancel; unusable windows are not resized.
- CLASSIC TEST 3 uses an isolated package and settings; experimental resize nudge
  remains disabled. Public binary, Store installation and Retail scope unchanged.
- Automated policy tests cover repeated requests without a manual span, no in-flight
  duplication, stability/cooldown, post-recovery flapping, failures, pause and plan
  changes during cooldown, rate limit and expiration. Live Anniversary repeated
  GUI-reset and user-control tests remain pending. See CLASSIC-GRAPHICS-TEST.md.


- Final Test 3 evidence: 88 policy assertions and existing Companion preference,
  topology/restore, packaging boundary and DPI layout checks pass. Verification
  deadline rejects late callbacks even if the latest observed window is healthy.
- Packaged/copied executable SHA-256:
  B63EB1D09C94E0737FB0F0EEBAD017104EBCACD14EB38F8523C3DB7A89A22163.
  Source SHA-256:
  D9528F26667F2666FC58B4072357A57845AE72EC8C8EC9DC03EECD54E34B1910.
- Review candidate: D:/Tools/Code/Offhand/dist/companion-classic-graphics-test3.
  ZIP executable bytes and copied files verified. Frozen public EXE SHA-256 still
  81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB.
- Test 3 repeated-recovery behavior remains live pending; Test 2's Anniversary
  acceptance does not substitute for the new cooldown/rate-limit validation.


### Classic Test 3 repeated Anniversary recovery passed

- User reports all six repeated-reset steps completed and supplies intact game/
  workspace screenshot and CLASSIC TEST 3 log screenshot, WowClassic PID 44304.
- Full candidate log shows one initial manual span at 20:15:26 UTC and stable
  arming at 20:15:29. Automatic recovery 1 completes at 20:16:10.276 and re-arms
  after observed stability/cooldown at 20:16:21.942. Automatic recovery 2 completes
  at 20:16:40.166 and re-arms at 20:16:51.954. No intervening manual Span request.
- Each immediate readback reports 4000x2560 outer/client, original offset origin,
  matching clipping bounds and borderless style. Screenshot shows retained map,
  character, bags, chat and Mainhand game presentation. No failure/rate-limit pause
  is logged. This accepts two consecutive recoveries and re-arm cycles on this
  Anniversary configuration, based on Companion log plus user visual evidence.
- Latest Windows observer file window-20261024-221545-189.jsonl is empty. The
  preceding 221429 capture predates the reset sequence. Do not claim independent
  native-observer confirmation for Test 3. Probe SavedVariables on disk predate
  this run until normal logout; do not relabel older data as current evidence.
- Preserved Companion log: primary tree dist/display-captures/
  classic-test3-20261024-2016-companion.log.
- Remaining live Test 3 gates: cancellation during cooldown and intentional
  Restore Window/pause-resume behavior with the new re-arm state. Test 2 passed
  those controls without automatic re-arming; regression tests cover new states.
  Rate-limit exhaustion remains automated-only, not deliberately forced in game.
- Retail, Era and original Midnight hang remain outside this acceptance.


### Classic Test 3 Anniversary safety acceptance completed

- User confirms the final Test 3 sequence: Restore Window remains restored for ten
  seconds; manual span establishes stable ownership; a further GUI VSync reset
  recovers; Pause Monitor immediately after restoration cancels during cooldown;
  another VSync change while paused is not recovered; Resume Monitor followed by
  ten seconds does not revive recovery; manual span restores normal use.
- Together with two logged consecutive automatic recoveries/re-arm cycles, this
  accepts the targeted graphics-reset recovery, cooldown and user-control behavior
  on the tested Anniversary build/configuration. The rolling attempt limit and
  failure/deadline guards have automated coverage; exhaustion was not forced live.
- Scope remains Anniversary 2.5.6 build 70006, offset 2560x1440 Mainhand plus
  1440x2560 portrait workspace. Era, other arrangements and Retail remain untested.
- Next investigation may proceed to Retail as a separate client baseline with
  diagnostics. Do not enable Retail recovery based only on Classic acceptance;
  original Midnight hang/excessive-error report remains unresolved.
- Test candidate is still unpublished. No public/Store binary replacement or
  promotion has occurred. Candidate hash and prior test evidence remain unchanged.


### Retail baseline preparation, not yet installed or tested

- User authorized proceeding to Retail after Anniversary Test 3 acceptance.
- Staged addon release-tag v2.1.2-beta.22 at commit
  62de7a3f0e850601c02e1cb7d1db713186680988, with file hashes and a guarded Retail-only
  installer backing up existing development files while preserving generated
  bridges/SavedVariables. Tag source was validated; CF ZIP bytes were not compared.
- Current Retail installation remains development source until installer succeeds.
  Classic is still running, so no client deployment occurred in this preparation.
- Retail executable metadata: 12.1.5.70575. In-game build remains to be captured.
  Probe source hashes match; BugGrabber and BugSack files exist, but per-character
  enablement still requires in-game confirmation. No error state was cleared.
- Public Store Beta 20 is the intended Companion baseline, with no automatic
  recovery. CLASSIC TEST 3 remains blocked from Retail; no scope code changed.
- A Retail-only native-capture launcher rejects Classic clients. Watcher startup
  now flushes an initial record before monitor enumeration and logs exceptions,
  without claiming a root cause for the previous empty capture. Read-only Classic
  preflight, own-region interop self-test and Retail-rejection tests passed.
- Next: close Classic normally, install the prepared Retail baseline, then follow
  docs/RETAIL-DISPLAY-BASELINE.md. No Retail runtime/taint/hang result yet.


### Retail release-tag baseline installed after normal client exit

- User confirmed clients closed. Guarded installer deployed v2.1.2-beta.22 commit
  62de7a3f0e850601c02e1cb7d1db713186680988 into Retail, verifying 45 copied files.
  Two generated bridge files were preserved; SavedVariables and Classic addon
  folders were untouched. Full development-addon backup was verified under the
  named retail-public-beta22-20261024-224337-597 backup directory.
- installed.json in the primary dist/retail-baseline-beta22 folder records the
  deployment and backup. Retail runtime remains untested until user launches it.
- First gate is a working Retail span with public Store Companion Beta 20 and
  no unexplained Lua errors before initiating the Graphics Options VSync capture.


### Retail release-tag baseline visually accepted

- User reports Baseline is OK after the requested Store Beta 20/manual span and
  reload sequence. Screenshot shows Retail game/HUD on landscape Mainhand,
  Character and combined bags on portrait Offhand, with visible chat region.
- No first Lua error has been supplied for this baseline. Do not equate that with
  a verified empty BugGrabber session. Live build awaits probe metadata.
- Next: one captured GUI VSync Enabled-to-Disabled change, before manual recovery.
  Public Store Companion has no graphics-reset auto-recovery, preserving the
  initiating behavior for this comparison. Original Midnight hang remains open.


### Retail native reset confirmed; isolated Retail Test 4 prepared

- User reports no BugSack errors and top-left compaction after GUI VSync Disabled.
  Native capture window-20261024-225409-314.jsonl is valid and identifies Retail
  process Wow PID 51712, HWND 343151298, requestedClient=Retail.
- At 20:54:09 UTC: outer/client 4000x2560 at (-1440,-1114), borderless style
  0x140B0000, extended style 0x00040000 and 4000x2560 complex region (3 rectangles).
- At 20:54:30.328: outer 2114x1353 at old span origin, client 2100x1339, style
  0x140F0000, extended 0x00040100, with stale 4000x2560 region unchanged. This
  matches the captured Anniversary signature, including nonclient accounting.
- At 20:55:17.768: manual re-span restores outer/client 4000x2560 and borderless
  style. No sampled hung state. User's no-BugSack-error report is not an independent
  error-log audit. Original Midnight hang/excessive-error warning still unreproduced.
- Correction: file-list Length=0 while an observer file is open did not mean it
  was empty. Direct content reading succeeds. Previous empty-capture conclusions
  were premature. The full Test 3 native capture (221545) is now available and
  independently confirms both Anniversary resets/restorations at 20:16:04/10 and
  20:16:33/40 UTC. Keep old notes as history, with this correction authoritative.
- RETAIL TEST 4 uses the SAME tested policy with a separate Retail-only compile
  scope and labels/settings/log filename. Classic variant remains Classic-only;
  public build keeps recovery disabled. Retail candidate rejects Classic/Forever,
  skips the experimental resize nudge and uses the same cooldown/limit/ownership
  guards. The baseline addon installation is not replaced.
- Automated: 91 policy/scope checks pass separately in Classic and Retail modes,
  plus existing Companion tests and ZIP/copy byte verification. Frozen public EXE
  remains unchanged. Retail auto-recovery is live pending. Test instructions:
  docs/RETAIL-GRAPHICS-TEST.md; copied candidate under primary dist/
  companion-retail-graphics-test4. No Store/public publication.


### First Retail Test 4 run: recovery not armed, retest baseline required

- User reports Done. Test 4 log shows initialization at 21:21:02 UTC and detection
  of an already-spanned Retail client at 21:21:04, but no manual Span, native
  readback, stable confirmation, graphics-reset attempt or recovery completion.
- Native capture window-20261024-232344-631.jsonl starts with the already-collapsed
  window and stale region: outer 2114x1353 at span origin, client 2100x1339,
  frame styles and 4000x2560 clipping. Later it recenters to outer 2128x1367 with
  client 2114x1353. No recovery in this interval and no sampled hung state.
- Same Retail PID/HWND as the previous Store baseline remained running; Test 4
  attached to an inherited span. The candidate requires its own manual span from
  a smaller ordinary window and stable verification to arm safely. Original
  pre-span dimensions are intentionally not guessed from an inherited span.
- This is not an armed-recovery failure or acceptance. Repeat using Test 4 Restore
  Window, set VSync Enabled in the ordinary window, then Span WoW Now and wait for
  Retail span verified stable before starting a fresh capture and GUI toggle.
- Production guidance should make inherited-span/unarmed recovery status explicit;
  current detection log only mentions display-loss protection. Do not weaken the
  ownership/baseline guard solely to make this test appear to pass.


### Retail Test 4 first armed recovery and re-arm accepted

- User confirms the corrected full sequence succeeded, including Restore Window,
  Enabled VSync, Test 4 manual span/stable arm, fresh GUI disable capture, automatic
  recovery and cooldown re-arm without manual re-spanning.
- Candidate log confirms Restore at 21:30:12 UTC, manual span at 21:30:40, stable
  arm at 21:30:44, automatic reset detection/recovery at 21:31:42 and re-arm after
  stability/cooldown at 21:31:54. Each recovery readback verifies 4000x2560 outer/
  client, matching region, original offset origin and borderless style 0x140B0000.
- Companion log preserved as primary dist/display-captures/
  retail-test4-20261024-2131-companion.log. Latest native capture is
  window-20261024-233121-362.jsonl; read contents directly while open rather than
  relying on cached file-list length.
- State: one Retail armed recovery/re-arm live accepted on this configuration.
  Remaining Retail checks: second automatic recovery without manual span and
  Restore Window/pause-resume priority (including cooldown). Shared automated
  coverage and Anniversary acceptance do not substitute for those Retail checks.
- The original Midnight application hang/excessive-error report remains
  unreproduced and unresolved. No Store/public release or addon promotion.

### 2026-10-25: Retail Test 4 cancellation checks confirmed by user

- User confirms steps 1-4 of the final control sequence passed: repeat automatic
  recovery without manual span, Pause Monitor during cooldown, no recovery while
  paused, Resume without restoring cancelled ownership, Restore Window staying
  restored, and explicit manual spanning for normal use.
- Evidence level: user-confirmed visible behavior on the tested Retail display
  arrangement. The open Options panel retained its old offset after Restore;
  this is tracked separately as addon menu placement, not native re-spanning.
- Retail and Anniversary candidate recovery/control sequences are now accepted
  for this arrangement. Other display configurations, rate-limit exhaustion and
  the original Midnight hang/excessive-error report are not live verified here.
- After completion of the release-tag baseline test, the local development addon
  candidate including MenuPlacement was installed into Retail for separate UI QA.
  72 copied files hash verified; two generated bridges preserved; SavedVariables
  untouched. Full prior addon backup: D:/Games/World of Warcraft/
  _offhand_deploy_backups/onboarding-identify-20261025-000349-712-Retail/Offhand.
- No Store or public Companion binary was replaced and no release was published.

### 2026-10-25: Separate addon menu-placement follow-up passed

User confirms the installed addon development candidate keeps open Graphics
Options centered and usable after Restore Window and re-span, and Options/Escape
menu close/reopen checks passed with no new BugSack errors reported. This follows
the successful Retail Test 4 repeat recovery and cancellation sequence. Scope is
the tested configuration; the original client hang remains unreproduced. No
Store/public release has been made.

### 2026-10-25: Full client matrix and Forever-priority candidate

- User requests all supported client families be accounted for in the Companion
  rebuild, with Forever the priority for the planned November 4 release.
- Added COMPANION-CLIENT-MATRIX.md: Retail, Anniversary, Era, Forever, progression
  Classic, test/PTR clients and experimental legacy/custom installs each have
  explicit evidence and release gates. Known process name is not sufficient
  evidence to enable graphics-reset recovery.
- Added an isolated FOREVER GRAPHICS TEST 5 define, explicit Forever recovery
  scope, independent ForeverTestConfig.ini/log and package builder/test switches.
  It retains the shared bounded policy and existing stopped-client state bridge.
  Existing test scopes remain exclusive; normal build recovery stays disabled
  pending unified production integration and startup ownership tests.
- All three scope builds pass 104 assertions each; Companion preference/topology/
  packaging suite passes. Frozen Beta 20 binary unchanged. Historical accepted
  Classic Test 3 and Retail Test 4 binaries were not rebuilt or replaced.
- New candidate: primary dist/companion-forever-graphics-test5/Offhand.exe and ZIP.
  Archive EXE hash verified. Live Forever testing is pending, including protected
  HUD and normal SavedVariables persistence before recommending a bridge fallback.
- Do not infer final November 4 build compatibility from current executable
  1.60.1.70532. Other topologies, Era and progression Classic still need live QA.

### 2026-10-25: Companion work consolidated in planning; Forever testing deferred

User requests Forever live testing wait until the November 4 release and treats
this recovery work plus the experimental work in Investigate v21 Forever Beta
issue as one ongoing Companion build. Shared record: docs/COMPANION-ONGOING-BUILD.md
in D:/Tools/Code/Offhand. Separate worktrees and accepted artifacts are preserved;
no source merge or publication implied. Reconcile the graininess resize mitigation
with the recovery candidate's deliberate omission of that handshake before making
one final candidate. Other work may proceed meanwhile. No automation scheduled.
