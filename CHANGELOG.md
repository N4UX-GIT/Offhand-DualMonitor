# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed
- Added an initial compatibility target for the original WoW 3.3.5a client
  (`Interface 30300`). A legacy-only runtime adapter supplies the timer and
  physical-window primitives used by Offhand, while Backdrop and visibility
  code now falls back to APIs available in Wrath. This target remains
  experimental until exercised on a real 3.3.5a client.
- Companion 2.1.2 Beta 19 is the next desktop candidate. Addon manifests now
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
- Addon-only release automation now restores the published Beta 18 Companion,
  verifies its exact SHA-256, and reuses those frozen bytes in the complete
  bundle and the stable `releases/latest/download` asset names. Rebuilding the
  Companion still requires an explicit Companion-change release lane.
- Companion no longer creates a Windows Run-key startup entry or inspects
  process security tokens. Removing these nonessential beta.11 additions
  reduces overlap with generic antivirus heuristics while retaining the
  Companion's required window-management behavior.

### Fixed
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
- Group-loot rolls now use the restricted secure Mainhand positioner and no
  longer receive Offhand event scripts, keeping the roll UI out of the monitor
  seam without adding an insecure hook to Blizzard's loot path.
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
