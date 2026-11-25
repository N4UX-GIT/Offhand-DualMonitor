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
manifests (preserving identical load lists across flavors) and check at file
load whether their target addon global is present. When the target addon is not
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
`Offhand.AddonWindowCatalog[id]` automatically.

## 4. Callbacks the core makes

Every callback is optional and runs inside `pcall`:

| Method / Field | When called | Return value |
| --- | --- | --- |
| `Refresh(reason)` | `"layout"` (`Canvas:UpdateLayout`), `"map"` (`Canvas:ConfigureWorldMap`), `"tick"` (Forever 0.5s ticker; can run in combat) | Ignored |
| `RefreshBags(services)` | Forever bag Escape pass with `{ UpdateEscapeRegistration, IsEscapeRegistered, CanSuppressVendorClose, IsGameMenuBagClose, IsSettingsBagClose }` | Ignored |
| `GetDiagnostics()` | Compatibility diagnostics report | Non-empty string or `nil` |
| `ShouldPreserveSingleScreenPosition(frame, metrics)` | Single-screen recovery for saved workspace panels | Literal `true` to preserve vendor placement |
| `GetBagFrames()` | Workspace bag toggle check | Table of bag frames |
| `IsEditModeActive()` | Before learned-window selection or refresh | Literal `true` to pause Offhand selection |
| `IdentifyLearnPlacement(frame, name, file)` | Learned-window opt-in check for cataloged bridge frames | Role string matching `bridge.catalog[role].learnPlacementFile` |
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

Existing geometry services (`Core/MainhandGeometry.lua`): `GetMainhandFrame`,
`GetMainhandRect`, `GetGeometryRevision`, `RegisterGeometryCallback`,
`UnregisterGeometryCallback`, `AnchorToMainhand`.

## 6. Error isolation and tests

Every core-to-bridge callback runs inside `pcall`. Failing bridges stay
registered, record their latest error in `Offhand.Bridges.errors[id]`, and
surface `Bridge:<id>=error` in compatibility diagnostics without breaking
Offhand or other bridges.

Regression suites:
- `tests/bridges-contract.lua`: registry, storage, dispatch, isolation, public API, and core purity.
- `tests/bridge-daylightui-layout.lua`: built-in DaylightUI bridge inert load, layout, Edit Mode (`Replace` 2.2.3+ and `ImportLayout` 2.2.1), scenes, rolls, and legacy `DaylightOffhand` stand-down.
- `tests/bridge-daylightui-map.lua`: DaylightUI world map mover stand-down (mock and optional live vendor `MapMove.lua`).
