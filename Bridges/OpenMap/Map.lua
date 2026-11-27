--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/OpenMap/Map.lua: OpenMap's world map provider

    The OpenMap parts of Core/CanvasForeverMap.lua, Core/CanvasCompatibility.lua,
    Core/MapScale.lua, Core/ExpandedMap.lua and Core/MainhandGamepad.lua, moved
    behind the bridge contract with unchanged behaviour: camera follow, the
    movement fade reader, the windowScale settings action, expanded map and
    windowed recovery, Forever fullscreen handling, the contract notice and
    the map diagnostics. Core reaches these through Bridges:CallMap("OpenMap",
    method, ...) only while OpenMap is the World Map owner, and through the
    map.fade entry Init.lua registers.

    Registered on every client, like the core code it replaces; OpenMap is read
    when asked.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.GetBridgeNamespace) ~= "function" then return end

local namespace = API.GetBridgeNamespace("OpenMap")
local Contract, Recovery = namespace.Contract, namespace.Recovery
if type(Contract) ~= "table" or type(Recovery) ~= "table" then return end

local Provider = { owner = "OpenMap" }
namespace.Provider = Provider

local function IsAddonLoaded(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, addonName)
        if ok and loaded then return true end
    elseif IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, addonName)
        if ok and loaded then return true end
    end
    return false
end

