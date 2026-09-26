# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed
- Addon settings and Companion now identify the exact `v2.1.2-beta.11`
  pre-release build while retaining `2.1.2` as the compatible base version.
- Companion display-plan and activity-log messages now wrap instead of drawing
  long missing-monitor diagnostics outside their cards.
- Companion's Hotkey selector is narrower so it no longer covers the monitor
  checklist when three or more displays are connected.
- Companion documents an experimental same-prefix, same-runner Wine path,
  including a Lutris pre-launch example and Linux extraction checks, while
  keeping native X11 and compositor-specific Wayland support as separate work.
- Release ZIPs now use portable forward-slash entry paths so Linux extractors
  preserve the addon directory tree without a custom deflattening script.
- The executable in the complete release bundle is now consistently named
  `Offhand.exe`, matching the standalone file and Companion archive.
- Release automation now builds the Companion once, reuses that exact executable
  in every release container, and verifies each embedded copy against the
  canonical SHA-256 before publishing.
- Companion can now be explicitly registered for current-user Windows startup;
  startup launches one instance minimized to the notification area without a
  service, scheduled task, administrator access, or Battle.net modification.

### Fixed
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
- Companion now compares its Windows integrity level with WoW before Span or
  Restore, suppresses repeated automatic attempts when elevated WoW cannot be
  controlled, and exposes copyable, path-specific recovery steps in System
  Status. Unknown Wine integrity remains a non-blocking diagnostic.
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
  reload. Offhand now vacates Blizzard's active panel slot without temporarily
  replacing protected `OnShow`/`OnHide` scripts, preventing the reported quest-
  pin `Button:SetPassThroughButtons()` taint while preserving map persistence.
- Forever now fails safe to a normal full-window viewport when exact Companion
  topology is absent, including after Restore Window. The same recovery flow
  preserves workspace panel state and offers the player-click Modern/Offhand
  Edit Mode handoff so protected HUD elements cannot remain in black void.
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

## [2.1.2] - 2026-09-22
### Added
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
