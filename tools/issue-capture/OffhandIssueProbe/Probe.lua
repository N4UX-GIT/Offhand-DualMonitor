-- Temporary observer, deliberately absent from the product TOCs. Native hooks
-- are installed only after /ohissue start. No scripts or fields on native frames,
-- geometry/CVar writes, SaveLayouts calls, chat capture or network messages.
local controller = CreateFrame("Frame")
local active, started, snapshotting, stopping
local hooked = setmetatable({}, {__mode = "k"})
local apiHooked = setmetatable({}, {__mode = "k"})
local frames = {"UIParent", "WorldFrame", "CharacterFrame", "ProfessionsFrame", "ProfessionsBookFrame",
    "TradeSkillFrame", "SkillFrame", "SpellBookFrame", "WorldMapFrame", "Minimap",
    "MinimapCluster", "PlayerFrame", "MainActionBar", "BuffFrame"}
local function Secret(value)
    if not issecretvalue then return false end
    local ok, secret = pcall(issecretvalue, value)
    return not ok or secret
end
local function Atom(value)
    if Secret(value) then return "<secret>" end
    local kind = type(value)
    if kind == "string" then return value:sub(1, 2048) end
    if kind == "boolean" then return value end
    if kind == "number" and value == value and math.abs(value) < math.huge then return value end
end
local function Field(value, key)
    if Secret(value) or type(value) ~= "table" then return nil end
    local ok, result = pcall(rawget, value, key)
    if ok then return result end
end
local function Read(frame, method)
    local ok, value = pcall(function()
        if frame.IsForbidden and frame:IsForbidden() then return nil end
        if type(frame[method]) == "function" then return frame[method](frame) end
    end)
    return ok and Atom(value) or nil
end
local function FrameName(frame)
    if Secret(frame) then return "<secret>" end
    if type(frame) == "string" then return frame:sub(1, 96) end
    if frame == nil then return "nil" end
    return Read(frame, "GetName") or "anonymous"
end
local function Combat()
    return InCombatLockdown and InCombatLockdown() or false
end
local function Stack()
    if type(debugstack) ~= "function" then return "unavailable" end
    local ok, trace = pcall(debugstack, 3, 8, 0)
    return ok and Atom(trace) or "unavailable"
