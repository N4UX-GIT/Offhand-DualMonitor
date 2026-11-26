# Bridge modules and contract

This document describes the contract between Offhand's core and bridge
integrations (both built-in bridges shipped inside `Offhand/Bridges/` and
optional third-party external bridge addons). The registry and public services
live in [Core/Bridges.lua](../Core/Bridges.lua); when this document and that
file disagree, `Core/Bridges.lua` is authoritative.

Bridge architecture originally contributed by **Kintrok (`@DCtheGeek`)** in
PR #136 and adapted for single-folder packaging inside `Offhand/`.

## 1. What a bridge is

A bridge adapts one third-party addon to Offhand. It holds everything Offhand
needs to know about that addon: frame names, hooks into its internals, its
saved settings, and its own map, bag, or layout handling.

No file under `Core/`, `UI/` or `Modules/` (nor `Bindings.xml`) names a
third-party addon: every addon specific lives in `Bridges/<Addon>/`. The core
calls registered bridges at fixed points inside `pcall`, reads the facts they
declare (section 3.1), and offers a small `Offhand.API` service surface. The
final purity scan in `tests/bridges-contract.lua` enforces this, with its
justified exceptions listed in the test (`Locales/*.lua` keep player-facing
text and key names).

## 2. Built-in layout and packaging

Built-in bridges ship inside the single base `Offhand/` addon folder (no
sibling addon folder, no separate TOC, no required `## Dependencies:`, and no
extra `SavedVariables` file):

```
Bridges/<Name>/*.lua
Bridges/<Name>/README.md   (repo docs only; packaging copies only *.lua)
```

Built-in bridge `.lua` files are listed at the end of all six `Offhand*.toc`
manifests (preserving identical load lists across flavors, with the shared
helper of section 6 first and the DaylightUI block last) and check at file
load whether their target addon is present. When the target addon is not
installed or enabled, the bridge exits immediately with zero frames, hooks,
slash commands, or runtime overhead. `Offhand_Forever.toc` may list the target
under `## OptionalDeps:` (never `## Dependencies:`) purely to guarantee load
order when installed.

External third-party addons can still register against the exact same
`Offhand.API.RegisterBridge(id, bridge)` contract (version `1`).

## 3. Registration

```lua
local Offhand = _G.Offhand
local API = Offhand and Offhand.API
if not (API and API.BRIDGE_CONTRACT == 1 and API.RegisterBridge) then return end

local bridge = { contract = API.BRIDGE_CONTRACT }
function bridge:Refresh(reason) --[[ ... ]] end

local ok, problem = API.RegisterBridge("MyAddon", bridge)
```

`Offhand.API.RegisterBridge(id, bridge)` returns `true`, or `false` and one of:
`"id"`, `"bridge"`, `"contract"`, or `"duplicate"`.

If `bridge.catalog` is a table, registering the bridge attaches it under
`Offhand.AddonWindowCatalog[id]` automatically. If `bridge.data` is a table it
is merged as addon data for `id` (section 3.1). If `bridge.mapProvider` is a
table with a non-empty `owner`, it becomes that world map owner's provider for
`Bridges:CallMap` (the first bridge to claim an owner keeps it). If
`bridge.bagProvider` is a table it joins the bag providers (section 4), sorted
by its `order` (unordered last) then registration.

### 3.1 Addon data

`Offhand.API.RegisterAddonData(addon, data)` merges plain facts once into
lookup tables in `Core/Bridges.lua`. It creates no bridge (nothing in
`Bridges:List()`), so it may run unconditionally on every client. It returns
`true`, or `false` and `"id"` or `"data"`. The same data table merges only
once. Only a detector's `active` and a matcher's `verify` run in `pcall`, and
only after the declarative part passed; a throw counts as false and is
recorded in `Offhand.Bridges.errors[addon]`. Both must return a literal `true`.

A *detector* is a table whose given fields must all pass: `loaded="Folder"`
(IsAddOnLoaded, called directly), `global="Name"` (`_G[Name] ~= nil`), `present="Name"` (either),
`anyOf={detector, ...}`, `forever=true` (Forever client), `active=function()`.
No detector means present.

A *frame matcher* selects a frame by any one of `names={...}`, `patterns={...}`
(on the name), `identity={"Global", ...}` (`frame == _G[Global]`),
`widget={global, key}` (`rawget(_G[global], key) == frame`),
`index={global, key}` (`_G[name] == frame` and `_G[global][name][key] == name`),
`field="key"` (`frame[key] ~= nil`), `fieldTrue="key"` (`frame[key] == true`),
then requires every qualifier: `when=detector`, `parent="GlobalFrame"`,
`verify=function(frame, name)`. A plain string is a name. Name-only matchers
compile into one set.

