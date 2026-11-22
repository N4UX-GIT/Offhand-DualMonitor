# Bridge addons

This is the contract between Offhand and its bridge addons. The registry and
the services it describes live in `Core/Bridges.lua`; when this document and
that file disagree, the file is right and this document needs fixing.

## 1. What a bridge is

A bridge is a separate addon that adapts one third-party addon to Offhand. It
holds everything Offhand needs to know about that addon: frame names, hooks
into its internals, its saved settings, its own map or bag handling.

Offhand's core names no bridged addon. The core calls registered bridges at a
few fixed points and offers them a small set of services; it does not know
which addons they adapt. This keeps code for an addon that most players do not
run out of every player's Offhand, and lets a bridge change when its target
addon changes without touching Offhand's core.

A bridge loads only when both Offhand and its target addon are enabled,
because its TOC lists both under `## Dependencies`. With either one disabled
the client does not load the bridge at all.

## 2. Layout and packaging

Source layout in this repository:

```
Bridges/<Name>/Offhand_<Name>.toc
Bridges/<Name>/*.lua
Bridges/<Name>/README.md
```

Each bridge folder holds exactly one TOC, named `Offhand_<Name>.toc`.
`package.ps1` and `scripts/check-compatibility.py` both refuse a bridge folder
with no TOC, several TOCs, or a TOC whose name does not start with `Offhand_`.

The client loads only addons that sit directly under `Interface/AddOns`, so a
bridge cannot ship inside the `Offhand/` folder. `package.ps1` stages each
bridge as a sibling folder named after its TOC, holding only the TOC and the
files it lists (no README, no tests):

```
Offhand-v<version>.zip
  Offhand/...
  Offhand_<Name>/Offhand_<Name>.toc
  Offhand_<Name>/<listed files>

Offhand-Complete-v<version>.zip
  Offhand/...
  Offhand_<Name>/...
  Offhand.exe, README.md, ...
```

A file listed in a bridge TOC must exist and must stay inside that bridge's
folder; packaging fails otherwise. A `-CandidateId` QA build labels bridge
TOCs the same way as Offhand's (`[QA <id>]` title suffix and an
`## X-Offhand-Candidate:` line), so the build is recognisable in the addon list.

Required TOC fields:

| Field | Value |
| --- | --- |
| `## Dependencies:` | `Offhand, <TargetAddon>` |
| `## X-Offhand-Bridge:` | `<Name>` |
| `## X-Offhand-Bridge-Contract:` | `1` (the contract number in section 10) |
| `## Version:` | the same value as Offhand's own TOCs |
| `## Title:` | begins with Offhand's coloured name, `\|cffffbd0aOffhand\|r` |
| `## IconTexture:` | Offhand's icon, `Interface\AddOns\Offhand\Media\OffhandLogo64x64.blp` |
| `## Group:` | `Offhand` |

These follow the pattern DaylightUI uses for its own modules: a shared folder
name prefix, a dependency on the parent addon, and the parent's title prefix
and icon. Whether the Forever client's addon list actually nests a bridge under
Offhand has not been checked in game.

## 3. Load order

A bridge loads after Offhand and after its target addon, because it depends on
both. Its folder name starts with `Offhand_`, so it usually also loads after
the target's own modules whose folder names sort before it, such as
DaylightUI's modules. Do not
depend on that: the target may create frames later, on demand, or
before the bridge's code runs. A bridge must not rely on watching the target's
frames being created. It should sweep for frames that already exist when it
starts, and again when it is refreshed.

## 4. Registration

```lua
local Offhand = _G.Offhand
local API = Offhand and Offhand.API
if not (API and API.BRIDGE_CONTRACT == 1 and API.RegisterBridge) then return end

local bridge = { contract = API.BRIDGE_CONTRACT }
function bridge:Refresh(reason) --[[ ... ]] end

local ok, problem = API.RegisterBridge("MyAddon", bridge)
```

`Offhand.API.RegisterBridge(id, bridge)` returns `true`, or `false` and one of:

