# Offhand Issue Ledger

Stable IDs for reports that require follow-up across test sessions.

## OH-RET-001: Cutscene skip and contextual UI placement report

- Reporter confirms the Mythic+ completion panel is misplaced on test.2, with an
  image consistent with ChallengeModeCompleteBanner (no /fstack). Verified ZIP
  comparison: test.2 lacks that policy, test.3 includes it and native-method
  post-hook handling. This is baseline evidence; test.3 live retest is pending.
- Expanded notification source candidate/test.3 prepared from the audit: shared
  ordinary/special stacks, additional role/ready prompts, keystone/completion
  roots, toast final-anchor updates and independent side display. All 69 Lua
  suites and source/installed/extracted manifest checks pass; local Retail updated
  with backup/hash verification. Additional native geometry/action/taint passes
  remain pending, without weakening earlier original-issue confirmations.
  [Candidate and acceptance matrix](RETAIL-NOTIFICATION-CANDIDATE-20261031.md).
- Reporter now confirms Premade Groups working; no extra notification details.
  Named original issues have positive confirmation (cinematic/vehicle locally,
  Premade Groups by reporter). Broad notifications remain an audit category.
  Proactive source audit identifies additional LFG role/ready confirmations,
  Mythic+ keystone/completion roots, event-toast side display/reanchor timing and
  PvP/pet-battle confirmations for follow-up. These are source coverage candidates,
  not new live failures. Covered/inherited owners and exact source provenance:
  [Retail notification audit](RETAIL-NOTIFICATION-AUDIT-20261031.md).
- Developer confirms the local vehicle correction fixed and found Player/Pet
  frame previews in Advanced Options. Unit-frame configuration follow-up resolved
  through native UI. New reporter package `beta.24-retail-test.2` includes all
  three fix areas; 68 suites and extracted-package validation pass. Premade Groups
  reporter confirmation and broader action/combat/taint checks remain pending.
- Local override candidate visual retest: developer says the bar appears fixed;
  supplied images show it bottom-centered on Mainhand. Remaining unit-frame
  placement should be tested via native Edit Mode after exiting the vehicle.
  Blizzard swaps PlayerFrame to vehicle and PetFrame to player, so both positions
  must be checked. Actual ability/exit actions and combat/taint pass remain pending.
- Vehicle follow-up reproduced locally in an Ulduar Salvaged Chopper: Retail
  build 70688, 4000x2560 portrait-left/right-landscape setup, combat=0.
  OverrideActionBar shown at 1059/0/930/100 UIParent units, overlap=both. Source
  candidate now adopts the stock override root through the existing secure
  anchor writer, prepares Mainhand bottom placement out of combat, restores
  still-owned stock anchors on disable/unspan and yields to custom owners.
  All 68 Lua suites and six-manifest checks pass; three modules deployed locally
  with backup/hash verification. Candidate visual/action/taint retest pending.
  Details: [context UI audit](RETAIL-CONTEXT-UI-AUDIT-20261031.md).
- Additional pre-test reporter /fstack screenshot independently confirms
  `LFGListApplicationDialog` and its Border, with source
  `Interface/AddOns/Blizzard_GroupFinder/Mainline/LFGList.xml:1945`.
  Reporter narrows reproduction to Premade Groups > Dungeons sign-up and says
  regular Dungeon Finder appears correct. This matches the test package's target;
  it is not a post-package result. Reporter confirmation remains pending.
- Reporter follow-up identifies Premade Groups application-role and invitation
  dialogs across the physical seam. Diag: Retail 12.1.5 build 70688, Interface
  120105, addon Beta 24, Companion Beta 20/MATCH, 3840x1080, equal displays,
  Mainhand RIGHT, effective scale 0.700, combat=0. These are distinct from the
  previously handled LFGDungeonReadyPopup. The diag snapshot has PVEFrame hidden;
  Extra Action is inactive, so this does not reproduce a vehicle problem.
- Candidate adds native-stack-aware placement and diagnostics for
  LFGListApplicationDialog/LFGListInviteDialog, without native script/field writes
  or generic drag/persistence. All 67 Lua suites and six-manifest validation pass.
  Four modules deployed to local Retail and hash verified, with installed syntax
  validation. Backup: `D:/Games/World of Warcraft/_offhand_deploy_backups/retail-premade-dialogs-20261031-170648-665`.
  Live sign-up/note/accept/decline, stack, restoration and taint retests pending.
- Local visual retest after deployment: developer reports the new-character intro
  appears resolved. Two 4000x2560 screenshots show Mainhand-confined picture,
  one-/two-line subtitles/backgrounds and the native skip confirmation. Visual
  PASS for this scenario; standalone movie, button activation, restoration and
  combat/taint evidence remain unrecorded. Dungeon/vehicle investigation remains open.
- Developer subsequently reproduced the new-character cutscene failure locally;
  the 4000x2560 dwarf-intro screenshot also shows subtitles outside Mainhand.
  It does not establish skip-dialog visibility or key receipt. A source candidate
  now extends native dialog recovery to Retail and PLAY_MOVIE, without changing
  input/confirmation ownership. The Retail presentation candidate also confines
  cinematic/movie/subtitle roots to Mainhand, corrects camera aspect bounds and
  limits subtitle widths. All 65 Lua suites and six-manifest Lua 5.1 validation
  pass. Candidate live/taint and subtitle retesting remain;
  no installed addon was updated.
- Report received 31 October 2026 via the developer from Discord. Retail is
  suspected; exact client/build, addon release, topology and diagnostics pending.
- Original source finding: native skip-dialog recentering was gated to Forever,
  including on committed main. Blizzard's Retail dialogs default to full-window
  center. A displaced confirmation is plausible, but not reproduced on Retail.
  Standalone movies also need lifecycle coverage beyond CINEMATIC_START.
- Dungeon-ready prompts already have transient placement handling. Exact prompt
  identity, combat state, protection, settings and ownership need confirmation.
  Vehicle/override bars are separate from Extra Abilities and vehicle leave.
- Reporter output and candidate live/taint verification remain. No installed
  package update or release has been performed.
- Evidence and focused reproduction checklist:
  [Retail cutscene and contextual UI investigation](RETAIL-CUTSCENES-AND-CONTEXT-UI-20261031.md).

## OH-TBC-001: Reported out-of-memory crash during manual monitor spanning

- Report received 31 October 2026 via the developer, from a Discord user on TBC
  Anniversary. Exact build, addon release, exception text and hardware are pending.
- Reporter initially confirmed the crash occurs during window dragging. This
  first prioritized native resize handling and immediate display listeners;
  the subsequent bottom-control reproduction below broadens that assessment.
- Further clarification: edge dragging and Offhand's in-game bottom-offset +/-
  buttons both trigger severe FPS loss followed by the error. The button identity
  is confirmed by the developer. Each click immediately runs full layout and
  reapplies WorldFrame bounds, bypassing display debounce. Native window resizing
  is therefore not required for one reported trigger; the earlier native-resize
  priority is provisional. Test a single bottom-offset click with fixed native
  bounds and Offhand alone, recording the offset and FPS before/after.
- Source audit found the existing 0.75-second full-layout debounce and reused
  Mainhand anchor. Visible onboarding still schedules two short-lived callbacks
  per display/scale event; stale callbacks skip work but remain queued until due.
  Neither a leak nor the exhausted resource is established.
- All 63 existing Lua 5.1 suites pass on the current working tree. No native
  reproduction, behavior change, deployment or release for this report.
- Preserve the crash report and gx.log before relaunch, then compare identical
  manual resizing with all addons disabled and Offhand alone. Ordinary diag
  output cannot distinguish Lua memory, process commit and GPU allocation.
- Investigation, source scope, evidence request and comparison matrix:
  [TBC manual-span OOM](TBC-SPAN-OOM-20261031.md).

Local deployment, 27 October 2026: The working candidate on
`codex/professions-quest-ui` was copied into Offhand under
`C:/Games/World of Warcraft/_anniversary_/Interface/AddOns` and
`D:/Games/World of Warcraft/_retail_/Interface/AddOns` at the user's request.
Each installation changed 39 files; 72 source files per client were hash-checked.
Existing CompanionTopology.lua and ForeverState.lua were preserved byte-for-byte.
Both installed copies passed six-manifest/path/XML and Lua 5.1 syntax validation.
Backups and deployment record: `dist/local-deployments/20261027-2a4302c0/`.
This is a local test candidate retaining Beta 23 metadata, not a published release
or an in-game validation result. The shelved keyboard candidate is not included.

Local deployment, 28 October 2026: Extra Abilities recovery and Retail interaction
drag/anchor settlement changes copied to both authorized addon installations.
Fifteen files per client were hash-verified; generated bridges remain unchanged.
Backups and record: `dist/local-deployments/20261028-f2cac84c/`.
All 60 Lua suites pass, all six manifests and Lua 5.1 syntax validate, and live
acceptance remains pending. Beta 23 metadata and Companion binaries are unchanged.

## OH-UI-009: Crafting panel plays its opening sound but is not usable

- Developer evidence, 28 October (second test): Extra Abilities recovery repaired
  the bucket anchor; profession placement and drag release now behave correctly.
  After Gather Safe UI to Mainhand, reopening Professions again played sound and
  activated its button without a visible window. The new screenshot identifies
  **ProfessionsBookFrame=shown,alpha=1.00,bounds=unresolved**, while ProfessionsFrame
  is absent. This is Retail's standalone profession list, not its crafting root.
  Correction from the developer's subsequent settings screenshot: Lock selected
  Offhand windows open was unchecked, but independent panels, Escape persistence
  and reload persistence were enabled. The lock is a separate setting; its
  unchecked state does not disable those enabled persistence options. The earlier
  diagnosis attributing missing reload reopening to the unchecked lock was wrong.
  Supported standalone panels should restore with these settings when their open
  snapshot and loader are valid. Unnamed other protected panels have not been
  identified and cannot yet be assigned a reload policy.
- Candidate correction: The standalone Retail book now retains native UIPanel
  registration during workspace movement without being classified as an
  interaction-bound crafting session. Gather restores any native registration
  previously detached by Offhand before protected-panel eligibility and anchor
  placement, so a protected descendant does not strand a previously managed
  menu. Context-bound crafting and NPC registration remains untouched. Recovery
  transfers saved ownership to Mainhand without a synthetic hide/show cycle.
  This closes a source gap consistent with the observation; live confirmation
  of the shown-but-unanchored failure and its prevention is still pending.
