--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/MapWise/Bridge.lua: built-in bridge for MapWise's compact world map

    The MapWise parts of Core/CanvasForeverMap.lua, moved behind the bridge
    contract with unchanged behaviour: the reviewed MapWise 2 contract reader,
    its movement fade entry (map.fade, order 30) and the position guard that
    keeps MapWise's passive compact anchor replay from undoing Offhand's
    placement, with the observer fit that replaces it. Core calls the guard
    through Bridges:CallMap("MapWise", ...) while MapWiseAPI exists (role
    map.layoutGuard in Data.lua), passing its map state table by reference and
    a services table: NativeGamepadOwnsMap(), ShouldYieldWorldMap(map),
    IsDragging(map), GetWorkspaceMetrics(), GetSavedMapPositions(),
    IsPosition(position), ForFrame(metrics, map, position), FitWindow(map,
    metrics, onWorkspace), GetPanelPhysicalPlacement(map),
    ResolveWorkspacePosition(...), ClampWorkspacePoint(...).

    Registered on every client, like the core code it replaces; MapWise is read
    when asked.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function" then return end

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

local function ParseMajorVersion(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return nil end
    end
    if type(value) == "number" and value == value and value >= 0 and value < math.huge then
        return math.floor(value)
    end
    if type(value) ~= "string" then return nil end
    return tonumber(value:match("^v?(%d+)%."))
end

local function ReadMapWise(map)
    local api = _G.MapWiseAPI
    if type(api) ~= "table" or ParseMajorVersion(api.version) ~= 2
        or not IsAddonLoaded("MapWise") then return end
    local db, integration = api.db, api.Integration
    if type(db) == "table" and db == _G.MapWiseAtlasDB
        and type(integration) == "table" and integration.native == map then return db, api.MapWiseUI end
end

local function ReadMapWiseFade(map)
    local db = ReadMapWise(map)
    if db and type(db.fadeMapWhileMoving) == "boolean" then return db end
end

local Provider = { owner = "MapWise" }

function Provider:InstallPositionGuard(map, state, services)
    local db, vendor = ReadMapWise(map)
    if not db or type(vendor) ~= "table" or type(vendor.ApplyWindowPosition) ~= "function" then return end

    local applyWindowPosition = vendor.ApplyWindowPosition
    vendor.ApplyWindowPosition = function(self, ...)
        if not API.IsEnabled() or not map:IsShown() or (map.IsMaximized and map:IsMaximized())
            or services.NativeGamepadOwnsMap() or services.ShouldYieldWorldMap(map) or InCombatLockdown()
            or services.IsDragging(map) or self.dragging or self.positioning or self.resizeDrag
            or (map.IsForbidden and map:IsForbidden()) then return applyWindowPosition(self, ...) end

        local metrics = services.GetWorkspaceMetrics()
        if not metrics or not metrics.isSpanned then return applyWindowPosition(self, ...) end

        local workspace, mainhand = services.GetSavedMapPositions()
        if type(workspace) == "table" and workspace.autoRoute and not metrics.workspaceRegions then workspace = nil end
        if type(mainhand) == "table" and mainhand.autoRoute and not metrics.workspaceRegions then mainhand = nil end
        local onWorkspace = services.IsPosition(workspace)
        local position = onWorkspace and workspace or mainhand
        local firstLayout = not state.layoutOpened
        state.layoutOpened = true
        if not services.IsPosition(position) then
            local previous = state.layoutPlacement
            if firstLayout or not previous or previous.vendorPosition ~= db.compactPosition then
                return applyWindowPosition(self, ...)
            end
            onWorkspace, position = previous.onWorkspace, previous
        end

        -- MapWise invokes this method after its compact layout, including
        -- tabs with identical dimensions. Skip only its passive anchor
        -- replay. Fit on the independent observer, outside the click or
        -- native map stack. The vendor's move/resize/reset paths are separate.
        state.layoutPending = { position = position, onWorkspace = onWorkspace,
            vendorPosition = db.compactPosition }
        if self.UpdateWindowResetIcon then self:UpdateWindowResetIcon() end
    end
    state.layoutGuard = vendor
end

function Provider:UpdateLayout(map, state, shown, maximized, services)
    local vendor = state.layoutGuard
    if not vendor then return end
    local db = ReadMapWise(map)
    if not db then return end

    if not shown or maximized or services.NativeGamepadOwnsMap() or services.ShouldYieldWorldMap(map)
        or services.IsDragging(map) or vendor.dragging or vendor.resizeDrag then
        state.layoutPending, state.layoutPlacement = nil, nil
        if not shown then state.layoutOpened = nil end
        return
    end
    if InCombatLockdown() then return end
    local placement = services.GetPanelPhysicalPlacement(map)
    local layout = state.layoutPending
    state.layoutPending = nil
    if placement and layout and layout.vendorPosition == db.compactPosition then
        local metrics = services.GetWorkspaceMetrics()
        if layout.onWorkspace then
            metrics = services.ForFrame(metrics, map, layout.position)
        end
        if metrics and metrics.isSpanned then
            services.FitWindow(map, metrics, layout.onWorkspace)
            placement = services.GetPanelPhysicalPlacement(map)
            if placement then
                local x, y
                if layout.onWorkspace then
                    x, y = services.ResolveWorkspacePosition(
                        metrics, layout.position, placement.width, placement.height, false)
                else
                    x, y = services.ClampWorkspacePoint({
                        workspaceLeft = metrics.gameLeft, workspaceRight = metrics.gameRight,
                        workspaceBottom = metrics.gameBottom, workspaceTop = metrics.gameTop,
                    }, layout.position.x, layout.position.y, placement.width, placement.height)
                end
                if x and (math.abs(placement.x - x) > 0.01 or math.abs(placement.y - y) > 0.01) then
                    map:ClearAllPoints()
                    map:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / placement.factor, y / placement.factor)
                    placement = services.GetPanelPhysicalPlacement(map)
                end
            end
        end
    end
    if placement and (placement.onWorkspace or placement.onMainhand) then
        placement.vendorPosition = db.compactPosition
        state.layoutPlacement = placement
    else
        state.layoutPlacement = nil
    end
end

API.RegisterBridge("MapWise", {
    contract = API.BRIDGE_CONTRACT,
    mapProvider = Provider,
    data = {
        ownership = {
            { role = "map.fade", name = "MapWise", order = 30, detect = { loaded = "MapWise" },
                read = ReadMapWiseFade, key = "fadeMapWhileMoving", opaque = false,
                helpKey = "MAP_MOVEMENT_MAPWISE" },
        },
    },
})