| Reason | Meaning |
| --- | --- |
| `"id"` | `id` is not a non-empty string |
| `"bridge"` | `bridge` is not a table |
| `"contract"` | `bridge.contract` is not `Offhand.API.BRIDGE_CONTRACT` |
| `"duplicate"` | a different table is already registered under this `id` |

One table per id. Registering the same table again under the same id is
accepted and changes nothing. On success the core sets `bridge.id = id`.
Bridges are called in the order they registered.

## 5. Callbacks the core makes

Every callback is optional; the core skips methods a bridge does not define.
Each is called as a method (`bridge:Method(...)`).

| Method | When it is called | Combat | Return value |
| --- | --- | --- | --- |
| `Refresh(reason)` | `reason` is `"layout"` when Offhand recomputes its layout (`Canvas:UpdateLayout`), `"map"` when it configures the world map (`Canvas:ConfigureWorldMap`), and `"tick"` on Forever only, twice a second from the Forever position ticker | Any reason can arrive in combat; `"tick"` keeps running in combat and during display changes | Ignored |
| `RefreshBags(services)` | Forever only, from the bag persistence refresh, after Offhand's own bag-addon Escape handling | Can arrive in combat; `UpdateEscapeRegistration` does nothing in combat | Ignored |
| `GetDiagnostics()` | When Offhand builds its compatibility diagnostics (`/offhand diag`) | Any time | A short string appended to the report; anything else is ignored |
| `ShouldPreserveSingleScreenPosition(frame, metrics)` | Before Offhand's single-screen recovery moves a frame with a saved Offhand position back onto the one screen | Any time | `true` when the bridged addon has just restored its own single-screen position for this frame and Offhand must leave it alone |
| `GetBagFrames()` | When the bag toggle key decides whether a bag-addon bag is on Offhand (only while a custom bag addon is detected) | Any time | A table whose values are the bridged addon's bag frames |

Optional field:

| Field | Meaning |
| --- | --- |
| `mapAddons` | Array of addon names whose versions belong in Offhand's map integration diagnostics |

### Bag services passed to `RefreshBags`

`services` is a table of plain functions (call them with a dot, not a colon):

| Function | Purpose |
| --- | --- |
| `UpdateEscapeRegistration(frame, name, supported, parent, proxy)` | Keeps a visible bag that sits on Offhand out of Escape's special-frame list, so Escape reaches its normal target first and the bag stays open; puts it back when it no longer qualifies. `supported` says whether this frame is one the bridge vouches for. `proxy`, if given, is the registration key used instead of `frame` (for addons that register a different frame in `UISpecialFrames`). `parent` is passed through to Offhand's Escape adapter. Returns a true value when the bag is now held out of the list, or was just closed while on Offhand, so the caller may close parked native bags. Returns nothing outside Forever, in combat, or when Offhand's Escape adapter is unavailable. |
| `IsEscapeRegistered(registration)` | `true` while Offhand holds an Escape registration for that frame or proxy |
| `CanSuppressVendorClose(frame, proxy)` | `true` when the bag is registered, visible, on Offhand, and Offhand may manage bags right now (not paused, not in combat, spanned). A bridge can then ignore the bag addon's own close request. |
| `IsGameMenuBagClose(stack)` | `true` when a `debugstack()` string shows the close came from the Game Menu's Escape path, which should not count as the player closing the bag |

## 6. Services a bridge may call

A bridge uses only `Offhand.API`. Reading `Offhand.db`, `Offhand.Canvas`,
`Offhand.Viewport` or any other internal table is outside the contract and may
break without notice.

Added for bridges (`Core/Bridges.lua`):

| Function | Returns |
| --- | --- |
| `Offhand.API.RegisterBridge(id, bridge)` | See section 4 |
| `Offhand.API.BRIDGE_CONTRACT` | The contract number, `1` |
| `Offhand.API.GetGameRect()` | The game rectangle as it is now, in UIParent units from its bottom-left corner: `left, bottom, right, top, width, height, screenWidth, screenHeight, isSpanned`. The whole screen when Offhand is off or WoW is not spanned. Never a cached value, unlike `GetMainhandRect`. |
| `Offhand.API.OwnsWorldMapPlacement()` | `true` while Offhand itself places the compact world map: enabled and spanned, allowed to manage panels, a saved map position exists, and no other map addon owns the map. A bridge for an addon with its own map mover stands that mover aside while this is true. |
| `Offhand.API.GetGroupLootSpot(height)` | `x, y` for the centre of a group loot roll slot of the given height, in UIParent units from its bottom-left corner: the player's saved Group Loot Rolls position if any, else the middle of the game rectangle 190 HUD units up. `nil` when the game rectangle is the whole screen. |