- Retail book reload owner: ProfessionsBookFrame resolves to
  `Blizzard_ProfessionsBook`, including correction of the historical
  `Blizzard_Professions` learned owner. Forever routing remains unchanged.
  Standalone book reopening is permitted only when the existing persistence
  settings and open snapshot request it. Crafting roots continue to retain
  position without automatically reopening a dead trade-skill interaction.
  Source inspected: [Retail book bootstrap](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ProfessionsBook/Blizzard_ProfessionsBook_Bootstrap.lua),
  [book template](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ProfessionsBook/Blizzard_ProfessionsBook.xml).
- Regression evidence: All 60 suites pass, including native registration on a new
  workspace drop, recovery from the former detached registry state after the root
  gains protected descendants, Mainhand transfer, subsequent native reopen and
  corrected Retail versus unchanged Forever load ownership. Native live, taint
  and cold-reload acceptance remain pending. Retest book movement, Gather Safe
  UI, close/reopen, and reload with persistence deliberately enabled/disabled.
  Both local installations received these five changed Core modules, hash-checked
  against source; generated bridges were preserved. Backups and deployment record:
  `dist/local-deployments/20261028-0e3fed16/`. Candidate retains Beta 23 metadata.
- Developer follow-up, 28 October 2026 (Retail investigation): First native open
  centers correctly on Mainhand. A drop on Offhand initially works, but reopening
  moves the root to Offhand's top-left. Subsequent opens and reload retain that
  anchor. Dragging back to Mainhand can leave the frame following the cursor
  until reload; the next opening uses the last cursor position. The exact native
  event sequence producing the stuck gesture has not yet been captured.
- Candidate correction, 28 October: Retail interaction panels now observe native
  root anchor resets and coalesce saved-position restoration after that pass.
  Repair state is held in a private weak table; restoration yields during drags,
  combat, hidden state and disabled state. Ordinary restore callbacks also yield
  during an active drag. A UIParent-owned release watcher runs only during an
  Offhand-started Retail interaction drag and finishes it when LeftButton is
  released, even if the native title no longer sends OnDragStop. It pauses during
  combat and detaches its OnUpdate when idle. Drag finalization stops an owned
  native move before policy early returns, while retaining combat restrictions.
  No replacement native scripts, forced profession reopening or interaction
  close/show cycle is introduced.
- Regression evidence: Simulated Retail Professions drop on Offhand, native
  close/reopen, later top-left anchor reset, exact saved-coordinate restoration,
  drag back to Mainhand with a pending repair, release without OnDragStop,
  saved Mainhand reopen, native registration and interaction lifetime all pass.
  This supports the prevention paths, not confirmation of the live root cause.
  Retest the developer's three-step sequence after reload, including both title
  and frame drag surfaces, rapid close/reopen, and current Lua/taint logs.
- Status: Source defect reproduced in simulation and prevention implemented on
  `codex/professions-quest-ui`. All 56 Lua suites and six manifests pass; Lua 5.1
  syntax checked. Reporter reproduction and protected-action live QA pending.
- New CurseForge report: Professions makes an opening sound but cannot be found
  while Offhand is enabled. Client family/build, addon version, display topology,
  profession root, replacement addons and original settings are not yet known.
  This report is independent of the shelved keyboard investigation, whose
  candidate is preserved on `codex/login-input-restoration` at `ab45f40`.
- Confirmed source defect: Moving a saved crafting root onto the workspace could
  remove its UIPanel metadata and run the generic HideUIPanel/direct Show cycle.
  The native Retail Professions OnHide closes its player interaction, trade-skill
  session and crafting orders. This is a lifecycle failure path in addition to
  possible off-screen placement; the report alone does not distinguish them.
  Source inspected: [Blizzard Professions frame source mirror](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Professions/Blizzard_ProfessionsFrame.lua),
  `ProfessionsMixin:OnHide`. The moving live branch is supporting source evidence,
  not proof of the unknown reporter's exact build.
- Prevention: ProfessionsFrame outside Forever, TradeSkillFrame, CraftFrame and
  ProfessionsCustomerOrdersFrame are interaction-bound. Generic workspace
  movement retains native panel registration and skips hide/show eviction;
  reload restoration does not reopen these shells without their native session.
  Saved geometry remains available on later native openings. Forever's isolated
  standalone ProfessionsFrame book continues to support its existing explicit
  reload-open persistence. The demodalization guard also preserves other already
  classified interaction panels' native registration.
- Regression evidence: Before the change, moving a mocked Retail crafting frame
  triggered its OnHide. Afterward it remains open without a synthetic close,
  retains the same UIPanel registration, restores position on the next native
  open and refuses a standalone reload-open request. Existing Forever book,
  Flight Map and Auction House cases still pass.
- Live QA: Obtain `/offhand diag full` immediately after attempting Professions,
  client/build and addon version. Test cold first open, close/reopen, tabs,
  selecting another profession, crafting and orders, workspace drag, reload and
  return to Mainhand. Include current taint/errors and the user's panel addons.
  If shown outside the displays, test each gather action separately outside
  combat. Never show the crafting shell directly as a recovery measure.

## OH-UI-010: Hallow's End water action button missing with Offhand

- Recovery gap addressed in candidate, 28 October 2026: Retail Recovery & Preview
  now exposes **Recover Extra Abilities**. The player-click transaction repairs
  ExtraAbilityContainer's serialized Edit Mode system, including a customized
  system-relative anchor, to bottom-center within Mainhand. The existing protected
  HUD repair path handles ExtraActionBarFrame and ZoneAbilityFrame candidates
  through the same system. Existing generated-layout systems are copied unchanged
  except Extra Abilities, preserving unrelated edits and avoiding a second span
  translation. Missing systems fail without saving. Combat, external controller
  ownership, API and Edit Mode-open guards remain in force. No protected button
  is directly shown, moved, reparented or rescaled; native availability still
  determines whether its icon appears. Reload/manual selection uses the existing
  layout confirmation workflow. New strings exist in all 11 dictionaries, with
  explicit English fallback pending translation in non-English locales.
- Regression evidence: Customized system-relative Extra Abilities recovery,
  unrelated generated edits, repeated repair without anchor drift and missing
  system failure without saves pass in simulation. Native protected-action,
  reload, water-button use and zone-ability live acceptance are still pending.
- Status: Investigation; developer-provided local Retail screenshots identify
  an extra-action water button that remains visible while spanned. The original
  reporter's quest, client and failing UI state are still unconfirmed. No
  protected action-button placement or visibility workaround implemented.
- Report: The same new reporter cannot see the throw-water icon during the
  Hallow's End quests with Offhand enabled. This could mean a quest-tracker item
  button, an extra/zone ability or an override action depending on the client
  and quest. Do not infer the frame from the holiday name alone.
- Local evidence, 27 October 2026: The developer supplied a Retail test at the
  Goldshire water barrel and burning training targets, on Nearlytwenty. The
  bucket button is visible above the main action bar in the ordinary window
  and on the lower-right Mainhand of a 4000x2560 mixed-height spanned screenshot.
  The latter shows the chat message naming the loaded character layout
  `Offhand - Mainhand - Nearlytwenty`. This confirms successful visible placement
  in that local state, not successful use of the action or reproduction of the
  reporter's disappearance. The exact quest title/build is not visible.
  The supplied frame stack includes ExtraActionButton1, ExtraActionBarFrame and
  ExtraAbilityContainer, establishing the local control family. TimerTracker is
  the selected stack entry; the displayed anchors and Timer.xml source belong
  to that selected frame, so they are not bucket-button geometry evidence.
  Keep this developer observation distinct from the reporter's missing-icon
  report; no reporter confirmation has been received.
- Further local evidence, 27 October: On TBC Anniversary the developer received
  Water Bucket as a clickable backpack item, not the Retail extra-action control.
  This makes Retail the stronger current hypothesis for the original report's
  missing throw icon, but the original reporter's client remains unconfirmed.
  The Anniversary screenshots separately expose tooltip-backdrop and tracker
  problems, tracked as OH-UI-011 and OH-UI-012 below.
- Investigation continued, 27 October: Treat Retail's extra-action path as the
  working scope based on the developer's client comparison. The reporter has
  still not confirmed a client or supplied a failing snapshot. Reviewed
  [native extra-action lifecycle](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ActionBar/Shared/ExtraActionBar.lua)
  and [container lifecycle](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIPanels_Game/Shared/ExtraAbilityContainer.lua).
  Native action availability drives bar animation and container registration;
  the container shows when it holds a registered action or Edit Mode is open.
  Offhand's generated layout already places the Extra Abilities system above
  the main action bar. Current review has not established a new direct Offhand
  visibility defect, so no forced Show, alpha, reparent or anchor repair is added.
  These moving source mirrors are supporting evidence, not the reporter's build.
- Targeted Retail evidence: `diag full` additionally records native extra-action
  availability, parent and first anchor for the container/bar/button even when
  hidden, icon effective alpha and the active Extra Abilities serialized anchor.
  This distinguishes inactive quest state, parent visibility, transparent art
  and custom system-relative placement. Each probe fails independently and all
  are skipped during combat and on other client families. No native layouts,
  frame fields, handlers or visibility are modified. Simulation covers a hidden
  container with an available action, custom layout anchor, zero icon alpha,
  inactive action, forbidden frames, missing capabilities and combat deferral.
  Local deployment: updated `Core/HUDRecovery.lua` in both authorized installs;
  source/installed SHA256 matches and both generated bridges are unchanged.
  Previous files and record: `dist/local-deployments/20261027-9394f3d8/`.
  All 60 Lua suites pass; six manifests and Lua 5.1 syntax validate. This remains
  an unpublished Beta 23 test candidate, with missing-button live QA pending.
- Professions review: The existing OH-UI-009 candidate still preserves native
  interaction lifetime when moving crafting panels and passes its regression.
  Runtime crafting and orders acceptance remain pending; extra-action evidence
  does not establish that the two reported symptoms share a cause.
