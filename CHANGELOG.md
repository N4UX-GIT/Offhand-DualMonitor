# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [2.1.2-beta.24] - 2026-10-31

### Fixed and improved
- Improved workspace chat position restoration and docked-tab visibility handling,
  including ownership detection for Ellesmere UI. Real incoming multi-tab traffic
  and the reported top-left position through zoning still need user verification.
- Restored Retail Spellbook availability, retained the selected Spellbook/Talents
  tab across reloads, and fitted wider Talents content inside the workspace.
  Panels closed before reload now stay closed.
- Preserved Retail World Map native panel registration and lifecycle when moved
  to Offhand, fixing the invisible map observed with OpenMap installed. This
  Offhand compatibility fix is included in Beta 24 and does not require changes
  to OpenMap.
- Added compatible shared Mainhand HUD layout reuse across characters while
  preserving character-specific rollback sources and external-addon anchors.
- Prevented old character-named HUD layouts from being adopted as shared layouts
  or automatically selected for another character.
- Explicit Mainhand HUD setup can preserve the current character's tuned legacy
  layout when updating the shared layout. The individual layout is retained and
  the previous shared layout is backed up.
- Added character GUID tracking so future same-name recreations receive a fresh
  HUD setup check. Existing data without a GUID cannot retrospectively identify
  a recreated character; account-wide installation setup remains preserved.
- Improved Mainhand bounds for world tooltips and supported speech bubbles.
- Improved Ellesmere bags, chat and status-bar ownership handling.
- Made Recover Missing UI clearer, with readable paragraphs, smaller body text,
  an opaque background and confirmation sizing that fits Mainhand.
- Added 0.1 percentage-point manual seam adjustments and decimal input.
- Updated setup guidance to recommend Companion first, explain UI repositioning,
  and recommend backing up Blizzard layouts and addon profiles before setup.

### Verified on Retail
- Shared layout selection and placement passed the two-character retest after
  updating the shared layout from the tuned individual layout.
- Tested packaged Offhand Beta 24 with an unmodified CurseForge installation of
  OpenMap v0.7.1-beta on Retail 12.1.5. After restarting, the map remained visible
  through repeated opening/closing, zooming and zone hovering, with no fresh
  errors reported. No local OpenMap patches were used for this retest.

### Known limitations and test focus
- Native loading artwork still uses the entire spanned WoW window and can crop
  across unequal or offset displays. Use Companion's Restore Window before
  loading, then Span WoW Now after returning to the world, as a manual workaround.
- Real incoming chat across tabs, exact top-left chat persistence through zoning,
  shared-layout rollback, recreated-character setup and the reported mixed-landscape
  border need further live verification. Combat/taint and physical stacked-display
  tooltip/bubble checks remain outstanding. Other clients need targeted retesting.
- This is an addon-only beta. Companion remains 2.1.2-beta.20; no native loading
  resize, graphics-reset recovery or Companion binary changes are included.

## [2.1.2-beta.23] - 2026-10-26

### Improved
- Reorganized addon services for clearer ownership of workspace panels,
  persistence, client compatibility, HUD recovery and Edit Mode integration.
- Refreshed settings with five-page navigation, section shortcuts, remembered
  page scrolling, consistent control styling and better dialog fitting.
- Improved slider dragging, typed values, decimal-comma entry, step buttons and
  synchronization when switching profiles. Companion-owned geometry controls
  consistently reflect their locked state.
- Reworked first-time setup with method-specific instructions, detected Windowed
  state, resumable calibration and Mainhand/Offhand region labels.
- Improved translated-text spacing, theme/help presentation and calibration
  validation messages without changing existing saved profiles.

### Fixed
- Restoring an ordinary window now selects the recorded source HUD layout;
  spanning again restores the character's Mainhand layout. Manual layout choices
  remain respected, and preset selection uses the correct layout-list index.
- Corrected Anniversary native action-bar placement while preserving Blizzard's
  artwork, controls and relative anchors.
- Corrected default Retail XP/reputation bar placement above the main action bar.
- Kept setup dialogs and confirmations reachable and correctly layered.
- Recentered already-open menus and Graphics Options after restoring the window.
- Corrected the legacy close-all-windows bag-provider decision scope.
- Removed the verified recurring Retail controller-detection CPU spike when the
  client lacks the Gamepad enum, avoiding unnecessary copies of preset trees.
- Reduced empty bag-snapshot allocations and unchanged addon-owned drag-handle
  layout writes; controller detection uses a guarded scalar fast path where
  supported. These additional changes have automated coverage, not an FPS claim.

### Companion and compatibility
- This is an addon-only update. Complete/portable downloads retain the unchanged
  Companion `2.1.2-beta.20`, with the existing protocol and minimum version.
- Experimental Companion VSync/graphics-reset recovery and graininess changes
  are not included. They remain separate integration work awaiting final-artifact
  testing. Beta 23 does not claim to fix the native graphics-reset issue.
- Existing client interface declarations are retained. Linux/Wine and original
  Wrath 3.3.5a support retain their existing experimental limitations.

## [2.1.2-beta.22] - 2026-10-22

### Compatibility
- Added Retail 12.1.7 interface `120107` to the generic and Mainline manifests,
  retaining Retail 12.1.5 and all previously declared client targets. This is
  package metadata compatibility; live 12.1.7 runtime testing remains pending.

### Added
- `/offhand diag full` provides detailed feature probes on request. The default
  report keeps versions, display geometry, persistence, Edit Mode and map
  ownership, with recovery details when relevant. Historical HUD bounds,
  controller counters and animation probes are no longer collected by default.
- Offhand can now load the optional, user-owned `Offhand_UserMedia` addon
  generated by the website's Background Studio. The Themes tab provides an
  explicit enable toggle plus Studio, Fill, Fit, and Stretch choices. Package
  metadata is validated before use, power-of-two texture padding is excluded,
  and the normal canvas theme remains the safe fallback.
- Background Studio media schema 2 stores presentation values as declarative
  TOC metadata and no longer generates or loads `Background.lua`. Its local ZIP
  importer accepts the older schema only for conversion, enforces an exact file
  layout and bounded stored entries, and omits executable Lua from the newly
  generated replacement.
- Forever now exposes a visible **Toggle gameplay and window focus** key
  binding. Players can assign a controller button or chord to
  Forever's native hidden `TOGGLEUIFOCUS` action, releasing a window after any
  interaction without reaching for the mouse. Offhand does not replace or
  modify Blizzard's focus stack.
- Forever profiles now include a **Show 'Drag to move' handles** option under
  Offhand Monitor. It is enabled by default and can immediately hide or restore
  the addon-owned mouse mover bars without changing saved panel positions,
  centering, or native Gamepad navigation.
- Group-loot positioning now offers an optional downward stack direction for
  players who place the first-roll anchor near the top of Mainhand. Blizzard's
  upward direction remains the default for all existing and new profiles.

### Fixed
- Forever now accepts a Companion span when the physical-size API still
  reports one selected monitor and the live UI canvas independently matches
  the full span. Restored and ambiguous canvases retain mismatch protection.
  Setup detection uses the accepted full-span dimensions for workspace sizes.
