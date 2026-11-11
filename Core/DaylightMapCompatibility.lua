-- Cooperate with DaylightUI's public map mover without changing its saved DB
-- or hooking the native map's geometry methods/scripts. Inspected 1.6.5.2/1.6.6:
-- Start accepts its config, Scale is read dynamically by all retained Apply
-- callbacks, and only MapMove reads the projected config supplied here.
local _, Offhand = ...
local Adapter = {}
Offhand.DaylightMapCompatibility = Adapter
local states = setmetatable({}, { __mode = "k" })
local current

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function FindModule()
    local vendor = _G.DaylightUI
    if not Offhand.isForever or type(vendor) ~= "table"
        or type(vendor.GetModule) ~= "function" then return end
    local ok, module = pcall(vendor.GetModule, vendor, "Skins")
    if ok and type(module) == "table" and type(module.ns) == "table" then
        return vendor, module, module.ns.MapMove
    end
end

local function WantsOwnership(state)
    local db, map = Offhand.db, _G.WorldMapFrame
    if state ~= current or not Offhand.isForever or not db or not db.enabled
        or _G.DaylightUI ~= state.vendor or state.module.enabled == false
        or type(state.module.db) ~= "table"
        or state.module.ns.MapMove ~= state.mover
        or state.mover.Start ~= state.wrappedStart or state.mover.Scale ~= state.wrappedScale
        or not map or type(map.GetScale) ~= "function"
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
    -- Do not acquire interactive controls in the middle of a vendor resize or
    -- combat. An already acquired projection can keep suppressing map writes.
    if state.mover.grip and state.mover.grip.grab then return false end
    if InCombat() and not state.active then return false end
    return true
end

local function Accessible(control)
    return control and type(control.IsMouseEnabled) == "function"
        and type(control.EnableMouse) == "function"
        and not (control.IsForbidden and control:IsForbidden())
        and not (control.IsProtected and control:IsProtected())
end

local function SyncControls(state)
    if InCombat() then return end
    for control, saved in pairs(state.controls) do
        if not state.active or (control ~= state.mover.bar and control ~= state.mover.grip) then
            if Accessible(control) then
                -- Restore only properties that still have our assigned value.
                if control:IsMouseEnabled() == false then control:EnableMouse(saved.mouse) end
                if saved.alpha ~= nil and control:GetAlpha() == 0 then control:SetAlpha(saved.alpha) end
                state.controls[control] = nil
            end
        end
    end
    if not state.active then return end
    for _, key in ipairs({ "bar", "grip" }) do
        local control = state.mover[key]
        if Accessible(control) then
            local saved = state.controls[control]
            if not saved then
                saved = { mouse = control:IsMouseEnabled() }
                state.controls[control] = saved
            end
            if control:IsMouseEnabled() then control:EnableMouse(false) end
            -- Apply can Show the grip after Scale returns. Alpha suppresses it
            -- throughout that same call without replacing any vendor scripts.
            if key == "grip" and control.GetAlpha and control.SetAlpha then
                if saved.alpha == nil then saved.alpha = control:GetAlpha() end
                if control:GetAlpha() ~= 0 then control:SetAlpha(0) end
            end
        end
    end
end

local function Sync(state)
    local wasActive = state.active
    state.active = WantsOwnership(state)
    if wasActive and not state.active then state.replay = true end
    SyncControls(state)
    return state.active
end

local function Install(vendor, module, mover)
    local state = states[mover]
    if state then return state end
    if type(mover) ~= "table" or type(mover.Start) ~= "function"
        or type(mover.Scale) ~= "function" or type(mover.Apply) ~= "function"
        or type(module.db) ~= "table" then return end
    state = {vendor = vendor, module = module, mover = mover, controls = {}, active = false,
        start = mover.Start, scale = mover.Scale}
    states[mover] = state
    -- Empty proxy, never stored in module.db or SavedVariables. Reads normally
    -- delegate; writes (including the player's Reset) always reach the real DB.
    state.proxy = setmetatable({}, {
        __index = function(_, key)
            if key == "mapSpot" and Sync(state) then return nil end
            return state.config and state.config[key]
        end,
        __newindex = function(_, key, value)
            if state.config then state.config[key] = value end
        end,
    })
    mover.Start = function(config)
        state.config = config
        return state.start(type(config) == "table" and state.proxy or config)
    end
    mover.Scale = function(...)
        if Sync(state) then return _G.WorldMapFrame:GetScale() end
        return state.scale(...)
    end
    state.wrappedStart, state.wrappedScale = mover.Start, mover.Scale
    return state
end

function Adapter:Refresh()
    local vendor, module, mover = FindModule()
    local previous = current
    if previous and (previous.vendor ~= vendor or previous.module ~= module or previous.mover ~= mover) then
        current = nil
        Sync(previous)
    end
    local state = mover and Install(vendor, module, mover)
    current = state
    if state then
        state.vendor, state.module = vendor, module
        Sync(state)
        if state.config ~= module.db then mover.Start(module.db) end
    end
    -- Old controls can still need restoration after a combat-time module swap.
    -- This small namespace registry is not a frame-tree or global scan.
    for _, pending in pairs(states) do
        if pending ~= state then Sync(pending) end
        if pending.replay and not InCombat() then
            pending.replay = nil
            if pending == state and not pending.active and pending.module.enabled ~= false then
                pending.mover.Apply()
            end
        end
    end
end

function Adapter:GetDiagnostics()
    if not current then return nil end
    return "DaylightMap=" .. (current.active and "Offhand" or "DaylightUI")
end

-- The vendor's saved anchor resumes when spanning ends. Generic single-screen
-- recovery must not center the map again after the vendor's OnShow applies it.
function Adapter:ShouldPreserveSingleScreenPosition(frame, metrics)
    if not metrics or metrics.isSpanned or frame ~= _G.WorldMapFrame then return false end
    local vendor, module, mover = FindModule()
    local state = mover and states[mover]
    if not state or state.vendor ~= vendor or state.module ~= module
        or module.enabled == false or type(module.db) ~= "table"
        or mover.Start ~= state.wrappedStart or mover.Scale ~= state.wrappedScale then return false end
    local spot = module.db.mapSpot
    if type(spot) ~= "table" then return false end
    for i = 1, 2 do
        local value = spot[i]
        if (issecretvalue and issecretvalue(value)) or type(value) ~= "number"
            or value ~= value or math.abs(value) == math.huge then return false end
    end
    return true
end