- Source findings: Extra abilities participate in supported Edit Mode layout
  generation and the protected HUD recovery registry. Generic panel gathering
  deliberately excludes protected/Edit Mode HUD controls. There is no dedicated
  legacy override-action relocation in SeamRedirect's ordinary action-bar list.
  These are coverage boundaries, not proof of which path failed for this player.
- Evidence added: `/offhand diag full` now reads a bounded set of profession,
  extra-action, zone-ability, override-bar and quest-tracker roots/buttons. It
  distinguishes absent, hidden, parent-hidden, forbidden and uninspectable
  frames, and prints effective alpha and UIParent-space bounds when available.
  Rectangle overlap against Mainhand and workspace distinguishes off-screen
  roots from visible-display placement. A partial overlap does not prove that
  the interactive child itself is reachable. Combat reports defer inspection.
  No buttons are shown, moved, reparented or given addon state by this probe.
- Automated evidence: Tests cover physical-void placement, scale conversion,
  both-display overlap, absent/hidden/parent-hidden controls, forbidden frames,
  unresolved bounds and combat deferral. Compact `/offhand diag` remains concise;
  the extra evidence is opt-in through `diag full` only.
- Next report: Obtain exact quest name, client/build, Offhand version, action-bar
  and quest-tracker addons, a screenshot and `diag full` while holding water and
  the icon is missing. Compare with Offhand disabled after reload in the same
  quest state. If using Edit Mode, inspect its Extra Abilities preview outside
  combat without resetting a custom layout. Do not assume either gather button
  can recover protected action controls, and do not reset SavedVariables.

## OH-UI-011: TBC Anniversary item tooltip text has no visible background

- Status: Developer-reported visible defect; cause unconfirmed. No backdrop
  repair applied. Read-only evidence added to the local candidate's `diag full`.
- Evidence: The local Anniversary Water Bucket tooltip shows title, item type,
  unique flag and use text over the open backpack, with no visible tooltip
  background or border. The developer reports no other addons that could cause
  this conflict. Do not attribute it to a third-party addon or treat this local
  observation as the original CurseForge user's report.
