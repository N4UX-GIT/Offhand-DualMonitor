-- Temporary diagnostics only. No hooks, CVar writes, window/frame mutations,
-- profile changes, chat capture, character names or automatic recovery.
local Probe = {}
OffhandDisplayProbe = Probe
local frame = CreateFrame("Frame")
local active, elapsed, pollElapsed, heartbeat = nil, 0, 0, 0
local lastSignature
local mapCallbacks = {}
local mapEvents = {"WorldMapOnShow", "WorldMapOnHide", "WorldMapMinimized", "WorldMapMaximized"}
local LIMIT, DURATION = 360, 180
local cvars = {"vsync", "gxVSync", "gxWindow", "gxMaximize", "gxResolution",
    "gxMonitor", "gxApi", "gxRefresh", "useUiScale", "uiScale", "renderScale",
    "gxTripleBuffer", "maxFPS", "maxFPSBk", "lowLatencyMode", "graphicsQuality", "miniWorldMap"}
local watched = {}
for _, name in ipairs(cvars) do watched[name:lower()] = true end
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then
        local safe, result = pcall(function()
            if type(value) == "boolean" then return value end
            if type(value) == "number" and value == value and math.abs(value) < math.huge then return value end
            if type(value) == "string" then return value:sub(1, 160) end
        end)
        if safe then return result end
    end
end
local function Say(key)
    -- Temporary English diagnostic commands, not a product setup flow.
    print("Offhand display capture: " .. key)
end
local function UTC()
    return date and date("!%Y-%m-%dT%H:%M:%SZ") or "unavailable"