local function Finite(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
        and value > -math.huge and value < math.huge
end

local function Number(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return nil end
    return value
end

local function IsSpanned()
    local metrics = API.GetViewportMetrics()
    return metrics and metrics.isSpanned
end

-- The player's opt-in to camera follow (data.settings in Init.lua, stored
-- key followPlayerWithOpenMap).
function namespace.FollowsPlayer()
    return API.GetBridgeSetting("OpenMap", "followPlayerWithOpenMap") == true
end

function namespace.SupportsFollow()
    local api = _G.OpenMapAPI
    return type(api) == "table" and api.major == 1
        and type(api.GetView) == "function" and type(api.WorldFromMap) == "function"
        and type(api.ShowWorld) == "function" and type(api.IsStitched) == "function"
end

-- OpenMap's camera glides for 0.4 seconds. A centered camera follows the
-- player; browsing away pauses follow until the player centers it again.
-- Returns true once it has handled the follow state.
function Provider:UpdateFollow(map, state)
    local api = _G.OpenMapAPI
    if not namespace.FollowsPlayer()
        or not namespace.SupportsFollow() or not api.IsStitched()
        or API.GetExternalMapOwner() ~= "OpenMap"
        or InCombatLockdown() or IsInInstance()
        or not IsSpanned() or not API.IsFrameOnWorkspace(map) then
        state.u = nil
        return true
    end
    local id = C_Map.GetBestMapForUnit("player")
    if not Finite(id) then state.u = nil; return true end
    local position = C_Map.GetPlayerMapPosition(id, "player")
    if (issecretvalue and issecretvalue(position)) or not position then state.u = nil; return true end
    local x, y = position:GetXY()
    if not Finite(x) or not Finite(y) then state.u = nil; return true end
    local u, v = api.WorldFromMap(id, x, y)
    local cu, cv, zoom = api.GetView()
    if not Finite(u) or not Finite(v) or not Finite(cu) or not Finite(cv)
        or not Finite(zoom) or zoom <= 0 then state.u = nil; return true end
    if map:IsMouseOver() and IsMouseButtonDown("LeftButton") then state.u = nil; return true end
    local offset = math.max(math.abs(cu-u), math.abs(cv-v)) * zoom
    if state.u and math.abs(state.zoom-zoom) > 0.00001 then
        state.u, state.v, state.zoom = cu, cv, zoom
        return true
    end
    if state.u and math.max(math.abs(cu-state.u), math.abs(cv-state.v)) * zoom > 0.015 then
        state.u = nil
    end
    if not state.u and offset > 0.015 then return true end
    if offset > 0.0005 then
        if not api.ShowWorld(u, v) then state.u = nil; return true end
        cu, cv = u, v
    end
    state.u, state.v, state.zoom = cu, cv, zoom
    return true
end

-- The map.fade reader: OpenMap's own moveFade preference while its world map
-- module is active, and the module, which holds mapFade itself meanwhile.
function namespace.ReadFade()
    if not IsAddonLoaded("OpenMap") then return end
    local module, db = Contract.GetOpenMapWorldMapModule()
    if module and module.enabled and type(module.RefreshExtras) == "function"
        and type(db.moveFade) == "number" and db.moveFade >= 0 and db.moveFade <= 0.9 then
        return db, module
    end
end

-- Its own refresh may have hidden the fader while the override was active.
-- Re-enable it through the vendor for a map that is still open.
function namespace.RefreshReleasedFade(module)
    module.RefreshExtras()
end

-- The windowScale range OpenMap's window options use.
function Provider:GetScaleRange()
    return 1.6, .05
end

-- OpenMap's windowScale settings action on Forever: the option, the settings
-- it writes, their current scale and the setting's key, or nothing.
function Provider:ReadScaleOption()
    -- Reviewed internal contract, not a public setter API. No mod:Refresh:
    -- rebuilding MapCanvas data providers is outside this settings action.
    local module, ownerDB = Contract.GetOpenMapWindowModule(true)
    if not module or not Number(ownerDB.windowScale)
        or type(module.WindowOptions) ~= "function" then return end
    local options = {}
    module:WindowOptions(options, function() return ownerDB.windowScale end,
        function(_, value) ownerDB.windowScale = value end,
        function() return ownerDB.enabled == false end)
    local option = options.windowScale
    if type(option) ~= "table" or option.min ~= .5 or option.max ~= 1.6
        or option.step ~= .05 or type(option.set) ~= "function"
        or type(option.disabled) ~= "function" or option.disabled() then return end
    return option, ownerDB, ownerDB.windowScale, "windowScale"
end

-- The expanded map hotkey supports OpenMap's world map on Forever.
function Provider:HandlesExpandedMap()
    return API.IsForeverClient() and Contract.GetOpenMapWorldMapModule() ~= nil
end

-- Windowed recovery needs the stitched OpenMap window.
function Provider:CanRecover()
    return Contract.GetOpenMapWindowModule() ~= nil
end

function Provider:Recover(workspace)
    return Recovery:Run(workspace)
end

function Provider:ReportRecoveryFailure(reason)
    API.Print(API.GetText(reason == "workspace-fit" and "OPENMAP_WORKSPACE_FIT" or "OPENMAP_RECOVERY_UNAVAILABLE"))
end

function Provider:ObserveUserDrag(map)
    Recovery:ObserveUserDrag(map)
end

-- In standard UI OpenMap takes over the maximized map while OpenMapAPI exists.
function Provider:HandlesFullscreen()
    return type(_G.OpenMapAPI) == "table"
end

-- A breaking OpenMap update: Offhand stands down its drag sync and recovery
-- helpers and says so once (Forever only).
function Provider:GetContractConflict()
    local contract = Contract.InspectOpenMapContract()
    if contract ~= "ok" and contract ~= "absent" and contract ~= "disabled" then
        return {
            id = "openmap-contract:" .. contract,
            kind = "openmap-contract",
            reason = contract,
        }
    end
end

function Provider:FormatConflict(conflict)
    if conflict.kind ~= "openmap-contract" then return end
    local fmt = API.GetText("COMPAT_CONFLICT_OPENMAP_CONTRACT")
        or "Notice: OpenMap updated to an unsupported contract (%s). Offhand stood down its OpenMap drag sync and recovery helpers."
    return string.format(fmt, conflict.reason)
end

-- With a supported contract OpenMap keeps the World Map in sync with a window
-- mover's writes, so that is no conflict.
function Provider:SyncsWorldMapMover()
    return Contract.InspectOpenMapContract() == "ok"
end

-- The detailed compatibility line's OpenMap part (Forever only).
function Provider:GetOwnerDiagnostics()
    local namespaceTable, data = _G.OpenMap, _G.OpenMapDB
    local version = type(namespaceTable) == "table" and namespaceTable.version
    local db = type(data) == "table" and data.worldmap
    if type(version) ~= "string" or type(db) ~= "table" then return end
    local getCVar = C_CVar and C_CVar.GetCVar or _G.GetCVar
    local cap = tonumber(db.mapFpsCap)
    local current = type(getCVar) == "function" and tonumber(getCVar("maxFPS"))
    local contract = Contract.InspectOpenMapContract()
    return string.format("OpenMap=%s | MapFPSCap=%s | maxFPS=%s | OpenMapWindow=%s | OpenMapContract=%s",
        version, cap or "unavailable", current or "unavailable",
        type(db.window) == "table" and "saved" or "none", contract)
end
