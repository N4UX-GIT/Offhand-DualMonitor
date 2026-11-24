--[[
    Offhand: Multi-Monitor Setup Addon
    Core/Bridges.lua: registry and public services for bridge modules and addons

    A bridge adapts one third-party addon to Offhand. Core modules stay free of
    bridged addon specifics: a bridge registers through Offhand.API and the core
    calls it at fixed, pcall-isolated points. See docs/BRIDGES.md for the contract.

    Bridge contract originally contributed by Kintrok (@DCtheGeek).
--]]

local _, Offhand = ...

local Bridges = { CONTRACT = 1, errors = {} }
Offhand.Bridges = Bridges
Offhand.API = Offhand.API or {}
Offhand.API.BRIDGE_CONTRACT = Bridges.CONTRACT

local registry, order = {}, {}
local namespaces, fallbackStorage = {}, {}

-- Returns true, or false and one of "id", "bridge", "contract", "duplicate".
function Bridges:Register(id, bridge)
    if type(id) ~= "string" or id == "" then return false, "id" end
    if type(bridge) ~= "table" then return false, "bridge" end
    if bridge.contract ~= self.CONTRACT then return false, "contract" end
    if registry[id] and registry[id] ~= bridge then return false, "duplicate" end
    if not registry[id] then
        registry[id] = bridge
        order[#order + 1] = id
    end
    bridge.id = id
    if type(bridge.catalog) == "table" and type(Offhand.AddonWindowCatalog) == "table" then
        Offhand.AddonWindowCatalog[id] = bridge.catalog
    end
    return true
end

function Bridges:Get(id)
    return registry[id]
end

function Bridges:List()
    local ids = {}
    for index, id in ipairs(order) do ids[index] = id end
    return ids
end

-- A failing bridge never breaks Offhand or another bridge. Its latest error is
-- kept for diagnostics and the bridge stays registered.
local function Call(id, method, ...)
    local bridge = registry[id]
    local handler = bridge and bridge[method]
    if type(handler) ~= "function" then return false end
    local ok, result = pcall(handler, bridge, ...)
    if not ok then
        Bridges.errors[id] = tostring(result)
        return false
    end
    return true, result
end

-- reason: "layout" (Canvas:UpdateLayout), "map" (Canvas:ConfigureWorldMap) or
-- "tick" (the Forever position ticker, twice a second). Can run in combat.
function Bridges:Refresh(reason)
    for _, id in ipairs(order) do Call(id, "Refresh", reason) end
end

-- services: the bag Escape helpers documented in docs/BRIDGES.md.
function Bridges:RefreshBags(services)
    for _, id in ipairs(order) do Call(id, "RefreshBags", services) end
end

function Bridges:GetDiagnostics()
    local parts = {}
    for _, id in ipairs(order) do
        local ok, text = Call(id, "GetDiagnostics")
        if ok and type(text) == "string" and text ~= "" then parts[#parts + 1] = text end
        if self.errors[id] then parts[#parts + 1] = "Bridge:" .. id .. "=error" end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " | ")
end

-- True when a bridge's addon has just restored its own single-screen position
-- for this frame, so generic single-screen recovery must leave it alone.
function Bridges:ShouldPreserveSingleScreenPosition(frame, metrics)
    for _, id in ipairs(order) do
        local ok, keep = Call(id, "ShouldPreserveSingleScreenPosition", frame, metrics)
        if ok and keep == true then return true end
    end
    return false
end

-- onWorkspace(frame) is the caller's own test; bridges only name their frames.
function Bridges:IsBagOnWorkspace(onWorkspace)
    if type(onWorkspace) ~= "function" then return false end
    for _, id in ipairs(order) do
        local ok, frames = Call(id, "GetBagFrames")
        if ok and type(frames) == "table" then
            for _, frame in pairs(frames) do
                if onWorkspace(frame) then return true end
            end
        end
    end
    return false
end

-- True while a bridged addon's own unlock/edit mode is active, so Offhand's
-- generic window selection pauses cleanly just like Blizzard Edit Mode.
function Bridges:IsEditModeActive()
    for _, id in ipairs(order) do
        local ok, active = Call(id, "IsEditModeActive")
        if ok and active == true then return true end
    end
    return false
end

-- Optional bridge opt-in for learned placement of a reviewed standalone window
-- belonging to a cataloged bridge addon.
function Bridges:CanLearnPlacement(frame, name, owner, file)
    local bridge = registry[owner]
    if not bridge or type(bridge.catalog) ~= "table" then return false end
    local ok, role = Call(owner, "IdentifyLearnPlacement", frame, name, file)
    if not ok or type(role) ~= "string" then return false end
    local entry = bridge.catalog[role]
    return type(entry) == "table" and entry.learnPlacementFile == file or false
end

-- Addon names whose versions belong in the map integration diagnostics.
function Bridges:GetMapAddons()
    local names, seen = {}, {}
    for _, id in ipairs(order) do
        local list = registry[id].mapAddons
        if type(list) == "table" then
            for _, name in ipairs(list) do
                if type(name) == "string" and name ~= "" and not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end
        end
    end
    return names
end

-- ---------------------------------------------------------------------
-- Public services for bridges (Offhand.API)
-- ---------------------------------------------------------------------

function Offhand.API.RegisterBridge(id, bridge)
    return Bridges:Register(id, bridge)
end

-- Private shared namespace for multi-file built-in bridges hosted inside
-- Offhand's own addon folder so they do not pollute Offhand's root table.
function Offhand.API.GetBridgeNamespace(id)
    if type(id) ~= "string" or id == "" then return {} end
    if not namespaces[id] then namespaces[id] = {} end
    return namespaces[id]
end

-- Account-wide persistent storage for built-in bridges under OffhandDB.bridges,
-- avoiding separate SavedVariables files.
function Offhand.API.GetBridgeStorage(id)
    if type(id) ~= "string" or id == "" then return {} end
    local account = _G.OffhandDB
    if type(account) == "table" then
        if type(account.bridges) ~= "table" then account.bridges = {} end
        if type(account.bridges[id]) ~= "table" then
            account.bridges[id] = fallbackStorage[id] or {}
        end
        fallbackStorage[id] = account.bridges[id]
        return account.bridges[id]
    end
    if not fallbackStorage[id] then fallbackStorage[id] = {} end
    return fallbackStorage[id]
end

function Offhand.API.FlushBridgeStorage()
    local persistence = Offhand.ForeverPersistence
    if persistence and type(persistence.SaveProfileSnapshot) == "function" then
        pcall(persistence.SaveProfileSnapshot, persistence, true)
    end
end

-- The game rectangle as it is now, in UIParent units from its bottom-left
-- corner: left, bottom, right, top, width, height, screenWidth, screenHeight,
-- isSpanned. The whole screen when Offhand is off or WoW is not spanned.
-- Unlike GetMainhandRect this is never a cached value.
function Offhand.API.GetGameRect()
    local geometry = Offhand.MainhandGeometry
    if geometry and geometry.GetCurrentRect then
        local ok, rect = pcall(geometry.GetCurrentRect)
        if ok and type(rect) == "table" then return rect end
    end
    local width = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
    local height = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
    return {
        left = 0, bottom = 0, right = width, top = height,
        width = width, height = height,
        screenWidth = width, screenHeight = height,
        isSpanned = false,
    }
end

-- Whether Offhand is placing the compact world map itself right now: it is
-- enabled and spanned, may manage panels, has a saved map position, and no
-- other map addon owns the geometry. A bridge for an addon with its own map
-- mover stands that mover aside while this is true.
function Offhand.API.OwnsWorldMapPlacement()
    local db, map = Offhand.db, _G.WorldMapFrame
    if not db or not db.enabled or not map or type(map.GetScale) ~= "function"
        or (map.IsForbidden and map:IsForbidden()) then return false end
    if map.IsMaximized and map:IsMaximized() then return false end
    local canvas = Offhand.Canvas
    if not canvas or not canvas.CanManagePanelsFromAddon
        or not canvas.CanManagePanelsFromAddon() then return false end
    local compatibility = Offhand.CanvasCompatibility
    if compatibility and compatibility.GetWorldMapExternalOwner() then return false end
    local persistence = Offhand.CanvasPersistence
    if not persistence or not (persistence.IsPosition(db.savedWorkspacePositions
        and db.savedWorkspacePositions.WorldMapFrame)
        or persistence.IsPosition(db.savedMainPositions and db.savedMainPositions.WorldMapFrame)) then
        return false
    end
    local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not metrics or not metrics.isSpanned then return false end
    return true
end

-- Where Offhand puts group loot roll pop-ups: the centre of a slot of the
-- given height, in UIParent units from its bottom-left corner. The player's
-- own Group Loot Rolls position if one was saved, else the middle of the game
-- rectangle, 190 HUD units up. Nil when the game rectangle is the whole screen.
function Offhand.API.GetGroupLootSpot(height)
    local rect = Offhand.API.GetGameRect()
    if rect.left <= 0 and rect.right >= rect.screenWidth
        and rect.bottom <= 0 and rect.top >= rect.screenHeight then return nil end
    local db = type(Offhand.db) == "table" and Offhand.db or nil
    local position = db and db.groupLootPosition
    local x = type(position) == "table" and tonumber(position.x) or nil
    local y = type(position) == "table" and tonumber(position.y) or nil
    if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
        return rect.left + (rect.right - rect.left) * x, rect.bottom + (rect.top - rect.bottom) * y
    end
    local hud = 1
    if db and Offhand.Viewport and Offhand.Viewport.GetMetrics then
        local ok, metrics = pcall(Offhand.Viewport.GetMetrics, Offhand.Viewport)
        if ok and type(metrics) == "table" and type(metrics.hudScale) == "number"
            and metrics.hudScale > 0 then hud = metrics.hudScale end
    end
    return (rect.left + rect.right) / 2,
        rect.bottom + 190 * hud + (type(height) == "number" and height or 100) / 2
end
