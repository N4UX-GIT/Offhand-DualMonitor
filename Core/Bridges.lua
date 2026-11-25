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

-- True when any registered bridge currently provides a live replacement bag frame.
function Bridges:HasCustomBag()
    for _, id in ipairs(order) do
        local ok, frames = Call(id, "GetBagFrames")
        if ok and type(frames) == "table" then
            for _, frame in pairs(frames) do
                if frame ~= nil then return true, id end
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

-- Snapshot any bridge-owned workspace open state before reload/logout.
function Bridges:CaptureWorkspaceState()
    for _, id in ipairs(order) do Call(id, "CaptureWorkspaceState") end
end

-- Restore bridge-owned workspace open state once the span is active.
function Bridges:RestoreWorkspaceState(mode)
    for _, id in ipairs(order) do Call(id, "RestoreWorkspaceState", mode) end
end

-- Pause/hide bridge-owned workspace windows during single-screen recovery
-- without discarding their workspace open intent.
function Bridges:PrepareSingleScreenRecovery(metrics)
    for _, id in ipairs(order) do Call(id, "PrepareSingleScreenRecovery", metrics) end
end

-- True when a bridge currently parks this native Blizzard panel out of sight
-- under its own holder so Offhand's core must leave its anchor/visibility alone.
function Bridges:IsParkedNativePanel(frame)
    if not frame then return false end
    for _, id in ipairs(order) do
        local ok, parked = Call(id, "IsParkedNativePanel", frame)
        if ok and parked == true then return true end
    end
    return false
end