- World-map geometry now yields to OpenMap's own saved position and scale,
  while Offhand retains workspace reopening. This prevents Offhand's mover
  and restore paths from competing with OpenMap's window management.
- Remembered FancyZones and manual canvases now remain the selected geometry
  source, so an older generated Companion topology cannot reject the smaller
  render area of an otherwise valid bordered Windowed client.
- The auto-configuration wizard now keeps the player on Step 4 when stale
  Companion topology or a Companion version mismatch blocks completion. The
  actionable recovery message appears beneath the calibration controls instead
  of unexpectedly returning the wizard to Step 1.
- A visible Forever Professions panel no longer loses its `Drag to move` grip
  when its first attachment attempt occurs while native Gamepad or another
  protected interface state owns the panel tree. Offhand now retries only
  visible, still-unattached Professions roots after the keyboard interface is
  safe, without reopening or repositioning panels that already have a grip.
- Opening another Blizzard panel no longer leaves an already-visible Offhand
  World Map at the shared top-left UIPanel anchor. The common panel transaction
  repair now starts the map's addon-owned, generation-scoped settlement after
  both opening and closing panels. Its bounded chained passes outlast nested
  native layout timers, restore only displaced geometry, and do not install
  handlers on the protected map tree. Replacement-bag visibility is not
  sampled during the temporary panel transaction.
- Forever now persists the current `ProfessionsFrame` root as well as the older
  `ProfessionsBookFrame` name. The hidden load-on-demand frame is prepared
  before its first visible layout pass, and position settlement no longer
  repeatedly hides and reopens the native panel. This removes the first-open
  anchor flash and repeated open/close audio while retaining Offhand placement
  across `/reload`.
- Social and Guild & Communities placement is now repaired after Blizzard's
  completed `UpdateUIPanelPositions` transaction, including unrelated panels
  which reuse the shared left slot. A root-anchor observer supplies a bounded
  next-frame fallback for later native layout continuations. Saved Mainhand and
  Offhand positions are restored, while an unsaved Social frame accidentally
  displaced into Offhand returns to its remembered Mainhand position. Forever's
  live `SocialUIFrame` root and older Friends aliases receive the same narrow
  out-of-combat, root-anchor-only exception as the Gamepad adapter. The first
  stable Mainhand coordinate is retained for the session, unchanged panels
  receive no anchor rewrite, and an unexpected native `SetPoint` is corrected
  synchronously before the next render.
- Opening Options no longer reopens Bagnon behind the still-visible Settings
  panel. Offhand retains the saved Offhand bag snapshot and restores it once
  after Settings closes, avoiding the transient bag flash and opening cue.
- Moving the Auction House or another NPC-bound panel to Offhand no longer
  detaches it with a native hide and direct-show cycle. These panels retain
  Blizzard's active interaction transaction, preserve native Escape and close
  behavior, and restore their saved monitor position on the next native open.
- Forever Gamepad movers now yield completely to Bagnon, Baganator, and other
  replacement-bag owners, so native bag roots no longer receive an Offhand
  `Drag to move` handle beneath the replacement UI. Social discovery also
  accepts Forever's alternate Friends roots while retaining the same protected
  root-only movement boundary.
- The controller-focus setup action now opens **Gamepad (Alpha)** instead of
  keyboard Keybindings, where players can enter Controller Configuration and
  assign Offhand's focus action. Forever's alternate `HEADER_OFFHAND` lookup is
  initialized alongside the standard binding header, removing the placeholder
  heading from the binding list.
- Gamepad help now states that Back and Escape retain Blizzard's native window
  dismissal behavior. Offhand delegates to Blizzard's native UI-focus action
  for controller-only unfocus and does not reopen protected windows from an
  Escape transaction.
- Forever now pauses all protected Gamepad destination and radial-menu anchor
  work for one second whenever the native interface style changes. The adapter
  then observes at a bounded rate instead of every rendered frame, and visible
  protected panels are left to Blizzard until they hide. This narrows the
  client-crash risk reported while toggling Gamepad mode.
- Existing Forever installations with the former Professions compatibility
  switch saved as disabled now migrate once to the enabled default. The hidden
  compatibility card no longer leaves Professions movement inaccessible, while
  the internal emergency-disable API remains available.
- Opening Social or Guild & Communities reapplies both panels' saved Mainhand
  or Offhand anchors in the same UI turn. The common panel-open repair above
  also covers displacement caused by other Blizzard windows.
- Forever's Gamepad destination anchors and `Drag to move` handles now activate
  only while the native Gamepad UI setting is enabled. A remembered Gamepad HUD
  layout no longer leaks the adapter into keyboard mode, so native panel
  placement and Escape behavior remain untouched and panels no longer jump
  from their keyboard anchor to a delayed saved Gamepad position. The Offhand
  binding category is also declared only once, removing the duplicate-header
  Lua warning at login.
- Forever's complete `/reload` fallback now tags per-character state with the
  character that wrote it. Account settings can still recover across
  characters, but Edit Mode preferences and Mainhand layout provenance cannot
  leak between them. Mainhand HUD creation also rejects a foreign character's
  generated target while retaining its safe Modern or Classic source preset,
  so normal and Gamepad layouts remain distinct for the selected character.
- Forever's **Repair HUD** now targets an unreachable Party or Raid Edit Mode
  entry instead of treating movement of unrelated HUD systems as a successful
  repair. System-relative group anchors are rebased through Blizzard's saved
  layout data into Mainhand, customized reachable layouts remain unchanged
  during ordinary generation, and a missing group entry now fails explicitly
  rather than starting a reload-and-prompt loop. `/offhand diag` now includes
  group-frame bounds and protected-HUD recovery state for follow-up reports.
- Bagnon's one-bag inventory now participates in Offhand workspace persistence.
  Escape preserves an open Offhand bag while still opening or closing the Game
  Menu, `/reload` restores the bag through Bagnon's public frame manager, and
  Bagnon's own close button or bag key continues to close it explicitly. A live
  Forever Gamepad test exposed that observing the root with `OnShow`/`OnHide`
  hooks entered Blizzard's protected focus ancestry. Bagnon discovery and
  Escape pairing now run only from Offhand-owned observers and secure global
  transaction hooks; Gamepad mode performs no Bagnon root inspection, reopen,
  reanchor or chrome update.
- Opening or closing Professions no longer converts its temporary Bagnon
  cleanup into an explicit bag close outside native Gamepad focus. Options
  defers restoration until Settings closes. Both paths use Bagnon's public
  frame manager and install no scripts on its root. Professions retains
  Blizzard's native panel lifecycle instead of using a hide/show slot eviction.
- Leatrix Maps is now the sole owner of World Map scale and anchors whenever it
  is loaded. Offhand retains only its independent workspace visibility contract,
  so Escape, simultaneous panels and reload restoration remain supported without
  competing with Leatrix during Professions or map layout changes.
- World-text fine tuning now applies on equal-height spans. The previous native
  topology shortcut also bypassed the user multiplier, causing the 50% setting
  to leave `WorldTextScale_v2` at 100%.