end
local function Say(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("[Offhand issue capture] " .. message) end
end
local function Layouts(data)
    if Secret(data) then return {unavailable = true} end
    local output = {active = Atom(Field(data, "activeLayout")), layouts = {}}
    local rows = Field(data, "layouts")
    if Secret(rows) or type(rows) ~= "table" then output.unavailable = true; return output end
    for i = 1, 12 do
        local row = Field(rows, i)
        if row == nil then break end
        local layout = {index = i, layoutType = Atom(Field(row, "layoutType")), systems = {}}
        for j = 1, 80 do
            local entry = Field(Field(row, "systems"), j)
            if entry == nil then break end
            local system = {}
            for _, key in ipairs({"system", "systemIndex", "isInDefaultPosition"}) do
                system[key] = Atom(Field(entry, key))
            end
            local anchor = Field(entry, "anchorInfo")
            system.anchor = {}
            for _, key in ipairs({"point", "relativeTo", "relativePoint", "offsetX", "offsetY"}) do
                system.anchor[key] = Atom(Field(anchor, key))
            end
            layout.systems[#layout.systems + 1] = system
        end
        output.layouts[#output.layouts + 1] = layout
        if Field(Field(row, "systems"), 81) ~= nil then layout.truncated = true end
    end
    if Field(rows, 13) ~= nil then output.truncated = true end
    return output
end
local Stop
local function Record(event)
    if not active then return end
    if #active.events >= 120 then if not stopping then Stop("event-limit") end; return end
    event.elapsed = GetTime() - started
    event.combat = Combat()
    active.events[#active.events + 1] = event
end
local function Snapshot(label)
    if snapshotting or not active then return end
    if #active.snapshots >= 8 then active.snapshotLimitReached = true; return end
    local snapshot = {label = label:sub(1, 64), elapsed = GetTime() - started, combat = Combat()}
    active.snapshots[#active.snapshots + 1] = snapshot
    -- Write arguments can still be recorded during combat, but protected frame
    -- geometry and native layout tables are inspected only outside combat.
    if snapshot.combat then snapshot.state = "combat-deferred"; return end
    snapshotting = true
    snapshot.frames = {}
    for _, name in ipairs(frames) do
        local frame = _G[name]
        if frame then
            local row = {shown = Read(frame, "IsShown"), scale = Read(frame, "GetEffectiveScale"),
                left = Read(frame, "GetLeft"), top = Read(frame, "GetTop"),
                width = Read(frame, "GetWidth"), height = Read(frame, "GetHeight")}
            local ok, parent = pcall(function()
                if frame.IsForbidden and frame:IsForbidden() then return nil end
                return frame.GetParent and frame:GetParent()
            end)
            row.parent = ok and FrameName(parent) or "unavailable"
            snapshot.frames[name] = row
        end
    end
    if C_EditMode and type(C_EditMode.GetLayouts) == "function" then
        local ok, data = pcall(C_EditMode.GetLayouts)
        if ok then snapshot.editMode = Layouts(data) end
    end
    local viewport = _G.Offhand and _G.Offhand.Viewport
    local metrics
    if viewport and type(viewport.GetMetrics) == "function" then
        local ok, data = pcall(viewport.GetMetrics, viewport)
        if ok then
            metrics, snapshot.metrics = data, {}
            for _, key in ipairs({"physicalWidth", "physicalHeight", "screenWidth", "screenHeight",
                "gamePixelLeft", "gamePixelBottom", "gamePixelWidth", "gamePixelHeight", "topologyStatus",
                "isSpanned", "workspacePixelLeft", "workspacePixelBottom", "workspacePixelWidth", "workspacePixelHeight"}) do
                snapshot.metrics[key] = Atom(Field(data, key))
            end
        end
    end
    if viewport and type(viewport.GetPerformanceDiagnostics) == "function" then
        local ok, diagnostics = pcall(viewport.GetPerformanceDiagnostics, viewport, metrics)
        if ok and type(diagnostics) == "table" then
            snapshot.renderer = {}
            for _, key in ipairs({"fps", "spanPixels", "mainhandPixels", "boundsToMainhandRatio",
                "gxWindowedResolution", "renderScale", "maxFPS", "maxFPSBk", "gxVSync", "gxApi"}) do
                snapshot.renderer[key] = Atom(Field(diagnostics, key))
            end
        end
    end
    snapshotting = nil
end
local function InstallHooks()
    if not active or Combat() or type(hooksecurefunc) ~= "function" then return end
    for _, name in ipairs(frames) do
        local frame = _G[name]
        if frame and not hooked[frame] then
            local ok, forbidden = pcall(function() return frame.IsForbidden and frame:IsForbidden() end)
            if ok and not forbidden then
                hooked[frame] = true
                for _, method in ipairs({"SetPoint", "ClearAllPoints", "SetScale"}) do
                    local frameName, methodName = name, method
                    if type(frame[method]) == "function" then
                        local installed = pcall(hooksecurefunc, frame, method, function(_, a, b, c, x, y)
                            if not active then return end
                            Record({kind = "frame-write", frame = frameName, method = methodName,
                                point = Atom(a), relative = FrameName(b), relativePoint = Atom(c),
                                x = Atom(x), y = Atom(y), stack = Stack()})
                        end)
                        if not installed then active.hookGaps[frameName .. ":" .. methodName] = true end
                    end
                end
            end
        end
    end
    if C_EditMode and not apiHooked[C_EditMode] then
        apiHooked[C_EditMode] = true
        for _, method in ipairs({"SaveLayouts", "SetActiveLayout"}) do
            local methodName = method
            if type(C_EditMode[method]) == "function" then
                local installed = pcall(hooksecurefunc, C_EditMode, method, function(value)
                    if not active then return end
                    -- Save payload capture is bounded independently from event
                    -- capture and never invokes a native save or activation.
                    if methodName == "SaveLayouts" and not Combat() and #active.snapshots < 8 then
                        active.snapshots[#active.snapshots + 1] = {label = "SaveLayouts payload",
                            elapsed = GetTime() - started, editMode = Layouts(value)}
                    end
                    Record({kind = "editmode-call", method = methodName, value = Atom(value),
                        stack = Stack()})
                end)
                if not installed then active.hookGaps["C_EditMode:" .. methodName] = true end
            end
        end
    end
end
Stop = function(reason)
    if not active or stopping then return end
    stopping = true
    Snapshot("stop:" .. reason)
    active.stopReason, active.duration = reason, GetTime() - started
    active = nil
    stopping = nil
    controller:SetScript("OnUpdate", nil)
    Say("Stopped. Captures are saved on normal logout or /reload.")
end
local function Start(label)
    if Combat() then Say("Start outside combat."); return end
    if active then Stop("restart") end
    if OffhandIssueProbeDB == nil then OffhandIssueProbeDB = {schema = 1, runs = {}} end
    if type(OffhandIssueProbeDB) ~= "table" or OffhandIssueProbeDB.schema ~= 1
        or type(OffhandIssueProbeDB.runs) ~= "table" then Say("Unsupported capture data; left unchanged."); return end
    local runs = OffhandIssueProbeDB.runs
    while #runs >= 3 do table.remove(runs, 1) end
    local version, build, _, interface = GetBuildInfo()
    active = {label = label:sub(1, 64), version = Atom(version), build = Atom(build),
        interface = Atom(interface), offhand = Atom(_G.Offhand and _G.Offhand.fullVersion),
        events = {}, snapshots = {}, hookGaps = {}}
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if type(metadata) == "function" then
        local ok, value = pcall(metadata, "Offhand", "X-Offhand-Candidate")
        if ok then active.candidate = Atom(value) end
    end
    runs[#runs + 1] = active
    started = GetTime()
    Snapshot("start")
    InstallHooks()
    controller:SetScript("OnUpdate", function() if active and GetTime() - started >= 180 then Stop("time-limit") end end)
    Say("Started for up to 180 seconds. /ohissue mark LABEL, then /ohissue stop.")
end
SLASH_OFFHANDISSUEPROBE1 = "/ohissue"
SlashCmdList.OFFHANDISSUEPROBE = function(message)
    local command, label = (message or ""):match("^(%S+)%s*(.*)$")
    if command == "start" then Start(label)
    elseif command == "mark" then Snapshot(label)
    elseif command == "stop" then Stop("manual")
    else Say("/ohissue start LABEL | mark LABEL | stop. Last three captures only; local data, no messages sent.") end
end
controller:RegisterEvent("ADDON_LOADED")
controller:RegisterEvent("PLAYER_REGEN_DISABLED")
controller:RegisterEvent("PLAYER_REGEN_ENABLED")
controller:RegisterEvent("PLAYER_LOGOUT")
controller:SetScript("OnEvent", function(_, event)
    if not active then return end
    if event == "PLAYER_LOGOUT" then Stop("logout")
    elseif event == "ADDON_LOADED" then InstallHooks()
    else
        if event == "PLAYER_REGEN_ENABLED" then InstallHooks() end
        Snapshot(event)
    end
end)