-- Optional HUD alignment/reset actions offered by active bridges for Offhand's
-- Settings panel, keeping bridge-specific UI text out of core options code.
function Bridges:GetHUDLayoutActions()
    local actions = {}
    for _, id in ipairs(order) do
        local ok, list = Call(id, "GetHUDLayoutActions")
        if ok and type(list) == "table" then
            for _, entry in ipairs(list) do
                if type(entry) == "table" and type(entry.id) == "string" and entry.id ~= "" then
                    actions[#actions + 1] = entry
                end
            end
        end
    end
    return actions
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

-- True when (x, y) in UIParent units from bottom-left lands inside Mainhand
-- or any active Offhand workspace region (false inside L/T-shaped dead voids).
function Offhand.API.IsPointVisible(x, y)
    if type(x) ~= "number" or type(y) ~= "number"
        or x ~= x or y ~= y or math.abs(x) == math.huge or math.abs(y) == math.huge then
        return false
    end
    local rect = Offhand.API.GetGameRect()
    if x >= rect.left and x <= rect.right and y >= rect.bottom and y <= rect.top then
        return true
    end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
    if type(metrics) ~= "table" or not metrics.isSpanned then return false end
    if type(metrics.workspaceRegions) == "table" then
        for _, r in ipairs(metrics.workspaceRegions) do
            if type(r) == "table" and type(r.x) == "number" and type(r.y) == "number"
                and type(r.width) == "number" and type(r.height) == "number"
                and x >= r.x and x <= r.x + r.width and y >= r.y and y <= r.y + r.height then
                return true
            end
        end
        return false
    end
    return type(metrics.workspaceLeft) == "number" and type(metrics.workspaceRight) == "number"
        and type(metrics.workspaceBottom) == "number" and type(metrics.workspaceTop) == "number"
        and x >= metrics.workspaceLeft and x <= metrics.workspaceRight
        and y >= metrics.workspaceBottom and y <= metrics.workspaceTop
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

-- Active Offhand workspace monitor rectangles in UIParent units from
-- bottom-left. Empty when Offhand is disabled or the client is not spanned.
function Offhand.API.GetWorkspaceRects()
    local rects = {}
    if not Offhand.db or not Offhand.db.enabled then return rects end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
    if type(metrics) ~= "table" or not metrics.isSpanned then return rects end
    if type(metrics.workspaceRegions) == "table" and #metrics.workspaceRegions > 0 then
        for _, r in ipairs(metrics.workspaceRegions) do
            if type(r) == "table" and type(r.x) == "number" and type(r.y) == "number"
                and type(r.width) == "number" and type(r.height) == "number"
                and r.width > 0 and r.height > 0 then
                rects[#rects + 1] = {
                    id = r.id,
                    left = r.x, bottom = r.y,
                    right = r.x + r.width, top = r.y + r.height,
                    width = r.width, height = r.height,
                }
            end
        end
        return rects
    end
    if type(metrics.workspaceLeft) == "number" and type(metrics.workspaceRight) == "number"
        and type(metrics.workspaceBottom) == "number" and type(metrics.workspaceTop) == "number"
        and metrics.workspaceRight > metrics.workspaceLeft and metrics.workspaceTop > metrics.workspaceBottom then
        rects[1] = {
            id = "WORKSPACE",
            left = metrics.workspaceLeft, bottom = metrics.workspaceBottom,
            right = metrics.workspaceRight, top = metrics.workspaceTop,
            width = metrics.workspaceRight - metrics.workspaceLeft,
            height = metrics.workspaceTop - metrics.workspaceBottom,
        }
    end
    return rects
end

-- True when frame's current center sits on an active Offhand workspace monitor.
function Offhand.API.IsFrameOnWorkspace(frame)
    if not frame or type(frame) ~= "table" then return false end
    if Offhand.Canvas and type(Offhand.Canvas.IsFrameOnWorkspace) == "function" then
        local ok, onWorkspace = pcall(Offhand.Canvas.IsFrameOnWorkspace, frame)
        if ok then return onWorkspace == true end
    end
    local rects = Offhand.API.GetWorkspaceRects()
    if #rects == 0 then return false end
    local ok, cx, cy = pcall(function()
        if frame.IsForbidden and frame:IsForbidden() then return nil end
        local left, bottom = frame.GetLeft and frame:GetLeft(), frame.GetBottom and frame:GetBottom()
        local w, h = frame.GetWidth and frame:GetWidth(), frame.GetHeight and frame:GetHeight()
        if type(left) ~= "number" or type(bottom) ~= "number" or type(w) ~= "number" or type(h) ~= "number" then
            return nil
        end
        local fs = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local ps = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if fs <= 0 or ps <= 0 then return nil end
        local k = fs / ps
        return (left + w / 2) * k, (bottom + h / 2) * k
    end)
    if not ok or type(cx) ~= "number" or type(cy) ~= "number" then return false end
    for _, r in ipairs(rects) do
        if cx >= r.left and cx <= r.right and cy >= r.bottom and cy <= r.top then return true end
    end
    return false
end

-- True when Offhand is configured to keep Offhand workspace panels open on Escape.
function Offhand.API.IsEscapeProtectionEnabled()
    local db = Offhand.db
    return type(db) == "table" and db.enabled == true
        and db.persistentWorkspacePanels ~= false
end

-- True when Offhand is configured to keep and restore Offhand workspace panels
-- across Escape and UI reloads.
function Offhand.API.IsWorkspacePersistenceEnabled()
    local db = Offhand.db
    return type(db) == "table" and db.enabled == true
        and db.persistentWorkspacePanels ~= false
        and db.restoreWorkspaceOnReload ~= false
end

-- Notify Offhand after a bridged addon's drag bar moves a standard Blizzard
-- panel so Offhand records workspace/Mainhand ownership and reload open state.
function Offhand.API.NotifyExternalPanelMoved(frame)
    local canvas = Offhand.Canvas
    if not canvas or type(canvas.RecordExternalPanelDrag) ~= "function" then return false end
    local ok, recorded = pcall(canvas.RecordExternalPanelDrag, canvas, frame)
    return ok and recorded == true
end

-- Clear Offhand's workspace ownership for a standard Blizzard panel when a
-- bridged addon resets that panel back to Blizzard's default anchor.
function Offhand.API.ForgetExternalWorkspacePanel(name)
    local canvas = Offhand.Canvas
    if not canvas or type(canvas.ForgetExternalWorkspacePanel) ~= "function" then return false end
    local ok, cleared = pcall(canvas.ForgetExternalWorkspacePanel, canvas, name)
    return ok and cleared == true
end