end
local function Snapshot(reason)
    local state = {reason = reason, utc = UTC(), elapsed = elapsed, cvars = {}, canvas = {}, metrics = {}}
    local signature = {}
    local function Put(target, key, value)
        if value ~= nil then target[key] = value end
        signature[#signature + 1] = key .. "=" .. tostring(value)
    end
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    for _, name in ipairs(cvars) do Put(state.cvars, name, Read(getter, name)) end
    if UIParent then
        Put(state.canvas, "width", Read(UIParent.GetWidth, UIParent))
        Put(state.canvas, "height", Read(UIParent.GetHeight, UIParent))
        Put(state.canvas, "effectiveScale", Read(UIParent.GetEffectiveScale, UIParent))
    end
    if GetPhysicalScreenSize then
        local ok, width, height = pcall(GetPhysicalScreenSize)
        if ok then
            Put(state.canvas, "physicalWidth", Read(function() return width end))
            Put(state.canvas, "physicalHeight", Read(function() return height end))
        end
    end
    local addon = _G.Offhand
    if addon then
        Put(state.metrics, "enabled", addon.db and addon.db.enabled == true)
        Put(state.metrics, "transition", addon._displayGeometryTransitionActive == true)
        if addon.Viewport and addon.Viewport.GetMetrics then
            local ok, m = pcall(addon.Viewport.GetMetrics, addon.Viewport)
            if ok and type(m) == "table" then
                for _, key in ipairs({"isSpanned", "companionTopology", "topologyStatus", "manualCanvasState",
                    "physicalWidth", "physicalHeight", "gameLeft", "gameRight", "gameBottom", "gameTop", "hudScale"}) do
                    Put(state.metrics, key, Read(function() return m[key] end))
                end
            end
        end
    end
    Put(state.metrics, "hudDeferred", type(OffhandCharDB) == "table" and OffhandCharDB.mainhandLayoutDeferred == true)
    state.frames = {}
    for _, name in ipairs({"UIParent", "WorldFrame", "WorldMapFrame"}) do
        local target = _G[name]
        if target and not Read(target.IsForbidden, target) then
            local values = {}
            for key, method in pairs({shown="IsShown", left="GetLeft", bottom="GetBottom",
                width="GetWidth", height="GetHeight", scale="GetEffectiveScale"}) do
                Put(values, key, Read(target[method], target))
            end
            state.frames[name] = values
        end
    end
    return state, table.concat(signature, "|")
end
local function Append(reason, force)
    if not active then return end
    local state, signature = Snapshot(reason)
    if force or signature ~= lastSignature then
        if #active.records >= LIMIT then Probe:Stop("record limit"); return end
        active.records[#active.records + 1] = state
        lastSignature = signature
    end
end
function Probe:Stop(reason)
    if not active then return end
    active.stoppedUTC, active.stopReason = UTC(), reason or "manual"
    active.duration = elapsed
    active = nil
    frame:SetScript("OnUpdate", nil)
    frame:UnregisterAllEvents()
    if EventRegistry and type(EventRegistry.UnregisterCallback) == "function" then
        for name in pairs(mapCallbacks) do pcall(EventRegistry.UnregisterCallback, EventRegistry, name, Probe) end
    end
    mapCallbacks = {}
    if reason ~= "logout" then Say("stopped. Exit WoW normally after taking the result screenshot to save the log.") end
end
function Probe:Start()
    if active then Say("already recording; use /ohcapture stop first."); return end
    OffhandDisplayProbeDB = type(OffhandDisplayProbeDB) == "table" and OffhandDisplayProbeDB or {}
    local db = OffhandDisplayProbeDB
    db.schema = 1
    db.captures = type(db.captures) == "table" and db.captures or {}
    -- Keep only the previous and current capture, bounding SavedVariables growth.
    while #db.captures >= 2 do table.remove(db.captures, 1) end
    local version, build, _, interface = GetBuildInfo()
    active = {startedUTC = UTC(), version = version, build = build, interface = interface, records = {}}
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    active.addonRelease = Read(metadata, "Offhand", "X-Offhand-Release")
    db.captures[#db.captures + 1] = active
    elapsed, pollElapsed, heartbeat, lastSignature = 0, 0, 0, nil
    for _, event in ipairs({"CVAR_UPDATE", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "PLAYER_LOGOUT"}) do
        frame:RegisterEvent(event)
    end
    Append("start", true)
    -- Use the native callback registry, not hooks/fields on the protected map.
    if EventRegistry and type(EventRegistry.RegisterCallback) == "function"
        and type(EventRegistry.UnregisterCallback) == "function" then
        for _, name in ipairs(mapEvents) do
            local observed = name
            local ok = pcall(EventRegistry.RegisterCallback, EventRegistry, observed,
                function() Append(observed, true) end, Probe)
            if ok then mapCallbacks[observed] = true end
        end
    end
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed, pollElapsed, heartbeat = elapsed + delta, pollElapsed + delta, heartbeat + delta
        if elapsed >= DURATION then Append("timeout", true); Probe:Stop("timeout"); return end
        if pollElapsed >= 0.25 then
            pollElapsed = 0
            Append(heartbeat >= 5 and "heartbeat" or "poll", heartbeat >= 5)
            if heartbeat >= 5 then heartbeat = 0 end
        end
    end)
    Say("recording for up to 3 minutes. Open the map once OR make one Graphics Options change, then /ohcapture stop BEFORE re-spanning.")
end
frame:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGOUT" then Append("logout", true); Probe:Stop("logout"); return end
    if event == "CVAR_UPDATE" then
        name = type(name) == "string" and name:lower() or ""
        if not watched[name] then return end
        -- Coalesce bursts into the next 250ms sample while retaining event identity.
        if active then
            active.events = active.events or {}
            if #active.events < LIMIT then active.events[#active.events + 1] = {elapsed = elapsed, name = name} end
        end
        return
    end
    Append(event, true)
end)
SLASH_OFFHANDDISPLAYPROBE1 = "/ohcapture"
SlashCmdList.OFFHANDDISPLAYPROBE = function(message)
    message = tostring(message or ""):lower():match("^%s*(.-)%s*$")
    if message == "start" then Probe:Start()
    elseif message == "stop" then Append("stop", true); Probe:Stop("manual")
    else Say("/ohcapture start or /ohcapture stop. Logs are saved on normal logout; no settings are changed.") end
end