| Key | Shape | Read by |
| --- | --- | --- |
| `ownership` | Array of `{ role, name, order, detect, ... }`, sorted by `(order, registration)`, unordered last | `Bridges:HasRole(role, accept)`, `Bridges:GetRoleOwners(role, accept)` (names, entries; `accept(entry)`, when given, is the caller's own test of a present entry's facts, called directly), `Bridges:FirstRoleOwner(role)` (name, entry), `Bridges:GetRoleEntries(role)` (every entry, present or not), `Bridges:GetRoleEntry(role, name)` (the first entry of that name, present or not) |
| `frameRules` | `{ [rule] = { matcher, ... } }` | `Bridges:MatchFrame(rule, frame, name)`, `Bridges:MatchName(rule, name)`, `Bridges:GetRuleNames(rule)` (literal names, qualifiers not evaluated), `Bridges:GetRuleWidget(rule)` (the frame the first resolving `widget` matcher holds and that holder's global name, qualifiers not evaluated) |
| `moverFields` | `{ movable = { "field" }, moving = { "field" } }` | `Bridges.IsExternallyMovable(frame)` (a field `== true`), `Bridges.IsExternallyMoving(frame)` (a field set) |
| `catalogs` | `{ [addonFolder] = catalog }` | Merged into `Offhand.AddonWindowCatalog[addonFolder]` (the core file holds only the empty table) |
| `windows` | `{ sourceless = { name }, names = { name }, patterns = { pattern }, owners = { addonFolder }, headerDrag = true, openers = { slash = { key }, globals = { key }, methods = { { get = function, key } }, links = { { link, when = detector } } } }` | The addon window Escape adapter (`Core/CanvasAddonEscape.lua`) through `Bridges:IdentifyWindow(frame, name, readSource)`: a `sourceless` name calls that bridge's `IdentifyWindow(frame, name, nil)` before the source is read; a listed name, or a matching pattern (patterns in registration order until one answers), calls it with the source and only when `readSource(frame)` returns one. The first addon listing a name or owner keeps it, and no other bridge is called. `Bridges:GetWindowCloseButtons(frame, owner, name)` and `Bridges:WindowUsesHeaderDrag(owner)` (the root's `header` drags are observed too) ask the bridge listing `owner`. `Bridges:ObserveWindowOpeners(kind, observe)` hooks openers by kind (`slash`, `globals`, then after Offhand's own options, `methods`, whose `get` runs in `pcall`) in registration order; `Bridges:HasWindowOpenerLinks()` (a link's detector passes) installs one `SetItemRef` observer, and `Bridges:IsWindowOpenerLink(link)` tells its links apart |
| `parkedReason` | A string | The reason `Bridges:IsParkedNativePanel(frame)` returns second (and the Gamepad panel status shows) for a panel parked by that addon's bridge or `parkedNativePanel` matchers; `bridge-parked` without one |
| `settings` | `{ [key] = { store = "profile" or "character", legacyKey, default, resetOnCharacterChange } }` | `Offhand.API.Get/SetBridgeSetting`, `Get/SetBridgeCharacterSetting`, `Bridges:GetSettingDefaults()`, `Bridges:GetCharacterResetKeys()`, `Bridges:GetSettingKey(key)` (the stored profile key of the first addon declaring `key`, for a record core reads by its declared name) |
| `guidance` | Array of `{ id, order, addon, when = { [ownersList] = name }, key, fallback, args = 2, suffixWhen = detector, suffixKey, suffixFallback }`, sorted like ownership | `Bridges:GetGuidanceEntries()` (entries, and per entry whether `suffixWhen` passes); `CanvasCompatibility.GetExternalControlGuidance` shows an entry when a `when` name is in that list of `GetActiveExternalOwners()`, as `L[key] or fallback`, formatted with `addon` twice when `args = 2`, plus `" " .. (L[suffixKey] or suffixFallback)` |
| `diagnostics` | Array of `{ slot, order, label, present = "Folder" }`, `{ slot, order, label, value = function() }` or `{ slot, order, label, detect = detector, text, absent }`, sorted like ownership | `Bridges:GetDiagnosticSegments(slot)` (entries, and per entry whether its `detect` passes); slot `minimap`: `label:yes/no` (present) or `label:value` in the minimap visibility report; slot `chat`: present labels joined as `ChatProviders=`; slot `panelPlacement` (entries also carry `frame = "GlobalName"`): ` | label=value` appended to that root's panel placement diagnostics line (`unavailable` when the value fails or is not a string); slot `compat.tail` (value entries): ` | label=value` at the very end of the compatibility diagnostics, after the bridges' `GetDiagnostics` segment (`unavailable` likewise); slots `compact` (after `WorldMapOwner=` in the compact compatibility line), `compat.head` (before `WorldMapOwner=` in the full line) and `compat.map` (right after it): ` | label=text`, where a `detect` segment shows `text` (default `loaded`) while it passes, else `absent` (skipped without one), and a `value` function gets the last external map coordinate font refresh count |

Roles and rules core reads:

