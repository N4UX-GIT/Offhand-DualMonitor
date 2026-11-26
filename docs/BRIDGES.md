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

Offhand's bridged core modules (`Core/Canvas.lua`, `Core/BagPersistence.lua`,
`Core/CanvasCompatibility.lua`, `Core/CanvasMapPresentation.lua`,
`Core/WorkspaceToggleKeys.lua`, `Core/AddonWindowCatalog.lua`,
`Core/CanvasAddonEscape.lua`, and `Core/LearnedAddonWindows.lua`) do not name
bridged addons directly. The core calls registered bridges at fixed points
inside `pcall` and offers a small `Offhand.API` service surface.

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
`Bridges:CallMap` (the first bridge to claim an owner keeps it).

### 3.1 Addon data

`Offhand.API.RegisterAddonData(addon, data)` merges plain facts once into
lookup tables in `Core/Bridges.lua`. It creates no bridge (nothing in
`Bridges:List()`), so it may run unconditionally on every client. It returns
`true`, or `false` and `"id"` or `"data"`. The same data table merges only
once. Only a detector's `active` and a matcher's `verify` run in `pcall`, and
only after the declarative part passed; a throw counts as false and is
recorded in `Offhand.Bridges.errors[addon]`. Both must return a literal `true`.

A *detector* is a table whose given fields must all pass: `loaded="Folder"`
(IsAddOnLoaded; a throwing query counts as not loaded), `global="Name"` (`_G[Name] ~= nil`), `present="Name"` (either),
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
| `ownership` | Array of `{ role, name, order, detect, ... }`, sorted by `(order, registration)`, unordered last | `Bridges:HasRole(role)`, `Bridges:GetRoleOwners(role)` (names, entries), `Bridges:FirstRoleOwner(role)` (name, entry) |
| `frameRules` | `{ [rule] = { matcher, ... } }` | `Bridges:MatchFrame(rule, frame, name)`, `Bridges:MatchName(rule, name)`, `Bridges:GetRuleNames(rule)` (literal names, qualifiers not evaluated) |
| `moverFields` | `{ movable = { "field" }, moving = { "field" } }` | `Bridges.IsExternallyMovable(frame)` (a field `== true`), `Bridges.IsExternallyMoving(frame)` (a field set) |
| `catalogs` | `{ [addonFolder] = catalog }` | Merged into `Offhand.AddonWindowCatalog[addonFolder]` |
| `settings` | `{ [key] = { store = "profile" or "character", legacyKey, default, resetOnCharacterChange } }` | `Offhand.API.Get/SetBridgeSetting`, `Get/SetBridgeCharacterSetting`, `Bridges:GetSettingDefaults()`, `Bridges:GetCharacterResetKeys()` |

Roles and rules core reads:

| Role or rule | Read by |
| --- | --- |
| `hud.controller` | Every controller site: an owner present means an external controller addon owns the protected controller HUD, so Offhand's native Gamepad placement, controller Edit Mode layouts, learned windows, addon window Escape handling and toggle keep-open stand aside; `Offhand.API.IsControllerOwned()` |
| `hud.actionBars`, `hud.statusBars` | `HUDCompatibility.HasCustomActionBarAddon`, `HasCustomStatusBarAddon` |
| `hud.editModeBlocker` | Edit Mode HUD recovery (`Core/Recovery.lua`) skips its rebuild |
| `report.actionBars` | Action bar owners in the compatibility report, in role order |
| rule `diagnosticFrame` | Extra roots in the panel placement diagnostics, after core's own |

Settings live under the same key as before (`legacyKey`, else `key`) in
Offhand's profile settings or `OffhandCharDB`, so nothing migrates. A read of an
unset key gives `default`; an undeclared key, or one of the other store, reads
`nil` and does not write. A character write never creates `OffhandCharDB`.

## 4. Callbacks the core makes

Every callback is optional and runs inside `pcall`:

| Method / Field | When called | Return value |
| --- | --- | --- |
| `Refresh(reason)` | `"layout"` (`Canvas:UpdateLayout`), `"map"` (`Canvas:ConfigureWorldMap`), `"tick"` (Forever 0.5s ticker; can run in combat) | Ignored |
| `RefreshBags(services)` | Forever bag Escape pass with `{ UpdateEscapeRegistration, IsEscapeRegistered, CanSuppressVendorClose, IsGameMenuBagClose, IsSettingsBagClose }` | Ignored |
| `GetDiagnostics()` | Compatibility diagnostics report | Non-empty string or `nil` |
| `GetDebugDiagnostics()` | `/offhand diag debug` only, printed as `<label> diagnostics: <text>.` | `label, text` (both non-empty strings) or nothing |
| `ShouldPreserveSingleScreenPosition(frame, metrics)` | Single-screen recovery for saved workspace panels | Literal `true` to preserve vendor placement |
| `GetBagFrames()` | Workspace bag toggle check | Table of bag frames |
| `IsEditModeActive()` | Before learned-window selection or refresh | Literal `true` to pause Offhand selection |
| `IdentifyLearnPlacement(frame, name, file)` | Learned-window opt-in check for cataloged bridge frames | Role string matching `bridge.catalog[role].learnPlacementFile` |
| `IsExternallyOwnedFrame(frame, name)` | `HUDCompatibility.IsExternallyOwnedHUDFrame`, so generic popup rescue and panel movement skip a vendor HUD root the bridge places itself | Literal `true` to keep core away from the frame |
| `RefreshTransientFrames(phase)` | With the Mainhand transient passes: `"hook"` (discovery) and `"position"` (placement, ahead of core's own popups and alerts) | Ignored |
| `GetSettingsContributions(slot)` | `Bridges:GetSettingsContributions(slot)` for an Options slot (`map`, `alerts`, `recovery`, `help:EDIT_MODE`, `mapScaleTitle`, `mapDescription`) | Array of `{ id, kind, text, tooltip, get, set, onClick, shown, width, height, order }`; entries without an id are dropped, the rest sorted by `order` then bridge order |
| `mapProvider` | `Bridges:CallMap(owner, method, ...)`: one `pcall` into the provider of the owner the caller resolved | The method's own results; nothing when absent or failing |
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
- `Offhand.API.QueuePopupBounds(frame)`: queues a tooltip-like frame for Offhand's popup bounds pass, which fits it inside the game rectangle once shown; `true` when queued
- `Offhand.API.RegisterAddonData(addon, data)` and the settings services of section 3.1
- `Offhand.API.RegisterHUDTransfer(provider)`: sets `Offhand.HUDTransfer` to the one HUD layout transfer provider (`provider.id` required); `false, "provider"` or `false, "duplicate"` otherwise
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

`Bridges/ConsolePort` is a data bridge: it registers through
`Offhand.API.RegisterAddonData` on every client and supplies the roles
`hud.controller`, `hud.actionBars`, `hud.statusBars` and `hud.editModeBlocker`
(while the `ConsolePort` global exists), `report.actionBars` (order 40, loaded
or global) and the `diagnosticFrame` name `ConsolePortCrosshair`.

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
