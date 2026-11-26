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
    local state = {available=false, owner=owner, min=.5, max=2.5, step=.01, value=1}
    -- An owner's provider can narrow the range to the one its own scale uses.
    local bridges = Offhand.Bridges
    local max, step
    if owner and bridges then max, step = bridges:CallMap(owner, "GetScaleRange") end
    if max and step then state.max, state.step = max, step end
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
    if metrics and Offhand.WorkspaceRegions then
        local saved = not owner and db.savedWorkspacePositions and db.savedWorkspacePositions.WorldMapFrame
        metrics = Offhand.WorkspaceRegions:ForFrame(metrics, map, saved)
    end
    if owner then
        state.workspace = Offhand.Canvas.IsFrameOnWorkspace(map)
        if not Offhand.isForever or not bridges then return state end
        -- On Forever the owner's provider can offer its own scale setting: the
        -- option whose set({key}, value) applies it, the settings it writes,
        -- the current value and the setting's key.
        local option, ownerDB, value, key = bridges:CallMap(owner, "ReadScaleOption")
        if type(option) ~= "table" then return state end
        state.option, state.ownerDB, state.optionKey = option, ownerDB, key
        state.value = value
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
    return ok and state or {available=false, min=.5, max=2.5, step=.01, value=1}
end

function Scale:ObserveMapChanges(card, refresh)
    if not (EventRegistry and EventRegistry.RegisterCallback and C_Timer and C_Timer.After) then return end
    local pending = false
    local function QueueRefresh()
        if pending or not card:IsVisible() then return end
        pending = true
        -- Read the final map mode after Blizzard and the map provider have handled the event.
        C_Timer.After(0, function()
            pending = false
            if card:IsVisible() then refresh() end
        end)
    end
    for _, event in ipairs({"WorldMapOnShow", "WorldMapOnHide", "WorldMapMaximized", "WorldMapMinimized", "MapCanvas.MapSet"}) do
        EventRegistry:RegisterCallback(event, QueueRefresh, card)
    end
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
        state.option.set({state.optionKey}, requested)
    else
        Offhand.db[state.key] = value == "AUTO" and "AUTO" or requested
        Offhand.Canvas:ConfigureWorldMap()
        if Offhand.Canvas.RestoreWorkspacePosition then Offhand.Canvas.RestoreWorkspacePosition(state.map) end
    end
    return true
end