| Role or rule | Read by |
| --- | --- |
| `hud.controller` | Every controller site: an owner present means an external controller addon owns the protected controller HUD, so Offhand's native Gamepad placement, controller Edit Mode layouts, learned windows, addon window Escape handling and toggle keep-open stand aside; `Offhand.API.IsControllerOwned()` |
| `hud.actionBars`, `hud.statusBars` | `HUDCompatibility.HasCustomActionBarAddon`, `HasCustomStatusBarAddon`, and the Edit Mode ActionBar and StatusTrackingBar systems |
| `hud.minimap`, `hud.chat` | `HUDCompatibility.HasCustomMinimapAddon`, `HasCustomChatAddon`, and their Edit Mode systems |
| `hud.partyFrames` | `HUDCompatibility.HasCustomPartyFrames` (party and raid frames); the first owner's `noticeKey` is the missing-layout notice |
| `hud.unitFrames`, `hud.groupFrames`, `hud.cooldownViewer`, `hud.objectiveTracker` | `HUDCompatibility.IsExternallyOwnedEditModeSystem`: unit frame systems, party and raid systems (with `hud.partyFrames`), CooldownViewer, ObjectiveTracker |
| `hud.layoutSignature` | The saved HUD layout ownership signature: present owner names joined with `:` in role order (the stored strings depend on it), then `native-status` when an owner with `statusOwner = true` is present but status bars are not externally owned; a new owner matching a `suitePattern` counts as that suite gaining ownership |
| `hud.editModeBlocker` | Edit Mode HUD recovery (`Core/Recovery.lua`) skips its rebuild |
| `report.actionBars`, `report.unitFrames`, `report.chat`, `report.movers` | Owner lists of `CanvasCompatibility.GetActiveExternalOwners()`, in role order, each name once |
| `report.minimap` | The compatibility report's minimap owner (first present owner) |
| `map.owner` | `CanvasCompatibility.GetWorldMapExternalOwner()`: the first present owner owns World Map geometry (the owner names are observable in diagnostics and conflict ids). Its entry's facts: `positionsMap = true` (the owner positions the map: `IsExternallyPositionedWorldMap`), `escapeProtection = true` or `"forever"` (Offhand keeps Escape protection for the map, on every client or on Forever only), `bootstrapsAnchor = true` (Offhand bootstraps only an anchorless shown map), `gamepadNative = true` (under the Gamepad UI a map whose `Maximize` is still Blizzard's is Offhand's), `label` (the report's display name) |
| `map.fade` | `CanvasCompatibility.GetWorldMapFadeAddon()`: the first present owner handles the map's movement fade (Options description from its `helpKey`, zone refocus). Entries with `read` join the Forever workspace map fade override in role order: `read(map)` returns the addon's settings table and, while the addon holds `mapFade` itself, a holder; `key` is the preference set to `opaque` while the map is on the workspace and restored after; `refresh(holder)` re-enables the addon's fader after a release |
| `map.layoutGuard`, `map.blocksCombatAnchorRepair` | The Forever map observer installs the first present owner's position guard (`InstallPositionGuard`, then `UpdateLayout`); a present owner keeps the compact map's combat anchor repair away |
| `map.cameraOwner` | An addon that drives the map camera itself: the Forever map follow runs (through the owner's `UpdateFollow`) and zone changes do not refocus the map |
| `map.integration` | The map integrations diagnostics: every entry in role order, reported while loaded, with the version from the `versionNamespace` table first; then the bridges' `mapAddons` |
| `map.blocksPanelManagement`, `map.blocksSlotRepair` | `CanvasCompatibility.HasPanelManagementOwner()` (native panel origin, cold combat panel loads, combat clamps and anchor repair stand aside) and `HasPanelSlotRepairOwner()` (default native slot repair stands aside) |
| `map.configurationOwner` | `CanvasCompatibility.HasWorldMapConfigurationOwner()`: Offhand's World Map configuration and TBC cursor conversion stand aside |
| `panels.externalOwner` | `CanvasCompatibility.ShouldYieldFrameToExternalOwner(frameOrName)`: the first present owner's `frames` (an array of names) keep their own movement, drag, persistence and recovery; `Canvas:RelinquishExternalOwnerFrames()` hands them back |
| rule `diagnosticFrame` | Extra roots in the panel placement diagnostics, after core's own |
| rule `parkedNativePanel` | `Bridges:IsParkedNativePanel(frame)` after the bridges' own `IsParkedNativePanel` callbacks (tested without a name): a native panel the addon parks under its own holder, which core's placement, auto-open, HUD ownership and Gamepad passes leave alone |
| rule `workspaceChrome` | `WorkspaceChrome`: addon windows whose close buttons are hidden while on the workspace, beside core's own names |
| `tooltip.owner` | `PopupBounds`: the first present owner positions tooltips itself, so Offhand's tooltip fitting yields and the diagnostics name it |
| rule `preservePopup` | `HUDCompatibility.ShouldPreservePopupPosition`: automatic popup recovery leaves a matched frame where its addon put it, before the user-placed test |
| rule `externalHUD` | `HUDCompatibility.IsExternallyOwnedHUDFrame`: a matched frame is vendor HUD the generic popup and workspace passes leave alone |
| rule `menuFrame` | Menus centred on Mainhand like the Blizzard menus, after the Blizzard names |
| rule `yieldNativeContainer` | `CanvasCompatibility.ShouldYieldNativeContainer`: for a native container name (`ContainerFrameCombinedBags`, `ContainerFrame<n>`), a match yields its drag, persistence, layout and recovery |
| rule `recoverableGuide` | `HUDCompatibility.GetPreservedAnonymousRoot()` (`GetRuleWidget`): an anonymous addon root that missing-window recovery may bring back, reported under its widget's name |
| rule `vendorGameplay` | `CanvasAddonEscape:IsVendorGameplayFrame(frame, name)`: a frame its addon positions and shows itself; Offhand never saves, gathers or repairs its placement. Its matchers are listed under `preservePopup` as well |
| rule `unsavedPosition` | `Config`: no Forever position record for these names, and their records are scrubbed from every profile (`GetRuleNames`) |
| rule `minimapDiagnosticFrame` | The minimap visibility report: these names follow `MinimapCluster` and `Minimap`, present or not (`GetRuleNames`) |
| `moverFields` | Panel anchor repair, workspace repair and the Forever Game Menu placement: a movable frame's TOPLEFT/UIParent/BOTTOMLEFT write is repaired before render; a moving frame is never repaired |
| `hud.bags` | `HUDCompatibility.HasCustomBagAddon`: a present owner replaces the bags (before a bridge's live `GetBagFrames` and the native-root fallback); an entry with `yieldsToNativeGamepad = true` stands aside on Forever under the native Gamepad interface |
| `report.bags` | `CanvasCompatibility.GetActiveBagOwners()`: present owners in role order (the same Gamepad stand-down), then a bridge's live bag id; the order is part of the `bags-conflict:a+b` id |
| `bags.selfRestoring` | The reload bag reopen stands aside for an addon that restores its own bag roots |
| rules `bagNamespace.openScan`, `bagNamespace.logoutScan`, `bagNamespace.recoveryAnchor` | Replacement bag name patterns of the reload reopen scan, the logout open-state capture and the single-screen recovery bag anchor (three lists that differ on purpose) |
| rule `bagRestorable` | `CanvasBackpackState.IsRestorableRootName`: replacement bag roots that may reopen bags on reload, after the native roots |
| rule `customBagRoot` | Workspace window lock: a replacement bag root of type `bags` whose open state goes to the custom bag workspace record |
| rule `selfManagedBag` | `CanvasCompatibility.IsForeverSelfManagedBag`: on Forever these bag roots own their visibility, layout and Escape proxy, so the generic panel passes leave them alone |
| setting `customBagWorkspacePanels` | The custom bag workspace record (the open replacement bag root's position), read by `Core/BagPersistence.lua`, `Core/CanvasPanelPlacement.lua`, `Core/WorkspaceBehavior.lua` and `Core/WorkspaceChrome.lua` through `Bridges:GetSettingKey`; without that setting there is no record |

Settings live under the same key as before (`legacyKey`, else `key`) in
Offhand's profile settings or `OffhandCharDB`, so nothing migrates. A read of an
unset key gives `default`; an undeclared key, or one of the other store, reads
`nil` and does not write. A character write never creates `OffhandCharDB`.
Profile defaults (`Bridges:GetSettingDefaults()`) join Offhand's own defaults
when the configuration is initialized, so a fresh profile stores them as before.

## 4. Callbacks the core makes

Every callback is optional and runs inside `pcall`:

| Method / Field | When called | Return value |
| --- | --- | --- |
| `Refresh(reason)` | `"layout"` (`Canvas:UpdateLayout`), `"map"` (`Canvas:ConfigureWorldMap`), `"persistence"` (`Canvas:UpdatePersistenceBehavior`), `"tick"` (Forever 0.5s ticker; can run in combat) | Ignored |
| `PrepareTransition()` | Once per reload or logout teardown, before the workspace capture and whether or not it runs | Ignored |
| `BeginSession()` | Every `PLAYER_ENTERING_WORLD` (login, reload, zone change), before any workspace restore | Ignored |
| `RefreshScale()` | Every full layout pass, right after Offhand applies its global UI scale and before the viewport updates | Ignored |
| `InitializePopupWindows()` | Once, when the popup bounds handling initializes (a bridge may start observing its addon's presentation windows) | Ignored |
| `GetSetupNotes(context)` | `Bridges:GetSetupNotes(context)` for an onboarding moment: `"before-span"` (the span step's instructions) | Non-empty string, or `nil`; the answers are joined by a blank line in registration order |
| `OwnsFeature(feature)` | `Bridges:OwnsFeature(feature)`: `"chatBubbles"` in the chat bubble replacement decision, not per frame | Literal `true` when the addon handles the feature itself; `OwnsFeature` returns the first such bridge id (the chat bubble diagnostics' `replacementConflict`), else `nil` |
| `RefreshBags(services)` | Forever bag Escape pass (at bag provider order 60) with `{ UpdateEscapeRegistration, IsEscapeRegistered, CanSuppressVendorClose, IsGameMenuBagClose, IsSettingsBagClose, IsPaused, TrackEnabled, IsSpanned, InputReserved, CanOpenBagsFromAddon, IsFrameOnWorkspace, CloseParkedNativeBags, KeepsIndependentPanels }` | Ignored |
| `GetDiagnostics()` | Compatibility diagnostics report | Non-empty string or `nil` |
| `GetDebugDiagnostics()` | `/offhand diag debug` only, printed as `<label> diagnostics: <text>.` | `label, text` (both non-empty strings; `text` may be an array of strings, one line each) or nothing |
| `GetOwnershipConflicts(context)` | `CanvasCompatibility.GetOwnershipConflicts()`, with `{ mapOwner, mapLabel, positionsMap, bagOwners, SyncsWorldMapMover() }` (`SyncsWorldMapMover` asks the map owner's provider, Forever only) | Array of conflict tables (`id`, `kind`, and the fields `FormatConflictMessage` reads), each with an `order`; core sorts them with its own: the map owner's contract notice at 10 and the multiple bag addon conflict at 30 |
| `GetMoverDiagnostics(context)` | The full compatibility diagnostics line, after the map owner's part, with `{ mapOwner, positionsMap, SyncsWorldMapMover() }` (on every client) | Non-empty string, appended as ` | text` |
| `RefreshAddonOptions(getMetrics)` | Forever: every popup layout pass and after combat; `getMetrics()` returns the options metrics (nil while Offhand is off or not spanned), read at most once per pass | Ignored |
| `ShouldPreserveSingleScreenPosition(frame, metrics)` | Single-screen recovery for saved workspace panels | Literal `true` to preserve vendor placement |
| `GetBagFrames()` | Workspace bag toggle check | Table of bag frames |
| `IsEditModeActive()` | Before learned-window selection or refresh | Literal `true` to pause Offhand selection |
| `IdentifyLearnPlacement(frame, name, file)` | Learned-window opt-in check for cataloged bridge frames | Role string matching `bridge.catalog[role].learnPlacementFile` |
| `IdentifyWindow(frame, name, source)` | Addon window Escape and learned-placement checks, only for a name or pattern in the bridge's `data.windows` (section 3.1); `source` is the lower-case source location with `/` separators, or `nil` for a `sourceless` name | `owner, role` (an addon folder in `Offhand.AddonWindowCatalog` and its role), or `nil` |
| `GetWindowCloseButtons(frame, owner, name)` | Workspace close buttons of a root identified for an owner the bridge lists | Array of buttons |
| `RetireStalePlacements(services)` | Each addon window Escape refresh while it is active, before openers are observed, with `{ HasPlacement(name), IsVendorGameplayFrame(frame, name), ForgetPosition(name), ForgetOpen(name) }` over the active profile; open panels are saved once afterwards if one was forgotten | Ignored |
| `IsExternallyOwnedFrame(frame, name)` | `HUDCompatibility.IsExternallyOwnedHUDFrame`, so generic popup rescue and panel movement skip a vendor HUD root the bridge places itself | Literal `true` to keep core away from the frame |
| `IsParkedNativePanel(frame)` | `Offhand.IsBridgeParkedPanel(frame)`: panel placement, auto-open, HUD ownership and Gamepad destination passes, before the `parkedNativePanel` rule | Literal `true` while the addon parks that native panel under its own holder (the bridge's `data.parkedReason` is reported) |
| `RefreshTransientFrames(phase)` | With the Mainhand transient passes: `"hook"` (discovery) and `"position"` (placement, ahead of core's own popups and alerts) | Ignored |
| `GetSettingsContributions(slot)` | `Bridges:GetSettingsContributions(slot)` for an Options slot (`map`, `alerts`, `recovery`, `help:EDIT_MODE`, `mapScaleTitle`, `mapDescription`) | Array of `{ id, kind, text, tooltip, get, set, onClick, shown, width, height, order }`; entries without an id are dropped, the rest sorted by `order` then bridge order. Slot `mapScaleTitle` renders `kind = "suffix"` entries (`text` after the Map Scale title, `help` as its tip), `mapDescription` `kind = "prefix"` entries (`text` and a space ahead of the map description) and `kind = "fallback"` entries (off Forever, the first whose `addon` is loaded and enabled replaces the default description with `text`) and `map` `kind = "button"` entries (24 high, below the description, each `height` (default 30) under the previous, `tooltip` titled `text`, `onClick()`), each only while `addon` is loaded and enabled for the character and the World Map owner is `owner`. Slot `alerts` renders `kind = "check"` entries (with `get` and `set`) as checkboxes below the redirect option, titled `text` with tooltip `tooltip`, each row `max(height, wrapped text at width + 14)` high (defaults 32 and 600). `addon = "Folder"` shows an entry only while that addon is loaded and enabled for the character, and that addon's `ADDON_LOADED` refreshes the card; `help` is added to the card's help while the entry is shown |
| `mapProvider` | `Bridges:CallMap(owner, method, ...)`: one `pcall` into the provider of the owner the caller resolved. Methods core calls: `UpdateFollow(map, state)` (every 0.5 s while a `map.cameraOwner` is present and the map shown; `true` once handled, else core clears `state.u`), `GetScaleRange()` (`max, step` of the map scale setting), `ReadScaleOption()` (Forever: `option, settings, value, key`; Map Scale calls `option.set({key}, value)`), `HandlesExpandedMap()`, `CanRecover()`, `Recover(workspace)` (`moved, reason`), `ReportRecoveryFailure(reason)`, `ObserveUserDrag(map)`, `HandlesFullscreen()` (standard UI), `GetContractConflict()` (Forever: a conflict table), `FormatConflict(conflict)`, `SyncsWorldMapMover()`, `GetOwnerDiagnostics()` (Forever: appended as ` | text` after the bag part of the compatibility line), `RefreshCoordinateFonts(map)` (owner of `map.configurationOwner`, after a live span and outside combat: the number of labels refreshed), `InstallPositionGuard(map, state, services)` and `UpdateLayout(map, state, shown, maximized, services)` (owner of `map.layoutGuard`; the map state fields `layoutGuard`, `layoutOpened`, `layoutPending` and `layoutPlacement` are shared with the observer, and services are `NativeGamepadOwnsMap`, `ShouldYieldWorldMap`, `IsDragging`, `GetWorkspaceMetrics`, `GetSavedMapPositions`, `IsPosition`, `ForFrame`, `FitWindow`, `GetPanelPhysicalPlacement`, `ResolveWorkspacePosition`, `ClampWorkspacePoint`) | The method's own results; nothing when absent or failing |
| `bagProvider` | Functions called without `self`. `RefreshEscape(services)`: the Forever bag Escape pass, one `pcall` per provider in provider order, with the bridges' own `RefreshBags` at order 60 (`Bridges:RefreshBags`). `CancelEscape()`, `PreserveThroughEscape(services)` (Offhand's `ToggleGameMenu` post-hook) and `PreserveThroughPanelShow(panel, services)` (its `ShowUIPanel` post-hook): `Bridges:NotifyBagProviders(method, ...)`, each in `pcall`. `toggleActions` (binding action names) and `GetToggleFrame(action)` (that action's window; with `nil`, the provider's inventory window for the generic inventory toggles, by provider order around the bridges' `GetBagFrames` at order 60): the workspace toggle keys, inside their own `pcall` (`Bridges:GetBagToggleActions()`, `Bridges:GetBagToggleFrame(action)`, `Bridges:GetBagProviders()`). `closeButtonRoots` (names) and `GetCloseButtons(frame, name)`: `Bridges:GetBagCloseButtons(frame, name)` for the workspace close button handling. Persistent workspace bag roots (the engine in `Core/BagPersistence.lua`, each call one `pcall` through `Bridges:CallBagProvider(entry, method, ...)`, which returns `true` and the first result, or `false`; "first" means the first provider in provider order whose answer is true): `IsRoot(name, frame)` (the provider owning a root, also its pruning and `BagPersistence.IsSelfAnchoredRoot(frame, name)` for `selfAnchored = true`, which `Core/CanvasPersistence.lua` uses to leave the root's native Escape registration and title-drag anchor alone), `IsRootName(name)` (the provider's root family by name alone: stale records under a child name are pruned, a visible root without a rectangle keeps its saved open state, and a saved root of it is not restored through Escape while the shared toggle is contested), `Discover(register, deep, services)` (`register(name, frame)` returns whether it registered; `deep` only in the lifecycle pass after login and after the provider's own `loadAddon` load when it sets `deepDiscovery = true`; every other pass, the ticker's included, must be constant-time), `InstallCallbacks(services)` (at `PLAYER_LOGIN` and on its `loadAddon`'s `ADDON_LOADED`; the result is kept in `BagPersistence.callbacksInstalled[id]`), `hookScripts` (absent or `true`: the root's `OnShow`/`OnHide` are hooked; `false`: never, for a root in a protected focus path; a function `(name, frame)`: only on a literal `true`), `dragStopCapture` (`true`: on Forever its `OnDragStop` also triggers a capture), `IsDirectEscapeRoot(name, frame)` with `escapeOrder` and `escapeSource` (a root that keeps its own native Escape registration; tried in `escapeOrder`, it can leave that registration while open on the workspace, and the Escape observer labels the pending restore with `escapeSource`), `CloseParkedBags(services)` (after a capture pass in which its root left the registration, in `escapeOrder`), `panelTransitions` (`"all"` or `"options"`: the panel transitions its saved root is reopened through), `ClaimsSharedToggle()` (its addon replaced `ToggleAllBags`; with two claimants the toggle is never called and the reopen needs the exact saved root), `Show(name, frame, services)` (reopens the saved root itself: `true`/`false` when handled, `nil` to fall through to `ToggleAllBags`), `GetManagedRoot()` (the root name the provider restores itself through its own paths, or `nil`: its saved open state wins, it gets no workspace position record, Escape after `CloseSpecialWindows`, the Talents tab and reload go through `CanRestore(frame, services)`, `Restore(frame, position, services)` and `Resume(name, frame, services)` (`"wait"` retries), and `CapturePosition(position, frame, services)` adds to its open snapshot), `ExplicitlyClosed(name)` (the player closed the saved root; its open snapshot is forgotten) and `GetRootDiagnostics()` (appended as ` | text` to the bag diagnostics). Services add `IsPreservingPanelShown`, `HasSharedToggleConflict`, `OpenSavedRoot(name)`, `RegisterRoot(name, frame)`, `Discover(deep)`, `GetRoots()` (read only) and `GetSavedRecords()` | Ignored, a frame, or an array of buttons |
| `slashCommands` | `Bridges:RunSlashCommand(cmd, arg)` calls `slashCommands[cmd](arg)` of the first bridge naming `cmd` | `RunSlashCommand` returns `true` when a bridge claimed `cmd` (even if it failed) |
| `mapAddons` | Map integration diagnostics | Array of addon folder names |
| `catalog` | Registered into `Offhand.AddonWindowCatalog[id]` | Catalog table (supports `suitePrefix` and role entries) |

## 5. Public services (`Offhand.API`)

Added by `Core/Bridges.lua`:
- `Offhand.API.BRIDGE_CONTRACT` (`1`)
- `Offhand.API.RegisterBridge(id, bridge)`
- `Offhand.API.GetBridgeNamespace(id)`: private shared table per built-in bridge so multi-file bridges do not pollute `Offhand.*`
- `Offhand.API.GetBridgeStorage(id)`: persistent account-wide storage table under `OffhandDB.bridges[id]`
- `Offhand.API.FlushBridgeStorage()`: flushes Forever's profile snapshot before `ReloadUI()`
- `Offhand.API.GetGameRect()`: live Mainhand game rectangle in `UIParent` units (`left, bottom, right, top, width, height, screenWidth, screenHeight, isSpanned`)
- `Offhand.API.OwnsWorldMapPlacement()`: whether Offhand currently owns compact world map placement
- `Offhand.API.GetGroupLootSpot(height)`: center `x, y` for group loot roll slots on the game rectangle, or `nil` when unspanned
- `Offhand.API.IsPopupRedirectEnabled()`: whether Offhand is enabled with its popup and alert redirection on; a bridge that re-anchors a vendor's alerts releases them when this is false
- `Offhand.API.GetMainhandPixelHeightRatio()`: Mainhand's game pixel height over the physical window height while spanned, else `1`; a bridge multiplies a vendor's native frame scale by it
- `Offhand.API.GetOptionsWindowHelpers()`: the generic addon options window fitting helpers of `Core/PopupBounds.lua` (read only): `CanLayoutAddonOptions`, `ReadWindowPoint`, `SetWindowPoint`, `OwnsOptionsPoint`, `FitAddonOptions(frame, state, metrics)`, `GetOptionsBounds`, `FrameBounds`, `Fits` and `PublicNumber`; `nil` before that file loads
- `Offhand.API.QueuePopupBounds(frame)`: queues a tooltip-like frame for Offhand's popup bounds pass, which fits it inside the game rectangle once shown; `true` when queued
- `Offhand.API.RegisterAddonData(addon, data)` and the settings services of section 3.1
- `Offhand.API.RegisterHUDTransfer(provider)`: sets `Offhand.HUDTransfer` to the one HUD layout transfer provider (`provider.id` required); `false, "provider"` or `false, "duplicate"` otherwise. Core reads `IsAvailable()`, `ShowPreview(direction, onDismiss)` (its presence adds the setup wizard's transfer step after the HUD step, with the same step number, sizes and order as before), `HasPendingReload()`, `PromptImportReload()`, `addon` (the folder whose load and enable state show the Options controls and whose `ADDON_LOADED` refreshes them), `reloadPopup` (its import reload popup gets Offhand's controller-safe popup), `copyDirection` (the preview direction that copies Offhand's native layout into the suite) and `text` (locale keys by name: `title`, `stage`, `wizardIntro`, `wizardBody`, `wizardSelect`, `wizardReload`, `wizardExisting`, `wizardSelectManual`, `setupDesc`, `finishCurrent`, `finishReload`, `importReady`, `savedInactive`, `busy`, `previewDesc`, `helpBody`, `characterReview`; a missing name shows empty text)
- HUD transfer services: `GetHUDTransferSource(geometryOnly, targetSizes)` (the Mainhand Edit Mode layout to transfer, read only), `SaveHUDTransferFallback(context, rows)` (saves the rows as a separate inactive native layout: `true, name` or `false, reason`), `GetGeometrySignature(rect)`, `GetLayoutFailureText(reason)`
- Map services: `GetViewportMetrics()` (the live viewport metrics, enabled or not), `GetWorkspaceRegion(metrics)` (the workspace region those metrics resolve to), `KeepsWorkspacePanelsOpen()` (false only when the player turned workspace panel persistence off)
- Core state, read as core reads it: `IsEnabled()`, `IsForeverClient()`, `IsInputReserved()`, `IsControllerOwned()` (an owner of the `hud.controller` role is present), `IsGamepadUIEnabled()`, `IsNativeGamepadInterface()`, `IsGeometryTransitionActive()`, `IsLoggingOut()`, `GetExternalMapOwner()`, `GetOptionsMetrics()` (viewport metrics while enabled and spanned, else `nil`)
- Core actions: `Print(fmt, ...)`, `GetText(key)`, `ShowPopup(popupKey, textArg1, textArg2, data)`, `RequestFullLayout(preserveScale)`, `RefreshWorkspaceChrome()`, `RegisterDynamicChromeFrame(name)`, `GetReloadFunction()`, `GetControls()`

Existing geometry services (`Core/MainhandGeometry.lua`): `GetMainhandFrame`,
`GetMainhandRect`, `GetGeometryRevision`, `RegisterGeometryCallback`,
`UnregisterGeometryCallback`, `AnchorToMainhand`.

## 6. Default-anchor bridges and the shared helper

Many addons place a window, button or alert with one anchor on `UIParent`'s
centre, top, bottom or a corner. Under a span that is the seam between displays
or the far display. `Bridges/Shared/DefaultAnchors.lua` holds the common
handling so such a bridge is a short table of frames plus whatever is special
about its addon. It loads ahead of every bridge, creates nothing by itself, and
fills `Offhand.API.GetBridgeNamespace("Shared")`:

| Member | Purpose |
| --- | --- |
| `Available(addonName)` | Contract version 1, the Forever client, and the addon loaded. A bridge returns at file load when this is false |
| `IsForever()`, `IsLoaded(addonName)` | The two tests behind `Available` |
| `GameRect()` | `left, bottom, right, top, screenWidth, screenHeight` from `Offhand.API.GetGameRect()`; the whole screen when not spanned |
| `IsSpanned()`, `PointDelta(point)`, `Near(a, b)` | Geometry helpers. `PointDelta` is how far a point of the game rectangle is from the same point of the screen |
| `NewAnchorFitter(spots)` | `spots` maps a frame's global name to the addon's own default anchor `{ point, relativePoint, x, y }`. Returns a fitter with `Refresh()`, `Fit(name)`, `Holds(name)`, `Count()` and `moves` |
| `NewParentHolder(name)` | A named 1x1 frame with `Adopt(frame)`: an adopted frame that is sent back to `UIParent` goes under the holder instead |
| `Register(id, bridge)` | `RegisterBridge` plus a geometry callback that calls `bridge:Refresh("geometry")` |
| `Describe(label, fitter)` | `"<label>=<moved>/<total>"` for `GetDiagnostics` |

The fitter moves a frame only while it has exactly one anchor, on `UIParent`,
equal to the addon's default (within 0.6) or to the spot the fitter last gave
it. The frame is re-anchored to the same point of the game rectangle, with the
offsets converted to the frame's own scale. A frame the player dragged no longer
matches and is left alone. A protected frame is never moved in combat and gets
no `OnShow` hook; the next `Refresh` tries again. When Offhand is off or not
spanned the shift is zero and a frame the fitter moved returns to the addon's
default. Nothing is saved.

These bridges have no `catalog`, so learned addon windows are unaffected: a
window the player placed with **Addon windows** no longer matches its default
and the bridge stands aside.

Built-in default-anchor bridges (each has a README beside it):

| Bridge | Also handles |
| --- | --- |
| `Bridges/Beastfinder` | |
| `Bridges/EasyFishing` | The unnamed skill-up popup |
| `Bridges/ForeverLedger` | |
| `Bridges/Gathercraft` | World-map pins kept off `UIParent` |
| `Bridges/MobInfo2` | |
| `Bridges/Questie` | Popup stack dialogs, the QuestieTrace consent prompt, map icons kept off `UIParent`, the tracker width cap, quest item tooltips |
| `Bridges/RareScanner` | The button position RareScanner saves on reset |

They were written against the Forever builds of those addons, so `Available`
limits them to the Forever client, where core's 0.5 s `"tick"` refresh exists.

`Bridges/ForeverPlus` is not a default-anchor bridge: it is the former
`Core/ForeverPlusWarnings.lua`, moved behind the contract with unchanged
behaviour. It uses `IsExternallyOwnedFrame`, `RefreshTransientFrames` and
`IsPopupRedirectEnabled`, and registers on Forever before ForeverPlus exists so
a vendor that loads late is still hooked (`tests/forever-plus-warnings.lua`).

`Bridges/DialogueUI` is not a default-anchor bridge either: it is the former
`Core/DialogueUICompat.lua`, moved behind the contract with unchanged
behaviour, and it is not limited to the Forever client. It uses `GetGameRect`,
`GetMainhandFrame`, `GetMainhandPixelHeightRatio` and `QueuePopupBounds`,
keeps its own event refreshes, and offers its long report through
`GetDebugDiagnostics` only. Like the core module it registers before Dialogue
UI exists and waits for the vendor's `ADDON_LOADED`
(`tests/dialogue-ui-compat.lua`).

`Bridges/ProcDoc/Bridge.lua` is the former `Core/ProcDocCompatibility.lua`,
moved behind the contract with unchanged behaviour, beside the folder's data
file. It registers on every client before ProcDoc exists and keeps its own
`ADDON_LOADED` and `PLAYER_REGEN_ENABLED` refreshes, so a ProcDoc that loads
after Offhand is still centred. It runs on `Refresh("layout")` only, keeps its
opt-in under the stored key `centerProcDocOnMainhand` (`data.settings`), offers
it as an `alerts` checkbox and reports `ProcDocCenter=<status>` as a
`compat.tail` segment (`tests/procdoc-compatibility.lua`).

`Bridges/KerzoQuestLog` is the former `Core/CanvasKerzoQuestLog.lua`, moved
behind the contract with unchanged behaviour. It registers on every client
before Kerzo Classic Quest Log exists and looks its root up on each refresh, so
a late Kerzo is still handled; hooks go in on Forever only. It runs on
`Refresh("persistence")` and on `Refresh("tick")` outside a geometry
transition, pauses on `PrepareTransition` and resumes on `BeginSession`. Its
data holds the `Kerzo Classic Quest Log` catalog entry, the `workspaceChrome`
name `KerzosQuestLog` and the character setting `kerzoQuestLogOpen` (stored key
unchanged, cleared on a character change) (`tests/kerzo-quest-log.lua`,
`tests/kerzo-quest-log-reload.lua`).

`Bridges/OpenMap` holds the former `Core/OpenMapRecovery.lua` (`Recovery.lua`) and
the OpenMap parts of the World Map core (`Contract.lua`, `Map.lua`), moved behind
the contract with unchanged behaviour beside the folder's data file. `Init.lua`
registers one bridge on every client with the `mapProvider`, the `map.fade` entry,
the `recovermap` slash command and the World Map card controls
(`tests/openmap-recovery.lua`, `tests/forever-openmap-follow.lua`,
`tests/map-scale-settings.lua`, `tests/expanded-map.lua`).

`Bridges/EllesmereUI/Scale.lua` is the former
`Core/EllesmereScaleCompatibility.lua`, moved behind the contract with unchanged
behaviour, beside the folder's data file. It registers on every client before
EllesmereUI exists and looks `EllesmereUI.PP` up on each `RefreshScale()`, so a
late EllesmereUI is still hooked. It keeps the pixel grid on the live root while
Offhand is enabled and spanned, and after EllesmereUI's own scale setter asks for
`RequestFullLayout(true)` (`tests/ellesmere-scale-compatibility.lua`).
`Bridges/EllesmereUI/Windows.lua` is the former EllesmereUI window fitting of
`Core/PopupBounds.lua` (settings window, popups, Unlock Mode toolbar) and the chat
bubble ownership probe of `Core/ChatBubbles.lua`, with unchanged behaviour. Its
`InitializePopupWindows()` starts the 0.2 s window ticker on Forever only when
EllesmereUI exists at that moment, as before, and `OwnsFeature("chatBubbles")`
makes the bubble replacement yield while EllesmereUI's bubble styling is enabled
(`tests/popup-bounds.lua`, `tests/chat-bubble-scale.lua`). The suite's files share
one bridge object registered as `EllesmereUI`. Its `GetSetupNotes("before-span")`
is the former onboarding profile backup advice (Forever, while EllesmereUI can
export its profile). `Bridges/EllesmereUI/Layout.lua` and `Preview.lua` are the
former `Core/ForeverEllesmereLayout.lua` and `UI/EllesmereLayoutPreview.lua`, moved
with unchanged behaviour: on the Forever client (with or without EllesmereUI, as
before) they register the HUD transfer provider and the `ellesmere` slash
command, and `Bridge.lua` names the provider's locale keys
(`tests/forever-ellesmere-layout.lua`, `tests/wizard-autoconfig.lua`,
`tests/character-setup.lua`).

`Bridges/DaylightUI/Init.lua` also registers DaylightUI facts on every client, whether or not
DaylightUI was loaded when the bridge loaded (formerly in core): the `parkedNativePanel` matcher for
`PlayerSpellsFrame` and `ClassTrainerFrame` under its live `Win.Followers` holders (Forever only), the
`parkedReason` `daylight-parked` and the `diagnosticFrame` names `DaylightUIBook` and `DaylightUINpc`.

`Bridges/ConsolePort` is a data bridge: it registers through
`Offhand.API.RegisterAddonData` on every client and supplies the roles
`hud.controller`, `hud.actionBars`, `hud.statusBars` and `hud.editModeBlocker`
(while the `ConsolePort` global exists), `report.actionBars` (order 40, loaded
or global) and the `diagnosticFrame` name `ConsolePortCrosshair`.

The HUD and report owners are data bridges of the same kind, one folder per
addon: `Bartender4`, `BlizzMove`, `Carbonite`, `Cell`, `Chattynator`,
`Dominos`, `EllesmereUI`, `ElvUI`, `MoveAny`, `MoveMyBags`, `PitBull4`,
`SexyMap`, `ShadowedUnitFrames`, `Tukui`, `XPerl` and `ZPerl`. Each file's
header lists its roles, orders, guidance and diagnostic segments; the orders
reproduce the lists core used to hold (`tests/bridges-contract.lua` pins them).

Addon windows: `Bridges/DonCore` (Questdon, Leveldon, DonMap), `Bridges/Platynator`,
`Bridges/ForeverDungeonJournal` and `Bridges/Leatrix` (`Settings.lua`) hold the
former vendor parts of `Core/CanvasAddonEscape.lua` with unchanged behaviour
(`data.windows`, `IdentifyWindow`, `GetWindowCloseButtons`, DonCore's
`RetireStalePlacements` and `vendorGameplay` frames, the journal's
`minimapDiagnosticFrame`), each with a README. They register on every client.
The other catalog entries come from data bridges: `ArkInventory`, `Baganator`,
`Bagnaros`, `Bagnon`, `BagSmith`, `BetterBags`, `ClassicUIForever`,
`EllesmereUI`, `ElvUI`, `FlareUI`, `MoveAny`, `OpenMap` (`Data.lua`) and
`RestedXP` (also `vendorGameplay` and `unsavedPosition`).

Popup roots, frame-name rules, tooltip owners and mover fields come from data
bridges of the same kind: `Baganator`, `BetterBags`, `Details`, `ForeverXPBar`,
`MoveMyBags`, `ProcDoc`, `Questie` (`Rules.lua`, beside its Forever-only
bridge), `RestedXP` and `Titan` (`preservePopup`), `EllesmereUI`
(`externalHUD`), `BugSack` and `RedIsFriend` (`menuFrame`), `MoveMyBags`
(`yieldNativeContainer`), `RestedXP` (`recoverableGuide`), `ForeverXPBar`
(`diagnosticFrame` and a `panelPlacement` segment), `TipTac`, `TinyTooltip`
and `TinyTooltipReforged` (`tooltip.owner`, orders 10 to 30) and `OneForAll`
(`moverFields`).

Addon options windows and window mover conflicts: `Bridges/ItemRack/Bridge.lua` and
`Bridges/Questie/Options.lua` (its own id `QuestieOptions`, beside the default-anchor Questie bridge) are the
former ItemRack and Questie options window fitting of `Core/PopupBounds.lua`, with unchanged behaviour. They
register on Forever only, install their hooks from `InitializePopupWindows()` and again on their addon's
`ADDON_LOADED`, and fit through `RefreshAddonOptions(getMetrics)` with the core helpers of
`GetOptionsWindowHelpers()` (`tests/addon-options-bounds.lua`). `Bridges/OneForAll/Bridge.lua` holds the
former OneForAll conflicts and diagnostics of `Core/CanvasCompatibility.lua` (`GetOwnershipConflicts`, orders
20 and 40, and `GetMoverDiagnostics`) beside its `moverFields` data, and `Bridges/Zygor/Bridge.lua` the former
read-only guide frame probe as a `GetDebugDiagnostics` report labelled `Guide frame`
(`tests/canvas-compatibility.lua`, `tests/guide-addon-diagnostics.lua`). Both register on every client.

Bag owners are data bridges of the same kind: `EllesmereUI` (EllesmereUIBags), `MoveMyBags`,
`Baganator` (also the Baginator and BGR spellings, `bags.selfRestoring` and the custom bag workspace
record, stored key `baganatorWorkspacePanels`), `Bagnon`, `AdiBags`, `ArkInventory`, `BetterBags`,
`Inventorian`, `ElvUI`, `Tukui`, `Bagnaros` and `BagSmith` (whose parked native bags count only on
Forever) hold `hud.bags` and `report.bags` (orders 10 to 120 reproduce the former core lists) and the bag
name rules. The former Forever bag Escape adapters of `Core/BagPersistence.lua` are bag providers in each
folder's `Bags.lua`, with unchanged behaviour and a README: `ArkInventory` (order 10), `Bagnaros` (20),
`BetterBags` (30), `BagSmith` (40), `ElvUI` (50) and `EllesmereUI` (EllesmereUIBags, 70, also its close
button finder). `Bagnon/Bags.lua` supplies its toggle binding only. Their bag root persistence
(Baganator, Bagnon and the EllesmereUI bag) is still in `Core/BagPersistence.lua`.

World map owners are data bridges of the same kind: `MoveAny`, `ClassicUIForever`, `OpenMap`
(`Data.lua`) and `Leatrix` (`Maps.lua`, merged under the `Leatrix` id ahead of `Settings.lua`)
hold `map.owner` (orders 10 to 40; Leatrix Maps' owner name is `LeatrixMaps`), `OpenMap`
(`Init.lua`), `MapUtils`, `MapWise` (`Bridge.lua`) and `Leatrix` hold `map.fade` (orders 10 to
40, the first three with their fade readers), and those with `BlizzMove` hold
`map.integration` (the former core order) and the map diagnostics segments, which still print
`MoveAny=absent`, `LeatrixMaps=absent` and `OpenMap=absent`. `Bridges/MapWise/Bridge.lua` is
the former MapWise position guard of `Core/CanvasForeverMap.lua`, and `Leatrix/Maps.lua`
carries the former Leatrix Maps coordinate label refresh as the `LeatrixMaps` map provider of
the `Leatrix` bridge, both with unchanged behaviour and a README.

## 7. Error isolation and tests

Every core-to-bridge callback runs inside `pcall`. Failing bridges stay
registered, record their latest error in `Offhand.Bridges.errors[id]`, and
surface `Bridge:<id>=error` in compatibility diagnostics without breaking
Offhand or other bridges.

Regression suites:
- `tests/bridge-shared-anchors.lua`: the shared helper's fit rule, holder, registration and inert load.
- `tests/bridge-beastfinder.lua`, `bridge-easyfishing.lua`, `bridge-foreverledger.lua`, `bridge-gathercraft.lua`, `bridge-mobinfo2.lua`, `bridge-questie.lua`, `bridge-rarescanner.lua`: each bridge's inert load, default spots, dragged frames, unspanned release and addon-specific parts, on the mock client in `tests/support/bridge-client.lua`.
- `tests/bridges-contract.lua`: registry, storage, dispatch, isolation, public API, and core purity.
- `tests/bridge-daylightui-layout.lua`: built-in DaylightUI bridge inert load, layout, Edit Mode (`Replace` 2.2.3+ and `ImportLayout` 2.2.1), scenes, rolls, and legacy `DaylightOffhand` stand-down.
- `tests/bridge-daylightui-map.lua`: DaylightUI world map mover stand-down (mock and optional live vendor `MapMove.lua`).