- Workspace window locking now waits for the normal login or `/reload`
  restoration to finish before active close recovery begins. Active recovery
  uses one bounded, short settlement path for maps, bags and Character instead
  of repeatedly accumulating full startup restoration callbacks.
- Slider drags now commit the thumb's final displayed value on mouse release,
  so Character workspace scaling updates immediately without requiring a
  subsequent step-button click.
- Retail 12.1.5 now uses the correct `120105` interface number in the generic
  and Mainline manifests, preventing the client from marking Offhand out of
  date. The invalid `121500` and redundant `121000` values were removed.
- Forever's native gamepad interface no longer receives Offhand-owned child
  drag controls during login or `/reload`. Offhand now detects the live input
  interface style, leaves SmartNavigation-managed Blizzard window structures
  untouched, suspends its broad popup re-anchoring scan, does not automatically
  reopen panels or bags, and avoids panel-slot and Escape-registry mutations
  while native gamepad navigation is active. Player-opened windows still return
  to their saved Offhand positions. ConsolePort continues to retain ownership
  of its protected layouts. The panel lifecycle diagnosis and initial fix were
  contributed by Frosted (`bitwize01`) in
  [PR #18](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/18).
- Offhand dialogs use addon-owned cards while native Gamepad UI is active, so
  setup links, confirmation prompts, recovery choices and reload notices no
  longer activate Blizzard's protected `StaticPopupGamepad` focus stack.
  Keyboard and mouse mode continues to use Blizzard's standard popups. The
  addon-owned cards are centered within Mainhand.
- Forever no longer rewrites or refreshes the native `Gamepad (Preset)`. Live
  testing showed that runtime preset-manager mutation taints Blizzard Edit
  Mode and later secret-value reads in `CompactUnitFrame`. On current Forever
  builds, the player-clicked Mainhand HUD action instead copies the native
  Gamepad preset into an Offhand-owned custom layout, translates that copy,
  saves and selects it through the public Edit Mode APIs, then asks the player
  to `/reload` so the Edit Mode transaction cannot taint later gameplay.
  ConsolePort layouts remain externally owned.
- Forever's native Gamepad radial Main Menu opened by Start is centered within
  Mainhand even though it is not exposed through Edit Mode. Offhand identifies
  the localized visual container without attaching code to the Blizzard frame
  tree, adjusts only an unprotected root anchor outside combat, and restores
  Blizzard's original anchor when native Gamepad mode or spanning is inactive.
- Forever now centers eligible fixed Character, Map and Quest Log, Chat
  Channels, native bag, Options, AddOns, and Customer Support destinations opened from the
  Gamepad radial menu. A bounded addon-owned observer changes only a shown,
  unprotected root anchor, installs nothing in the native frame tree, performs
  no combat writes, and restores the original anchor only while it still owns
  the applied position. Every simultaneously visible supported root receives
  its own Offhand-owned drag bar without becoming a child of the Blizzard panel
  or changing its scripts, movability, focus, or input metadata. The observer
  now settles newly shown roots before the next render to avoid a visible jump
  from the native anchor. Completed offsets are saved per character.
- The native Gamepad HUD path never mutates preset tables or invokes an Edit
  Mode manager refresh. It uses only `SaveLayouts` and Blizzard's public
  custom-layout activation APIs from the explicit player action, preserving
  the built-in preset while allowing the Mainhand HUD to be applied.
- Forever now automatically recovers the named Edit Mode save, rename, import,
  delete, and unsaved-changes dialogs when native Gamepad mode anchors an
  unprotected dialog root in the mixed-height void. Recovery remains outside
  combat and does not touch dialog buttons or Gamepad focus handlers.
- Pet battles now place their complete native interface inside Mainhand instead
  of splitting the top and bottom panels across the monitor seam. Offhand
  prepares Blizzard's full-screen pet-battle root before combat lockdown,
  preserves its internal layout and visibility lifecycle, and yields when a
  user or another addon has supplied a custom anchor.
- Retail reload restoration no longer re-enters the character sheet's
  hide/show lifecycle while its PaperDoll view is expanding. The frame is
  detached from Blizzard's panel slot before opening and receives Blizzard's
  own final display refresh, keeping the properties pane inside the character
  window on the first login or `/reload` presentation.

## [2.1.2-beta.21] - 2026-10-13

### Added
- Group-loot rolls can now be positioned from Display settings with an
  Offhand-owned draggable preview. The saved position is proportional to the
  Mainhand viewport, additional rolls retain Blizzard's upward stacking, and a
  reset button restores the lower-center default. Movement is unavailable in
  combat and yields when another addon owns a roll anchor. Layout refreshes are
  suspended for the preview while it is actively being dragged, preventing it
  from jittering toward its previously saved position.

### Fixed
- Group-loot rolls now remain inside Mainhand during combat. Offhand follows
  Blizzard's native group-loot update and redirects the individual roll rows,
  so later movement of Blizzard's managed alert container cannot pull them back
  to the monitor seam. Native stacking is retained, and custom row movers keep
  ownership instead of being overwritten.

### Changed
- `/offhand diag` now reports a concise current support snapshot instead of the
  accumulated renderer, anti-aliasing, nameplate, bag, cinematic, panel-reload,
  Professions, party-frame, and protected-HUD probes used by resolved test
  investigations. It retains environment and topology context while focusing
  live Beta 21 evidence on combat-text scaling, speech-bubble replacement,
  group-loot secure positioning, Edit Mode, and loaded compatibility addons.
- World text compensation is now topology-aware and user-adjustable. Equal-height
  spans retain Blizzard's native combat/XP scale, while mixed-height spans use
  the automatic correction with an independent on/off switch and 50–150% fine
  tuning. On affected mixed-height Forever spans, speech-bubble compensation now
  leaves Blizzard's world-positioned frame untouched and overlays a normal-size,
  classic-styled bubble. Equal-height and unspanned layouts remain completely
  native, EllesmereUI customization takes precedence, and a separate 50–150%
  slider fine-tunes only Offhand's replacement.
- Companion download guidance now recommends the Microsoft Store for Windows
  while retaining the version-matched GitHub ZIP for portable and Linux/Wine
  use. The in-game guide, settings, generated GitHub release notes, and Discord
  release announcements now use the same channel distinction.
- Added an initial compatibility target for the original WoW 3.3.5a client
  (`Interface 30300`). A legacy-only runtime adapter supplies the timer and
  physical-window primitives used by Offhand, while Backdrop and visibility
  code now falls back to APIs available in Wrath. This target remains
  experimental until exercised on a real 3.3.5a client.
- Companion 2.1.2 Beta 20 is the current public testing build. Addon manifests now
  identify the actual addon release separately from Companion protocol `1` and
  minimum Companion version `2.1.2-beta.19`, so later addon-only releases can
  reuse the exact approved Companion bytes without rebuilding them.
- The Companion now respects the configured automatic-span delay on Forever as
  well as other clients. Choose `0` explicitly when immediate pre-login
  spanning is desired.
- The Companion no longer registers system-wide hotkeys and adds a managed
  **Identify Displays** overlay for mapping Offhand display numbers and roles.
- The user-initiated update check now reads the official Offhand repository's
  published release list. Beta installations include published prereleases,
  stable installations ignore them, and Companion-specific release metadata
  prevents addon-only version bumps from producing false update prompts.
- The settings header now shows the Companion release paired with the installed
  addon. Its version tooltip lists the exact addon build and paired Companion
  build separately, and explains that WoW cannot inspect the executable that is
  actually running.
- Forever users whose client opens Professions reliably can explicitly enable
  experimental movement from a new collapsed Advanced compatibility card. The
  override is off by default, requires a crash warning confirmation, resets on
  client build changes, and supports only delayed dragging and position restore;
  automatic opening, Escape protection and reload persistence remain disabled.
- Addon metadata now separates the addon's independently advancing public
  release from the Companion protocol and minimum supported Companion build.
- Companion display-plan and activity-log messages now wrap instead of drawing
  long missing-monitor diagnostics outside their cards.
- Companion replaces the former Hotkey selector with the display-identification
  control, avoiding the prior overlap and removing the global-hotkey behavior.
- Companion documents an experimental same-prefix, same-runner Wine path,
  including a Lutris pre-launch example and Linux extraction checks, while
  keeping native X11 and compositor-specific Wayland support as separate work.
- Release ZIPs now use portable forward-slash entry paths so Linux extractors
  preserve the addon directory tree without a custom deflattening script.
- The executable in the complete release bundle is now consistently named
  `Offhand.exe`, matching the standalone file and Companion archive.
- Addon-only release automation now restores the published Beta 19 Companion,
  verifies its exact SHA-256, and reuses those frozen bytes in the complete
  bundle and the stable `releases/latest/download` asset names. Rebuilding the
  Companion still requires an explicit Companion-change release lane.
- Companion no longer creates a Windows Run-key startup entry or inspects
  process security tokens. Removing these nonessential beta.11 additions
  reduces overlap with generic antivirus heuristics while retaining the
  Companion's required window-management behavior.
- Companion update actions now follow the installation channel. Microsoft Store
  packages open the official Store product page without querying GitHub, while
  portable builds retain the explicit, user-initiated GitHub release check.

### Fixed
- Leatrix Maps player/cursor coordinates no longer retain their enlarged
  pre-span font raster until `/reload`. After a live display transition,
  Offhand now refreshes only coordinate-like font strings anchored to the
  bottom of `WorldMapFrame`, preserving their existing font data while leaving
  Leatrix's map scale, anchors, scripts, settings, and saved variables untouched.
- Speech-bubble replacement now reacts to bubble-producing chat events and
  rescans again on the next frame, removing the visible tenth-second shrink on
  the first bubble after spanning. Percentage fields now restore their unit
  after Enter even when the value is unchanged, and slider dragging uses a
  gentler physical-pixel curve. The speech-bubble size control is labelled as
  the replacement size so its scope is explicit.
- `/offhand diag` no longer aborts when a client omits an optional renderer
  CVar; missing formatted values are reported as `unavailable` and the
  remaining diagnostic sections continue.
- Floating combat, damage, healing and experience text now uses the same
  geometry-derived absolute visual baseline as the Mainhand HUD on clients
  exposing a native scale control. Capability detection prefers Forever's
  `WorldTextScale_v2` and falls back to legacy `WorldTextScale`; the selected
  key and player's original value are preserved for exact restoration. Live
  Forever testing confirms the versioned control corrects damage and XP text
  immediately and across reloads. Forever speech-bubble frames are left at
  their native scale while this control is active, preventing the direct frame
  compensation from displacing bubbles toward the game-view origin. Live frame
  diagnostics identified a native WorldFrame-anchored root and one anonymous
  visual child owning both the FontString and all NineSlice textures. Because
  scaling either frame also rescales Forever's position offsets, Offhand keeps
  all Forever speech-bubble frames, anchors, NineSlice textures and fonts under
  Blizzard ownership. Live testing showed the Beta 19 native bubble was already
  correct, while every attempted shell compensation caused displacement,
  deformation or disappearance. Offhand performs only a one-time cleanup of
  font/texture state written by the affected beta iterations; the native
  13-point font baseline is retained for that recovery. Combat, healing and XP
  text remain independently corrected through `WorldTextScale_v2`. Beta 22 testing
  separately proved engine text ignores WorldFrame scaling, so that root
  remains native. A live EllesmereUI comparison subsequently proved that an
  addon-owned visual can safely follow the untouched outer carrier across span
  and restore transitions. Offhand now uses that narrower architecture only on
  affected mixed-height spans: it mirrors the already-formatted native text into
  Blizzard's classic chat-bubble artwork, hides only the accessible native visual
  child after the replacement is ready, and restores it on every ownership exit.
  Instances, failures, hidden children and EllesmereUI-managed bubbles fail open
  to their existing owner.
- Forever no longer synthesizes visibility, docking, or floating presentation
  for the built-in Combat Log. Positive native dock or tab-parent evidence now
  immediately returns `ChatFrame2` to Blizzard; if the removed unsafe recovery
  records that it previously ran, Offhand repairs its persisted dock bit,
  removes stale placement, and hides the inactive Combat Log bleeding over
  General. Hidden or ambiguously detached Combat Logs remain
  untouched; only an already-visible, explicitly detached Combat Log may have
  its saved position restored. Custom detached chat windows retain the existing
  settlement and presentation recovery. Generic persistent-panel restoration
  now excludes every Forever secondary Blizzard chat frame, preventing a stale
  `ChatFrame2` record from resizing, reanchoring, or showing the docked Combat
  Log before Blizzard finishes rebuilding its dock. Only the existing tracked
  chat path may restore a secondary frame after settled evidence proves it is
  detached. Offhand also leaves Forever's primary chat button side entirely to
  Blizzard Edit Mode.
- First-time onboarding now supports manual dual-display and intentional
  single-ultrawide layouts at Step 4 without requiring Companion topology.
  Because WoW cannot report physical monitor boundaries, manual users receive
  an explicit confirmation instead of a false automatic-detection claim;
  stale Companion topology remains blocked. The calibration recommendation for
  a 21:9 single display preserves a 16:9 Mainhand and assigns the remaining
  width to Offhand.
- The final wizard step now offers a confirmed **Finish Without HUD Layout**
  path when Blizzard's custom-layout cap, combat state, or an unavailable Edit
  Mode API prevents HUD generation. The per-character deferral completes
  onboarding without claiming protected frames were repaired, remains visible
  in Recovery & Preview, and suppresses an immediate automatic repair prompt;
  creating or repairing the layout later clears the deferral.
- The setup wizard and Recovery panel now replace the internal `span` HUD-layout
  failure token with actionable guidance. A stale Companion topology is blocked
  during wizard preflight and explains both respan and manual-setup recovery;
  other unconfirmed spans direct the user to Windowed mode and `/offhand diag`.
- Forever World Map restore queues now keep every generation/pending marker in
  addon-owned weak state instead of writing generic `_Offhand*` fields onto
  `WorldMapFrame`. M/L geometry settlement also runs from Offhand's independent
  observer after Blizzard's protected toggle stack has returned. Its initial
  hidden construction frame no longer erases a saved open marker, and the first
  geometry settlement runs immediately on the observed visibility edge to
  reduce the opening reposition. Placement, scaling, dragging, reload
  persistence, and open state remain Offhand-owned.
- Forever native backpacks again persist both position and intentional open
  state on the Offhand canvas. A bag left open reopens after `/reload`, Escape
  and system-panel cleanup restore it through Blizzard's public bag APIs, and
  explicit B or close-button actions clear the marker and remain closed. The
  recovery path never directly shows an uninitialized native bag frame.
  Forever's direct `ToggleAllBags`, `ToggleBag`, and default-B
  `ToggleBackpack` paths are treated as explicit even when they bypass
  `CloseAllBags`, so B remains responsive immediately after the Game Menu
  closes. The former three-second panel-transition grace timer has been removed;
  Settings/AddOns/Edit Mode recovery now depends on visible panel state,
  visibility edges, and same-turn navigation markers instead of elapsed time.
- Manual **Restore Window** now returns to the remembered pre-span bordered
  bounds instead of first filling the complete Mainhand work area. This avoids
  the observed two-stage resize that could make Retail lose and recreate its
  D3D12 device, briefly freezing the client while textures loaded again.
  Missing-display recovery continues to fill the surviving Mainhand.
- Unit context menus near a Mainhand edge now remain inside the physical game
  view instead of treating the complete spanned desktop as usable space and
  extending downward or sideways off-screen. Modern menu proxies and legacy
  dropdown lists are handled without recurring discovery scans.
- Accessible world-owned nameplates use UIParent's absolute spanned-layout
  scale, while clients exposing `WorldTextScale_v2` or legacy
  `WorldTextScale` apply the same baseline to engine text without changing
  WorldFrame. The disproven Forever root fallback has been removed.
- Retail friendly player nameplates no longer become blank health bars outside
  instances when the friendly-name CVar is disabled. While Offhand owns an
  active span and friendly plates are enabled, it writes Retail's canonical
  boolean token, keeps their names visible through later CVar refreshes, and
  restores the player's exact prior preference when the span is removed.
- Item and comparison tooltips opened from an Offhand-side bag now treat the
  physical workspace edge as their boundary. Offhand preserves Blizzard's
  comparison-card dependency graph and translates only the primary tooltip
  after the completed comparison transaction, preventing circular anchors and
  leaving a small seam margin. Cursor-, world- and Mainhand-owned tooltips
  retain Blizzard's placement.
- An explicit Retail drag of the primary or combined backpack into Mainhand now
  retains its clamped drop point instead of clearing user placement and
  immediately returning the bag to Blizzard's default bottom-right anchor.
- Closing a custom Blizzard chat window now retires its Offhand placement so it
  remains closed after reload. Re-docked tabs also adopt the primary chat
  window's font size as well as its dimensions.
- Addon-bag discovery no longer scans WoW's complete global namespace every
  second. EllesmereUI roots are resolved directly, saved Baganator roots are
  resolved by name, and new Baganator frame groups are learned from its
  lifecycle callbacks. Workspace close-button refreshes now consume that small
  shared registry instead of performing their own recurring global scan.
- Forever's Edit Mode control recovery now remains available after Companion
  restores WoW to one display with a stale spanned topology. The read-only
  detector covers both the manager and its separate settings dialog; only the
  explicit recovery-popup click centers shown, unprotected control surfaces.
- Detached native chat backgrounds now receive a bounded final presentation
  replay after Forever's delayed Settings fade, preserving the player's saved
  color and opacity instead of losing them when the chat Settings UI opens.
  Settings initialization is observed even when Blizzard marks its color/alpha
  replay `doNotSave`; an addon-owned Settings-state observer also covers native
  fades that bypass both setters. Reload-time dock/save callbacks no longer
  delete detached positions; only an observed user re-dock relinquishes them. A one-time Forever
  migration reopens and recaptures a detached Combat Log hidden by the affected
  beta while retaining Blizzard's native position.
- Forever's native Blizzard bags can again be placed and restored on the
  Offhand workspace through an isolated `UIParent`-owned title grip. Offhand
  installs no scripts or hooks on the bag, its title/close controls, item
  buttons, bag functions, or Blizzard's anchor manager; only a user-initiated
  root move and an out-of-combat root-anchor restore cross into the native
  frame. Existing native-bag snapshots are retained, reload restoration uses
  Blizzard's own opener, and custom bag addons remain independently supported.
  Returning the bag to Mainhand clears both the active-root and shared-family
  workspace snapshots so the observer cannot pull it back across the seam.
  The observer now preserves a tracked workspace bag when Escape closes it and
  also completes Forever's consumed Game Menu toggle. After the native call
  stack ends, Offhand applies the already-requested menu visibility change
  directly, then reopens the bag through Blizzard's native API. It never calls
  `ToggleGameMenu` from deferred addon code, avoiding Forever's protected
  `SpellStopCasting` path. Secure post-hooks on the
  global close/toggle transaction distinguish Escape and system cleanup from
  B/X without attaching to the native bag tree or replacing Blizzard functions.
  The isolated bag controller also observes Settings, AddOns and Edit Mode
  visibility so their delayed native cleanup cannot discard the tracked bag;
  explicit B/X closes remain authoritative while those panels are open.
  If Forever hides the bag root but leaves its logical-open state set, Offhand
  normalizes that mismatch through Blizzard's toggle/open APIs before restoring
  it, rather than clearing persistence or directly showing an uninitialized
  `ContainerFrame` shell.
  Forever can reject all native bag APIs while Options, AddOns or Edit Mode owns
  the modal UI. In that narrow state, Offhand may re-show only the same bag root
  it observed fully initialized and visible immediately before the transition;
  the fallback cannot construct or expose an unseen login/reload shell.
  A bounded transition window bridges lazy Settings discovery and the additional
  cleanup performed when AddOn List closes. Secure post-hooks on Blizzard's
  Settings-opening APIs identify Options' own `ToggleAllBags` cleanup before
  its frame is observable. Forever builds that bypass those APIs are covered by
  the simultaneous open-to-hidden Game Menu transition; an ordinary B/X close
  outside panel navigation still cancels the window.
  Settings' older immediate recovery path also retains the tracked-open intent
  when the modal panel rejects native bag APIs, allowing the isolated controller
  to complete recovery instead of discarding persistence.
  Anchors settle every rendered frame so the
  default bottom-right opening position is corrected before paint.
  This replaces the overly broad OH-FOR-006 containment that removed native
  bag workspace support while preserving the protected item-click boundary.
- Group-loot rolls now use the restricted secure Mainhand positioner and a
  secure post-layout wrapper on Blizzard's roll frames. This corrects the
  container's initially unanchored load state and the
  `BottomManagedFrameContainer` reset that occurs after the pre-combat anchor,
  keeping the roll UI out of the monitor seam without adding an insecure hook
  to Blizzard's loot path.
- Detached Blizzard chat windows placed on Mainhand now retain their individual
  positions through Forever login and UI reloads instead of stacking at the
  full-span center. Offhand restores both Mainhand and workspace chat snapshots
  after Forever's late native chat layout while preserving deliberate moves,
  even when Forever leaves stale dock flags on a detached frame. Offhand leaves
  the tracked window shown before committing its observed detached state, then
  clears the stale runtime dock flag and reapplies Blizzard's saved floating
  color, opacity, and fade-in. This includes custom windows left without legacy
  dock flags by an earlier beta. Later color-picker changes receive the same
  next-frame appearance refresh so their newly saved values remain visible.
  Re-docking a detached tab clears its Offhand snapshot and adopts the primary
  dock's dimensions instead of retaining its detached size.
- When Chattynator is loaded, Offhand now leaves its borrowed native chat frames
  entirely under Chattynator ownership. Stale `ChatFrameN` snapshots are cleared
  without hooking, clamping, resizing, or reanchoring the embedded Combat Log;
  Offhand also leaves Chattynator's custom windows and shared text input alone.
- Companion now repairs a generated display-topology snapshot when an addon
  update replaces it with the packaged placeholder while WoW is still exactly
  spanned. The window is not moved; the repaired handoff becomes active after
  one `/reload`.
- Companion compatibility now treats the manifest value as a minimum version.
  A newer beta or stable Companion no longer produces a false update warning.
- Automatic onboarding, recovery UI, and inherited workspace/bag restoration are
  deferred while Blizzard owns player input during cinematics, movies, and
  first-character intro scenes. Replacement-bag snapshots now retain only
  top-level roots instead of child widgets. Forever's native cinematic skip
  confirmation, which can be placed outside the visible Mainhand rectangle by a
  mixed-height span, is recentered only after Blizzard shows it; Offhand does not
  intercept Escape or invoke the confirmation action.
- Forever now tracks its recovery Edit Mode layout per character instead of
  assuming every character uses a custom layout named `Offhand`. Existing users
  keep all Blizzard layouts unchanged: a healthy exact-span session adopts the
  active custom layout, ambiguous cases can designate it from the Recovery card,
  and legacy profile-scoped recovery state is validated before migration.
- Retail and Anniversary now remember each character's selected Blizzard Edit
  Mode layout instead of forcing every character onto a layout named `Offhand`
  after login. Existing characters adopt their currently active layout on the
  first upgraded session, and later manual selections replace that preference.
- Battleground objective widgets, the live PvP scoreboard and post-match
  results now use secure Mainhand anchors instead of appearing at the center of
  the complete monitor span. Offhand adopts only Blizzard's stock positions and
  leaves existing user/addon placements untouched.
- Companion guidance now distinguishes a missing or stale display-layout
  handoff from a genuine version mismatch. Matching installations no longer
  receive an alarming download prompt, layout guidance appears at most once
  per UI session after display geometry settles, and only confirmed version
  mismatches show the paired Companion download address.
- Forever now preserves supported addon-owned workspace bags through Escape and
  restores them after reload without treating Escape's native `CloseAllBags`
  call as an intentional close. The compatibility path now recognizes both
  Baganator backpack roots and EllesmereUI's `EUI_MainBagFrame`; their own bag
  APIs remain responsible for opening and closing the windows.
- Addon-owned bag snapshots now store the top edge used by Offhand's common
  panel restorer. Beta 18 bottom-edge snapshots are upgraded when the bag root
  appears, preventing map toggles, Escape recovery and reload restoration from
  shifting the bag downward by its own height.
- EllesmereUI's explicit bag-close state now cancels Offhand's open-window
  snapshot, so pressing Escape after closing its bag no longer reopens it. The
  saved workspace position remains eligible for normal reload restoration.
- Escape and Edit Mode transitions remain owned by Blizzard and EllesmereUI;
  Offhand no longer reopens hidden addon bags or ordinary panels from their
  hide/menu callbacks, preventing Game Menu state from becoming inaccessible.
- Moving an EllesmereUI or Baganator bag to Mainhand now retires its stale
  Offhand workspace anchor before map layout repair, so opening or closing the
  World Map cannot move the bag back to the secondary workspace.
- Forever now observes both the M-key World Map and L-key Quest Log entry points
  for their shared `WorldMapFrame`, keeping one saved workspace location.
- Reload recovery for ordinary Blizzard workspace panels is now
  serialized through the native UIPanel lifecycle. Multiple left-slot panels no
  longer close one another before Offhand can detach and restore them. Protected
  Edit Mode frames and automatic Professions opening remain deliberately excluded.
- Companion configuration now uses measured auto-layout columns instead of
  scaling fixed child coordinates. Native spinners, display checklists, and
  combo boxes remain separated and usable at 125%, 150%, and 200% Windows
  scaling with two or more monitors; additional display rows still scroll.
- Forever's opt-in experimental Professions movement now uses an original,
  title-only Offhand adapter around Blizzard's `PanelDragBarTemplate`. Blizzard
  retains the native drag scripts, the grip is securely hidden in combat, and
  Offhand only observes gesture completion for its existing position storage.
  The adapter fails closed if combat-safe visibility cannot be established.
- Ordinary registered Forever Blizzard panels now use that same validated,
  Offhand-owned title-grip adapter instead of enabling mouse input or installing
  drag handlers on the panel body or native title. Protected Edit Mode/HUD
  systems, transient popups, World Map, bags and chat remain on their dedicated
  paths; unavailable secure grip support fails closed.
- The optional Offhand window-chrome controls now include a separate World Map
  enlarge-button toggle, matching NoCloseX without coupling it to the general X
  button option. The native return-to-windowed control is deliberately retained.
- Forever native backpacks remain draggable from the visual title region after
  a clean load. The input surface is an independent `UIParent` sibling rather
  than Blizzard's native title, and mouse input remains disabled on the bag
  root, avoiding recurrence of the grey item-grid overlay.
- Forever's opt-in experimental Professions movement now centers the fully
  opened window on Mainhand when it has no saved Offhand position. This makes
  its drag surface reachable when Blizzard's default upper-left anchor lands in
  the non-physical area of a mixed-height span, without enabling automatic open,
  Escape ownership or reload persistence.
- Forever native backpacks no longer enter Offhand's generic whole-panel drag
  lifecycle when a generated bag temporarily reports itself as unprotected.
  Their external title grip leaves the item grid and native title untouched,
  preventing the item-grid hover shade from remaining over the backpack.
- Forever no longer reopens a saved workspace backpack when Escape is pressed
  after Restore Window or while Offhand is otherwise unspanned. Native backpack
  recovery also never calls `Show()` on a `ContainerFrame`; if Blizzard's bag
  API declines to rebuild the frame, Offhand clears the stale open request
  instead of exposing an uninitialized grey shell whose next hide can error.
- On Forever mixed-height spans, an unsaved World Map opened from the M key is
  now rescued from non-physical canvas space by the existing external toggle
  hook. The recovery does not attach scripts to the protected MapCanvas tree
  and leaves maximized maps under Blizzard ownership.
- Forever now warns once when Blizzard Party or Raid Frames are visible outside
  both physical monitor rectangles. The in-game guidance explains the safe Edit
  Mode recovery through Companion's Restore Window flow and why inaccessible
  protected HUD frames cannot be dragged or gathered while the span is active.
- Forever's load-on-demand Professions interface is now Blizzard-owned by
  default. Offhand no longer changes its panel registration, position or open
  state unless the user explicitly enables the isolated experimental movement
  override. This removes the default behavior from the repeatedly confirmed
  client-crash path.
- `/offhand diag` now reports the client's windowed resolution, render scale,
  resampling quality, and window mode as read-only diagnostics for investigating
  visual degradation after an external span.
- Companion now uses an explicit 96-DPI design baseline with linear DPI
  autoscaling, preventing fixed dashboard panels from clipping enlarged text
  on high-resolution and mixed-scale displays.
- The System Status display-plan diagnostic now has room for three wrapped
  lines, and the auto-span checkbox no longer covers the Span displays heading.
- In-engine cinematics no longer leave the 3D camera centred on the monitor
  seam. Offhand now reapplies only the configured Mainhand viewport after
  cinematic start and completion, including delayed and combat-safe recovery.
- Companion idle monitoring now queries only the allowlisted WoW executable
  names, backs off while WoW is absent, and pauses polling while its window is
  being moved or its Help dialog is open. This avoids broad process-table
  discovery while preserving the low idle CPU and safe stopped-client guard.
- Manual Restore Window now returns keyboard focus to WoW after the bordered
  Mainhand window is established, avoiding a restored client that appears
  unresponsive while the Companion remains foreground.
- Window-border failures now include the native Windows error code and explain
  the common mismatched-privilege case instead of showing only a generic error.
- Companion addon verification now reports the exact path expected by the
  running WoW client and identifies nested, version-suffixed, or sibling-client
  installs instead of repeating a generic installation instruction. It also
  rejects mismatched Companion/addon beta builds before spanning, displays the
  complete diagnostic on the status card, and records it in the activity log.
- Span now stops before resizing WoW when Companion cannot write the selected
  display topology into the running client's Offhand folder, preventing a
  desktop-sized game window with no matching addon viewport geometry.
- Forever workspace maps remain fully opaque while the player moves without
  altering Blizzard's protected map scripts or UIPanel metadata.
- Persisted load-on-demand panels such as Professions are reopened after their
  Blizzard addon registers the frame, instead of being skipped because the
  frame did not exist during Offhand's initial reload restoration pass.
- Load-on-demand panels now wait for Blizzard's native registration/opening
  sequence to settle before reload restoration. This removes a possible
  re-entry into the Forever Beta Professions loader while preserving workspace
  position, open state and the user's panel-persistence settings.
- The seam guide is now vertical for side-by-side layouts and horizontal for
  stacked layouts in both Companion-controlled and manual topology modes.
- Unsaved Blizzard panels now open on Mainhand instead of inheriting a
  UIParent anchor in the Offhand workspace. Explicit Mainhand drops persist
  across close/reopen and reload, while only explicit Offhand drops receive
  Offhand ESC and open-panel persistence behavior. Stale coordinates are
  clamped back onto the visible game monitor.
- Anniversary now preserves an already-selected Blizzard Edit Mode layout by
  comparing its active name, and loads `Offhand` through the correct layout
  index API instead of confusing the global active ID with a manager row ID.
- Auto-Setup Wizard step 2 now places the Mainhand aspect-ratio title above
  its buttons instead of drawing the label across the first button row.
- Calibration Wizard steps 2 and 3 now explain when Companion-owned monitor
  geometry disables their manual controls, and step 3 no longer overlaps the
  Offhand Monitor width label with its alignment instructions.
- The installation guide now resumes at step 4 after its requested `/reload`,
  and its visible copy uses plain punctuation instead of em dashes.
- Classic Era and Anniversary clients now accept Companion topology when their
  resolution API reports only Mainhand but the live UI canvas matches the full
  span; restored single-monitor windows still reject stale topology.
- Frames dragged into any horizontal or stacked workspace now retain their
  final hardware-drag coordinates before Blizzard can restore a native anchor.
  Forever also keeps the frame's user-placed state, preventing valid workspace
  drops from snapping back to the game-view center.
- Load-on-demand Blizzard panels are now discovered dynamically, including
  Forever panels flagged protected, gain an out-of-combat title-bar drag
  handle, and are fitted wholly inside the nearest visible monitor when their
  default anchor straddles a mixed-height display void.
- Forever now anchors Blizzard Options directly to Mainhand instead of relying
  on timing-sensitive void rescue, and keeps a tracked workspace backpack open
  while entering Options from the Game Menu.
- Offhand now leaves `ChatFrame1EditBox` anchored by Chattynator, so pressing
  Enter reveals Chattynator's text input while its window is on the workspace.
- Explicit Offhand chat placements now survive Blizzard's late cold-start
  anchor pass on Retail and Forever while still yielding during Retail Edit
  Mode, preventing the default chat window from returning to Mainhand.
- Companion-controlled layouts now show a concise game/workspace summary in
  settings, explain why manual geometry is locked, and no longer overlap that
  status with the redundant Companion download button.
- Companion retries inaccessible WoW executable paths through
  `QueryFullProcessImageName`, recognizes every supported Offhand TOC, and
  diagnoses an accidental `Offhand/Offhand` addon installation directly.
- Companion now keys saved selections to physical monitor identities instead of
  renumberable Windows `DISPLAY#` labels. Existing installations require one
  confirmation before automatic spanning resumes, preventing a stale label from
  silently swapping Mainhand and workspace.
- Restored settings panels now resynchronize the master enable checkbox and all
  displayed values from the active profile whenever shown.
- Exact portrait-plus-landscape topology is no longer mislabeled or saved as
  dual landscape. The settings panel and wizard now explain that Companion owns
  exact monitor geometry while those manual controls are disabled.
- Forever no longer replaces Blizzard's global window/bag close functions or
  mutates secure panel-manager metadata. This closes the remaining taint paths
  behind reported `CompactUnitFrame` and `TextStatusBar` secret-number errors.
- Blizzard Cooldown Viewer and other Forever Edit Mode-managed frames are now
  excluded from generic dragging, saved-position recovery and void rescue,
  preventing aura-table taint after display-orientation changes.
- Forever leaves the Game Menu and protected Edit Mode systems under Blizzard
  ownership. If the unprotected Edit Mode control window opens in mixed-height
  display void, a player-click prompt can move only that window to Mainhand.
- Forever workspace maps again remain open through Escape and reopen after
  reload without replacing protected `OnShow`/`OnHide` scripts. Map dragging is
  now provided by an independent Offhand-owned surface: no handler or addon
  bookkeeping is attached to the native map, title container, title button, or
  close button. This protects both quest-pin acquisition and the yellow `Map Pin
  Sharing` waypoint's Shift-click chat-link action while preserving map
  movement and persistence.
- Forever now honors the configured manual split and allows the calibration
  wizard to complete when Companion topology is absent. A present but
  mismatched Companion topology still fails safe to a normal full-window
  viewport, preserves workspace panel state, and offers the player-click
  Modern/Offhand Edit Mode handoff so protected HUD elements cannot remain in
  black void.
- Forever Edit Mode recovery now matches the `Offhand` layout name without case
  sensitivity and re-resolves that name before restoration when its local custom
  layout slot differs from the previously remembered ID.
- Chat-tab persistence now observes Blizzard's native drag lifecycle without
  forcing locked or docked chat frames into a movable state, avoiding the
  `ChatFrame1:StartMoving(): Frame is not movable` error on Forever.
- Retail now leaves the primary chat frame under Blizzard Edit Mode ownership
  while it is on Mainhand, preventing saved layouts from snapping the frame
  upward or restoring stale Offhand coordinates after Edit Mode closes. An
  intentional workspace placement is captured after Edit Mode exits, and the
  native channel/menu button strip is reattached through Blizzard's layout API.
- Combined and individual backpack modes now share one tracked workspace
  position, discard stale coordinates from the inactive presentation, and
  prepare the new native bag root before Blizzard opens it. This prevents bags
  from disappearing after switching modes and avoids Retail's combined-bag
  toggle assertion.
- Retail panel transitions no longer reopen the world map as an unintended
  side effect of opening another Blizzard panel.
- Blizzard Edit Mode frames, including the native Damage Meter, are now
  excluded from generic centering and dragging on every supported client. This
  preserves Blizzard's secure initialization while retaining the explicit
  player-click recovery prompt for an Edit Mode control window in display void.

## [2.1.2] - 2026-09-22
### Added
- Added an opt-in **Hide close buttons on Offhand windows** setting. Supported
  Blizzard, Baganator and EllesmereUI close buttons become transparent and
  non-interactive only while their visible parent window is in the Offhand
  workspace, and are restored on Mainhand or when the option is disabled. The
  controller uses polling rather than attaching scripts to protected Blizzard
  controls.
- Added durable Forever onboarding state and Companion recovery so acknowledged welcome/setup state survives reloads and cold launches.
- Expanded the in-game FAQ, first-run guide, website, and distribution documentation with the complete Companion, Wizard, Edit Mode, and cold-launch setup flow.
- Added Companion control tooltips, an in-app setup/help guide, a security behavior disclosure, release SHA-256 verification instructions, and GitHub build-provenance attestations.
- Added exact Companion-to-addon game/workspace rectangles, an explicit Mainhand selector, stable Windows display identities, and an opt-in one-screen 32:9/32:10 split.
- Added automated coverage for reordered, missing, mixed-resolution, negative-coordinate, stacked, ultrawide-split, and stale-topology display states.

### Changed
- Companion automatic spanning is now disabled by default on fresh installs while preserving existing saved choices.
- Replaced automatic startup update traffic with an explicit **Check for Updates** action.
- Replaced the oversized embedded Companion artwork with the supplied 64×64 asset, reducing the executable from roughly 2 MB to roughly 250 KB.
- Companion release archives now include their exact C# source, manifest, build script, artwork, and security documentation.
- Normal spanning now requires exactly two selected displays; one display is accepted only with explicit super-ultrawide split mode. More than two are rejected until multi-workspace semantics are designed.
- Workspace placement, panel clamping, maps, bags, chat, popup rescue, and seam guides now use a full rectangle instead of a left/right deck-width assumption.
- Fresh addon profiles remain inert until the setup wizard enables Offhand.

### Fixed
- Disabled and temporary single-screen profiles no longer change tooltip scale,
  override another addon's tooltip parent-scale choice, or rewrite Blizzard bag
  anchors during logout. This protection applies across Retail and Classic clients.
- Fixed the Welcome to Offhand popup returning after it was acknowledged or after the setup wizard was completed.
- Fixed Forever workspace panels and Blizzard Edit Mode controls drifting or becoming inaccessible after window spanning and full client restarts.
- Fixed mixed-resolution and stacked layouts being treated as equal-height side-by-side screens, which caused overlap, squashed game views, and black bars.
- Fixed disconnected displays silently collapsing a saved dual-monitor span onto one screen and shrinking the UI to an unreadable size.
- Fixed a disconnected workspace leaving a previously spanned WoW window partially outside the surviving display; Companion now restores a bordered window that fills the surviving Mainhand work area.
- Fixed **Restore Window** returning WoW to a stale position on the workspace display; manual recovery now fills the selected connected Mainhand.
- Fixed display selectors remaining stale when a monitor is connected or disconnected after Companion starts; the controls now refresh without discarding saved device identities.
- Fixed vertical camera movement eventually stopping while right-button mouse-look remained held on mixed-height shaped spans. Offhand now manages raw mouse input only while spanned and restores the player's previous setting afterward.
- Fixed the missing-workspace Edit Mode prompt appearing during the brief normal-launch interval before a manual Companion span; recovery now requires a sustained topology mismatch and cancels stale prompts when the saved topology arrives.
- Fixed Forever retaining its spanned protected-HUD Edit Mode layout after a display disconnect. Because Forever only accepts this protected layout change from a hardware event, Offhand now presents player-click **Use Modern** and **Restore Offhand** recovery prompts without overriding a manual choice.
- Fixed a consumed Forever recovery bridge overwriting newer SavedVariables again on `/reload`.
- Fixed Forever reverting newly changed options and profiles during `/reload`. A bounded, checksummed session snapshot now restores complete Offhand account and character state only when the standard SavedVariables revision is stale; normal loading automatically remains authoritative after a client-side fix.
- Fixed map, character, bag, and chat windows remaining unreachable on a temporary single-screen setup while preserving their saved Offhand positions for reconnection.
- Fixed 32:9 Mainhand displays being constrained by the legacy 16:9/21:9 resolution heuristic.

## [2.0.0] - 2026-09-20
### Added
- **Multi-Monitor Support:** Added full support for complex 3 and 4 monitor setups, including a dedicated monitor selection interface in the Companion App to choose exactly which screens to span.
- **Vertical Stack Support:** Added full support for vertically stacked monitor configurations (Top/Bottom) to both the Addon and Companion App.
- **Auto-Updates:** Added an automatic update checker to the Companion App to notify you when new releases drop on GitHub.
- **Enhanced Heuristics:** The 1-Click Auto-Setup Wizard now automatically detects irregular ultra-wide spanned resolutions and suggests the correct monitor aspect ratio.

### Fixed
- **World Map Dimming:** Fixed a major issue where the World Map would forcefully fade, dim, or close itself while your character was moving during combat.
- **Process Detection:** Expanded Companion App executable detection to reliably hook into any WoW client regardless of region, executable name, or PTR status.

## [1.0.1] - 2026-09-19
### Fixed
- Fixed a critical issue where the WoW client could permanently save the squished 3D viewport dimensions to its internal layout cache if the addon was disabled or uninstalled. Offhand now gracefully restores the WorldFrame back to full screen milliseconds before the game shuts down or reloads.

## [1.0.0] - 2026-09-18
### Added
- Initial public release of Offhand - Dual-Monitor Workstation!
- Intelligent 3D viewport rendering to restrict the game world to your primary monitor.
- Companion App for Windows to achieve flawless, borderless window spanning.
- 1-Click Auto-Configuration Wizard for instant calibration.
- Full support for Retail, Classic Era, Progression Classic, and WoW Forever.