- Source review: Offhand redirects item-tooltip owner anchors and normalizes
  tooltip scaling. It does not explicitly hide or recolor NineSlice backgrounds.
  The Anniversary native template uses NineSlice for the backdrop, and native
  style handling can intentionally hide it for embedded tooltips. Forcing Show,
  alpha or a replacement backdrop without identifying the state could interfere
  with that contract. Native source reference:
  [Anniversary shared tooltip templates](https://github.com/Gethe/wow-ui-source/blob/classic_anniversary/Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.lua).
- Evidence added: `diag full` reports the primary/reference/comparison tooltip
  and NineSlice shown state, effective alpha, strata, frame level, embedded flag
  and background center alpha. Inspection is guarded and deferred during combat;
  no background state, layout, ownership or appearance is changed by the probe.
- Automated evidence: Read-only diagnostics cover an opaque visible tooltip with
  a hidden transparent backdrop, embedded tooltips, missing/forbidden frames,
  failed inspection and combat deferral. Compact diagnostics remain unchanged.
- Next local QA: Using the candidate, capture the tooltip presentation lines
  while hovering a backpack item, and repeat for an equipped item and comparison
  tooltip. Record the exact Anniversary build and Offhand release. Compare the
  same item with Offhand disabled after reload and in single-screen mode. If the
  backdrop reports shown with normal alpha, inspect NineSlice frame-stack
  layering and rectangle before selecting a repair. No live result yet.
- Follow-up local result: Both objectives and tooltip backgrounds appear after
  Companion window restore, but both issues persist while spanned. The supplied
  full report has all four tooltip roots hidden. Their shown, opaque NineSlice
  entries are therefore hidden-parent state, not evidence of the visible
  item's backdrop. The candidate now arms one diagnostic hover capture for
  30 seconds after `diag full`, printing after the next primary tooltip's native
  show turn settles. Root/backdrop effective scale and UIParent-space bounds are
  also included. The capture expires, does not run on ordinary hovers, and is
  suppressed in combat. No tooltip appearance repair is claimed.
- Subsequent hover capture: The issue persists while spanned. The hovered root
  and NineSlice both report shown, alpha 1, center alpha 1, TOOLTIP strata and
  level 1, at effective scale 0.394 and matching UIParent-space rectangles around
  `2817/70/222/63`. The screenshot visibly puts text over the workspace backpack;
  the reported rectangle is instead near the full canvas's right edge. This
  supports an anchor/render-placement mismatch rather than a hidden/transparent
  backdrop, but native engine behavior remains to be verified. Classic now keeps
  native ANCHOR_LEFT/ANCHOR_RIGHT owner placement and skips the Retail manual
  ANCHOR_NONE/root SetPoint/comparison-root path. Retail and Forever retain their
  existing behavior. Regression coverage checks the Classic direct/default-anchor
  paths never enter manual root placement. Candidate copied to both local clients;
  actual rendering acceptance is pending.
- Local acceptance update: After closing/reopening the backpack, the developer
  observed the tooltip background return and persist across reload. The supplied
  spanned screenshot shows a correctly aligned opaque Water Bucket tooltip on
  the workspace. This confirms that local Anniversary case after the Classic
  native-anchor change; broader item/comparison/client coverage remains separate.
- Acceptance withdrawn by subsequent local evidence: With the backpack over
  Character, Wild Hog Shank shows a full card, while Hearthstone has text and
  a narrow vertical border strip without a correctly sized background. The
  developer reports that success depends on backpack position, item column and
  nearby UI. The earlier backpack-reopen/reload result was only a successful
  state, not a reliable resolution. This issue remains open.
- Latest isolation candidate: Classic no longer receives Offhand tooltip-owner
  direction changes, manual root/comparison placement, forced scale or forced
  parent-scale policy. Its native tooltip transactions remain untouched on both
  workspace halves; read-only hover diagnostics remain available. Retail and
  Forever retain their prior confinement/scaling path. Native tooltip placement
  or size may differ from the earlier confinement candidate. This tests the
  suspected interaction between direction/scale changes and native backdrop
  sizing without asserting a confirmed engine cause. A new Anniversary regression
  failed on scaling-hook installation before the change; afterward it passes
  with all 59 Lua suites and six manifests. PopupBounds.lua and Init.lua were
  backed up and hash-verified into both authorized local clients.
- Next acceptance check: After reload, hover every occupied backpack column with
  the bag on both workspace halves, first alone and then overlapping Character.
  Repeat moving the bag across the workspace center, close/reopen, and reload.
  Check primary and comparison card text/background alignment. No live acceptance
  is recorded for this newest candidate.
- Latest local result: The developer now confirms correct quest objective
  placement and visible backpack tooltips. The supplied screenshot shows an
  intact Handful of Candy card crossing from the workspace into Mainhand when
  the backpack is close to the seam. The prior native-ownership/scaling isolation
  is retained; the remaining defect is physical-display confinement.
- New confinement candidate: On Classic only, temporarily extend the native
  tooltip clamp rectangle to reserve the portions of the window outside the
  workspace. Preserve the native original clamp insets and restore only state
  still owned by Offhand on hide or transfer to a Mainhand owner. This changes
  engine clamping, not owner, direction, anchor graph, dimensions, background or
  scale. Comparison cards resolve their actual item owner through the primary
  tooltip. Embedded, inactive, disabled, unavailable and oversized cases yield;
  combat restoration is deduplicated and re-evaluated after combat. Insets are
  included in the existing opt-in presentation report. API reference:
  [Blizzard Anniversary SimpleFrame API declarations](https://github.com/Gethe/wow-ui-source/blob/classic_anniversary/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua).
  All 60 Lua suites and six manifests pass. Tests verify left/right geometry,
  effective scale, no owner/anchor/scale writes, native-state restoration,
  comparison ownership and combat deferral. PopupBounds.lua was backed up and
  hash-verified into both authorized clients. Visible confinement and intact
  text/background rendering near every workspace edge still need local QA.
- Local follow-up: Tooltip cards now respect the workspace border, but the
  developer observes a brief appearance at Mainhand's upper-left anchor before
  final placement. Confinement is locally accepted; transition rendering remains
  open. The candidate previously set clamp policy from OnShow/OnSizeChanged.
  It now observes the completed native SetOwner call to prepare only the clamp
  policy before content/show, without resetting the owner, changing direction,
  applying root points, scaling, visibility changes or deferring placement to a
  timer. Hidden tooltips are prepared from owner/display geometry without reading
  their stale content rectangle; visible sizing still checks oversized cases.
  A regression failed before this change and now verifies pre-show preparation,
  exactly one native owner call and no first-show/hidden-size policy churn.
  All 60 suites and six manifests pass. PopupBounds.lua was backed up and
  hash-verified into both authorized local clients. The brief native render
  transition still needs the developer's visual confirmation.

## OH-UI-012: Classic tracked quests can remain above a shorter Mainhand

- Status: Source positioning gap reproduced in simulation; candidate implemented
  on `codex/professions-quest-ui`. All 58 Lua suites and six manifests pass with
  Lua 5.1 syntax checked. Native layout, combat/taint and persistence QA pending.
- Evidence: The developer's Anniversary screenshot shows a 4000x2560 mixed-height
  span with Mainhand at the lower right, a correctly visible Minimap, and no
  visible quest tracker beneath it. Whether an active quest is tracked in that
  exact image is not established by the screenshot alone.
- Source gap: Anniversary's WatchFrame is parented to the right managed frame
  container. Native `EditModeUtil:GetRightContainerAnchor` uses UIParent TOPRIGHT,
  and the panel manager reapplies that full-window anchor. Offhand previously
  accounted for the Minimap but not this container, allowing the tracker to
  remain above the shorter physical Mainhand. Source references:
  [Anniversary Edit Mode utility](https://github.com/Gethe/wow-ui-source/blob/classic_anniversary/Interface/AddOns/Blizzard_EditMode/Shared/EditModeUtil.lua),
  [WatchFrame template](https://github.com/Gethe/wow-ui-source/blob/classic_anniversary/Interface/AddOns/Blizzard_UIPanels_Game/Wrath/WatchFrame.xml).
- Candidate: Translate only the native right-container root anchor onto Mainhand,
  preserving native offsets and effective scale. Observe completed native
  container reflows instead of adding handlers/state to WatchFrame or its
  interactive descendants. Combat work is deduplicated and queued. Disable,
  single-screen and HUD-redirection-off restore the last native anchor only
  while it remains Offhand-owned. Custom root anchors, user-placed trackers,
  controller ownership, Retail, Forever and original Wrath are excluded. The
  probe also includes the managed container in full visibility diagnostics.
  No tracker visibility, tracked quests, parent, child anchors or scale changes.
- Automated evidence: Full-span versus Mainhand positioning, non-unit scale,
  native reflows with changed offsets, no-op repeat updates, combat deferral,
  disabled/single-screen/client/controller gating and external-anchor ownership.
- Live QA: Explicitly track a known active quest first. Test quest progress,
  track/untrack, collapse/expand and item actions outside and during combat;
  inspect fresh taint and protected-action errors. Test login, reload, window
  restore/re-span, left and right Mainhand, UI scale, custom tracker positioning
  and long lists. Native container height/layout remains Blizzard-owned, so long
  lists and clipping require particular attention. Do not infer taint safety or
  actual missing-tracker recovery from the simulation alone.
- Corrected client model: The first installed candidate did not recover the
  local spanned Anniversary tracker. Its full report explicitly shows WatchFrame
  absent; the right managed container partially overlaps Mainhand, which does
  not establish that its top or tracked entries are reachable. Installed client
  executable metadata is 2.5.6.70577. Anniversary's TBC QuestLogFrame.xml defines
  QuestWatchFrame with UIParent as its parent and the right container as its
  template's layoutParent. The earlier direct-child WatchFrame model described
  the Wrath template and was insufficient for this client. The guard now accepts
  QuestWatchFrame and its native layout registration as well as direct WatchFrame
  children. A TBC-specific regression failed before and passes after this change.
  Full diagnostics now include QuestWatchFrame. Reference:
  [Anniversary TBC quest tracker template](https://github.com/Gethe/wow-ui-source/blob/classic_anniversary/Interface/AddOns/Blizzard_UIPanels_Game/TBC/QuestLogFrame.xml).
  The corrected candidate and one-shot tooltip capture were copied into both
  previously authorized local clients, with previous versions of the four
  changed files backed up under `dist/local-deployments/`. All 58 suites and six
  manifests pass; actual spanned recovery still awaits the next local test.
- Subsequent local result: Still no tracker while spanned. QuestWatchFrame is
  shown and opaque at `2921/1778/122/39`, outside the physical displays. The right
  container is at `2921/73/122/1685`; its partial Mainhand overlap did not recover
  the tracker at its top. The native-layout test now covers a direct container
  SetPoint reset outside the public delegate transaction. The candidate observes
  only that root method with an addon-owned weak registration table and guarded
  re-entrancy; the prior shared dispatcher method hook was removed. No native
  child hooks or addon fields are installed. `diag full` adds Classic tracker
  placement status, root point count/anchor, parent registration and user-placed
  flags to expose eligibility failures or anchor overwrites without another
  inference from partial bounds. Combat deferral and external ownership remain.
  All 58 suites and six manifests pass. Three changed runtime files were backed
  up and hash-verified into both authorized clients; native acceptance and fresh
  protected-action/taint checks are still pending.
- Local acceptance update: The objectives now appear while spanned, confirming
  the root reset correction reaches the local Anniversary tracker. The new
  screenshot shows the quest title and objective crowding the Minimap's lower
  edge. A spacing refinement now bounds the managed root against the live
  MinimapCluster lower edge with a 12-UIParent-unit gap, including any positive
  tracker header offset above the container. It converts effective scales,
  preserves native horizontal clearance and reads Minimap geometry after HUD
  placement. Hidden or workspace-only Minimap positions do not displace the
  Mainhand tracker. Tests cover changed Minimap bounds, unequal scales, header
  protrusion and repeated updates without cumulative downward drift. All 58
  suites and six manifests pass. MainhandCompatibility.lua and SeamRedirect.lua
  were backed up and hash-verified into both authorized clients; the spacing
  refinement still needs visible in-game confirmation.
- Local acceptance: The developer reports the objective list now looks correct
  while spanned. The new screenshot places the quest title and objective below
  the Minimap with clear separation. This accepts the visible local placement;
  long-list, other-topology and protected-action matrix checks remain separate.

## Current acceptance, 25 October 2026

Integration update: all post-v22 addon performance sources are merged into
`addon/develop` (`4a7b200`), including the separately accepted PR #37 CPU fix.
Companion VSync/graphics recovery and graininess sources are committed and
reconciled on `companion/develop` (`8e9b925`). See
`POST-V22-INTEGRATION-20261025.md` for the inventory and evidence boundaries.
This supersedes earlier source-missing/draft-only descriptions without changing
the recorded live acceptance or deferred Forever testing.

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

### 2026-10-25: Accepted addon work integrated; performance investigation isolated

- PR #34 (structural refactor) and PR #35 (UI/setup/HUD/menu stabilization) are
  merged into origin/addon/develop. GitHub required checks passed. The known
  CloseAllWindows local bag-provider defect is included with a red/green regression.
- Integration commit: d197f8ded46ef1022c219d47d3748c116b9b36eb.
- User acceptance closes the listed Gamepad/Bagnon/Party/Dialogue UI/pet-battle
  items; historical incomplete QA notes remain evidence history, not reopened work.
- Linux/Wine is assumed fixed with direct Linux-user verification outstanding.
  Native experimental source remains isolated under the combined Companion plan.
- Performance branch codex/addon-performance-audit contains the small idle bag
  allocation candidate, expanded regression, temporary standalone observer and
  docs/ADDON-PERFORMANCE-20261025.md. 55 Lua suites and six manifests pass.
  Synthetic allocation savings do not establish a live CPU/FPS or stutter fix.
- Main/public release, website, game installations and frozen Companion unchanged.

## OH-UI-013: Missing-only recovery and confirmation before layout changes

- Requested 28 October 2026: Recover missing UI without disturbing the current
  visible layout; explain recovery scope and unintended-layout risk. Confirm
  existing broad recovery actions before they execute.
- Candidate: Recovery & Preview and Help now expose Recover Missing UI. Any
  nonzero overlap with either physical display counts as visible, including
  partially clipped or seam-crossing roots. Such elements receive no recovery
  anchor or saved-position changes. Shown, completely off-screen or unanchored
  supported windows can move to Mainhand. A hidden loaded standalone window can
  reopen only with saved workspace-open intent and native UIPanel registration.
  Hidden bags, NPC/crafting interactions, untracked dormant windows, parent-hidden,
  forbidden and unsupported roots are not forced open. A hidden standalone window
  also yields if another native UIPanel slot is occupied, preventing reflow of a
  visible panel. Ordinary visible bag snapshots are not reset by this action.
- HUD scope: Bounded native Extra Abilities, Minimap, Objective Tracker, Player,
  Party, Raid and main action bar systems are eligible when their shown root is
  completely off-screen/unanchored. Hidden Extra Abilities is eligible only when
  the native extra action is available. Other dormant HUD systems stay hidden.
  Feature-detected enums and indices, current client capabilities, controller and
  known replacement ownership determine support. Native frames are not force-shown
  or reparented. Oversized/uninspectable roots yield. Selected systems are repaired
  through one serialized Edit Mode transaction, copying the currently active layout
  and preserving all other entries without translating or refining them again.
  Missing systems abort layout saving. Combat and open Edit Mode block execution.
- Confirmation: Missing-only recovery presents its scope and overlap/adjustment
  disclaimer. Gather Safe UI to Mainhand, Create Mainhand HUD Layout and Recover
  Extra Abilities each present action-specific warnings before execution. Cancel
  and Escape do nothing. An accepted callback is consumed once; state is inspected
  at acceptance rather than using a stale pre-confirmation snapshot. Native HUD
  activation/reload prompts still follow the accepted recovery transaction.
- Player strings exist in all 11 locale dictionaries, with English fallback for
  the new messages until translated. The broad gather description accurately
  describes the currently supported visible Offhand windows and excludes protected
  HUD systems; it does not claim to gather all Blizzard frames.
- Automated evidence: All 61 Lua suites pass. New coverage includes physical voids,
  partial overlap, hidden/forbidden/unanchored frames, tracked safe reopening,
  occupied native slots, native extra-action availability, visible HUD preservation,
  combat deferral, selective active-layout edits and single-use confirmation.
  Six-manifest/path/XML and Lua 5.1 syntax validation pass. Live UI layout, native
  protected actions, taint, reload, Classic and Retail acceptance remain pending.
- Local deployment: 22 source files per authorized Anniversary/Retail installation
  were hash-verified; generated CompanionTopology/ForeverState bridges were
  preserved. Backups and deployment record:
  `dist/local-deployments/20261028-6b733071/`. Beta 23 metadata retained.

## OH-UI-014: Retail map opening coincides with graphics recovery and lost span

- Reported 28 October: map opening appeared to restore the window or game/UI area.
  No recovery button was needed. A later re-span restored normal map behavior.
- Read-only native observation establishes an actual 2114x1353 window retaining
  the old 4000x2560 clipping region. A subsequent observation confirms successful
  re-span to window/client 4000x2560. The same graphics log records two
  DXGI_ERROR_DEVICE_REMOVED / 0x887A0001 faults followed by GxRestart DeviceRecovery;
  the first explicitly restores rendering to 2114x1353. This explains the immediate
  failure mechanism, but the initiating fault and map/addon causality are unknown.
- Evidence and source review: [map reset investigation](MAP-SPAN-RESET-20261028.md).
  No product map, graphics or Companion behavior was changed. Existing temporary
  display-probe source gains opt-in native map-event and frame-geometry capture;
  it has not been installed in the running client. All 61 Lua suites and probe
  Lua 5.1 compilation pass; native event and taint acceptance remain pending.

## OH-UI-015: Retail spellbook returns to Mainhand top-left after an Offhand drop

- Developer retest, 28 October: spellbook positioning appears corrected; profession
  positioning is also retained. Group Finder reflow and gather/Escape coverage
  are separate follow-ups, OH-UI-016 and OH-UI-017.
- Developer evidence, 28 October: After a fresh game launch the map/span failure
  did not reproduce. A separate spellbook placement problem remained: after an
  Offhand move, the window appears at Mainhand's top-left; Gather Safe UI returns
  it to Mainhand center. The supplied frame stack identifies PlayerSpellsFrame
  and its SpellBookFrame child. TimerTracker is selected, so its printed anchors
  are not spellbook-anchor evidence.
- Source gap: Retail PlayerSpellsFrame was not included in the native-registration
  preservation or saved-position anchor-reset observer used for the profession
  roots. Generic workspace demodalization could detach the registry required for
  out-of-combat positioning of its protected root; later native layout passes were
  not covered by its initial OnShow restoration. This is a source failure path
  consistent with the report, not live confirmation of every triggering native call.
- Candidate: Retail PlayerSpellsFrame now retains native panel registration and
  avoids synthetic slot eviction. The bounded private-state anchor observer repairs
  native SetPoint resets after layout settles, yielding during dragging, combat,
  hidden or disabled state. It uses the existing interaction/standalone-panel
  registration policy, preserving Forever handling and standalone reload eligibility.
  No native tab, minimization or show/hide script is replaced. The root also gains
  the existing Retail mouse-release fallback. Full diagnostics now include
  PlayerSpellsFrame and legacy SpellBookFrame visibility/geometry.
- Native source reviewed: [PlayerSpellsFrame](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_PlayerSpells/Blizzard_PlayerSpellsFrame.lua).
  Native tabs and minimize/maximize paths perform layout/lifecycle work. This
  moving source mirror is supporting evidence rather than the exact client build.
- Automated evidence: All 61 Lua suites and six manifests pass, including Lua 5.1
  syntax validation. A Retail protected-root regression covers saved Offhand drop,
  exact registration retention, native reopen, later Mainhand-top-left reset and
  return-to-Mainhand placement. Existing Forever spellbook tests still pass.
- Live QA pending: reload the candidate, move spellbook to Offhand, close/reopen,
  switch available tabs, toggle native minimize/maximize, and reload. Verify saved
  placement and normal spell controls. Also test gather and subsequent native open,
  with current Lua/taint evidence. Keep OH-UI-014 graphics-device recovery separate.
- Local deployment: three Core modules copied and hash-verified in both authorized
  installations; generated bridges preserved. Backups and record:
  `dist/local-deployments/20261028-037da268/`. Beta 23 metadata retained.

## OH-UI-016: Retail Group Finder oscillates between workspace and native anchors

- Developer report, 28 October: PVEFrame jumps between Offhand/Mainhand top-left,
  especially when opening another panel such as the spellbook. Supplied stacks
  show the PVEFrame, GroupFinderFrame and LFDParentFrame hierarchy. The selected
  TimerTracker anchor is not Group Finder geometry evidence.
- Candidate: Keep PVEFrame's native registration, manage only the verified outer
  root, and exclude descendant content from independent drag, restore and reload
  intent. Gather canonicalizes nested content to the root and deduplicates it.
  A root SetPoint observer still settles late layout writes, while post-hooks on
  native ShowUIPanel and UpdateUIPanelPositions restore its saved anchor at the
  end of each transaction before rendering. Synchronous settlement invalidates
  any already-queued retry. Drag/combat/hidden/disabled guards remain in force.
- Evidence: A simulated protected root retains its native registry, its nested
  content receives no separate movement owner, native reflow restores the exact
  saved Offhand point synchronously, and later settlement does not oscillate.
  Live repeat-opening, tab changes, native queue controls and taint checks pending.

## OH-UI-017: Gather and Escape coverage differ between panel families

- Cleanup-filter live retest: the developer reports Offhand windows remain open
  on Escape without a new Lua error after reloading. This accepts the reported
  out-of-combat scenario; active casting, combat, cold login, explicit X and the
  full panel matrix still need separate runtime coverage.
- Historical screenshot from the rejected registration build: blocked=22,
  session errors=2, last action Offhand: SpellStopTargeting(), observed roots all
  hidden. Repeated presses were generating blocked events despite no new visible
  error report. The shared Escape registry approach is rejected for both casting
  and targeting, and the temporary QA readout has been removed.

- Second live failure, 28 October: securecallfunction registration preserved the
  panels but still caused the initial SpellStopCasting forbidden action. Both
  registration variants are rejected. The absence of further visible reports on
  repeated Escape does not establish safety.
- Replacement under test: no shared Escape registration or retry loader. The
  captured native CloseAllWindows callback dynamically looks up CloseWindows;
  the candidate filters that later panel-cleanup boundary, preserving visible
  workspace roots without Hide/Show. Other close contexts, combat, reserved input,
  controller layouts, disabled persistence and unspanned mode retain native cleanup.
  Native casting, dialogs and menu fallback remain under the original dispatcher.
  All 62 suites and six manifests pass; live taint/combat acceptance is pending.
  Retail installed candidate is hash-verified; the temporary readout is removed.
  Anniversary still has the prior withdrawal. Record:
  `dist/local-deployments/20261028-cleanup-filter/`.

- Developer rollback retest: the protected SpellStopCasting error is resolved,
  but native panels now close on Escape again. This confirms the safety rollback
  and the loss of keep-open behavior; it does not close the persistence defect.
  Further source review confirms native CloseWindows closes active panel slots,
  including an unconditional doublewide close. A post-hide Show cannot preserve
  the crafting interaction, and the shared-dispatch registration remains
  withdrawn. No further speculative Escape interception was deployed in response
  to this retest. A safe replacement is still outstanding.
- Live safety failure and withdrawal, 28 October: The developer received
  ADDON_ACTION_FORBIDDEN for SpellStopCasting while pressing Escape with the
  professions panel on Offhand. The stack is in Blizzard's casting handler and
  securecallfunction dispatcher before the addon-priority callback. This is
  consistent with taint from the newly modified shared handler registry. The
  attempted dispatcher implementation described below is withdrawn, not accepted.
  Registration, retry loader and custom target/menu handling are removed from
  the candidate. No native Escape-registry, dispatcher or casting function is
  changed by the replacement. Native registration-dependent panels retain normal
  Escape behavior; UI text and diagnostics disclose unsupported protection.
  The new regression asserts the no-registration/no-loader boundary and unchanged
  native function identities, rather than treating mocked callbacks as taint
  safety evidence. All 62 suites and six manifests pass. A fresh reload is
  required to discard the contaminated running Lua session. Live retest pending.
- Developer report: Gather Safe UI moved some windows but omitted others; Offhand
  profession and crafting windows closed on Escape despite enabled persistence.
- Gather finding/candidate: The broad action only enumerated registered/tracked
  roots and established bag roots, omitting untracked movable top-level windows.
  It now also inspects movable UIParent children. It deduplicates Group Finder
  descendants to PVEFrame, retains native HUD/external/forbidden/protection guards,
  and counts eligible ownership exclusions rather than silently omitting them.
  The last gather report distinguishes moved, protected-unregistered, native
  HUD/Edit Mode, maximized-map, external/geometry ownership and placement failure.
  Hidden and already-Mainhand windows remain outside the broad movement scope.
- Escape finding/candidate: Retail's panel manager registers the original
  CloseAllWindows reference with the Game Menu Escape dispatcher before addons
  load. Replacing its global later does not intercept that captured reference.
  The candidate registers once at the native AddOn priority, after casting,
  dialogs and framework handlers. It keeps native workspace roots untouched,
  closes eligible Mainhand windows using native panel APIs, and then permits
  target clearing or Game Menu display without invoking the captured broad close.
  It does not hide/reopen crafting or profession shells, mutate native panel
  registration or replace native frame scripts. Capability installation also
  retries at login/relevant native module load, then unregisters its loader.
- Exceptions: Combat, controller UI, reserved input, disabled persistence,
  unsupported APIs and no supported native workspace root yield to native Escape.
  Explicit X/toggle closure remains native. Loss-of-control CloseAllWindows
  context is forwarded unchanged, and interaction roots are excluded from the
  old wrapper's close-then-show fallback. These distinctions matter for valid
  crafting/NPC sessions. The settings description now reflects native Escape
  support versus limited support on the current client.
- Full diagnostics expose root/content identity, registration, location, reload
  classification, persistence setting, installed Escape route and last gather
  outcomes within the existing panel-controller report. Combat inspection defers.
- Audit and QA matrix: [panel recovery policy](PANEL-RECOVERY-POLICY.md).
  All 62 Lua suites and six manifests pass; Lua 5.1 syntax checked. Simulations
  include the captured native callback, simultaneous workspace profession/crafting
  preservation, Mainhand closure, Game Menu and target behavior, explicit close,
  combat/loss-of-control exceptions, root deduplication, untracked gathering and
  skip reasons. Native visible behavior, protected actions and taint remain pending.
- Local deployment: 19 source files per authorized installation were hash-verified;
  generated bridges and the unrelated installed Init capacity callback were left
  intact. Backups and record: `dist/local-deployments/20261028-8fea66ca/`.
  Beta 23 metadata and Companion binaries remain unchanged.
- Withdrawal deployment: 13 files per authorized installation were hash-verified;
  generated bridges preserved. Backups and record:
  `dist/local-deployments/20261028-f9a7dcd1/`. The running client must reload before
  retesting; copying files cannot unregister or untaint its existing dispatcher.

## OH-UI-018: Retail Contacts return drag and standalone reload gaps

- Live status, 28 October 2026: developer confirms the Contacts issue is
  resolved after the content-root correction. The window can be moved without
  separating its contents. This closes the reported Contacts drag/content defect
  in the local candidate. Spellbook/profession reload acceptance is separate and
  was not confirmed by this report. No release promotion is implied.

- Developer report, 28 October 2026: FriendsFrame (Contacts) snaps to the bottom
  left of Mainhand when dragged back from Offhand. PlayerSpellsFrame and
  ProfessionsBookFrame do not reopen on Offhand after reload. Frame-stack captures
  identify these outer roots. The developer later corrected the chat report: ChatFrame1 does not retain
  Edit Mode placement after saving and closing. That issue remains separate.
- Contacts candidate: retain the Retail FriendsFrame native panel registration
  and use the existing native-root anchor/release adapter. Avoid the legacy
  detach/Hide/Show movement cycle. Social anchor repair now defers throughout a
  hardware drag, including immediate transaction and queued repair callbacks.
- Reload finding: RequestPersistentPanelLoad still rejected every non-Forever
  client, even though the Retail spellbook and standalone profession list were
  eligible and their correct addon owners were known. Allow these two Retail
  roots through the existing saved-open, saved-position and lifecycle guards.
- Reload candidate: when independent panels are enabled, show these initialized
  standalone menus without enrolling each in the shared native UIPanel slot.
  This prevents restoring one workspace menu from closing the preceding one.
  Native registration and scripts stay intact; crafting/NPC interaction roots
  remain excluded from synthetic reopening.
- Automated evidence: 62 suites pass, including active Contacts drag versus
  social repair, exact Mainhand drop, native registration retention, loading both
  absent Retail owners and keeping both restored roots on the workspace. Six
  manifests and Lua 5.1 syntax pass. Live drag, reload and protected descendant
  verification remain pending. No release or Companion change.

### OH-UI-018 follow-up: Contacts content separated during dragging

The developer's live screenshot rejects the prior Contacts candidate: the shell
remains at the Mainhand lower-left while list content is detached and further
dragging fails. The preceding regression covered only the outer FriendsFrame and
missed its native content hierarchy.

Blizzard's Retail FriendsFrame XML defines FriendsListFrame as a nested
setAllPoints content frame. Offhand's social alias list also considered that name
as an independent root, allowing social repair to overwrite its native anchors.
The correction expands Retail position-root ancestry resolution to FriendsFrame
as well as PVEFrame. Social repair and hook installation, generic dragging,
Mainhand placement/recovery, explicit toggle synchronization and reload restore
now reject native content descendants. Historical child positions are ignored,
without promoting them over the user's outer-window placement. Other clients
retain their existing root resolution. A reload rebuilds the already-altered
native child anchors and removes the old session's child hooks.

All 62 suites and six manifest/Lua 5.1 checks pass. New coverage models the actual
parent/child relationship, verifies both native child points remain untouched
through drag and social maintenance, rejects stale child reload/recovery, and
retains the requested root drop. Live visual and protected-action acceptance
remain pending. Retail and Anniversary addon copies are updated; generated
bridges, Init divergence, settings and Companion binaries are preserved.

## OH-UI-019: Retail chat reverts after saving and closing Edit Mode

- Live status, 28 October 2026: developer confirms the chat issue is resolved
  after the settlement-guard correction. This closes the reported Edit Mode
  save/close positioning defect in the local candidate. Historical report and
  test rationale below are retained; broader combat/cold-login coverage is not
  inferred from this confirmation.

- Corrected developer report: ChatFrame1 does NOT remain where placed after
  saving and closing Edit Mode. The earlier apparent chat acceptance was a typo,
  not a runtime pass. A later live retest is recorded in the status above.
- Candidate finding: the existing close-settlement marker suspended HUD repair,
  but generic Canvas restoration and tracked chat OnShow could still consume the
  old saved anchor during that same closing turn. Extend the shared Retail chat
  Edit Mode guard through settlement and apply it to tracked chat restoration,
  including its deferred apply path. The existing settlement capture then stores
  the final workspace drop or relinquishes stale positions for Mainhand.
- Regression now exercises direct Canvas restoration and native chat OnShow
  between manager OnHide and settlement capture, in addition to queued HUD repair.
  The native drop must remain untouched until capture, then become authoritative.
  No new native hooks, settings, chat docking or frame visibility changes.
  Native visible behavior remains pending; this is a source/runtime hypothesis
  supported by the regression, not a confirmed live resolution.

## OH-CF-20261029: CurseForge multi-user chat, spellbook and setup reports

Investigation date: 29 October 2026. Source: current working tree on
`codex/professions-quest-ui`, addon metadata 2.1.2 Beta 23. This tree already
contains substantial uncommitted work; findings below distinguish that candidate
from the unspecified versions installed by the reporters. No release, installation
sync, website publication or Companion rebuild was performed for this triage.

### Chat overlap: reproduced source defect, guarded in the local candidate

- The supplied `8816.jpg` shows stacked displays with the world below the
  workspace and visibly crowded/overlapping chat text above it. The pixels do
  not identify which ChatFrame roots are simultaneously visible, their docking
  state, or the exact client/addon version. This is consistent with the source
  reproduction, but does not establish that it is the reporter's only cause.
- `Canvas:RestorePersistentFrames` could call `Show` on a hidden secondary chat
  window with an old saved-open/workspace record. `RestoreWorkspacePosition`
  could then replay its detached size and UIParent anchor, even when Blizzard's
  dock currently owned it. The existing generic-path protection covered Forever
  secondary chat only. The tracked-chat path's dock check did not protect these
  two generic entry points on Retail.
- Before the correction, a probe using the existing chat harness reproduced a
  hidden, docked ChatFrame2 becoming shown, resized from 752x537 to a stale
  430x120 and reanchored from ChatFrame1 to UIParent at (100,600).
- Candidate: `CanvasChat.lua` now exposes `ShouldDeferSecondaryChatRestore`.
  Both generic entry points yield to positively docked secondary windows on
  other clients, while retaining Forever's stricter settlement requirement.
  No new hooks, native visibility writes or SavedVariables migration were added.
  Dormant detached records remain available if the player later undocks a tab.
- Regression: hidden docked tab, selected/shown docked tab, direct restoration,
  generic persistent restoration, and subsequent explicit detached restoration.
  Existing Forever settlement and primary-chat Edit Mode tests remain passing.
- Status: reproduced and corrected in simulation. Live verification pending on
  Retail with General/Combat Log/custom tabs, reload, zone transition and repeated
  tab switching, both Blizzard-only and the reporter's actual UI addon modules.

### Chat returns to bottom-left: related candidate, exact trigger unconfirmed

- OH-UI-019 has developer acceptance for saving/closing Retail Edit Mode. It
  does not establish this report's cold-login, reload or zone-transition behavior.
- Current source captures the settled workspace drop after Retail Edit Mode
  closes and queues repair when native primary-chat anchors change. World entry
  also invokes ApplyFullLayout and persistent restoration after 0.5 seconds.
  `CaptureForeverFramePosition`, used by the native FCF save hook, is intentionally
  Forever-only; that hook alone does not persist arbitrary Retail owner movement.
- Need compare ChatFrame1's native anchor, effective scale, active Edit Mode
  layout and savedWorkspacePositions before reload, after world entry, and after
  opening/unlocking Edit Mode. Distinguish a missing/stale snapshot from a late
  native/addon overwrite. Test top-left workspace placement in stacked and
  horizontal layouts. Do not classify the overlap guard as a primary-position fix.

### Invisible spellbook: related existing correction, separate acceptance needed

- OH-UI-015 identifies Retail PlayerSpellsFrame registration/anchor-reset gaps;
  developer retest says positioning appears corrected. OH-UI-018 adds missing
  Retail load-on-demand restoration for that standalone root. These changes
  already existed in the working tree before this investigation.
- This reporter hears opening and sees action-bar changes. That does not tell
  whether the root is hidden, offscreen, covered, wrongly scaled, or whether a
  child rather than PlayerSpellsFrame was manipulated. An open-state symptom is
  not proof that the previous positional correction resolves this report.
- Retest the same client/build with current candidate: open from a restored
  single-monitor window, span, place on workspace, close/reopen, change native
  tabs/minimize state, reload and cold login. Capture both PlayerSpellsFrame and
  SpellBookFrame geometry/visibility with `/offhand diag full`; inspect fresh
  Lua/taint evidence and protected spellbook actions. No additional speculative
  spellbook mutation was added here.

### Shared layout request: names and ownership policy, not storage alone

- `MainhandEditMode.lua` explicitly names layouts
  `Offhand - Mainhand - <Character>` and validates current-character names.
  Where supported, creation already sets layoutType to Account. The duplication
  is therefore partly a naming/reuse policy, not simply character-only storage.
- Generation and recovery use OffhandCharDB.mainhandLayout with source layout,
  owner, geometry signature, controller mode and target identity. Simply removing
  UnitName or selecting any row named Offhand would bypass those safeguards and
  can overwrite another character's customizations or reuse incompatible geometry.
- Proposed follow-up: explicit shared-layout adoption during the player's setup
  action, with geometry/controller checks, reuse of an existing compatible target,
  and preservation of per-character source/rollback records and existing layouts.
  Test two characters with different source HUDs, keyboard/controller modes,
  topology changes, interrupted setup and near-capacity layout lists.

### Vertical tooltip and speech-bubble spill: coverage gaps confirmed

- GameTooltip is excluded from generic panel movement. PopupBounds' new native
  tooltip clamp explicitly excludes Retail and Forever and handles workspace-owned
  tooltips on Classic; context-menu bounds do not constitute universal tooltip
  bounds. Dialogue UI has a separate adapter. This does not meet a universal
  Mainhand clamp for world/cursor tooltips in a stacked Retail layout.
- ChatBubbles compensates scale and, for eligible mixed-height Forever spans,
  provides a replacement anchored at the native bubble center. It does not clamp
  bubbles to Mainhand. Ellesmere chat-bubble ownership is detected for that
  replacement path, so blindly adding another anchor writer would risk a conflict.
- Follow-up must distinguish world/cursor tooltips from tooltips owned by panels
  intentionally on Offhand. Test all four Mainhand edges on stacked displays,
  item comparisons, instances, combat and external tooltip/bubble owners. Native
  protected/secret-sensitive bubble capabilities need client-specific validation.

### UI addon disruption and onboarding: incomplete compatibility and copy

- HUDCompatibility recognizes several replacement addons but action-bar ownership
  does not explicitly recognize Ellesmere modules or Naowh. Ellesmere raid frames
  and bubble replacement have narrow adapters; Canvas chat yields explicitly to
  Chattynator. These are not general Ellesmere/Naowh compatibility guarantees.
  Exact module names, versions and actual frame ownership are needed before adding
  exclusions; a brand name alone does not identify the frame that owns placement.
- Spanning changes the UIParent canvas used by full-canvas-relative addons. A
  displaced UI can result without Offhand editing that addon's saved profile.
  The reports do not establish wholesale profile destruction.
- English onboarding still recommends FancyZones on Windows. The website's main
  setup copy also leads with manual/FancyZones paths despite exposing the Store
  Companion. The manual website guide now contains detailed FancyZones steps,
  but that does not establish what instructions the reporter saw earlier.
- No explicit pre-setup reminder to back up Blizzard layouts and UI addon profiles
  was found in the current wizard/onboarding copy. Follow-up should present the
  Store Companion prominently, preserve manual alternatives, and give a concise
  backup/layout-impact reminder before spanning or generating a HUD. Verify all
  locales and onboarding card wrapping when implementing the copy changes.

### Mixed resolution loading screen, seam and border

- Exact Companion topology represents physical monitor rectangles; manual mode
  cannot obtain their desktop placement from addon Lua. Capture topology source,
  2560x1440/1920x1080 orientation and offsets, Windows scaling, render-canvas size,
  and remembered-window state before treating this as an incorrect width ratio.
- RetailFullscreen constrains PerksProgramFrame (Trading Post), not loading-screen
  presentation. WorldFrame viewport placement does not prove the native loading
  screen will fit Mainhand. Inspect the actual client-owned loading presentation
  and its accessibility before choosing an adapter; do not reparent UIParent or
  promise an addon can reposition an engine-owned loading surface.
- Both current seam controls use 0.005 ratio steps (0.5 percentage points), with
  15%-80% bounds and typed input. Existing regressions accept `50,5%` as 50.5%.
  Therefore the current source does not substantiate an only-0.5-or-1 restriction.
  If the request means 0.1 percentage-point steps, that finer resolution is absent;
  if it means ratios 0.1-0.9, the present range also does not cover both ends.
  Get the exact control/value/unit before changing it. Exact Companion geometry
  intentionally disables this manual ratio control.
- A thick visible border may involve native window placement, physical void,
  bezel compensation or workspace decoration. The supplied stacked screenshot
  is not evidence for this other reporter's horizontal mixed-resolution setup.

### Discord invitation

- Current website links use `https://discord.gg/3BAVSXBXH`. Both the invitation
  URL and Discord invite API were inaccessible through the web tool during this
  investigation. Validity/expiry could not be established; this is not a confirmed
  expired invite. Verify the published CurseForge URL as well as the website URL
  and resolve the invitation against the intended server before replacing it.

### Validation and next acceptance order

- All 62 existing Lua suites pass after the docked-chat regression was added.
  All six manifests pass path/XML checks and Lua 5.1 syntax validation (63 Lua
  files plus one XML runtime file). Sandbox process launch failed before execution;
  the successful Lua run used the approved execution outside the sandbox.
- No live WoW session was launched. Priority: chat visibility and primary position,
  spellbook accessibility, stacked tooltip/bubble ownership, then mixed-resolution
  fullscreen presentation. Shared-layout adoption and onboarding copy are separate
  changes and should not be bundled into the proven chat guard.
- Reporter follow-up data: addon version, WoW client/build, Companion version/path,
  `/offhand diag full`, actual enabled UI module names/versions, active Edit Mode
  layout, and a screenshot/frame stack when the defect is present. For mixed
  displays include Windows arrangement/scaling and Companion topology state.

### Implementation follow-up, 29 October 2026

Status: local source candidate, not released or deployed. The user authorized
implementation after the investigation. All earlier uncommitted work is retained.

- Chat: generic restore now also preserves the hidden primary message area when
  another native tab is selected. A queued detached-window replay rechecks docking
  and external ownership before applying. An explicit primary workspace drop is
  repaired after a late native anchor reset even when automatic chat docking is
  disabled. Native Edit Mode settlement and Forever's stricter dock policy remain.
- Ellesmere chat: Canvas persistence, presentation, visibility restoration and
  HUD placement now yield to EllesmereUIChat as well as Chattynator. The service
  is named HasCustomChatAddon to describe both providers. Ellesmere action-bar
  and minimap modules are recognized by runtime ownership checks. Serialized HUD
  generation also preserves recognized external action-bar, minimap, chat,
  unit-frame, cooldown and tracker entries. Existing ElvUI/Bartender/Dominos
  provider detection is reused for profile bundles; this is not a claim of full
  Naowh or Ellesmere visual compatibility.
- Spellbook: Retail position-root resolution includes PlayerSpellsFrame ancestry.
  Its nested SpellBookFrame content is excluded from independent movement and
  restoration, including historical child snapshots. Existing registration,
  anchor-reset and root reload fixes remain. No claim that every invisible-book
  trigger has been reproduced; native visibility and protected actions need QA.
- Shared layouts: new keyboard layouts use Offhand, native controller layouts use
  Offhand - Gamepad. A versioned OffhandDB.sharedMainhandLayouts registry tracks
  client, geometry, frame owners and source provenance. A fresh character's
  explicit setup action selects a compatible existing row without SaveLayouts,
  even at capacity. Per-character source/return records remain separate. Changed
  geometry or frame owners produce a numbered variant; unknown same-name rows
  are preserved. Character-named legacy layouts are retained. Saved rows remain
  adoptable after an activation failure. No login-time generation was added.
- World/cursor tooltips: UIParent/WorldFrame-owned tooltips use native clamp
  insets for Mainhand on Retail, Forever and Classic, including stacked layouts.
  Completed world-tooltip comparison transactions apply the same bounds without
  rewriting their anchor graph. Existing Offhand panel-tooltip handling remains.
  Protected/forbidden, embedded, oversized and known external tooltip-owner cases
  yield; combat writes defer. Original clamp settings restore on hide/disable
  only while Offhand still owns them.
- Speech bubbles: accessible native roots use reversible native clamp insets.
  Forever's eligible mixed-height replacement clamps only its addon-owned bubble,
  leaving the world-space native attachment untouched. Ellesmere bubble ownership
  yields. Protected/forbidden and Retail instance fallback behavior remain native.
  Visual behavior of the client renderer is still pending live verification.
- Seam: Options, calibration dragging, typed input, step buttons and viewport
  geometry now agree on 10%-90% with 0.1 percentage-point precision. Exact
  Companion topology still owns its seam and disables manual ratio controls.
- Setup: Companion is the first in-game method; English/fallback copy, README
  and local website sources recommend the Store path. Onboarding and direct
  calibration remind players to back up Edit Mode layouts and UI addon profiles
  before spanning. The warning explains possible custom-UI repositioning.
- Discord: direct Discord API verification now returns 404 for 3BAVSXBXH. The
  tools' recorded J2P3SM6pAY invitation resolves to N4UX ADDONS with no expiry
  reported. Local website and CurseForge description links now use the verified
  invitation. No Discord message or new invitation was created, and nothing was
  published to CurseForge or the hosted website.

Remaining limits and evidence:

- Loading-screen cropping is not claimed corrected. The reviewed native UI source
  has no LoadingScreenFrame implementation; generated
  [LoadingScreen API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/LoadingScreenDocumentation.lua)
  exposes loading events and no positioning functions. The README now distinguishes
  native loading presentation from the in-world viewport. No speculative global
  UIParent mutation, native-window resize during loading, or Companion change.
- A thick border in the other reporter's mixed-resolution horizontal setup still
  needs exact window/topology/scaling evidence. Finer manual calibration is now
  available; it does not establish the border's cause or repair exact geometry.
- Ownership names were checked against the upstream
  [Ellesmere module roster](https://github.com/EllesmereGaming/EllesmereUI/blob/main/EllesmereUI.lua).
  No upstream addon implementation was copied.
- Automated acceptance: 62 Lua suites, six manifests with Lua 5.1 syntax/path/XML
  validation, Companion preference/display/layout checks and release metadata
  checks pass. The Companion source, executables, release metadata and installed
  addon copies were not changed by this follow-up. Live client, combat/taint,
  reload/cold-login and translated text/scale acceptance remain pending.

Live continuation, 29 October 2026: Retail build 70575, manually placed spellbook
and native chat on the portrait workspace. Spellbook close/reopen and chat
workspace position through `/reload` pass. Reload restores PlayerSpells on Talents
instead of the previously open Spellbook tab; its wider panel extends beyond the
portrait workspace. P selects Spellbook and restores the original visible position.
Track selected-tab restoration and oversized-tab placement as unresolved follow-up,
not full spellbook reload acceptance. No new saved Lua errors. See
`tests/QA-notes.md`, manual-placement continuation, for evidence and cleanup.

Follow-up implementation and targeted acceptance, 29 October 2026: the candidate
now retains the selected semantic PlayerSpells tab and resolves its native ID and
availability before automatic reload opening. Native root resize observation fits
wide tabs inside the workspace without replacing child layout or native panel
registration. Scale reduction is reversible when returning to smaller tabs or
relinquishing workspace placement, and preserves externally changed scale.
Retail build 70575 live retest passed Spellbook reload, deliberately selected
Talents reload with full portrait-workspace containment, and restored original
Spellbook scale/position and close/reopen. Both semantic saved values were verified.
All 62 Lua suites and six manifest syntax/path/XML checks pass. No new BugGrabber
records. See the PlayerSpells candidate section in `tests/QA-notes.md` for private
evidence, cleanup and limits; this does not establish combat/taint acceptance.

Installed-addon follow-up, 29 October 2026: user installed EllesmereUI modules
and Naowh Smart Reminders 1.4.29. Added explicit Ellesmere bag ownership even when
native bag frames still exist, and independent DataBars status-system ownership.
Both combinations have regression coverage. Retail startup confirms Ellesmere
chat/bags/action bars/minimap plus Smart Reminders loaded and Offhand's ownership
probes yielding. A full Naowh profile is not installed. Live reload/tab-marker
validation awaits a manual chat-input handoff because tool-entered command text
was not visible. User explicitly deferred combat and physical stacked displays.
Native loading artwork remains outside addon positioning control; the original
mixed-resolution thick-border case still lacks a matching reproduction. Neither
is marked fixed. Website/CurseForge copy is available locally for review and
describes these limits. See the latest QA section for exact evidence and cleanup.

Manual handoff outcome, 29 October 2026: the saved native tab-switch capture has
General hidden, Combat Log shown and unchanged spanned dock geometry; Ellesmere
ownership and loaded Smart Reminders are confirmed. Combat Log did not retain
the synthetic red marker, so this does not establish incoming-message separation
or resolve the overlap report. A cold spanned follow-up encountered server
disconnect WOW51900319 and is inconclusive. Target client closed normally and
temporary diagnostic addon removed; private evidence retained. Remaining live
acceptance includes real incoming chat, exact top-left/zoning/cold persistence,
two-character layout reuse/rollback and the user-deferred stacked/combat checks.

Visible-panel continuation, 30 October 2026: Retail 12.1.5 build 70575 cold launch
and manual Companion span succeeded. A real click selected Combat Log before
spanning. Native frames and Ellesmere's separately parented panels both retained
exclusive visibility after spanning; the green General marker was absent from
the selected Combat Log view. Spellbook restored visibly on the portrait
workspace. This passes that specific visible tab transition and existing-setup
cold/manual-span restoration. Incoming multi-tab messages, reporter-specific
top-left placement/zoning, two-character live migration and deferred checks
remain open. No speculative renderer changes made. Temporary QA addon removed
after normal client exit. See QA notes and shared knowledge's recorded source gap.

User acceptance follow-up, 30 October 2026:

- User reports Spellbook/Talents reopens after reload even when explicitly closed.
  Added a Retail PlayerSpellsFrame.CloseFrame callback outside the native frame
  tree to clear stale open intent. Deferred evaluation ignores transient minimize
  hide/show and the existing transition flag preserves zone/logout snapshots.
  Anchor and selected-tab state remain saved. Native-close regression, all 62 Lua
  suites and six manifest/path/XML/Lua 5.1 checks pass. Two changed runtime files
  deployed with backup/hash verification; live closed-before-reload retest pending.
- User's loading-screen screenshot confirms mixed-display cropping remains open.
  Preserved privately with the local deployment evidence. No loading-art fix
  implemented or claimed.
- OpenMap v0.7.1-beta reports zero-scale and grain UV errors. User confirms errors
  also occur without Offhand. Recorded installed-source findings and an independent
  retest plan in docs/OPENMAP-RETAIL-20261030.md. Third-party files unchanged.

Recovery readability and Retail XP follow-up, 30 October 2026:

- Recovery confirmations now use Offhand's existing opaque 520-unit dialog on
  keyboard and controller layouts, with larger, left-aligned text and measured
  height. Missing-UI copy uses short paragraphs, with visible elements preserved
  and layout/reload consequences retained. Other popup alignment/font is reset
  when the shared card is reused. Acceptance behavior is unchanged.
- EllesmereUIActionBars hides/unregisters Blizzard's StatusTrackingBarManager
  when useBlizzardDataBars is false, the Retail default. That explains why the
  native XP bar is not available as an ordinary Blizzard HUD element in that mode.
  The replacement XP bar belongs to Ellesmere's own settings and unlock system;
  its live position/visibility has not yet been measured in the reported session.
- Corrected an earlier ownership assumption: standalone EllesmereUIDataBars
  supplies information panels and does not by itself replace native XP/Rep bars.
  Native status layout generation now also respects Ellesmere ActionBars' explicit
  useBlizzardDataBars=true preference. Unavailable profile access conservatively
  preserves external ownership. No external bar is forced shown or repositioned.
- All 62 Lua suites and six manifests pass. Deployed 13 files with backup/hash
  verification, preserving local Init additions. Evidence in ignored
  dist/local-deployments/20261030-recovery-readability/. Dialog visual acceptance
  and actual replacement XP bounds remain pending; running client untouched.

Live resolution of the current XP report: parent Ellesmere disabled and runtime
EllesmereUIActionBars loaded=false. Native manager shown=true; both native
containers hidden but correctly located inside Mainhand. User's guarded local
probe reports XP disabled=true, level=12 and no selected status-bar indices.
The character's disabled XP gains explain the missing XP display. No XP-enable
setting or native visibility was forced. This is not an off-screen layout failure.
The separate external-owner correction remains covered for other configurations.
Recovery dialog visual preview passed after reload: opaque, readable paragraphs,
larger left-aligned text, no clipping and both buttons visible. Recovery not run.

## Final local retest, 30 October 2026

Target: Retail 12.1.5 build 70575, installed OpenMap v0.7.1-beta.
User confirmed the map remained invisible with original OpenMap files. Temporary
read-only diagnostics showed zero map anchors, native area none, and a zero-size
canvas. Offhand now preserves Retail WorldMapFrame native panel registration
and avoids synthetic panel eviction. User reloaded and confirmed map appears.
All 63 Offhand Lua suites and six-manifest syntax/path validation passed.

WorldMap.lua remains byte-for-byte original. Close.lua contains only the local
grain correction. A separately observed Extras.lua hover failure used a map ID
without a stitched rectangle. The local guard skips unavailable/degenerate hover
coordinates and labels, then resumes on valid input. Focused tests execute the
actual candidate functions; missing rectangles, zero bounds, missing cursor and
valid recovery pass. Extras.lua passes Lua 5.1 syntax validation.

Installed SHA256:
- WorldMap.lua: CEB4E17C79D086134A3230636BD0A408904D8762CEDEAC96B80EC392BF8C2D95
- Close.lua: E41F860878177F010380A231477F092B58D2D1790F6729825C43581ACE2A6778
- Extras.lua: F6818A2CDCF7D4A9832AE3C04C56915FA89D4B0819D5EF7C616E031B702AB237

After reload, reopen/close twice, zoom and zone hovering, user explicitly reports:
"Map visible; no new errors". This accepts this local out-of-combat workflow,
not general compatibility or combat/taint safety. Historical error entries can
remain. Temporary /offhandmapqa command removed; profiles unchanged. Third-party
patches remain outside Offhand runtime/package and addon updates may replace them.
Original backups and test drivers remain under ignored local-deployments folder.
No release, publication or upstream message occurred.

Loading comparison: user confirms artwork visible after Companion Restore Window
on one monitor. Restored span afterward using Span WoW Now (4000x2560). Windows
monitor arrangement unchanged. This verifies a manual workaround; spanned native
loading-art cropping remains unresolved. No automatic loading resize or Companion
binary change was implemented. Recovery dialog font and XP-enabled-character bar
visibility are accepted by user; closed Spellbook/Talents survive reload.

## Shared HUD and recreated-character candidate, 31 October 2026

Retail 12.1.5 build 70575 report: shared Offhand and old individual rows both
visible; shared placement differs; Noggtester remembers Nearlytwenty's layout;
recreating a same-name character does not repeat the first-character setup flow.
Screenshots compare shared and individual layouts. Native account layouts are
account-wide, so old individual rows being listed alone is not a defect.

Read-only saved-state evidence: sharedMainhandLayouts incorrectly contains an
Offhand - Mainhand - Nearlytwenty entry created by a one-system repair. The
Noggtester HUD record names Offhand and owner Noggtester, but editModeLayoutName
names Nearlytwenty's individual row. Shared Offhand metadata describes 47 moved
systems and Chattynator ownership; legacy one-system metadata alone is not proof
that the complete legacy payload is invalid or compatible with another owner.

Candidate:
- Only canonical shared names (Offhand / Offhand - Gamepad, numeric variants)
  qualify for registry adoption. Character-named rows are not shareable even if
  an older build registered them. New Retail setup no longer adopts same-name
  orphan legacy rows without current-character provenance.
- Login/selection memory rejects another character's generated layout. A stale
  preference uses the valid current HUD target, otherwise requests HUD setup.
  Unknown active legacy rows cannot become a new character's rollback source.
- Explicit Retail full setup can promote a proven current-character legacy
  payload on matching geometry into the shared row without translating it twice.
  Old individual row retained; previous shared payload backed up in account state.
  Ordinary second-character adoption never rewrites the shared layout.
- Store characterGUID and generated-record ownerGUID. A changed GUID invalidates
  HUD selections/recovery tickets, keeps old provenance for recovery and requests
  HUD setup. Account onboarding, calibration and selected Offhand profile remain.
  A first upgrade with no historical GUID cannot retrospectively distinguish a
  same-name recreation; it seeds identity without inventing that evidence.

Knowledge README/skill/status consulted. EditMode search index stale; direct
source/saved-state evidence used. Structured Retail UnitGUID lookup documented
with no variant conflict; declarations do not establish live lifecycle or taint.
All 66 Lua suites pass, including new shared-layout-identity test plus native
login-selector regression. All six source and installed manifests pass Lua 5.1,
XML/path validation. No combat or live acceptance claimed.

Five candidate runtime files deployed only to Retail. Backups, private native
layout/SavedVariables snapshots and hashes are under ignored
 dist/local-deployments/20261031-shared-layout-identity/.
No saved layouts/profiles were edited by deployment and OpenMap was untouched.
Manual Noggtester selection and Nearlytwenty-to-shared promotion retest pending.
Prepared Beta24 ZIP has not been rebuilt and does not include this candidate.
Hold publication until this report is accepted. Other pending cinematic/viewport
work in the shared tree was preserved, not part of this deployment.
## Shared HUD live acceptance and package refresh, 31 October 2026

User reports "Shared selection and placement correct" for the requested
Noggtester reload, Nearlytwenty explicit legacy-to-shared update and return to
Noggtester. This accepts selection and tuned placement in that Retail setup.
GUID-based recreation and shared-layout rollback remain simulated, not live-tested.

Updated Beta24 changelog and rebuilt the held addon-only ZIP. It includes only
five accepted runtime file changes and CHANGELOG.md relative to the previous
validated archive. Init.lua receives only EnsureCharacterIdentity at PLAYER_LOGIN;
separate pending cinematic/viewport work remains outside this package and stays
untouched in the working tree and test installation. Four other changed runtime
files match accepted current source. All 75 archive entries match reviewed staged
bytes; CRC, portable paths and the six-entry change audit pass. All 66 current-tree
Lua suites passed; 63 applicable suites passed against extracted packaged runtime
with development test helpers provided outside ZIP. Three suites for separate
pending cutscene behavior are excluded from that package scope. Six extracted
manifests pass Lua 5.1/XML/path validation; release metadata regression passes.

Current ZIP SHA256:
C3B16558AC8DD95F10C606E061FC9C7FC6B5FB6276BC93A702FFEBD8C8A761B3
Artifact remains dist/curseforge-beta24-20261030/dist/Offhand-v2.1.2-beta.24.zip.
Manifest and upload notes refreshed. No OpenMap files, native Companion binaries,
SavedVariables or native layouts were edited by packaging. No publication/tag/
commit made. Existing source and runtime test install retain separate pending
cinematic work, so the final archive is not an all-current-working-tree snapshot.
