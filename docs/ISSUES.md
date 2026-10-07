# Offhand Issue Ledger

Stable IDs for reports that require follow-up across test sessions.

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

- Status: Fix implemented and automated validation passed; live group-loot QA
  pending.
- Client: Forever Beta, Offhand 2.1.2 Beta 18.
- Symptom: Blizzard's group-loot roll container appears at the full-span center
  or partly off-screen instead of inside Mainhand.
- Fix: `GroupLootContainer` now uses the same restricted secure Mainhand
  positioner as battleground widgets. Offhand accepts Blizzard's build-varying
  single UIParent anchor, preserves user/addon-relative placements, adds no
  insecure frame scripts, and discovers both known load-on-demand loot modules.
- Live QA: Trigger several simultaneous need/greed rolls before and during
  combat, `/reload` in a group, and confirm the rolls remain visible without
  protected-action or secret-value errors.

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
  drag relinquishes Offhand's position. A one-time Forever migration repairs the
  exact affected-beta signature where Combat Log remains natively detached but
  both its shown bit and Offhand snapshot were cleared; Blizzard's own position
  is retained and recaptured.
  When those fields disagree, Offhand first persists the tracked window as
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
