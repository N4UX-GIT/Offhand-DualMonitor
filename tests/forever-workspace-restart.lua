-- Exercise quit, process restart, and a later Companion span as one sequence.
-- Only the saved account and character tables cross the simulated process boundary.
local noop = function() end
StaticPopupDialogs, SlashCmdList = {}, {}
GetBuildInfo = function() return "1.60.1", "71037", "", 16001 end
GetScreenWidth = function() return 1920 end
InCombatLockdown = function() return false end
UIParent = { GetEffectiveScale = function() return 1 end }
UIPanelWindows = { WorldMapFrame = {}, CharacterFrame = {}, SocialUIFrame = {} }

local function panel(name)
    local frame = { shown = false, opens = 0 }
    function frame:GetName() return name end
    function frame:IsShown() return self.shown end
    frame.IsVisible = frame.IsShown
    function frame:GetWidth() return 160 end
    function frame:GetHeight() return 180 end
    frame.ClearAllPoints = noop
    function frame:SetPoint(_, _, _, x, y) self.x, self.y = x, y end
    function frame:Show() self.shown = true; self.opens = self.opens + 1 end
    function frame:Hide() self.shown = false end
    return frame
end

local function startSession(spanned)
    local addon, timers, dispatch = {}, {}, nil
    local metrics = { isSpanned = spanned, workspaceLeft = 0, workspaceRight = 1440,
        workspaceBottom = 0, workspaceTop = 600, workspaceWidth = 1440, workspaceHeight = 600,
        gameLeft = 1440, gameRight = 3360, gameBottom = 0, gameTop = 1080 }
    local time = 0
    GetTime = function() return time end
    local function later(delay, callback)
        local timer = { due = time + delay, run = callback }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end
    local function settle()
        local count = 0
        while #timers > 0 do
            count = count + 1
            assert(count < 100, "workspace restore must settle")
            local first = 1
            for i = 2, #timers do
                if timers[i].due < timers[first].due then first = i end
            end
            local timer = table.remove(timers, first)
            time = timer.due
            if not timer.cancelled then timer.run() end
        end
    end
    C_Timer = { After = later, NewTimer = later }
    CreateFrame = function(_, name)
        return { RegisterEvent = noop, SetScript = function(_, script, fn)
            if name == "OffhandEventFrame" and script == "OnEvent" then dispatch = fn end
        end }
    end
    WorldMapFrame = panel("WorldMapFrame")
    ContainerFrameCombinedBags = panel("ContainerFrameCombinedBags")
    CharacterFrame, SocialUIFrame = panel("CharacterFrame"), panel("SocialUIFrame")
    C_Map = { OpenWorldMap = function() WorldMapFrame:Show() end }
    OpenAllBags = function() ContainerFrameCombinedBags:Show() end
    for line in io.lines("Offhand_Forever.toc") do
        local path = line:gsub("\\", "/"):gsub("%s+$", "")
        if path == "Core/Init.lua" or path == "Core/ClientRuntime.lua" or path:match("^Core/Canvas.*%.lua$") then
            assert(loadfile(path))("Offhand", addon)
        end
    end
    addon.db = OffhandDB
    addon.Viewport = { GetMetrics = function() return metrics end }
    -- Geometry and notice rendering have their own suites. The real Init event
    -- handler, visibility decisions, bag opener and panel queue run here.
    addon.ApplyFullLayout = noop
    addon.RefreshCompanionNoticeState = noop
    addon.RefreshMainhandLayoutAttention = noop
    return function(event, ...) dispatch(nil, event, ...) end, settle, metrics
end

local function restartWith(spanAtLogin, mapOpen, bagOpen, characterOpen)
    OffhandDB = {
        enabled = true, firstRunComplete = true, savedMainPositions = {},
        savedWorkspacePositions = { WorldMapFrame = {x=20, y=500}, ContainerFrameCombinedBags = {x=300, y=500},
            CharacterFrame = {x=10, y=300}, SocialUIFrame = {x=400, y=300} },
        openWorkspacePanels = {},
    }
    OffhandCharDB = {}
    local beforeQuit = startSession(true)
    if mapOpen then WorldMapFrame:Show() end
    if characterOpen then CharacterFrame:Show() end
    if bagOpen then
        ContainerFrameCombinedBags:Show()
        Offhand.Canvas:SetWorkspacePanelOpen(ContainerFrameCombinedBags, true)
    end
    beforeQuit("PLAYER_LOGOUT")
    local event, settle, metrics = startSession(spanAtLogin)
    event("PLAYER_ENTERING_WORLD", true, false)
    settle()
    if not spanAtLogin then
        assert(not WorldMapFrame:IsShown() and not ContainerFrameCombinedBags:IsShown()
            and not CharacterFrame:IsShown(), "saved windows must wait for the workspace")
        metrics.isSpanned = true
        event("DISPLAY_SIZE_CHANGED")
        event("UI_SCALE_CHANGED")
        settle()
    end
    assert(WorldMapFrame.opens == (mapOpen and 1 or 0), "map must follow the state saved at quit")
    assert(ContainerFrameCombinedBags.opens == (bagOpen and 1 or 0), "bag must follow the state saved at quit")
    assert(CharacterFrame.opens == (characterOpen and 1 or 0), "Character must follow the state saved at quit")
    assert(SocialUIFrame.opens == 0, "having a saved position must not reopen a closed panel")
end

for _, spanned in ipairs({ false, true }) do
    restartWith(spanned, true, true, true)
    restartWith(spanned, false, false, false)
    restartWith(spanned, true, false, true)
    restartWith(spanned, false, true, false)
end
print("PASS: Forever workspace visibility across logout, fresh login and span")
