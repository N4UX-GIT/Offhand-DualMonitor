-- Explicit settings actions. Map geometry continues to belong to its owner.
local _, Offhand = ...
local Scale = {}
Offhand.MapScale = Scale

local function Number(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return nil end
    return value
end

local function Inspect()
    local db, map = Offhand.db, _G.WorldMapFrame
    local owner = Offhand.CanvasCompatibility.GetWorldMapExternalOwner()
    local state = {available=false, owner=owner, min=.5, max=2.5, value=1}
    if owner == "OpenMap" then state.max = 1.6 end
    if not db or not db.enabled or not map or (map.IsForbidden and map:IsForbidden()) then return state end
    state.value = Number(map:GetScale()) or 1
    if (InCombatLockdown and InCombatLockdown())
        or (map.IsMaximized and map:IsMaximized())
        or (Offhand.isForever and Offhand.IsGamepadUIEnabled and Offhand:IsGamepadUIEnabled())
        or (Offhand.CanvasMapPresentation and Offhand.CanvasMapPresentation.IsNativeGamepadOwned(Offhand.Canvas)) then
        return state
    end
    local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    state.workspace = db.savedWorkspacePositions and db.savedWorkspacePositions.WorldMapFrame
        or (not (db.savedMainPositions and db.savedMainPositions.WorldMapFrame)
            and Offhand.Canvas.IsFrameOnWorkspace(map))
    state.key = state.workspace and "workspaceMapScale" or "mainMapScale"
    if owner then
        state.workspace = Offhand.Canvas.IsFrameOnWorkspace(map)
        if owner ~= "OpenMap" or not Offhand.isForever then return state end
        local namespace, api = _G.OpenMap, _G.OpenMapAPI
        -- Reviewed internal contract, not a public setter API. No mod:Refresh:
        -- rebuilding MapCanvas data providers is outside this settings action.
        if type(namespace) ~= "table" or namespace.version ~= "v0.7.5-beta"
            or type(namespace.GetModule) ~= "function" or type(api) ~= "table"
            or api.major ~= 1 or api.version ~= 4 or type(api.IsStitched) ~= "function"
            or not api.IsStitched() then return state end
        local module = namespace:GetModule("worldmap")
        local ownerDB = type(module) == "table" and module.db
        if type(ownerDB) ~= "table" or ownerDB.enabled == false
            or type(_G.OpenMapDB) ~= "table" or ownerDB ~= _G.OpenMapDB.worldmap
            or not Number(ownerDB.windowScale) or type(module.WindowOptions) ~= "function" then return state end
        local options = {}
        module:WindowOptions(options, function() return ownerDB.windowScale end,
            function(_, value) ownerDB.windowScale = value end,
            function() return ownerDB.enabled == false end)
        local option = options.windowScale
        if type(option) ~= "table" or option.min ~= .5 or option.max ~= 1.6
            or option.step ~= .05 or type(option.set) ~= "function"
            or type(option.disabled) ~= "function" or option.disabled() then return state end
        state.option, state.ownerDB = option, ownerDB
        state.value = ownerDB.windowScale
    else
        if not metrics or not metrics.isSpanned then return state end
        state.value = tonumber(db[state.key]) or Number(map:GetScale()) or 1
    end
    state.map, state.metrics = map, metrics
    state.available = true
    return state
end

function Scale:GetState()
    local ok, state = pcall(Inspect)
    return ok and state or {available=false, min=.5, max=2.5, value=1}
end

local function Fit(state)
    local map, m = state.map, state.metrics
    if not m then return end
    local width, height = Number(map:GetWidth()), Number(map:GetHeight())
    local effective, own = Number(map:GetEffectiveScale()), Number(map:GetScale())
    local parent = Number(UIParent:GetEffectiveScale())
    local areaWidth = Number(state.workspace and (m.workspaceWidth or m.deckWidth) or m.gameWidth)
    local areaHeight = Number(state.workspace and m.workspaceHeight or m.gameHeight)
    if not width or width <= 0 or not height or height <= 0 or not effective or effective <= 0
        or not own or own <= 0 or not parent or parent <= 0
        or not areaWidth or areaWidth <= 24 or not areaHeight or areaHeight <= 24 then return end
    local inherited = effective / own / parent
    return math.max(state.min, math.min(state.max,
        (areaWidth - 24) / width / inherited, (areaHeight - 24) / height / inherited))
end

function Scale:Set(value)
    local state = self:GetState()
    if not state.available then return false end
    local requested = value == "AUTO" and Fit(state) or Number(value)
    if not requested then return false end
    requested = math.max(state.min, math.min(state.max, requested))
    if state.option then
        -- Invoke the owner's narrow Apply closure with a DB-only setter.
        -- Its existing Hold hook, reopen and reload paths now agree with it.
        state.option.set({"windowScale"}, requested)
    else
        Offhand.db[state.key] = value == "AUTO" and "AUTO" or requested
        Offhand.Canvas:ConfigureWorldMap()
        if Offhand.Canvas.RestoreWorkspacePosition then Offhand.Canvas.RestoreWorkspacePosition(state.map) end
    end
    return true
end