Existing geometry services (`Core/MainhandGeometry.lua`; see
[MAINHAND-PLACEMENT.md](MAINHAND-PLACEMENT.md)):

| Function | Returns |
| --- | --- |
| `Offhand.API.GetMainhandFrame()` | `OffhandMainhandFrame`, a frame covering the game rectangle, or `nil` before it can be created |
| `Offhand.API.GetMainhandRect()` | A copy of the last applied Mainhand rectangle (same fields as `GetGameRect`) |
| `Offhand.API.GetGeometryRevision()` | A number that increases each time the Mainhand rectangle changes |
| `Offhand.API.RegisterGeometryCallback(owner, callback)` | `true` if registered. `callback(rect, reason, revision)` runs after each change; returning `false` or raising an error unregisters it. One callback per `owner`. |
| `Offhand.API.UnregisterGeometryCallback(owner)` | Nothing |
| `Offhand.API.AnchorToMainhand(frame, point, relativePoint, x, y)` | `true`, or `false` and `"frame"`, `"forbidden"`, `"protected"`, `"combat"` or `"unavailable"`. Refuses protected frames and anything in combat. |

## 7. Error isolation

Every callback runs inside `pcall`. A bridge that raises an error never breaks
Offhand or another bridge. The failing bridge stays registered and is called
again next time. Its latest error message is kept in
`Offhand.Bridges.errors[id]`, and the diagnostics show `Bridge:<id>=error`
until the addon reloads.

The services in section 6 do not protect the caller: an error a bridge causes
inside its own code outside a callback (for example in an event handler or a
hook) is the bridge's to handle.

## 8. Rules for bridge authors

- Never copy third-party source into this repository. Reference the target
  addon's frames, functions and saved variables by name at run time.
- Wrap third-party internals defensively. Check that every table, function and
  field you rely on exists and has the shape you expect, and stand the affected
  piece down (do nothing, keep the target's own behaviour) when it does not.
  Target addons change without notice.
- No protected-frame writes in combat. Check `InCombatLockdown()` before moving,
  showing or hiding anything that may be protected, and defer to after combat.
- Do not write the other addon's SavedVariables unless that write is the fix,
  and say so in the bridge's README.
- Bridge-specific saved variables are named `Offhand<Name>DB`.
- Document what the bridge does, how it was tested and what it leaves alone in
  `Bridges/<Name>/README.md`.

## 9. Tests and checks

- `tests/bridges-contract.lua` covers the registry, dispatch, error isolation
  and the public services. It also fails if any Lua file loaded by Offhand's
  own TOCs, or `Bindings.xml`, mentions a bridged addon by name (currently the
  word "daylight", case-insensitive). Add a bridged addon's name to that guard
  when you add its bridge.
- `tests/bridge-daylightui-*.lua` cover the DaylightUI bridge.
- `scripts/check-compatibility.py` follows every `Bridges/*/*.toc` manifest as
  well as Offhand's six, checks the files they load, and with `--installed`
  compares bridge files with the sibling `Offhand_<Name>` folder next to the
  installed `Offhand` folder. See [COMPATIBILITY.md](COMPATIBILITY.md).

## 10. Versioning

The contract number is `Offhand.Bridges.CONTRACT`, published as
`Offhand.API.BRIDGE_CONTRACT`; it is `1`.

Adding an optional callback or a new service is compatible and keeps the
number. Changing the meaning or arguments of an existing callback or service,
or removing one, bumps the number. A bridge that registers with a different
number is refused (`"contract"`), so it does nothing until it is updated.
Bridges should also check that each service they use exists before relying on
it, and stay inactive when Offhand is too old to offer it.
