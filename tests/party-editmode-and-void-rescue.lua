--[[
    Offhand: Tests for Party Frames, Edit Mode, and Void Rescue
--]]

local addon = {
    modules = {},
    db = {
        enabled = true,
        seamRedirect = true,
        independentWorkspacePanels = true,
        savedWorkspacePositions = {},
        savedMainPositions = {},
        groupLootPosition = {},
        groupLootStackDirection = "UP",
    }
}
local nativeGamepad = false
addon.Mainhand = {
    IsNativeGamepadInterface = function() return nativeGamepad end,
    IsControllerLayout = function() return nativeGamepad end,
}

UIParent = {
    GetEffectiveScale = function() return 1 end,
    GetWidth = function() return 4000 end,
    GetHeight = function() return 2560 end,
    GetLeft = function() return 0 end,
    GetRight = function() return 4000 end,
    GetTop = function() return 2560 end,
    GetBottom = function() return 0 end,
    GetAttribute = function(self, key) return self[key] or 0 end,
    SetAttribute = function(self, key, val)
        self.attributeWrites = (self.attributeWrites or 0) + 1
        self[key] = val
    end,
    children = {},
    GetChildren = function(self) return unpack(self.children) end,
}

local metrics = {
    screenWidth = 4000, screenHeight = 2560,
    physicalWidth = 4000, physicalHeight = 2560,
    deckWidth = 1440, gameWidth = 2560, gameHeight = 1440,
    gameLeft = 1440, gameBottom = 6, gameRight = 4000, gameTop = 1446,
    gamePixelLeft = 1440, gamePixelBottom = 6, gamePixelWidth = 2560, gamePixelHeight = 1440,
    workspaceLeft = 0, workspaceBottom = 0, workspaceRight = 1440, workspaceTop = 2560,
    workspaceWidth = 1440, workspaceHeight = 2560,
    hudScale = 1, bezel = 0, preset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
    actualAR = 2560 / 1440, arMode = "16_9", isSpanned = true,
}

addon.Viewport = { GetMetrics = function() return metrics end }
addon.Print = function() end
local combatLocked = false
local combatQueue = {}
addon.RunOrQueueCombat = function(self, fn)
    if combatLocked then
        combatQueue[#combatQueue + 1] = fn
    else
        fn()
    end
end
local experimentalProfessionsMovement = false
addon.IsExperimentalForeverProfessionsMovementEnabled = function()
    return experimentalProfessionsMovement
end
InCombatLockdown = function() return combatLocked end
local function LeaveCombat()
    combatLocked = false
    local queued = combatQueue
    combatQueue = {}
    for _, fn in ipairs(queued) do fn() end
end

local timers = {}
local tickers = {}
local lastTimerDelay
C_Timer = {
    After = function(delay, fn) lastTimerDelay = delay; table.insert(timers, fn) end,
    NewTicker = function(interval, fn)
        local ticker = { interval = interval, callback = fn, cancelled = false }
        function ticker:Cancel() self.cancelled = true end
        table.insert(tickers, ticker)
        return ticker
    end,
}
local function flushTimers()
    local t = timers
    timers = {}
    for _, fn in ipairs(t) do fn() end
    for _, ticker in ipairs(tickers) do
        if not ticker.cancelled then ticker.callback() end
    end
end

local frames = {}
local function makeMockFrame(name, w, h)
    local f = {
        name = name, w = w or 200, h = h or 100,
        shown = true, alpha = 1, points = {}, scripts = {}, scale = 1,
        userPlaced = false, movable = false, clamped = false, mouse = false,
        attributes = {}, registeredEvents = {},
    }
    function f:SetSize(w,h) self.w=w; self.h=h end
    function f:GetName() return self.name end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:SetHeight(h) self.h = h end
    function f:SetWidth(w) self.w = w end
    function f:GetEffectiveScale() return self.scale end
    function f:GetScale() return self.scale end
    function f:SetScale(s) self.scale = s end
    function f:IsIgnoringParentScale() return self.ignoreParentScale == true end
    function f:SetIgnoreParentScale(value) self.ignoreParentScale = value == true end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i)
        i = i or 1
        local p = self.points[i]
        if p then return p[1], p[2], p[3], p[4], p[5] end
        return nil
    end
    function f:SetPoint(pt, rel, relPt, x, y)
        self.setPointCalls = (self.setPointCalls or 0) + 1
        table.insert(self.points, { pt, rel or UIParent, relPt or pt, x or 0, y or 0 })
    end
    function f:ClearAllPoints() self.points = {} end
    function f:GetLeft()
        local p = self.points[#self.points]
        if not p then return 0 end
        if p[3] == "CENTER" then return UIParent:GetWidth()/2 + (p[4] or 0) - self.w/2 end
        if p[1] == "BOTTOMLEFT" or p[1] == "TOPLEFT" or p[1] == "LEFT" then return p[4] or 0 end
        if p[1] == "CENTER" or p[1] == "TOP" or p[1] == "BOTTOM" then return (p[4] or 0) - (self.w / 2) end
        if p[1] == "RIGHT" or p[1] == "TOPRIGHT" or p[1] == "BOTTOMRIGHT" then return (p[4] or 0) - self.w end
        return p[4] or 0
    end
    function f:GetRight() return (self:GetLeft() or 0) + self.w end
    function f:GetTop()
        local p = self.points[#self.points]
        if not p then return self.h end
        local relTop = (p[2] and p[2].GetTop and p[2]:GetTop()) or 2560
        if p[1] == "TOP" or p[1] == "TOPLEFT" or p[1] == "TOPRIGHT" then
            if p[3] == "CENTER" then return relTop/2 + (p[5] or 0) end
            if p[3] == "BOTTOMLEFT" or p[3] == "BOTTOM" or p[3] == "BOTTOMRIGHT" then
                return (p[5] or 0)
            end
            return relTop + (p[5] or 0)
        end
        if p[1] == "BOTTOMLEFT" or p[1] == "BOTTOM" or p[1] == "BOTTOMRIGHT" then
            return (p[5] or 0) + self.h
        end
        if p[1] == "CENTER" then
            if p[3] == "BOTTOMLEFT" then
                return (p[5] or 0) + (self.h / 2)
            end
            local relCenterY = relTop / 2
            return relCenterY + (p[5] or 0) + (self.h / 2)
        end
        return self.h
    end
    function f:GetBottom() return self:GetTop() - self.h end
    function f:GetCenter()
        return self:GetLeft() + self.w / 2, self:GetBottom() + self.h / 2
    end
    function f:IsShown() return self.shown end
    function f:Show()
        self.shown = true
        if self.scripts["OnShow"] then self.scripts["OnShow"](self) end
    end
    function f:Hide()
        self.shown = false
        if self.scripts["OnHide"] then self.scripts["OnHide"](self) end
    end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetUserPlaced(up) self.userPlaced = up end
    function f:IsUserPlaced() return self.userPlaced end
    function f:SetMovable(m) self.movable = m end
    function f:SetFrameStrata(strata) self.strata = strata end
    function f:SetFrameLevel(level) self.frameLevel = level end
    function f:GetFrameLevel() return self.frameLevel or 0 end
    function f:SetClampedToScreen(c) self.clamped = c end
    function f:EnableMouse(m) self.mouse = m end
    function f:RegisterForDrag() end
    function f:StartMoving() self.startMovingCalls = (self.startMovingCalls or 0) + 1 end
    function f:StopMovingOrSizing() self.stopMovingCalls = (self.stopMovingCalls or 0) + 1 end
    function f:HookScript(event, fn)
        local orig = self.scripts[event]
        self.scripts[event] = function(...)
            if orig then orig(...) end
            fn(...)
        end
    end
    function f:GetScript(event) return self.scripts[event] end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:RegisterEvent(event) self.registeredEvents[event] = true end
    function f:CreateFontString()
        local fontString = { points = {} }
        function fontString:SetPoint(...) self.points[#self.points + 1] = { ... } end
        function fontString:SetText(text) self.text = text end
        return fontString
    end
    function f:GetAttribute(key) return self.attributes[key] end
    function f:SetAttributeNoHandler(key, value) self.attributes[key] = value end
    function f:IsForbidden() return false end
    function f:IsProtected() return false end
    frames[name] = f
    _G[name] = f
    return f
end

CreateFrame = function(frameType, name, parent, template)
    local f = makeMockFrame(name or ("AnonFrame_" .. tostring(#UIParent.children + 1)), 200, 100)
    f.parent = parent
    f.template = template
    function f:GetParent() return self.parent end
    if template == "SecureHandlerBaseTemplate" then
        f.frameRefs = {}
        function f:SetFrameRef(key, value) self.frameRefs[key] = value end
        function f:GetFrameRef(key) return self.frameRefs[key] end
        function f:SetAttribute(key, value) self.attributes[key] = value end
        function f:Execute()
            local target = self:GetFrameRef("offhandTransient")
            if target then
                target:ClearAllPoints()
                if self:GetAttribute("offhandBounds") then
                    target:SetPoint("BOTTOMLEFT", self:GetParent(), "BOTTOMLEFT",
                        self:GetAttribute("offhandLeft"), self:GetAttribute("offhandBottom"))
                    target:SetPoint("TOPRIGHT", self:GetParent(), "BOTTOMLEFT",
                        self:GetAttribute("offhandRight"), self:GetAttribute("offhandTop"))
                else
                    target:SetPoint(self:GetAttribute("offhandPoint"), self:GetParent(), "BOTTOMLEFT",
                        self:GetAttribute("offhandX"), self:GetAttribute("offhandY"))
                end
            end
        end
        function f:WrapScript(trigger, script)
            trigger:HookScript(script, function()
                local target = self:GetFrameRef("offhandTransientTarget")
                if target then
                    target:ClearAllPoints()
                    target:SetPoint(self:GetAttribute("offhandPoint"), self:GetParent(), "BOTTOMLEFT",
                        self:GetAttribute("offhandX"), self:GetAttribute("offhandY"))
                end
            end)
        end
    end
    if template == "PanelDragBarTemplate" then
        f:SetScript("OnDragStart", function(self)
            if self.parent then self.parent:StartMoving() end
        end)
        f:SetScript("OnDragStop", function(self)
            if self.parent then self.parent:StopMovingOrSizing() end
        end)
    end
    table.insert(UIParent.children, f)
    return f
end

RegisterStateDriver = function(frame, state, condition)
    frame.stateDrivers = frame.stateDrivers or {}
    frame.stateDrivers[state] = condition
end
UnregisterStateDriver = function(frame, state)
    if frame.stateDrivers then frame.stateDrivers[state] = nil end
end

hooksecurefunc = function(arg1, arg2, arg3)
    if type(arg1) == "string" then
        local fnName = arg1
        local hookFn = arg2
        local orig = _G[fnName]
        _G[fnName] = function(...)
            local ret = orig and orig(...)
            hookFn(...)
            return ret
        end
    elseif type(arg1) == "table" then
        local tbl = arg1
        local method = arg2
        local hookFn = arg3
        local orig = tbl[method]
        tbl[method] = function(s, ...)
            local ret = orig and orig(s, ...)
            hookFn(s, ...)
            return ret
        end
    end
end

-- Initialize mock frames
PlayerFrame = makeMockFrame("PlayerFrame", 232, 100)
TargetFrame = makeMockFrame("TargetFrame", 232, 100)
PartyMemberFrame1 = makeMockFrame("PartyMemberFrame1", 180, 80)
PartyMemberFrame2 = makeMockFrame("PartyMemberFrame2", 180, 80)
GameMenuFrame = makeMockFrame("GameMenuFrame", 200, 400)
GameMenuFrame:Hide()
StaticPopup1 = makeMockFrame("StaticPopup1", 420, 180)
StaticPopup1.ignoreParentScale = true
ExampleAddonWindow = makeMockFrame("ExampleAddonWindow", 220, 300)
table.insert(UIParent.children, ExampleAddonWindow)

-- Blizzard transient UI that defaults to the complete spanned UIParent. These
-- frames must be redirected to Mainhand without becoming persistent/draggable
-- workspace panels or having their native visibility changed.
ZoneTextFrame = makeMockFrame("ZoneTextFrame", 600, 100)
SubZoneTextFrame = makeMockFrame("SubZoneTextFrame", 600, 100)
BossBanner = makeMockFrame("BossBanner", 500, 180)
BossBanner:Hide()
EventToastManagerFrame = makeMockFrame("EventToastManagerFrame", 700, 160)
AlertFrame = makeMockFrame("AlertFrame", 500, 180)
RolePollPopup = makeMockFrame("RolePollPopup", 420, 180)
ReadyCheckFrame = makeMockFrame("ReadyCheckFrame", 320, 140)
ReadyCheckFrame.TitleContainer = {}
LFGDungeonReadyPopup = makeMockFrame("LFGDungeonReadyPopup", 520, 300)
GroupLootContainer = nil
GroupLootFrame1 = nil
GroupLootFrame2 = nil
GroupLootFrame3 = nil
GroupLootFrame4 = nil
PetBattleFrame = nil
local groupLootPreloadCount = 0
local petBattlePreloadCount = 0
C_AddOns = {
    LoadAddOn = function(name)
        if name == "Blizzard_GroupLoot" then
            groupLootPreloadCount = groupLootPreloadCount + 1
            GroupLootContainer = makeMockFrame("GroupLootContainer", 420, 180)
            -- Blizzard declares this hidden with no XML anchor. The managed
            -- frame system assigns its first point only when the first roll
            -- makes the container visible.
            GroupLootContainer:ClearAllPoints()
            GroupLootContainer:Hide()
            GroupLootContainer.rollFrames = {}
            GroupLootContainer.maxIndex = 0
            GroupLootContainer.reservedSize = 100
            for i = 1, 4 do
                local roll = makeMockFrame("GroupLootFrame" .. i, 420, 90)
                roll:Hide()
            end
            GroupLootContainer_Update = function(container)
                for i = 1, container.maxIndex do
                    local roll = container.rollFrames[i]
                    if roll then
                        roll:ClearAllPoints()
                        roll:SetPoint("CENTER", container, "BOTTOM", 0,
                            container.reservedSize * (i - 0.5))
                    end
                end
            end
            return true
        elseif name == "Blizzard_PetBattleUI" then
            petBattlePreloadCount = petBattlePreloadCount + 1
            PetBattleFrame = makeMockFrame("PetBattleFrame", 4000, 2560)
            PetBattleFrame:ClearAllPoints()
            PetBattleFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
            PetBattleFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
            PetBattleFrame.IsProtected = function() return true end
            PetBattleFrame:Hide()
            return true
        end
    end,
}
CombatText = makeMockFrame("CombatText", 600, 600)
CombatText.ignoreParentScale = true
TimerTracker = makeMockFrame("TimerTracker", 4000, 2560)
TimerTracker.GetParent = function() return UIParent end
TimerTracker.ignoreParentScale = true
local countdownTimer = makeMockFrame("TimerTrackerTimer1", 206, 26)
countdownTimer.GoTexture = makeMockFrame("TimerTrackerTimer1GoTexture", 256, 256)
TimerTracker.timerList = { countdownTimer }
HousingControlsFrame = makeMockFrame("HousingControlsFrame", 150, 50)
OverrideActionBar = makeMockFrame("OverrideActionBar", 900, 120)
OverrideActionBar.IsProtected = function() return true end
DamageMeter = makeMockFrame("DamageMeter", 500, 300)
DamageMeter.isManagedFrame = true
DamageMeter:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
table.insert(UIParent.children, DamageMeter)

UIWidgetTopCenterContainerFrame = makeMockFrame("UIWidgetTopCenterContainerFrame", 400, 60)
UIWidgetTopCenterContainerFrame.isManagedFrame = true
UIWidgetTopCenterContainerFrame:SetPoint("TOP", UIParent, "TOP", 0, -15)
PVPMatchScoreboard = makeMockFrame("PVPMatchScoreboard", 1024, 420)
PVPMatchScoreboard:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
PVPMatchResults = makeMockFrame("PVPMatchResults", 1024, 620)
PVPMatchResults:SetPoint("CENTER", UIParent, "CENTER", 140, 80)

ToggleGameMenu = function()
    if GameMenuFrame:IsShown() then
        GameMenuFrame:Hide()
    else
        GameMenuFrame:Show()
    end
end
local nativeUIPanelLayout
UpdateUIPanelPositions = function(...)
    if nativeUIPanelLayout then return nativeUIPanelLayout(...) end
end
ShowUIPanel = function(frame) frame:Show() end
HideUIPanel = function(frame)
    frame:Hide()
    UpdateUIPanelPositions()
end
UIPanelWindows = {
    EditModeManagerFrame = { area = "center", pushable = 0, whileDead = 1, neverAllowOtherPanels = 1 },
    HouseEditorFrame = { area = "full", pushable = 0, whileDead = 1, neverAllowOtherPanels = 1 },
}
OffhandCharDB = {}
RegisterUIPanel = function(frame)
    local name = frame and frame.GetName and frame:GetName()
    if name then UIPanelWindows[name] = UIPanelWindows[name] or { area = "left", pushable = 0 } end
end
SetUIPanelAttribute = function(frame, name, value)
    frame:SetAttributeNoHandler("UIPanelLayout-" .. name, value)
end

-- Load Offhand core scripts
assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", addon)
assert(loadfile("Core/HUDTransientPolicy.lua"))("Offhand", addon)
local seamChunk = loadfile("Core/SeamRedirect.lua")
assert(seamChunk, "Core/SeamRedirect.lua must compile cleanly")
seamChunk("Offhand", addon)

local panelMotionChunk = loadfile("Core/PanelMotion.lua")
assert(panelMotionChunk, "Core/PanelMotion.lua must compile cleanly")
panelMotionChunk("Offhand", addon)

local compatibilityChunk = assert(loadfile("Core/CanvasCompatibility.lua"))
compatibilityChunk("Offhand", addon)

local frameStateChunk = assert(loadfile("Core/CanvasFrameState.lua"))
frameStateChunk("Offhand", addon)

assert(loadfile("Core/CanvasPanelRegistry.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPersistence.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasBackpackState.lua"))("Offhand", addon)

local canvasChunk = loadfile("Core/Canvas.lua")
assert(canvasChunk, "Core/Canvas.lua must compile cleanly")
canvasChunk("Offhand", addon)

addon.HUD:HookFrames()

-- ============================================================================
-- TEST 1: Party Frame Default Positioning inside the 3D Game Viewport
-- ============================================================================
addon.HUD:AlignHUDFrames(metrics)

local function assertMainhandAnchor(frame, point, x, y, message)
    local anchor = frame.points[#frame.points]
    assert(anchor and anchor[1] == point and anchor[2] == UIParent and anchor[3] == "BOTTOMLEFT",
        message .. " must use a physical Mainhand anchor")
    assert(math.abs(anchor[4] - x) < 1 and math.abs(anchor[5] - y) < 1,
        string.format("%s expected (%s,%s), got (%s,%s)", message, x, y,
            tostring(anchor[4]), tostring(anchor[5])))
end

assertMainhandAnchor(ZoneTextFrame, "TOP", 2720, 1318, "Zone text")
assertMainhandAnchor(SubZoneTextFrame, "BOTTOM", 2720, 518, "Sub-zone text")
assertMainhandAnchor(BossBanner, "TOP", 2720, 1326, "Boss banner")
assertMainhandAnchor(EventToastManagerFrame, "TOP", 2720, 1256, "Event toast")
assertMainhandAnchor(AlertFrame, "BOTTOM", 2720, 134, "Alert frame")
assertMainhandAnchor(RolePollPopup, "TOP", 2720, 1431, "Role poll")
assertMainhandAnchor(ReadyCheckFrame, "CENTER", 2720, 716, "Ready check")
assertMainhandAnchor(LFGDungeonReadyPopup, "CENTER", 2720, 716, "Dungeon queue popup")
assertMainhandAnchor(GroupLootContainer, "BOTTOM", 2720, 196, "Group loot rolls")
local groupLootDiagnostics = addon.HUD:GetGroupLootDiagnostics()
assert(groupLootDiagnostics.loaded and groupLootDiagnostics.preloadAttempted
        and groupLootDiagnostics.anchorPrepared
        and groupLootDiagnostics.rowMoverPrepared
        and groupLootDiagnostics.rowMoverActive
        and groupLootDiagnostics.triggerCount == 4,
    "group-loot diagnostics must report the preload, fallback anchor, and row mover")
assert(PetBattleFrame:GetNumPoints() == 2,
    "pet-battle root must retain a bounded two-point rectangle")
local petBattleBottomLeft = { PetBattleFrame:GetPoint(1) }
local petBattleTopRight = { PetBattleFrame:GetPoint(2) }
assert(petBattleBottomLeft[1] == "BOTTOMLEFT" and petBattleBottomLeft[2] == UIParent
        and petBattleBottomLeft[3] == "BOTTOMLEFT" and petBattleBottomLeft[4] == 1440
        and petBattleBottomLeft[5] == 6,
    "pet-battle root must begin at the physical Mainhand bottom-left")
assert(petBattleTopRight[1] == "TOPRIGHT" and petBattleTopRight[2] == UIParent
        and petBattleTopRight[3] == "BOTTOMLEFT" and petBattleTopRight[4] == 4000
        and petBattleTopRight[5] == 1446,
    "pet-battle root must end at the physical Mainhand top-right")
local petBattleDiagnostics = addon.HUD:GetPetBattleDiagnostics()
assert(petBattleDiagnostics.loaded and petBattleDiagnostics.preloadAttempted
        and petBattleDiagnostics.boundsPrepared and not petBattleDiagnostics.conflict
        and petBattlePreloadCount == 1,
    "pet-battle diagnostics must report preloaded Mainhand bounds")
assert(not PetBattleFrame:IsShown(),
    "preparing pet-battle bounds must not change Blizzard visibility")
assertMainhandAnchor(CombatText, "CENTER", 2720, 726, "Floating combat text")
assert(CombatText:IsIgnoringParentScale() == false,
    "floating combat text must inherit Offhand's UIParent scale")
assertMainhandAnchor(StaticPopup1, "CENTER", 2720, 726, "Static popup")
assert(StaticPopup1:IsIgnoringParentScale() == false,
    "static popup text must inherit Offhand's UIParent scale")
assert(TimerTracker:GetNumPoints() == 2, "TimerTracker must be bounded to the Mainhand rectangle")
assert(TimerTracker:IsIgnoringParentScale() == false,
    "countdown overlays must inherit Offhand's UIParent scale")
local timerBottomLeft = { TimerTracker:GetPoint(1) }
local timerTopRight = { TimerTracker:GetPoint(2) }
assert(timerBottomLeft[1] == "BOTTOMLEFT" and timerBottomLeft[2] == UIParent
        and timerBottomLeft[3] == "BOTTOMLEFT" and timerBottomLeft[4] == 1440
        and timerBottomLeft[5] == 6,
    "TimerTracker must begin at the physical Mainhand bottom-left")
assert(timerTopRight[1] == "TOPRIGHT" and timerTopRight[2] == UIParent
        and timerTopRight[3] == "BOTTOMLEFT" and timerTopRight[4] == 4000
        and timerTopRight[5] == 1446,
    "TimerTracker must end at the physical Mainhand top-right")
local goPoint = { countdownTimer.GoTexture:GetPoint(1) }
assert(goPoint[1] == "CENTER" and goPoint[2] == TimerTracker
        and goPoint[3] == "CENTER" and goPoint[4] == 0 and goPoint[5] == 0,
    "countdown completion texture must follow the Mainhand TimerTracker")
assertMainhandAnchor(HousingControlsFrame, "TOP", 2720, 1416, "Housing controls")
assertMainhandAnchor(UIWidgetTopCenterContainerFrame, "TOP", 2720, 1431,
    "Battleground objective widgets")
assertMainhandAnchor(PVPMatchScoreboard, "CENTER", 2720, 726,
    "PvP scoreboard")
local customResultsPoint = { PVPMatchResults:GetPoint(1) }
assert(customResultsPoint[1] == "CENTER" and customResultsPoint[3] == "CENTER"
        and customResultsPoint[4] == 140 and customResultsPoint[5] == 80,
    "an existing custom PvP results placement must remain untouched")

-- A frame that later returns to Blizzard's stock anchor becomes eligible for
-- secure Mainhand adoption. Once adopted, native stock resets are repaired.
PVPMatchResults:ClearAllPoints()
PVPMatchResults:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
addon.HUD:PositionMainhandTransientFrames(metrics)
assertMainhandAnchor(PVPMatchResults, "CENTER", 2720, 726,
    "PvP match results")

-- Combat-time resets are not modified insecurely. One deferred pass repairs
-- the stock anchor as soon as combat ends.
combatLocked = true
PVPMatchScoreboard:ClearAllPoints()
PVPMatchScoreboard:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
addon.HUD:PositionMainhandTransientFrames(metrics)
addon.HUD:PositionMainhandTransientFrames(metrics)
local combatScorePoint = { PVPMatchScoreboard:GetPoint(1) }
assert(combatScorePoint[3] == "CENTER" and combatScorePoint[4] == 0
        and combatScorePoint[5] == 0 and #combatQueue == 1,
    "scoreboard repositioning must defer exactly once during combat")
LeaveCombat()
assertMainhandAnchor(PVPMatchScoreboard, "CENTER", 2720, 726,
    "PvP scoreboard after combat")

-- Wild pet battles hold combat lockdown. A native full-screen reset is left
-- untouched during combat and repaired by the one coalesced post-combat pass.
combatLocked = true
PetBattleFrame:ClearAllPoints()
PetBattleFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
PetBattleFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
addon.HUD:PositionMainhandTransientFrames(metrics)
addon.HUD:PositionMainhandTransientFrames(metrics)
local combatPetPoint = { PetBattleFrame:GetPoint(1) }
assert(combatPetPoint[1] == "TOPLEFT" and combatPetPoint[3] == "TOPLEFT"
        and combatPetPoint[4] == 0 and combatPetPoint[5] == 0 and #combatQueue == 1,
    "pet-battle repositioning must defer exactly once during combat")
LeaveCombat()
petBattleBottomLeft = { PetBattleFrame:GetPoint(1) }
petBattleTopRight = { PetBattleFrame:GetPoint(2) }
assert(petBattleBottomLeft[1] == "BOTTOMLEFT" and petBattleBottomLeft[4] == 1440
        and petBattleBottomLeft[5] == 6 and petBattleTopRight[1] == "TOPRIGHT"
        and petBattleTopRight[4] == 4000 and petBattleTopRight[5] == 1446,
    "pet-battle root must recover its Mainhand bounds after combat")

-- If another addon subsequently takes ownership with a custom anchor, yield
-- instead of creating an anchor tug-of-war.
PetBattleFrame:ClearAllPoints()
PetBattleFrame:SetPoint("CENTER", UIParent, "CENTER", 75, 25)
addon.HUD:PositionMainhandTransientFrames(metrics)
local customPetPoint = { PetBattleFrame:GetPoint(1) }
assert(customPetPoint[1] == "CENTER" and customPetPoint[3] == "CENTER"
        and customPetPoint[4] == 75 and customPetPoint[5] == 25,
    "custom pet-battle placement must remain untouched")
petBattleDiagnostics = addon.HUD:GetPetBattleDiagnostics()
assert(petBattleDiagnostics.conflict == "custom-anchor"
        and not petBattleDiagnostics.boundsPrepared,
    "pet-battle diagnostics must report and yield custom-anchor ownership")
PetBattleFrame:ClearAllPoints()
PetBattleFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
PetBattleFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
addon.HUD:PositionMainhandTransientFrames(metrics)
assert(addon.HUD:GetPetBattleDiagnostics().conflict == nil,
    "restoring Blizzard pet-battle bounds must permit Offhand adoption again")

-- The House Editor is load-on-demand. Its ModeBar is already shown beneath a
-- hidden full-screen parent when Blizzard_HouseEditor finishes loading, so it
-- will not necessarily receive a child OnShow when the parent later appears.
-- The ADDON_LOADED handoff must discover and position it immediately.
HouseEditorFrame = makeMockFrame("HouseEditorFrame", 4000, 2560)
HouseEditorFrame.TitleContainer = {}
HouseEditorFrame.ModeBar = makeMockFrame("HouseEditorModeBar", 700, 100)
HouseEditorFrame.StorageButton = makeMockFrame("HouseEditorStorageButton", 64, 64)
HouseEditorFrame.StoragePanel = makeMockFrame("HouseEditorStoragePanel", 520, 700)
HouseEditorFrame.MarketShoppingCartFrame = makeMockFrame("HousingMarketShoppingCart", 360, 180)
for _, frame in ipairs(UIParent.children) do
    local onEvent = frame.GetScript and frame:GetScript("OnEvent")
    if onEvent and frame.registeredEvents and frame.registeredEvents.ADDON_LOADED then
        onEvent(frame, "ADDON_LOADED", "Blizzard_HouseEditor")
    end
end
assertMainhandAnchor(HouseEditorFrame.ModeBar, "BOTTOM", 2720, 6, "House editor mode bar")
assertMainhandAnchor(HouseEditorFrame.StorageButton, "LEFT", 1464, 876, "House editor storage button")
assertMainhandAnchor(HouseEditorFrame.StoragePanel, "LEFT", 1464, 876, "House editor storage panel")
assertMainhandAnchor(HouseEditorFrame.MarketShoppingCartFrame, "BOTTOMRIGHT", 3970, 26,
    "House editor market cart")

-- Blizzard_CombatText is load-on-demand on current clients. If it did not
-- exist during Offhand initialization, its first combat/XP message must still
-- inherit Mainhand scale and positioning as soon as Blizzard loads the module.
CombatText = makeMockFrame("CombatText", 600, 600)
CombatText.ignoreParentScale = true
for _, frame in ipairs(UIParent.children) do
    local onEvent = frame.GetScript and frame:GetScript("OnEvent")
    if onEvent and frame.registeredEvents and frame.registeredEvents.ADDON_LOADED then
        onEvent(frame, "ADDON_LOADED", "Blizzard_CombatText")
    end
end
assertMainhandAnchor(CombatText, "CENTER", 2720, 726, "late-loaded floating combat text")
assert(CombatText:IsIgnoringParentScale() == false,
    "late-loaded floating combat text must inherit Offhand's UIParent scale")

assert(not BossBanner:IsShown(), "positioning transient UI must not change native visibility")

-- Blizzard can restore a stock full-span anchor during OnShow. The secure
-- post-hook must put it back on Mainhand without opening/closing anything.
BossBanner:ClearAllPoints()
BossBanner:SetPoint("TOP", UIParent, "TOP", 0, -120)
BossBanner:Show()
assertMainhandAnchor(BossBanner, "TOP", 2720, 1326, "Boss banner after native reset")
BossBanner:Hide()

LFGDungeonReadyPopup:ClearAllPoints()
LFGDungeonReadyPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
LFGDungeonReadyPopup:GetScript("OnEvent")(LFGDungeonReadyPopup, "LFG_PROPOSAL_SHOW")
assertMainhandAnchor(LFGDungeonReadyPopup, "CENTER", 2720, 716,
    "Dungeon queue popup after native reset")
GroupLootContainer:ClearAllPoints()
GroupLootContainer:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
assert(GroupLootContainer:GetScript("OnEvent") == nil,
    "Group loot must not receive an insecure event hook")
addon.HUD:PositionMainhandTransientFrames()
assertMainhandAnchor(GroupLootContainer, "BOTTOM", 2720, 196,
    "Group loot rolls after secure layout repair")

-- Blizzard can move its managed container on a combat-state layout pass. The
-- individual roll rows must remain attached directly to Mainhand, and every
-- native GroupLootContainer_Update must restore that independent row layout.
GroupLootContainer.rollFrames[1] = GroupLootFrame1
GroupLootContainer.maxIndex = 1
GroupLootContainer_Update(GroupLootContainer)
GroupLootFrame1:Show()
assertMainhandAnchor(GroupLootFrame1, "CENTER", 2720, 246,
    "first group-loot row after native update")
combatLocked = true
GroupLootContainer:ClearAllPoints()
GroupLootContainer:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
assertMainhandAnchor(GroupLootFrame1, "CENTER", 2720, 246,
    "group-loot row after in-combat container relocation")
GroupLootContainer_Update(GroupLootContainer)
assertMainhandAnchor(GroupLootFrame1, "CENTER", 2720, 246,
    "group-loot row after in-combat native update")
GroupLootContainer.rollFrames[2] = GroupLootFrame2
GroupLootContainer.maxIndex = 2
GroupLootContainer_Update(GroupLootContainer)
assertMainhandAnchor(GroupLootFrame2, "CENTER", 2720, 346,
    "second group-loot row after in-combat native update")
combatLocked = false

-- Offhand exposes its own non-secure preview outside combat instead of making
-- Blizzard's managed container or roll rows draggable. Saving the preview
-- records a proportional Mainhand position and the native update hook applies
-- it to every roll while preserving Blizzard's upward stack.
local moverOpened, moverReason = addon.HUD:SetGroupLootMoverShown(true)
assert(moverOpened and moverReason == "shown", "group-loot mover preview must open outside combat")
local groupLootMover = _G.OffhandGroupLootMover
assert(groupLootMover and groupLootMover:IsShown(), "group-loot mover preview must be visible")
groupLootMover:GetScript("OnDragStart")(groupLootMover)
groupLootMover:ClearAllPoints()
groupLootMover:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 3300, 700)
addon.HUD:PositionMainhandTransientFrames()
assertMainhandAnchor(groupLootMover, "CENTER", 3300, 700,
    "group-loot preview during an active drag and layout refresh")
local draggingDiagnostics = addon.HUD:GetGroupLootDiagnostics()
assert(draggingDiagnostics.moverDragging,
    "group-loot diagnostics must report an active preview drag")
groupLootMover:GetScript("OnDragStop")(groupLootMover)
assert(math.abs(addon.db.groupLootPosition.x - ((3300 - 1440) / 2560)) < 0.0001,
    "group-loot mover must save a normalized Mainhand X position")
assert(math.abs(addon.db.groupLootPosition.y - ((700 - 6) / 1440)) < 0.0001,
    "group-loot mover must save a normalized Mainhand Y position")
GroupLootContainer_Update(GroupLootContainer)
assertMainhandAnchor(GroupLootFrame1, "CENTER", 3300, 700,
    "first group-loot row at the user position")
assertMainhandAnchor(GroupLootFrame2, "CENTER", 3300, 800,
    "second group-loot row above the user position")
assert(addon.HUD:SetGroupLootStackDirection("DOWN"),
    "group-loot stack direction must accept the downward option")
assertMainhandAnchor(GroupLootFrame1, "CENTER", 3300, 700,
    "first group-loot row remains at the user anchor when stacking downward")
assertMainhandAnchor(GroupLootFrame2, "CENTER", 3300, 600,
    "second group-loot row below the user position")
GroupLootContainer_Update(GroupLootContainer)
assertMainhandAnchor(GroupLootFrame2, "CENTER", 3300, 600,
    "downward group-loot stack after native update")
local movedDiagnostics = addon.HUD:GetGroupLootDiagnostics()
assert(movedDiagnostics.customPosition and movedDiagnostics.moverShown
        and movedDiagnostics.stackDirection == "DOWN",
    "group-loot diagnostics must report the saved position, direction and visible preview")
assert(addon.HUD:SetGroupLootStackDirection("invalid")
        and addon.db.groupLootStackDirection == "UP",
    "unknown group-loot directions must safely fall back to Blizzard's upward direction")
assertMainhandAnchor(GroupLootFrame2, "CENTER", 3300, 800,
    "second group-loot row after restoring upward stacking")

addon.HUD:SetGroupLootMoverShown(false)
assert(not groupLootMover:IsShown(), "group-loot mover preview must hide on request")
combatLocked = true
local openedInCombat, combatReason = addon.HUD:SetGroupLootMoverShown(true)
assert(not openedInCombat and combatReason == "combat" and not groupLootMover:IsShown(),
    "group-loot movement must remain unavailable in combat")
combatLocked = false
assert(addon.HUD:ResetGroupLootPosition(), "group-loot position reset must succeed outside combat")
assert(addon.db.groupLootPosition.x == nil and addon.db.groupLootPosition.y == nil,
    "group-loot position reset must remove the saved custom coordinates")
assertMainhandAnchor(GroupLootFrame1, "CENTER", 2720, 246,
    "first group-loot row after position reset")
assertMainhandAnchor(GroupLootFrame2, "CENTER", 2720, 346,
    "second group-loot row after position reset")

GroupLootFrame1:Hide()
GroupLootFrame2:Hide()

-- START_TIMER dynamically creates/reuses timer children. The post-event hook
-- must catch a newly allocated completion texture immediately.
local secondCountdown = makeMockFrame("TimerTrackerTimer2", 206, 26)
secondCountdown.GoTexture = makeMockFrame("TimerTrackerTimer2GoTexture", 256, 256)
TimerTracker.timerList[2] = secondCountdown
TimerTracker:GetScript("OnEvent")(TimerTracker, "START_PLAYER_COUNTDOWN")
local secondGoPoint = { secondCountdown.GoTexture:GetPoint(1) }
assert(secondGoPoint[1] == "CENTER" and secondGoPoint[2] == TimerTracker
        and secondGoPoint[3] == "CENTER" and secondGoPoint[4] == 0 and secondGoPoint[5] == 0,
    "new countdown completion textures must follow the Mainhand TimerTracker")
print("PASS: transient Blizzard UI anchors to Mainhand without visibility ownership")

local partyPt = PartyMemberFrame1.points[#PartyMemberFrame1.points]
assert(partyPt, "PartyMemberFrame1 must be positioned by AlignHUDFrames")
assert(partyPt[1] == "TOPLEFT", "PartyMemberFrame1 anchor point must be TOPLEFT")
-- Game view metrics: gameLeft = 1440, gameTop = 1446
-- Anchor at TOPLEFT with x=16, y=-160 -> x = 1440 + 16 = 1456, y = 1446 - 160 = 1286
assert(math.abs(partyPt[4] - 1456) < 1, string.format("PartyMemberFrame1 X must be 1456, got %s", tostring(partyPt[4])))
assert(math.abs(partyPt[5] - 1286) < 1, string.format("PartyMemberFrame1 Y must be 1286, got %s", tostring(partyPt[5])))
print("PASS: PartyMemberFrame1 defaults cleanly inside the 3D Game Viewport (x=1456, y=1286)")

-- ============================================================================
-- TEST 2: Party Frame Click-Safety (No Overlaid Blocking Handles)
-- ============================================================================
addon.Canvas:EnableFreeDragging()
addon.Canvas:TryMakeFrameDraggable(ReadyCheckFrame)
addon.Canvas:TryMakeFrameDraggable(LFGDungeonReadyPopup)
addon.Canvas:TryMakeFrameDraggable(GroupLootContainer)
addon.Canvas:TryMakeFrameDraggable(TimerTracker)
addon.Canvas:TryMakeFrameDraggable(HouseEditorFrame)
addon.Canvas:TryMakeFrameDraggable(OverrideActionBar)
assert(PartyMemberFrame1._OffhandHandle == nil, "PartyMemberFrame1 must NOT have an overlaid drag handle so unit targeting/healing is never blocked")
assert(ReadyCheckFrame._OffhandMovable == nil,
    "ReadyCheckFrame must not receive generic panel dragging or persistence")
assert(LFGDungeonReadyPopup._OffhandMovable == nil,
    "LFGDungeonReadyPopup must not receive generic panel dragging or persistence")
assert(GroupLootContainer._OffhandMovable == nil,
    "GroupLootContainer must not receive generic panel dragging or persistence")
assert(TimerTracker._OffhandMovable == nil,
    "TimerTracker must not receive generic panel dragging or persistence")
assert(HouseEditorFrame._OffhandMovable == nil,
    "the full-screen House Editor must remain Blizzard-owned")
assert(OverrideActionBar._OffhandMovable == nil,
    "the protected Override Action Bar must remain Blizzard/Edit Mode-owned")
print("PASS: PartyMemberFrame1 click-safety confirmed (no overlaid handle)")

-- ============================================================================
-- TEST 3: Party Frame Dragging to the Workspace Monitor & Reload Persistence
-- ============================================================================
-- Simulate player dragging PartyMemberFrame1 to the secondary workspace (e.g. x = 200, y = 1500 on portrait monitor)
PartyMemberFrame1:ClearAllPoints()
PartyMemberFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 1500)
addon.Canvas.OnPanelDragStop(PartyMemberFrame1)

assert(addon.db.savedWorkspacePositions["PartyMemberFrame1"] ~= nil, "PartyMemberFrame1 position must be saved in savedWorkspacePositions")
assert(addon.db.savedWorkspacePositions["PartyMemberFrame1"].x == 200, "PartyMemberFrame1 saved x must match 200")
assert(addon.db.savedWorkspacePositions["PartyMemberFrame1"].y == 1500 + PartyMemberFrame1:GetHeight(), "PartyMemberFrame1 saved y must match 1500")

-- Simulate reload
PartyMemberFrame1:ClearAllPoints()
addon.HUD:AlignHUDFrames(metrics)
local reloadPt = PartyMemberFrame1.points[#PartyMemberFrame1.points]
assert(reloadPt and reloadPt[4] == 200 and reloadPt[5] == 1500 + PartyMemberFrame1:GetHeight(), "PartyMemberFrame1 must restore to workspace on reload")
print("PASS: PartyMemberFrame1 dragging to secondary workspace and reload persistence verified")

-- ============================================================================
-- TEST 4: Dragging Party Frame Back to the Game View Monitor
-- ============================================================================
-- Drag back to game monitor at x = 1600, y = 1000
PartyMemberFrame1:ClearAllPoints()
PartyMemberFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1600, 1000)
addon.Canvas.OnPanelDragStop(PartyMemberFrame1)

assert(addon.db.savedWorkspacePositions["PartyMemberFrame1"] == nil, "PartyMemberFrame1 must be cleared from savedWorkspacePositions when on Game View")
assert(addon.db.savedMainPositions["PartyMemberFrame1"] ~= nil, "PartyMemberFrame1 must be saved in savedMainPositions")
assert(addon.db.savedMainPositions["PartyMemberFrame1"].x == 1600, "PartyMemberFrame1 main x must be 1600")
assert(addon.db.savedMainPositions["PartyMemberFrame1"].y == 1000 + PartyMemberFrame1:GetHeight(), "PartyMemberFrame1 main y must be 1000")
print("PASS: PartyMemberFrame1 dragged back to Game View updates savedMainPositions")

-- ============================================================================
-- TEST 5: Forever yields protected HUD placement to Blizzard Edit Mode
-- ============================================================================
addon.isForever = true
C_AddOns = { IsAddOnLoaded = function(name) return name == "EllesmereUIRaidFrames" end }
assert(addon.HasEllesmerePartyFrames and addon.HasEllesmerePartyFrames(),
    "Offhand must detect EllesmereUI's loaded Party/Raid Frames module")
C_AddOns = nil
MainActionBar = makeMockFrame("MainActionBar", 500, 45)
MainActionBar.IsInDefaultPosition = function() return true end
local originalMainSetPoint = MainActionBar.SetPoint
PlayerFrame = makeMockFrame("PlayerFrame", 232, 100)
local originalPlayerSetPoint = PlayerFrame.SetPoint
local EditModeManagerFrame = makeMockFrame("EditModeManagerFrame", 600, 60)
EditModeManagerFrame:Hide()
local EditModeSystemSettingsDialog = makeMockFrame("EditModeSystemSettingsDialog", 400, 300)
local EditModeLayoutDialog = makeMockFrame("EditModeLayoutDialog", 420, 240)
local EditModeImportLayoutDialog = makeMockFrame("EditModeImportLayoutDialog", 520, 360)
local EditModeImportLayoutLinkDialog = makeMockFrame("EditModeImportLayoutLinkDialog", 520, 360)
local EditModeUnsavedChangesDialog = makeMockFrame("EditModeUnsavedChangesDialog", 350, 150)
EditModeSystemSettingsDialog:Hide()
EditModeLayoutDialog:Hide()
EditModeImportLayoutDialog:Hide()
EditModeImportLayoutLinkDialog:Hide()
EditModeUnsavedChangesDialog:Hide()
Enum = {
    EditModeSystem = { ActionBar = 1 },
    EditModeActionBarSystemIndices = { MainBar = 1 },
}
local layoutData = {
    -- Forever exposes Modern=1 and Classic=2 as global identifiers, reserves
    -- identifier 3, then maps custom layouts from layouts[1] to identifier 4.
    activeLayout = 6,
    layouts = {
        {layoutName = "123", layoutType = 1},
        {layoutName = "432", layoutType = 1},
        {
            layoutName = "Offhand",
            layoutType = 1,
            systems = {
                {system = 1, systemIndex = 1, isInDefaultPosition = true},
            },
        },
        {layoutName = "777", layoutType = 1},
        {layoutName = "666", layoutType = 1},
    },
}
local selectedLayout
C_EditMode = {
    GetLayouts = function() return layoutData end,
    SetActiveLayout = function(index)
        selectedLayout = index
        layoutData.activeLayout = index
    end,
}

-- Simulate on-demand loading of Blizzard_EditMode
addon.HUD.editModeLoadScheduled = nil
local panelAttributeWrites = UIParent.attributeWrites or 0
addon.HUD:HookFrames()
addon.HUD:AlignHUDFrames(metrics)
assert((UIParent.attributeWrites or 0) == panelAttributeWrites,
    "Forever must not write legacy UIParent panel-layout attributes")

assert(MainActionBar.SetPoint == originalMainSetPoint,
    "Forever must not install a SetPoint repair hook on MainActionBar")
assert(#MainActionBar.points == 0,
    "Forever must not directly anchor MainActionBar")
assert(PlayerFrame.SetPoint == originalPlayerSetPoint,
    "Forever must not install a SetPoint repair hook on PlayerFrame")
assert(#PlayerFrame.points == 0,
    "Forever must not directly anchor PlayerFrame")

-- Forever can load Blizzard_EditMode after Offhand's canvas initialization.
-- Protected unit frames must still be rejected when the manager did not exist
-- at the time draggable-frame discovery first ran.
local party2PointCount = #PartyMemberFrame2.points
addon.db.savedWorkspacePositions.EditModeManagerFrame = { point = "CENTER", x = 200, y = 200 }
addon.db.savedMainPositions.EditModeManagerFrame = { point = "CENTER", x = 200, y = 200 }
addon.db.openWorkspacePanels = { EditModeManagerFrame = true }
RegisterUIPanel(EditModeManagerFrame)
assert(not EditModeManagerFrame:IsShown()
        and addon.db.savedWorkspacePositions.EditModeManagerFrame == nil
        and addon.db.savedMainPositions.EditModeManagerFrame == nil
        and addon.db.openWorkspacePanels.EditModeManagerFrame == nil,
    "a load-on-demand Edit Mode registration must purge stale persistence without opening Edit Mode")
addon.db.savedWorkspacePositions.EditModeManagerFrame = { point = "CENTER", x = 200, y = 200 }
addon.db.savedMainPositions.EditModeManagerFrame = { point = "CENTER", x = 200, y = 200 }
addon.db.openWorkspacePanels.EditModeManagerFrame = true
addon.Canvas.MakePanelDraggable(PartyMemberFrame2)
addon.Canvas:TryMakeFrameDraggable(EditModeManagerFrame)
addon.Canvas:EnableFreeDragging()
addon.Canvas.RestoreWorkspacePosition(PartyMemberFrame2)
addon.Canvas.OnPanelDragStop(PartyMemberFrame2)
assert(not PartyMemberFrame2._OffhandMovable and not PartyMemberFrame2.movable,
    "Forever must not make party frames movable")
assert(not EditModeManagerFrame._OffhandMovable and not EditModeManagerFrame.movable,
    "Forever must not make EditModeManagerFrame movable")
assert(not EditModeManagerFrame._OffhandRetailChatExitHooked
        and next(EditModeManagerFrame.scripts) == nil,
    "Forever must not attach even read-only hooks to EditModeManagerFrame")
assert(not EditModeManagerFrame:IsShown()
        and addon.db.savedWorkspacePositions.EditModeManagerFrame == nil
        and addon.db.savedMainPositions.EditModeManagerFrame == nil
        and addon.db.openWorkspacePanels.EditModeManagerFrame == nil,
    "Forever must purge stale Edit Mode persistence without reopening the manager")
assert(not addon.Canvas:QueuePersistentPanelRestore(EditModeManagerFrame, "EditModeManagerFrame"),
    "generic persistence must reject the Forever Edit Mode manager")
flushTimers()
assert(not EditModeManagerFrame:IsShown(),
    "load-on-demand persistence must never reopen Forever Edit Mode")
assert(#PartyMemberFrame2.points == party2PointCount,
    "Forever must not restore or save party-frame anchors through Canvas")

-- A bottom-aligned 1080p workspace beside a 2160p Mainhand leaves real
-- UIParent coordinates above the workspace with no physical display. Detect a
-- Blizzard Party Frame there and guide the player without touching its anchor.
-- Keep the other visible protected-HUD candidates inside a physical display so
-- this scenario identifies PartyFrame deterministically.
TargetFrame:ClearAllPoints()
TargetFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2200, 200)
DamageMeter:ClearAllPoints()
DamageMeter:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2500, 200)
PartyFrame = makeMockFrame("PartyFrame", 300, 220)
PartyFrame.IsProtected = function() return true end
PartyFrame:ClearAllPoints()
PartyFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 1400)
local partyRecoveryPointCount = #PartyFrame.points
local partyRecoveryPromptCount, partyRecoveryPromptHidden = 0, 0
local partyRecoveryPromptNames = {}
addon.ShowForeverPartyFrameRecoveryPrompt = function(_, frameName)
    partyRecoveryPromptCount = partyRecoveryPromptCount + 1
    partyRecoveryPromptNames[#partyRecoveryPromptNames + 1] = frameName
end
addon.HideForeverPartyFrameRecoveryPrompt = function()
    partyRecoveryPromptHidden = partyRecoveryPromptHidden + 1
end
local partyRecoveryMetrics = {
    isSpanned = true, screenWidth = 5760, screenHeight = 2160,
    gameLeft = 1920, gameBottom = 0, gameRight = 5760, gameTop = 2160,
    workspaceLeft = 0, workspaceBottom = 0, workspaceRight = 1920, workspaceTop = 1080,
}
EditModeManagerFrame:Show()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(partyRecoveryPromptCount == 0
        and addon.HUD.foreverPartyFrameOutsideDisplays == "PartyFrame",
    "Forever must remember a lost Party Frame without interrupting Edit Mode")
local groupDiagnostics = addon.HUD:GetForeverGroupFrameDiagnostics()
assert(groupDiagnostics:find("Group=no", 1, true)
        and groupDiagnostics:find("EditMode=open", 1, true)
        and groupDiagnostics:find("PartyFrame=shown@", 1, true),
    "Forever group-frame diagnostics must distinguish Edit Mode preview visibility")
assert(#PartyFrame.points == partyRecoveryPointCount
        and PartyFrame.points[1][1] == "BOTTOMLEFT",
    "Party Frame recovery detection must remain read-only")
EditModeManagerFrame:Hide()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(partyRecoveryPromptCount == 1,
    "Forever must offer recovery after Edit Mode closes")
assert(partyRecoveryPromptNames[1] == "PartyFrame",
    "Forever recovery guidance must identify the affected protected HUD frame, got "
        .. tostring(partyRecoveryPromptNames[1]))
local previousMainhand = addon.Mainhand
local repairLayoutCalls, repairReloadCalls = 0, 0
local repairLayoutOptions
addon.Mainhand = {
    CreateOrUpdateEditModeLayout = function(_, options)
        repairLayoutCalls = repairLayoutCalls + 1
        repairLayoutOptions = options
        return true, "Offhand - Mainhand - Test", 7
    end,
    PromptReload = function() repairReloadCalls = repairReloadCalls + 1 end,
}
local repaired, repairedName, repairedFrames = addon.HUD:RepairProtectedHUDLayout()
assert(repaired and repairedName == "Offhand - Mainhand - Test" and repairedFrames == 7
        and repairLayoutCalls == 1 and repairReloadCalls == 1,
    "the recovery hardware click must rebuild the Blizzard layout and request reload")
assert(repairLayoutOptions and repairLayoutOptions.repairFrameName == "PartyFrame",
    "protected-HUD recovery did not target the detected Party frame")
assert(#PartyFrame.points == partyRecoveryPointCount,
    "layout recovery must not directly mutate the protected Party Frame")
addon.Mainhand = previousMainhand
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(partyRecoveryPromptCount == 1,
    "successful protected-HUD recovery must suppress repeats until placement changes")
PartyFrame:ClearAllPoints()
PartyFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 200)
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(partyRecoveryPromptHidden == 1
        and addon.HUD.foreverPartyFrameOutsideDisplays == nil,
    "recovering Party Frames must clear the guidance state")

-- The same bounded, read-only recovery must cover other persistent protected
-- Edit Mode systems. PetFrame represents the conditional unit-frame family;
-- transient popups and nameplates intentionally use separate lifecycles.
PetFrame = makeMockFrame("PetFrame", 180, 80)
PetFrame.IsProtected = function() return true end
PetFrame:ClearAllPoints()
PetFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 500, 1500)
local petRecoveryPointCount = #PetFrame.points
EditModeManagerFrame:Show()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(partyRecoveryPromptCount == 1
        and addon.HUD.foreverPartyFrameOutsideDisplays == "PetFrame",
    "protected HUD detection must remember Edit Mode evidence without prompting")
EditModeManagerFrame:Hide()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(partyRecoveryPromptCount == 2 and partyRecoveryPromptNames[2] == "PetFrame",
    "Forever must detect non-party protected HUD frames in mixed-height dead space")
local protectedHUDDiagnostics = addon.HUD:GetForeverProtectedHUDDiagnostics(partyRecoveryMetrics)
assert(protectedHUDDiagnostics:find("EditMode=closed", 1, true)
        and protectedHUDDiagnostics:find("Outside=not-scanned", 1, true)
        and protectedHUDDiagnostics:find("Candidate=PetFrame", 1, true),
    "Forever diagnostics must distinguish an Edit Mode candidate from dormant roots")
addon.Canvas:TryMakeFrameDraggable(PetFrame)
assert(not PetFrame._OffhandMovable and not PetFrame.movable
        and #PetFrame.points == petRecoveryPointCount
        and PetFrame.points[1][1] == "BOTTOMLEFT",
    "protected HUD recovery must diagnose PetFrame without mutating its anchor")
PetFrame:ClearAllPoints()
PetFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 500, 300)
EditModeManagerFrame:Show()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
EditModeManagerFrame:Hide()
assert(partyRecoveryPromptHidden == 2
        and addon.HUD.foreverPartyFrameOutsideDisplays == nil,
    "recovering a non-party protected HUD frame must clear the guidance state")

-- Retail uses the same Blizzard Edit Mode ownership model. It must receive the
-- same read-only dead-space diagnosis without enabling Forever-only recovery.
addon.isForever = false
addon.isRetail = true
PetFrame:ClearAllPoints()
PetFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 500, 1500)
StatusTrackingBarManager = makeMockFrame("StatusTrackingBarManager", 1000, 20)
StatusTrackingBarManager:ClearAllPoints()
StatusTrackingBarManager:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 1500)
local promptsBeforeRetailLoginScan = partyRecoveryPromptCount
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(partyRecoveryPromptCount == promptsBeforeRetailLoginScan
        and addon.HUD.foreverPartyFrameOutsideDisplays == nil,
    "Retail normal login must ignore dormant PetFrame and StatusTrackingBarManager roots")
StatusTrackingBarManager:ClearAllPoints()
StatusTrackingBarManager:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2500, 100)
EditModeManagerFrame:Show()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
EditModeManagerFrame:Hide()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(partyRecoveryPromptCount == 3 and partyRecoveryPromptNames[3] == "PetFrame",
    "Retail must detect protected Edit Mode HUD frames in mixed-height dead space")
assert(addon.HUD:GetForeverProtectedHUDDiagnostics(partyRecoveryMetrics)
        :find("Candidate=PetFrame", 1, true),
    "Retail diagnostics must retain the protected HUD candidate observed in Edit Mode")
PetFrame:ClearAllPoints()
PetFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 500, 300)
EditModeManagerFrame:Show()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
EditModeManagerFrame:Hide()

-- StatusTrackingBarManager is an Edit Mode ownership proxy whose reported root
-- bounds can remain in mixed-height dead space even while its visible bars are
-- correctly placed. Rebuilding the layout cannot change that proxy, so it must
-- never start the Repair HUD loop when Edit Mode closes.
StatusTrackingBarManager:ClearAllPoints()
StatusTrackingBarManager:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 1500)
local promptsBeforeStatusProxyScan = partyRecoveryPromptCount
EditModeManagerFrame:Show()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
EditModeManagerFrame:Hide()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(partyRecoveryPromptCount == promptsBeforeStatusProxyScan
        and addon.HUD.foreverPartyFrameOutsideDisplays == nil,
    "Retail StatusTrackingBarManager ownership proxy must not trigger Repair HUD")
assert(not addon.HUD:GetForeverProtectedHUDDiagnostics(partyRecoveryMetrics)
        :find("StatusTrackingBarManager", 1, true),
    "Retail diagnostics must not report the unreliable status-bar ownership proxy")

-- Retail's MinimapCluster ownership root can remain in the void while the
-- visible Minimap child is correctly placed by the selected layout. Trust the
-- visible child, but retain recovery when both presentation and root are lost.
MinimapCluster = makeMockFrame("MinimapCluster", 260, 260)
MinimapCluster:ClearAllPoints()
MinimapCluster:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 1500)
Minimap = makeMockFrame("Minimap", 220, 220)
Minimap:ClearAllPoints()
Minimap:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 5200, 300)
local promptsBeforeMinimapProxyScan = partyRecoveryPromptCount
EditModeManagerFrame:Show()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(addon.HUD.foreverPartyFrameOutsideDisplays == nil,
    "Retail must ignore an offscreen MinimapCluster when its visible minimap is reachable")
Minimap:ClearAllPoints()
Minimap:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 1500)
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(addon.HUD.foreverPartyFrameOutsideDisplays == "MinimapCluster",
    "Retail must retain recovery when the MinimapCluster and visible minimap are unreachable")
Minimap:ClearAllPoints()
Minimap:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 5200, 300)
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
EditModeManagerFrame:Hide()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(partyRecoveryPromptCount == promptsBeforeMinimapProxyScan
        and addon.HUD.foreverPartyFrameOutsideDisplays == nil,
    "a reachable visible minimap must clear its stale ownership-root candidate")

-- Retail can leave its legacy PartyFrame ownership root in dead space while
-- the selected layout's visible member presentation is correctly on Mainhand.
-- The stale proxy must not restart Repair HUD after a successful reload.
PartyFrame:ClearAllPoints()
PartyFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 1400)
local retailVisiblePartyMember = makeMockFrame("RetailVisiblePartyMember", 180, 80)
retailVisiblePartyMember:ClearAllPoints()
retailVisiblePartyMember:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 5000, 300)
PartyFrame.GetChildren = function() return retailVisiblePartyMember end
local promptsBeforeStaleRetailProxy = partyRecoveryPromptCount
EditModeManagerFrame:Show()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(partyRecoveryPromptCount == promptsBeforeStaleRetailProxy
        and addon.HUD.foreverPartyFrameOutsideDisplays == nil,
    "Retail must ignore an offscreen PartyFrame proxy when its visible member is reachable")
EditModeManagerFrame:Hide()
assert(addon.HUD:GetForeverProtectedHUDDiagnostics(partyRecoveryMetrics)
        :find("Candidate=none", 1, true),
    "Retail diagnostics must not retain a stale PartyFrame proxy as a candidate")
PartyFrame.GetChildren = nil
PartyFrame:ClearAllPoints()
PartyFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 200)
addon.isForever = true
addon.isRetail = nil
EditModeManagerFrame:Hide()

-- Classic and Anniversary expose Blizzard Edit Mode as a load-on-demand
-- capability rather than a Retail project identity. Once that capability is
-- present, their protected frames need the same dead-space recovery path.
addon.isForever = false
PetFrame:ClearAllPoints()
PetFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 500, 1500)
EditModeManagerFrame:Show()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
EditModeManagerFrame:Hide()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(partyRecoveryPromptCount == 4 and partyRecoveryPromptNames[4] == "PetFrame",
    "Classic-family Edit Mode clients must detect protected HUD frames in dead space")
PetFrame:ClearAllPoints()
PetFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 500, 300)
EditModeManagerFrame:Show()
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
EditModeManagerFrame:Hide()
addon.isForever = true

local protectedPanel = makeMockFrame("ProtectedPanel", 300, 200)
protectedPanel.TitleText = {}
protectedPanel.IsProtected = function() return true end
local forbiddenPanel = makeMockFrame("ForbiddenPanel", 300, 200)
forbiddenPanel.TitleText = {}
forbiddenPanel.IsForbidden = function() return true end
addon.Canvas:TryMakeFrameDraggable(protectedPanel)
addon.Canvas:TryMakeFrameDraggable(forbiddenPanel)
assert(not protectedPanel._OffhandMovable and not protectedPanel.movable,
    "Generic discovery must not mutate protected panels")
assert(not forbiddenPanel._OffhandMovable and not forbiddenPanel.movable,
    "Generic discovery must not mutate forbidden panels")
local damageMeterPoints = #DamageMeter.points
addon.Canvas:TryMakeFrameDraggable(DamageMeter)
flushTimers()
assert(not DamageMeter._OffhandMovable and not DamageMeter.movable
        and #DamageMeter.points == damageMeterPoints,
    "Edit Mode Damage Meter must remain outside generic drag and popup rescue")

ShowUIPanel(EditModeManagerFrame)
flushTimers()

local editPt = EditModeManagerFrame.points[#EditModeManagerFrame.points]
assert(EditModeManagerFrame:GetAttribute("UIPanelLayout-centerFrameSkipAnchoring") == nil,
    "Forever must not write Edit Mode panel-layout attributes")
assert(UIPanelWindows.EditModeManagerFrame.centerFrameSkipAnchoring == nil,
    "Forever must not mutate Edit Mode panel metadata")
assert(editPt == nil,
    "Forever must leave EditModeManagerFrame anchors entirely Blizzard-owned")
local editPointCount = #EditModeManagerFrame.points
EditModeManagerFrame:Hide()
ShowUIPanel(EditModeManagerFrame)
flushTimers()
assert(#EditModeManagerFrame.points == editPointCount,
    "Forever must not alter the Edit Mode manager when it reopens")

-- Companion geometry changes must not cause addon writes to the manager.
local originalGameTop = metrics.gameTop
metrics.gameTop = originalGameTop - 200
flushTimers()
local resizedEditPt = EditModeManagerFrame.points[#EditModeManagerFrame.points]
assert(resizedEditPt == nil,
    "Forever must not reanchor Edit Mode after a late Companion span")
metrics.gameTop = originalGameTop
flushTimers()
assert(#EditModeManagerFrame.points == 0,
    "Forever must preserve native Edit Mode ownership across geometry changes")
assert(selectedLayout == nil,
    "Forever must not auto-select an Offhand layout whose main action bar is still in its full-canvas default position")
assert(OffhandCharDB.editModeLayoutName == nil,
    "Forever must not create a character layout preference during ordinary login")
assert(addon.HUD.editModeGuidanceShown,
    "Forever must guide the player to configure an unpositioned Offhand Edit Mode layout")

-- A mixed-height span can place the Edit Mode manager in the physical void.
-- Keep the opt-out manual path covered before exercising automatic recovery.
addon.db.autoRecoverEditModeControls = false
-- Detection and acknowledgement must not attach handlers or mutate Blizzard
-- state: moving the manager breaks native drag behavior for Party Frames.
WorldFrame = makeMockFrame("WorldFrame", 2560, 1440)
local editModePromptCount, editModePromptHidden = 0, 0
addon.ShowForeverEditModeControlsPrompt = function() editModePromptCount = editModePromptCount + 1 end
addon.HideForeverEditModeControlsPrompt = function() editModePromptHidden = editModePromptHidden + 1 end
EditModeManagerFrame:ClearAllPoints()
EditModeManagerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1268, 1586)
local voidManagerPointCount = #EditModeManagerFrame.points
EditModeLayoutDialog:ClearAllPoints()
EditModeLayoutDialog:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
    metrics.gameLeft + 200, metrics.gameBottom + 200)
EditModeLayoutDialog:Show()
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
assert(editModePromptCount == 0,
    "reachable Edit Mode modal must suppress manager recovery while it has focus")
EditModeLayoutDialog:Hide()
lastTimerDelay = nil
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
assert(editModePromptCount == 0,
    "off-screen Edit Mode controls must wait for native positioning to settle")
assert(lastTimerDelay and lastTimerDelay > 0 and lastTimerDelay <= 0.25,
    "persistent Edit Mode recovery must confirm promptly")
flushTimers()
assert(editModePromptCount == 1, "Forever must offer recovery when Edit Mode controls are in the void")
assert(#EditModeManagerFrame.points == voidManagerPointCount
        and EditModeManagerFrame.points[1][1] == "BOTTOMLEFT",
    "Edit Mode void detection must remain read-only")
assert(next(EditModeManagerFrame.scripts) == nil,
    "Edit Mode recovery must not attach scripts to Blizzard's manager")
assert(addon.HUD:BringForeverEditModeControlsToMainhand(),
    "player-click recovery must bring the unprotected manager to Mainhand")
assert(editModePromptHidden == 0,
    "the Accept callback must let Blizzard close its popup without a re-entrant hide")
local recoveredManagerPoint = EditModeManagerFrame.points[1]
assert(recoveredManagerPoint and recoveredManagerPoint[1] == "CENTER"
        and recoveredManagerPoint[2] == UIParent,
    "Edit Mode recovery must center the manager without changing panel metadata")
assert(UIPanelWindows.EditModeManagerFrame.area == "center"
        and EditModeManagerFrame:GetAttribute("UIPanelLayout-centerFrameSkipAnchoring") == nil,
    "Edit Mode recovery must not mutate Blizzard panel metadata or attributes")
EditModeManagerFrame:Hide()
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
assert(editModePromptHidden >= 1 and addon.HUD.foreverEditModeManagerWasShown == nil,
    "Closing Edit Mode must reset control-window recovery for its next opening")

-- The manager toolbar can fit inside Mainhand while the separate settings
-- dialog is mostly in the void. That state needs the same read-only guidance.
EditModeManagerFrame:ClearAllPoints()
EditModeManagerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
    metrics.gameLeft + 100, metrics.gameBottom + 100)
EditModeManagerFrame:Show()
EditModeSystemSettingsDialog:ClearAllPoints()
EditModeSystemSettingsDialog:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1268, 1586)
EditModeSystemSettingsDialog:Show()
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
flushTimers()
assert(editModePromptCount == 2,
    "Forever must detect an off-screen Edit Mode settings dialog even when its manager fits")
assert(#EditModeSystemSettingsDialog.points == 1
        and EditModeSystemSettingsDialog.points[1][1] == "BOTTOMLEFT",
    "Edit Mode settings-dialog recovery guidance must remain read-only")
assert(addon.HUD:BringForeverEditModeControlsToMainhand(),
    "player-click recovery must bring an off-screen settings dialog to Mainhand")
local recoveredSettingsPoint = EditModeSystemSettingsDialog.points[1]
assert(recoveredSettingsPoint and recoveredSettingsPoint[1] == "CENTER"
        and recoveredSettingsPoint[2] == UIParent,
    "Edit Mode settings-dialog recovery must center the unprotected dialog")
EditModeSystemSettingsDialog:Hide()
EditModeManagerFrame:Hide()
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
EditModeManagerFrame:Show()

-- Current Edit Mode builds reuse one transactional dialog for save, rename,
-- and delete. Even while its native anchor is settling outside a display, it
-- must suppress the manager warning rather than create a competing modal.
EditModeManagerFrame:ClearAllPoints()
EditModeManagerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
    metrics.gameLeft + 100, metrics.gameBottom + 100)
EditModeLayoutDialog:ClearAllPoints()
EditModeLayoutDialog:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1268, 1586)
EditModeLayoutDialog:Show()
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
assert(editModePromptCount == 2,
    "layout dialog must not trigger recovery while Blizzard positions it")
assert(EditModeLayoutDialog.points[1][1] == "CENTER"
        and EditModeLayoutDialog.points[1][2] == UIParent,
    "off-screen layout dialog must be recovered non-modally to Mainhand")
EditModeLayoutDialog:ClearAllPoints()
EditModeLayoutDialog:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
    metrics.gameLeft + 200, metrics.gameBottom + 200)
flushTimers()
assert(editModePromptCount == 2,
    "layout dialog that settles on-screen must cancel its pending recovery prompt")
EditModeLayoutDialog:ClearAllPoints()
EditModeLayoutDialog:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1268, 1586)
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
flushTimers()
assert(editModePromptCount == 2,
    "off-screen layout save dialog must not inject a competing recovery modal")
local recoveredLayoutDialogPoint = EditModeLayoutDialog.points[1]
assert(recoveredLayoutDialogPoint and recoveredLayoutDialogPoint[1] == "CENTER"
        and recoveredLayoutDialogPoint[2] == UIParent,
    "Edit Mode layout save dialog must be centered without a recovery popup")
EditModeLayoutDialog:Hide()
-- Once the dialog becomes reachable/hidden, its prompt state must clear so
-- Blizzard can reuse the same frame for a later delete confirmation.
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
assert(addon.HUD.foreverEditModeControlsPromptShown == nil
        and addon.HUD.foreverEditModeControlsPromptDeclined == nil
        and addon.HUD.foreverEditModeOutsideControl == nil,
    "resolved Edit Mode modal must reset recovery state for delete-layout reuse")
EditModeLayoutDialog:ClearAllPoints()
EditModeLayoutDialog:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1268, 1586)
EditModeLayoutDialog:Show()
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
flushTimers()
assert(editModePromptCount == 2,
    "reused delete dialog must not receive an automatic recovery prompt")
assert(EditModeLayoutDialog.points[1][1] == "CENTER"
        and EditModeLayoutDialog.points[1][2] == UIParent,
    "reused delete dialog must be recovered non-modally to Mainhand")
EditModeLayoutDialog:Hide()

local originalLayoutDialogIsProtected = EditModeLayoutDialog.IsProtected
EditModeLayoutDialog.IsProtected = function() return true end
EditModeLayoutDialog:ClearAllPoints()
EditModeLayoutDialog:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1268, 1586)
EditModeLayoutDialog:Show()
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
flushTimers()
assert(EditModeLayoutDialog.points[1][1] == "BOTTOMLEFT" and editModePromptCount == 2,
    "non-modal recovery must never move or prompt for a protected layout dialog")
EditModeLayoutDialog.IsProtected = originalLayoutDialogIsProtected
EditModeLayoutDialog:Hide()
EditModeManagerFrame:Hide()
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
EditModeManagerFrame:Show()

-- Restoring the window to one monitor is when a stale spanned Edit Mode
-- control is most likely to be unreachable. Recovery must continue to offer
-- the same player-click action in the explicit topology-mismatch state.
local singleScreenMetrics = {
    gameLeft = 0, gameBottom = 0, gameRight = 2560, gameTop = 1440,
    workspaceLeft = 0, workspaceBottom = 0, workspaceRight = 0, workspaceTop = 0,
    screenWidth = 2560, screenHeight = 1440, isSpanned = false,
    topologyStatus = "MISMATCH",
}
EditModeManagerFrame:ClearAllPoints()
EditModeManagerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 3100, 1700)
addon.HUD:UpdateForeverEditModeControlsRecovery(singleScreenMetrics)
flushTimers()
assert(editModePromptCount == 3,
    "single-screen recovery must offer the off-screen Edit Mode controls action")
assert(addon.HUD:BringForeverEditModeControlsToMainhand(),
    "single-screen player click must recover stale spanned Edit Mode controls")
local singleScreenManagerPoint = EditModeManagerFrame.points[1]
assert(singleScreenManagerPoint and singleScreenManagerPoint[1] == "CENTER"
        and singleScreenManagerPoint[2] == UIParent,
    "single-screen recovery must center the manager in the current game display")

-- Retail uses the same off-screen manager and system-settings controls. Its
-- project identity must not suppress the recovery popup or hardware-click fix.
addon.isForever = false
addon.isRetail = true
EditModeManagerFrame:ClearAllPoints()
EditModeManagerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1268, 1586)
addon.HUD:UpdateForeverEditModeControlsRecovery(partyRecoveryMetrics)
flushTimers()
assert(editModePromptCount == 4,
    "Retail must offer recovery when its Edit Mode controls are in the void")
assert(addon.HUD:BringForeverEditModeControlsToMainhand(),
    "Retail's player-click recovery must bring Edit Mode controls to Mainhand")
local retailManagerPoint = EditModeManagerFrame.points[1]
assert(retailManagerPoint and retailManagerPoint[1] == "CENTER"
        and retailManagerPoint[2] == UIParent,
    "Retail Edit Mode recovery must center only its unprotected control window")
addon.isForever = true
addon.isRetail = nil

-- A disconnected saved display must temporarily use a built-in single-screen
-- layout rather than letting Blizzard clamp the spanned Offhand HUD into a
-- malformed arrangement. Reconnecting restores Offhand, unless the player
-- manually chose a different layout during recovery.
local recoveryPrompt
addon.ShowForeverLayoutRecoveryPrompt = function(_, kind) recoveryPrompt = kind end
local originalTopologyStatus, originalCompanionTopology, originalSpanned =
    metrics.topologyStatus, metrics.companionTopology, metrics.isSpanned
metrics.topologyStatus = "READY"
metrics.companionTopology = true
metrics.isSpanned = true
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(OffhandCharDB.foreverEditModeLayoutName == "Offhand"
        and OffhandCharDB.foreverEditModeLayoutID == 6,
    "a healthy exact Forever span must adopt the active custom layout per character")
metrics.topologyStatus = "MISMATCH"
metrics.companionTopology = true
metrics.isSpanned = false
layoutData.activeLayout = 6
selectedLayout = nil
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(recoveryPrompt == nil and OffhandCharDB.foreverEditModeRecovery == nil,
    "Forever must allow a normal launch grace period before declaring a display missing")
metrics.topologyStatus = "READY"
metrics.isSpanned = true
addon.HUD:UpdateForeverRecoveryLayout(metrics)
flushTimers()
assert(recoveryPrompt == nil and OffhandCharDB.foreverEditModeRecovery == nil,
    "A normal Companion span during the grace period must cancel missing-display recovery")
metrics.topologyStatus = "MISMATCH"
metrics.isSpanned = false
addon.HUD:UpdateForeverRecoveryLayout(metrics)
flushTimers()
assert(selectedLayout == nil and layoutData.activeLayout == 6 and recoveryPrompt == "fallback",
    "Forever must request a player click before selecting a protected single-screen layout")
assert(OffhandCharDB.foreverEditModeRecovery
        and OffhandCharDB.foreverEditModeRecovery.restoreLayoutID == 6
        and OffhandCharDB.foreverEditModeRecovery.restoreLayoutName == "Offhand"
        and OffhandCharDB.foreverEditModeRecovery.fallbackLayoutID == 1
        and OffhandCharDB.foreverEditModeRecovery.fallbackLayoutName == "Modern",
    "Forever must remember the protected layout handoff")
addon.HUD:ApplyForeverRecoveryChoice("fallback")
assert(selectedLayout == 1 and layoutData.activeLayout == 1
        and OffhandCharDB.foreverEditModeRecovery,
    "The single-screen recovery button must select Modern and retain the return handoff")

selectedLayout = nil
recoveryPrompt = nil
metrics.topologyStatus = "READY"
metrics.isSpanned = true
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(selectedLayout == nil and layoutData.activeLayout == 1 and recoveryPrompt == "restore",
    "Forever must request a player click before restoring its protected layout")
addon.HUD:ApplyForeverRecoveryChoice("restore")
assert(selectedLayout == 6 and layoutData.activeLayout == 6,
    "The restore button must select the remembered Offhand Edit Mode layout")
assert(OffhandCharDB.foreverEditModeRecovery == nil,
    "Forever must clear the completed protected layout handoff")

-- ABSENT is the normal packaged state for a deliberately manual span. It must
-- not trigger Companion recovery or replace the player's Edit Mode layout.
layoutData.activeLayout = 6
selectedLayout = nil
recoveryPrompt = nil
metrics.topologyStatus = "ABSENT"
metrics.companionTopology = false
metrics.isSpanned = false
addon.HUD:UpdateForeverRecoveryLayout(metrics)
flushTimers()
assert(selectedLayout == nil and layoutData.activeLayout == 6 and recoveryPrompt == nil,
    "Forever manual topology must not request Companion recovery")
assert(OffhandCharDB.foreverEditModeRecovery == nil,
    "Forever manual topology must not create a protected layout handoff")
metrics.topologyStatus = "READY"
metrics.companionTopology = true
metrics.isSpanned = true
recoveryPrompt = nil
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(recoveryPrompt == nil and layoutData.activeLayout == 6,
    "Exact topology must preserve the manual setup's active Offhand layout")

-- Layout names are case-insensitive, and a recovery snapshot must follow the
-- named layout if its custom slot differs from the ID remembered at disconnect.
layoutData.layouts[3].layoutName = "OFFHAND"
layoutData.activeLayout = 6
selectedLayout = nil
recoveryPrompt = nil
metrics.topologyStatus = "MISMATCH"
metrics.isSpanned = false
addon.HUD:UpdateForeverRecoveryLayout(metrics)
flushTimers()
assert(recoveryPrompt == "fallback" and OffhandCharDB.foreverEditModeRecovery
        and OffhandCharDB.foreverEditModeRecovery.restoreLayoutName == "OFFHAND",
    "Forever recovery must recognize Offhand layout names without case sensitivity")
addon.HUD:ApplyForeverRecoveryChoice("fallback")
local movedOffhand = layoutData.layouts[3]
layoutData.layouts[3] = layoutData.layouts[2]
layoutData.layouts[2] = movedOffhand
selectedLayout = nil
recoveryPrompt = nil
metrics.topologyStatus = "READY"
metrics.isSpanned = true
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(recoveryPrompt == "restore" and OffhandCharDB.foreverEditModeRecovery.restoreLayoutID == 5,
    "Forever recovery must re-resolve a named Offhand layout after its custom slot changes")
addon.HUD:ApplyForeverRecoveryChoice("restore")
assert(selectedLayout == 5 and layoutData.activeLayout == 5
        and OffhandCharDB.foreverEditModeRecovery == nil,
    "Forever restore must select the current slot for the remembered Offhand layout name")

-- Never trust a stale numeric slot when the remembered named layout no longer
-- exists; the slot may now belong to an unrelated custom profile.
OffhandCharDB.foreverEditModeRecovery = {
    restoreLayoutID = 6,
    restoreLayoutName = "Missing Offhand",
    fallbackLayoutID = 1,
}
layoutData.activeLayout = 1
selectedLayout = nil
recoveryPrompt = nil
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(OffhandCharDB.foreverEditModeRecovery == nil and selectedLayout == nil
        and layoutData.activeLayout == 1,
    "Forever must not select an unrelated stale slot when the named layout is missing")

layoutData.layouts[2] = layoutData.layouts[3]
layoutData.layouts[3] = movedOffhand
layoutData.layouts[3].layoutName = "Offhand"
layoutData.activeLayout = 6

-- If Forever ignores a non-hardware or otherwise blocked selection, retain the
-- marker and clear it only after a later read-back confirms Offhand.
layoutData.activeLayout = 6
metrics.topologyStatus = "MISMATCH"
metrics.isSpanned = false
addon.HUD:UpdateForeverRecoveryLayout(metrics)
flushTimers()
addon.HUD:ApplyForeverRecoveryChoice("fallback")
recoveryPrompt = nil
metrics.topologyStatus = "READY"
metrics.isSpanned = true
addon.HUD:UpdateForeverRecoveryLayout(metrics)
local blockedRestoreID
C_EditMode.SetActiveLayout = function(index)
    selectedLayout = index
    blockedRestoreID = index
end
addon.HUD:ApplyForeverRecoveryChoice("restore")
assert(blockedRestoreID == 6 and layoutData.activeLayout == 1
        and OffhandCharDB.foreverEditModeRecovery,
    "Forever must retain the protected layout handoff until selection is confirmed")
layoutData.activeLayout = blockedRestoreID
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(OffhandCharDB.foreverEditModeRecovery == nil and layoutData.activeLayout == 6,
    "Forever must clear the handoff after delayed Edit Mode read-back confirms Offhand")
C_EditMode.SetActiveLayout = function(index)
    selectedLayout = index
    layoutData.activeLayout = index
end

layoutData.activeLayout = 6
metrics.topologyStatus = "MISMATCH"
metrics.isSpanned = false
addon.HUD:UpdateForeverRecoveryLayout(metrics)
flushTimers()
addon.HUD:ApplyForeverRecoveryChoice("fallback")
layoutData.activeLayout = 2
selectedLayout = nil
metrics.topologyStatus = "READY"
metrics.isSpanned = true
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(selectedLayout == nil and layoutData.activeLayout == 2,
    "Forever must preserve a layout manually selected during single-screen recovery")
assert(OffhandCharDB.foreverEditModeRecovery == nil,
    "Forever must clear stale recovery state after manual layout selection")

-- The explicit player button can designate any active custom layout without
-- changing it. Built-in Modern/Classic layouts are rejected.
layoutData.layouts[3].layoutName = "Druid Forever"
layoutData.activeLayout = 6
selectedLayout = nil
OffhandCharDB.mainhandLayout = {
    generatedName = "Druid Forever", generatedID = 5, activationPending = true,
}
local designated, designatedName = addon.HUD:UseCurrentForeverEditModeLayout()
local designatedStatus = addon.HUD:GetForeverEditModeLayoutStatus()
assert(designated and designatedName == "Druid Forever"
        and designatedStatus.preferredName == "Druid Forever"
        and designatedStatus.preferredID == 6
        and designatedStatus.activeMatches
        and OffhandCharDB.mainhandLayout.generatedID == 6
        and OffhandCharDB.mainhandLayout.activationPending == nil
        and selectedLayout == nil,
    "Forever must designate the active custom layout per character without selecting it")
layoutData.activeLayout = 1
local builtInDesignated, builtInReason = addon.HUD:UseCurrentForeverEditModeLayout()
assert(not builtInDesignated and builtInReason == "builtin"
        and OffhandCharDB.foreverEditModeLayoutName == "Druid Forever",
    "Forever must reject built-in fallback layouts without replacing the saved custom layout")

-- A staged legacy profile transaction is accepted only when its named layout
-- resolves and the character is still on either side of that transaction.
OffhandCharDB.foreverEditModeLayoutName = nil
OffhandCharDB.foreverEditModeLayoutID = nil
OffhandCharDB.foreverEditModeRecovery = nil
OffhandCharDB.foreverEditModeLegacyRecovery = {
    restoreLayoutID = 6, restoreLayoutName = "Druid Forever",
    fallbackLayoutID = 1, fallbackLayoutName = "Modern",
}
layoutData.activeLayout = 6
metrics.topologyStatus = "READY"
metrics.companionTopology = true
metrics.isSpanned = true
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(OffhandCharDB.foreverEditModeLegacyRecovery == nil
        and OffhandCharDB.foreverEditModeLayoutName == "Druid Forever"
        and OffhandCharDB.foreverEditModeRecovery == nil,
    "Forever must validate and finish a staged legacy recovery on the owning character")

layoutData.layouts[3].layoutName = "Offhand"
layoutData.activeLayout = 6
addon.HUD:UseCurrentForeverEditModeLayout()
selectedLayout = nil
metrics.topologyStatus = originalTopologyStatus
metrics.companionTopology = originalCompanionTopology
metrics.isSpanned = originalSpanned

-- A designated custom layout that is already active is healthy even if
-- Forever retains the source layout's default-position marker. Do not repeat
-- setup guidance after every cold login when no player action is required.
addon.HUD.editModeGuidanceShown = nil
addon.HUD.editModeLoadScheduled = nil
addon.HUD:HookFrames()
flushTimers()
assert(not addon.HUD.editModeGuidanceShown,
    "Forever must keep a matching designated Edit Mode layout quiet on login")

-- Even after the player has configured the layout, Forever must leave profile
-- selection to Blizzard Edit Mode. A delayed switch can move or hide bars.
layoutData.layouts[3].systems[1].isInDefaultPosition = false
addon.HUD.editModeLoadScheduled = nil
addon.HUD:HookFrames()
flushTimers()
assert(selectedLayout == nil and layoutData.activeLayout == 6,
    "Forever must not change the active Edit Mode layout after reload")

-- Retail/Anniversary must adopt each character's current Blizzard layout on
-- upgrade instead of imposing the account's layout named Offhand. Later
-- mismatches restore that remembered name through C_EditMode's global layout
-- identifier; the custom-array index is a different namespace.
addon.isForever = false
EditModePresetLayoutManager = {
    GetCopyOfPresetLayouts = function()
        return {{ layoutName = "Modern" }, { layoutName = "Classic" },
            { layoutName = "Internal" }}
    end,
}
OffhandCharDB.editModeLayoutName = nil
layoutData.layouts[4].layoutName = "Druid Offhand"
local anniversaryActiveName = "Druid Offhand"
local managerSelection
EditModeManagerFrame.GetActiveLayoutInfo = function()
    return { layoutName = anniversaryActiveName }
end
EditModeManagerFrame.SelectLayout = function(_, index)
    managerSelection = index
end
layoutData.activeLayout = 5
selectedLayout = nil
addon.HUD.editModeLoadScheduled = nil
addon.HUD:HookFrames()
assert(groupLootPreloadCount == 1 and GroupLootContainer,
    "secure GroupLootContainer must be loaded before its first in-combat roll")
flushTimers()
assert(selectedLayout == nil and managerSelection == nil,
    "Retail upgrade must preserve the character's already-active Blizzard layout")
assert(OffhandCharDB.editModeLayoutName == "Druid Offhand",
    "Retail upgrade must remember the active Blizzard layout per character")
assert(type(EditModeManagerFrame.scripts.OnShow) == "function"
        and type(EditModeManagerFrame.scripts.OnHide) == "function",
    "Non-Forever Edit Mode manager must use read-only visibility observers")

anniversaryActiveName = "Modern"
selectedLayout = nil
managerSelection = nil
addon.HUD.editModeLoadScheduled = nil
addon.HUD:HookFrames()
flushTimers()
assert(selectedLayout == 7 and managerSelection == nil,
    "Anniversary must restore the remembered character layout through its global Edit Mode ID")

-- A later explicit selection becomes this character's new preference without
-- intercepting or replacing Blizzard's layout-selection API.
anniversaryActiveName = "Offhand"
EditModeManagerFrame:Show()
EditModeManagerFrame:Hide()
flushTimers()
assert(OffhandCharDB.editModeLayoutName == "Offhand",
    "Retail must remember a later explicit Edit Mode selection")
anniversaryActiveName = "Modern"
selectedLayout = nil
addon.HUD.editModeLoadScheduled = nil
addon.HUD:HookFrames()
flushTimers()
assert(selectedLayout == 6 and managerSelection == nil,
    "Retail must restore the character's newly selected layout by global ID")
addon.isForever = true
EditModePresetLayoutManager = nil
layoutData.activeLayout = 6
selectedLayout = nil

local recoveryPanel = makeMockFrame("RecoveryWorkspacePanel", 500, 400)
local recoveryChat = makeMockFrame("ChatFrame9", 500, 300)
local recoveryCharacter = makeMockFrame("CharacterFrame", 500, 700)
local recoveryBag = makeMockFrame("ContainerFrameCombinedBags", 500, 300)
addon.db.savedWorkspacePositions.RecoveryWorkspacePanel = { x = 100, y = 900 }
addon.db.savedWorkspacePositions.ChatFrame9 = { x = 100, y = 400 }
addon.db.savedWorkspacePositions.CharacterFrame = { x = 100, y = 800 }
addon.db.savedWorkspacePositions.ContainerFrameCombinedBags = { x = 100, y = 300 }
addon.Canvas:PrepareSingleScreenRecovery({ topologyStatus = "MISMATCH", isSpanned = false })
assert(not recoveryPanel:IsShown(),
    "single-screen recovery must temporarily close visible workspace panels")
assert(recoveryChat:IsShown(),
    "single-screen recovery must keep chat available")
assert(addon.db.savedWorkspacePositions.RecoveryWorkspacePanel,
    "single-screen recovery must preserve saved workspace geometry")
recoveryPanel:Show()
assert(addon.Canvas:PlaceForSingleScreenRecovery(recoveryPanel,
        { topologyStatus = "MISMATCH", isSpanned = false }),
    "a workspace panel opened during recovery must receive a temporary visible anchor")
local recoveryPoint = recoveryPanel.points[#recoveryPanel.points]
assert(recoveryPoint and recoveryPoint[1] == "CENTER" and recoveryPoint[2] == UIParent
        and recoveryPoint[3] == "CENTER" and recoveryPoint[4] == 0 and recoveryPoint[5] == 0,
    "single-screen recovery must center reopened workspace panels")
assert(addon.db.savedWorkspacePositions.RecoveryWorkspacePanel.x == 100,
    "temporary recovery anchors must not overwrite saved Offhand coordinates")
local chatPointCount = #recoveryChat.points
assert(not addon.Canvas:PlaceForSingleScreenRecovery(recoveryChat,
        { topologyStatus = "MISMATCH", isSpanned = false })
        and #recoveryChat.points == chatPointCount,
    "Modern must retain ownership of the single-screen chat anchor")
assert(addon.Canvas:PlaceForSingleScreenRecovery(recoveryCharacter,
        { topologyStatus = "MISMATCH", isSpanned = false }),
    "the character sheet must receive a single-screen recovery anchor")
local characterPoint = recoveryCharacter.points[#recoveryCharacter.points]
assert(characterPoint and characterPoint[1] == "TOPLEFT" and characterPoint[3] == "TOPLEFT",
    "the character sheet must recover near the upper-left")
assert(addon.Canvas:PlaceForSingleScreenRecovery(recoveryBag,
        { topologyStatus = "MISMATCH", isSpanned = false }),
    "the backpack must receive a single-screen recovery anchor")
local bagPoint = recoveryBag.points[#recoveryBag.points]
assert(bagPoint and bagPoint[1] == "BOTTOMRIGHT" and bagPoint[3] == "BOTTOMRIGHT",
    "the backpack must recover above the lower-right action UI")
recoveryPanel:Show()
addon.Canvas:PrepareSingleScreenRecovery({ topologyStatus = "ABSENT", isSpanned = false })
assert(recoveryPanel:IsShown(),
    "Forever manual topology must not close visible workspace panels")
assert(not addon.Canvas:PlaceForSingleScreenRecovery(recoveryPanel,
        { topologyStatus = "ABSENT", isSpanned = false }),
    "Forever manual topology must not apply Companion recovery anchors")

-- Edit Mode dialogs also remain entirely Blizzard-owned.
EditModeUnsavedChangesDialog:Show()
flushTimers()
local dialogPt = EditModeUnsavedChangesDialog.points[#EditModeUnsavedChangesDialog.points]
assert(dialogPt == nil, "Forever must not reanchor Edit Mode dialogs")
print("PASS: Forever preserves Blizzard ownership of Edit Mode and its manager")

-- ============================================================================
-- TEST 6: GameMenuFrame Centering & Escape Dismissal
-- ============================================================================
ToggleGameMenu()
flushTimers()
local menuPt = GameMenuFrame.points[#GameMenuFrame.points]
assert(menuPt and menuPt[1] == "CENTER" and menuPt[2] == UIParent
        and menuPt[3] == "BOTTOMLEFT"
        and math.abs(menuPt[4] - ((metrics.gameLeft + metrics.gameRight) / 2)) < 0.01
        and math.abs(menuPt[5] - ((metrics.gameBottom + metrics.gameTop) / 2)) < 0.01,
    "Forever must center GameMenuFrame on Mainhand during the native toggle")
ToggleGameMenu() -- Dismiss cleanly
assert(not GameMenuFrame:IsShown(), "GameMenuFrame must dismiss cleanly on toggle")
print("PASS: Forever centers GameMenuFrame before render and it dismisses cleanly")

-- ============================================================================
-- TEST 7: Universal Void Rescue Engine (Focused Roster Frame & Rogue Frames)
-- ============================================================================
-- Place ExampleAddonWindow high up in the black void (e.g. x = 2000, top = 2500, where gameTop is 1446)
ExampleAddonWindow:ClearAllPoints()
ExampleAddonWindow:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 2000, -50) -- y = 2510 in the void!
assert(ExampleAddonWindow:GetTop() > metrics.gameTop, "ExampleAddonWindow must initially be in the void")

-- Trigger HUD popup/void scanner
addon.HUD:HookFrames()
-- Manually invoke OnShow hook or ticker that runs RedirectExternalPopups
for _, child in ipairs(UIParent.children) do
    if child == ExampleAddonWindow then
        child:Show()
    end
end
flushTimers()

-- The Void Rescue Engine must detect GetTop() > m.gameTop and clamp it down
local rescuedPt = ExampleAddonWindow.points[#ExampleAddonWindow.points]
assert(rescuedPt, "ExampleAddonWindow must be repositioned by Void Rescue Engine")
local rescuedTop = ExampleAddonWindow:GetTop()
assert(rescuedTop <= metrics.gameTop, string.format("Rescued frame top (%s) must be <= gameTop (%s)", tostring(rescuedTop), tostring(metrics.gameTop)))
print(string.format("PASS: Void Rescue Engine successfully rescued ExampleAddonWindow from void (top=%s <= gameTop=%s)", tostring(rescuedTop), tostring(metrics.gameTop)))

-- A workspace stacked directly above Mainhand shares the same horizontal
-- range. The void scanner must use the complete workspace rectangle instead
-- of treating every frame above gameTop as lost.
local originalMetrics = {}
for key, value in pairs(metrics) do originalMetrics[key] = value end
metrics.screenWidth, metrics.screenHeight = 2560, 2880
metrics.physicalWidth, metrics.physicalHeight = 2560, 2880
metrics.gameLeft, metrics.gameBottom, metrics.gameRight, metrics.gameTop = 0, 0, 2560, 1440
metrics.workspaceLeft, metrics.workspaceBottom = 0, 1440
metrics.workspaceRight, metrics.workspaceTop = 2560, 2880
metrics.workspaceWidth, metrics.workspaceHeight = 2560, 1440

local stackedWorkspaceFrame = makeMockFrame("StackedWorkspaceFrame", 500, 400)
stackedWorkspaceFrame:ClearAllPoints()
stackedWorkspaceFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 700, 2500)
table.insert(UIParent.children, stackedWorkspaceFrame)

-- Exercise the complete Forever drag/save/reload path, not only the popup
-- scanner. A saved frame on an upper monitor shares Mainhand's X range and
-- must retain its absolute workspace Y coordinate.
addon.Canvas.OnPanelDragStop(stackedWorkspaceFrame)
local stackedSaved = addon.db.savedWorkspacePositions.StackedWorkspaceFrame
assert(stackedSaved and stackedSaved.canvasBottom == 1440
        and stackedSaved.y > metrics.gameTop,
    "Forever must save upper-workspace drag coordinates against the workspace rectangle")
stackedWorkspaceFrame:ClearAllPoints()
stackedWorkspaceFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
addon.Canvas.RestoreWorkspacePosition(stackedWorkspaceFrame)
assert(addon.Canvas.IsFrameOnWorkspace(stackedWorkspaceFrame),
    "Forever reload restoration must return a saved frame to the upper workspace")

local stackedPointCount = #stackedWorkspaceFrame.points
flushTimers()
assert(#stackedWorkspaceFrame.points == stackedPointCount
        and stackedWorkspaceFrame.points[#stackedWorkspaceFrame.points][1] == "TOPLEFT",
    "void rescue must not return a valid upper-workspace frame to Mainhand")
assert(addon.Canvas.IsFrameOnWorkspace(stackedWorkspaceFrame),
    "upper stacked workspace must be recognized by its full rectangle")
for key in pairs(metrics) do metrics[key] = nil end
for key, value in pairs(originalMetrics) do metrics[key] = value end
print("PASS: upper stacked workspace frames are not mistaken for Mainhand void")

-- Load-on-demand panels are not a stable name list. A newly registered spell
-- book with no explicit Offhand placement must be discovered, made draggable,
-- and moved from Blizzard's UIParent-relative workspace anchor to Mainhand.
local playerSpellsFrame = makeMockFrame("PlayerSpellsFrame", 600, 700)
local playerSpellsTitle = makeMockFrame("PlayerSpellsFrameTitleContainer", 500, 20)
playerSpellsFrame.TitleContainer = playerSpellsTitle
playerSpellsFrame.IsProtected = function() return true end
playerSpellsTitle.IsProtected = function() return true end
playerSpellsFrame.StartMoving = function(self) self.startMovingCalls = (self.startMovingCalls or 0) + 1 end
playerSpellsFrame.SetUserPlaced = function(self, value)
    self.setUserPlacedFalseCalls = (self.setUserPlacedFalseCalls or 0) + (value == false and 1 or 0)
    if value == false then
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 2720, 720)
    end
end
playerSpellsFrame:ClearAllPoints()
playerSpellsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 1000, 2500)
UIPanelWindows.PlayerSpellsFrame = { area = "left", pushable = 0 }
addon.Canvas:DiscoverUIPanels()
flushTimers()
assert(playerSpellsFrame._OffhandMovable and playerSpellsFrame.movable,
    "dynamic UIPanel discovery must make registered out-of-combat protected panels draggable")
assert(playerSpellsFrame._OffhandPanelMotionGrip
        and playerSpellsFrame._OffhandHandle == playerSpellsFrame._OffhandPanelMotionGrip
        and playerSpellsFrame._OffhandPanelMotionGrip.template == "PanelDragBarTemplate"
        and addon.Canvas:GetPanelMotionStatus(playerSpellsFrame) == "active",
    "Forever Blizzard panels must use Offhand's guarded Blizzard-template title grip")
assert(not playerSpellsFrame.mouse and not playerSpellsTitle.mouse,
    "guarded panel movement must not claim mouse input on the panel body or native title")
playerSpellsFrame._OffhandPanelMotionGrip.scripts.OnDragStart(
    playerSpellsFrame._OffhandPanelMotionGrip)
assert(playerSpellsFrame.startMovingCalls == 1,
    "dragging the guarded title grip must start moving its owning panel")
assert(playerSpellsFrame:GetLeft() >= metrics.gameLeft + 12
        and playerSpellsFrame:GetRight() <= metrics.gameRight - 12,
    "an unsaved Blizzard panel must default inside the Mainhand viewport")
assert(playerSpellsFrame:GetTop() <= metrics.gameTop - 12
        and playerSpellsFrame:GetBottom() >= metrics.gameBottom + 12,
    "default Blizzard panels must remain vertically contained in Mainhand")

playerSpellsFrame:ClearAllPoints()
playerSpellsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 260, 1900)
playerSpellsFrame._OffhandPanelMotionGrip.scripts.OnDragStop(
    playerSpellsFrame._OffhandPanelMotionGrip)
assert(addon.db.savedWorkspacePositions.PlayerSpellsFrame,
    "a dynamically discovered panel drag must persist its workspace position")
assert((playerSpellsFrame.setUserPlacedFalseCalls or 0) == 0,
    "Forever drag stop must not clear user-placed state and trigger a native center reset")
assert(addon.Canvas.IsFrameOnWorkspace(playerSpellsFrame),
    "a Forever panel dropped on the left workspace must not snap back to Mainhand")

local gamepadPanel = makeMockFrame("GamepadManagedPanel", 600, 700)
gamepadPanel.TitleContainer = makeMockFrame("GamepadManagedPanelTitleContainer", 500, 20)
gamepadPanel.IsProtected = function() return true end
UIPanelWindows.GamepadManagedPanel = { area = "left", pushable = 0 }
nativeGamepad = true
addon.Canvas:TryMakeFrameDraggable(gamepadPanel)
assert(not gamepadPanel._OffhandPanelMotionGrip and not gamepadPanel.movable
        and gamepadPanel._OffhandPanelMotionStatus == nil
        and addon.Canvas:GetPanelMotionStatus(gamepadPanel) == nil,
    "Forever native gamepad panels must not receive child grips, markers or movable ownership")

PartyFrame:ClearAllPoints()
PartyFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 1400)
addon.HUD.foreverPartyFrameOutsideDisplays = "PartyFrame"
addon.HUD.foreverProtectedHUDDetectedInEditMode = true
addon.HUD.foreverPartyFrameRecoveryPromptShown = true
local hiddenBeforeGamepadRecovery = partyRecoveryPromptHidden
local promptsBeforeGamepadRecovery = partyRecoveryPromptCount
addon.HUD:UpdateForeverPartyFrameRecovery(partyRecoveryMetrics)
assert(partyRecoveryPromptCount == promptsBeforeGamepadRecovery
        and partyRecoveryPromptHidden == hiddenBeforeGamepadRecovery + 1
        and addon.HUD.foreverPartyFrameOutsideDisplays == nil
        and addon.HUD.foreverPartyFrameRecoveryPromptShown == nil,
    "native gamepad Edit Mode must clear stale HUD recovery without scanning or prompting")
local gamepadRepairCalls = 0
addon.Mainhand = {
    IsControllerLayout = function() return true end,
    CreateOrUpdateEditModeLayout = function()
        gamepadRepairCalls = gamepadRepairCalls + 1
        return true
    end,
}
local gamepadRepaired, gamepadRepairReason = addon.HUD:RepairProtectedHUDLayout()
assert(not gamepadRepaired and gamepadRepairReason == "gamepad" and gamepadRepairCalls == 0,
    "native gamepad HUD recovery must never write or activate an Offhand layout")
addon.Mainhand = previousMainhand

EditModeManagerFrame:Hide()
EditModeUnsavedChangesDialog:Hide()
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
EditModeManagerFrame:ClearAllPoints()
EditModeManagerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1268, 1586)
EditModeManagerFrame:Show()
local promptsBeforeGamepadControls = editModePromptCount
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
flushTimers()
assert(editModePromptCount == promptsBeforeGamepadControls + 1,
    "native gamepad mode must still offer player-click recovery for unprotected Edit Mode controls: before="
        .. tostring(promptsBeforeGamepadControls) .. " after=" .. tostring(editModePromptCount))
assert(addon.HUD:BringForeverEditModeControlsToMainhand()
        and EditModeManagerFrame.points[1][1] == "CENTER"
        and EditModeManagerFrame.points[1][2] == UIParent,
    "native gamepad recovery must center only the unprotected Edit Mode manager")

EditModeLayoutDialog:ClearAllPoints()
EditModeLayoutDialog:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2000, 1900)
EditModeLayoutDialog:Show()
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
local gamepadDialogPoint = EditModeLayoutDialog.points[#EditModeLayoutDialog.points]
assert(gamepadDialogPoint and gamepadDialogPoint[1] == "CENTER"
        and gamepadDialogPoint[2] == UIParent,
    "native gamepad Edit Mode save/delete dialog was not recovered from the void")
EditModeLayoutDialog:Hide()

local gamepadOverlay = makeMockFrame("GamepadNavigationOverlay", 300, 180)
-- Automatic control rescue uses the same bounded settlement and narrowly
-- allowed unprotected roots as manual recovery. It must not repeat prompts,
-- disturb reachable user placement, or move protected HUD previews.
addon.db.autoRecoverEditModeControls = true
local autoRecoveryPromptCount = editModePromptCount
local partyPointsBeforeAuto = #PartyFrame.points
EditModeManagerFrame:ClearAllPoints()
EditModeManagerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1268, 1586)
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
assert(EditModeManagerFrame.points[1][1] == "BOTTOMLEFT",
    "automatic control rescue must wait for native anchor settlement")
flushTimers()
assert(EditModeManagerFrame.points[1][1] == "CENTER"
        and editModePromptCount == autoRecoveryPromptCount
        and #PartyFrame.points == partyPointsBeforeAuto,
    "automatic recovery must center only the unreachable control without a prompt")
local autoRecoveredManagerPoint = EditModeManagerFrame.points[1]
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
flushTimers()
assert(EditModeManagerFrame.points[1] == autoRecoveredManagerPoint,
    "reachable Edit Mode controls must not receive repeated anchor writes")
EditModeSystemSettingsDialog:ClearAllPoints()
EditModeSystemSettingsDialog:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1268, 1586)
EditModeSystemSettingsDialog:Show()
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
flushTimers()
assert(EditModeSystemSettingsDialog.points[1][1] == "CENTER"
        and editModePromptCount == autoRecoveryPromptCount,
    "the element-settings window must receive the same automatic recovery")
EditModeSystemSettingsDialog:Hide()
EditModeManagerFrame:ClearAllPoints()
EditModeManagerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1268, 1586)
combatLocked = true
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
assert(EditModeManagerFrame.points[1][1] == "BOTTOMLEFT",
    "automatic control rescue must not run in combat")
combatLocked = false
local nativeManagerProtected = EditModeManagerFrame.IsProtected
EditModeManagerFrame.IsProtected = function() return true end
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
flushTimers()
assert(EditModeManagerFrame.points[1][1] == "BOTTOMLEFT",
    "automatic control rescue must refuse a protected manager root")
EditModeManagerFrame.IsProtected = nativeManagerProtected
addon.HUD:BringForeverEditModeControlsToMainhand()
addon.db.autoRecoverEditModeControls = false
EditModeManagerFrame:ClearAllPoints()
EditModeManagerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1268, 1586)
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
flushTimers()
assert(EditModeManagerFrame.points[1][1] == "BOTTOMLEFT",
    "disabling automatic rescue must retain the manual recovery workflow")
addon.HUD:BringForeverEditModeControlsToMainhand()
gamepadOverlay:ClearAllPoints()
gamepadOverlay:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
table.insert(UIParent.children, gamepadOverlay)
local gamepadOverlayPoints = #gamepadOverlay.points
flushTimers()
assert(#gamepadOverlay.points == gamepadOverlayPoints
        and gamepadOverlay.points[1][4] == 0 and gamepadOverlay.points[1][5] == 0,
    "the broad popup scanner must not re-anchor native gamepad navigation frames")
nativeGamepad = false

-- Moving the same panel back to Mainhand is also an explicit placement. It
-- must survive a native close/reopen instead of falling back to the workspace
-- anchor, and it must rejoin normal Escape ownership there.
playerSpellsFrame:ClearAllPoints()
playerSpellsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 1900, 1100)
playerSpellsFrame._OffhandPanelMotionGrip.scripts.OnDragStart(
    playerSpellsFrame._OffhandPanelMotionGrip)
playerSpellsFrame._OffhandPanelMotionGrip.scripts.OnDragStop(
    playerSpellsFrame._OffhandPanelMotionGrip)
local spellMain = addon.db.savedMainPositions.PlayerSpellsFrame
assert(not addon.db.savedWorkspacePositions.PlayerSpellsFrame and spellMain
        and spellMain.x == 1900 and spellMain.y == 1100,
    "a Blizzard panel dragged back to Mainhand must save its Mainhand position")
assert(not addon.Canvas.IsFrameOnWorkspace(playerSpellsFrame),
    "a Blizzard panel dragged to Mainhand must remain there immediately")

playerSpellsFrame:Hide()
playerSpellsFrame:ClearAllPoints()
playerSpellsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 160, 2300)
playerSpellsFrame:Show()
flushTimers()
assert(not addon.Canvas.IsFrameOnWorkspace(playerSpellsFrame)
        and playerSpellsFrame:GetLeft() == 1900 and playerSpellsFrame:GetTop() == 1100,
    "closing and reopening a Mainhand panel must restore its saved Mainhand anchor")

-- Communities reanchors its root when switching internal tabs. An explicit
-- Mainhand placement must survive that same-show native reset.
CommunitiesFrame = makeMockFrame("CommunitiesFrame", 900, 760)
CommunitiesFrame.TitleContainer = makeMockFrame("CommunitiesFrameTitleContainer", 800, 24)
UIPanelWindows.CommunitiesFrame = { area = "left", pushable = 0 }
addon.Canvas:DiscoverUIPanels()
addon.db.savedMainPositions.CommunitiesFrame = { point="TOPLEFT", x=1880, y=1180 }
CommunitiesFrame:ClearAllPoints()
CommunitiesFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 80, 2400)
flushTimers()
assert(CommunitiesFrame:GetLeft() == 1880 and CommunitiesFrame:GetTop() == 1180,
    "Communities internal tab resets must preserve its explicit Mainhand placement")

-- Forever routes Social and Communities through the same native left-panel
-- stack. Opening Communities can reanchor an already shown Social panel before
-- the next frame, so the explicit toggle observer must repair both saved peers
-- synchronously rather than waiting for a later polling pass.
FriendsFrame = makeMockFrame("FriendsFrame", 430, 700)
FriendsFrame.TitleContainer = makeMockFrame("FriendsFrameTitleContainer", 360, 24)
FriendsFrame:ClearAllPoints()
FriendsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 1860, 1160)
UIPanelWindows.FriendsFrame = { area = "left", pushable = 1 }
addon.db.savedMainPositions.FriendsFrame = { point="TOPLEFT", x=1860, y=1160 }
ToggleCommunitiesFrame = function()
    FriendsFrame:ClearAllPoints()
    FriendsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 20, 2480)
    CommunitiesFrame:ClearAllPoints()
    CommunitiesFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 40, 2460)
    CommunitiesFrame:Show()
end
addon.Canvas:EnableFreeDragging()
ToggleCommunitiesFrame()
assert(FriendsFrame:GetLeft() == 1860 and FriendsFrame:GetTop() == 1160
        and CommunitiesFrame:GetLeft() == 1880 and CommunitiesFrame:GetTop() == 1180,
    "opening Communities did not preserve the shown Social and Communities Mainhand anchors")

-- Social can also be displaced by an unrelated native panel using the same
-- left slot. The common ShowUIPanel observer must repair that transaction, not
-- just the Social and Communities toggle functions.
local unrelatedPanel = makeMockFrame("UnrelatedLeftPanel", 600, 700)
UIPanelWindows.UnrelatedLeftPanel = { area = "left", pushable = 0 }
WorldMapFrame = makeMockFrame("WorldMapFrame", 900, 760)
UIPanelWindows.WorldMapFrame = { area = "left", pushable = 0 }
addon.db.savedWorkspacePositions.WorldMapFrame = {
    x = 120, y = 2380, canvasLeft = 0, canvasBottom = 0,
    canvasWidth = metrics.workspaceWidth, canvasHeight = metrics.workspaceHeight,
}
addon.Canvas:RestoreWorkspacePosition(WorldMapFrame)
local savedMapLeft, savedMapTop = WorldMapFrame:GetLeft(), WorldMapFrame:GetTop()
assert(addon.Canvas:GetPanelController("WorldMapFrame") == "forever-world-map"
        and addon.Canvas:GetPanelController("FriendsFrame") == "forever-social-community"
        and addon.Canvas:GetPanelController("CommunitiesFrame") == "forever-social-community"
        and addon.Canvas:GetPanelController("UnrelatedLeftPanel") == "generic",
    "Forever high-risk panels must have one explicit position controller")
FriendsFrame:ClearAllPoints()
FriendsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 20, 2480)
WorldMapFrame:ClearAllPoints()
WorldMapFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 12, 2050)
addon.Canvas:RepairShownWorkspacePanels(nil, true)
assert(WorldMapFrame:GetLeft() == 12 and WorldMapFrame:GetTop() == 2050,
    "the generic peer repair must not write the dedicated World Map anchor")
ShowUIPanel(unrelatedPanel)
assert(FriendsFrame:GetLeft() == 1860 and FriendsFrame:GetTop() == 1160,
    "opening an unrelated UIPanel did not restore the displaced Social frame")
assert(WorldMapFrame:GetLeft() == savedMapLeft and WorldMapFrame:GetTop() == savedMapTop,
    "opening another UIPanel did not restore the displaced Offhand World Map")
local controllerDiagnostics = addon.Canvas:GetPanelControllerDiagnostics()
assert(controllerDiagnostics:find("WorldMapFrame=forever-world-map/settlement#", 1, true)
        and controllerDiagnostics:find("FriendsFrame=forever-social-community/", 1, true),
    "panel diagnostics must expose the dedicated controller and its last activity")
addon.db.savedWorkspacePositions.WorldMapFrame = nil

-- Forever currently exposes the visible Friends panel as SocialUIFrame. It is
-- not one of the earlier guessed FriendsFrame/FriendsListFrame aliases and may
-- be absent from UIPanelWindows. Seed its native Mainhand position on the first
-- shown pass, then reproduce the close-time Collections layout which moves it
-- to the Offhand top-left anchor.
FriendsFrame:Hide()
UIPanelWindows.FriendsFrame = nil
addon.db.savedMainPositions.FriendsFrame = nil
SocialUIFrame = makeMockFrame("SocialUIFrame", 430, 700)
SocialUIFrame.IsProtected = function() return true end
SocialUIFrame:ClearAllPoints()
SocialUIFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 1840, 1150)
addon.Canvas:RepairShownSocialCommunityPanels()
local stableSocialWrites = SocialUIFrame.setPointCalls
addon.Canvas:RepairShownSocialCommunityPanels()
assert(SocialUIFrame.setPointCalls == stableSocialWrites,
    "an unchanged SocialUIFrame must not receive a redundant anchor refresh")
nativeUIPanelLayout = function()
    SocialUIFrame:ClearAllPoints()
    SocialUIFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 20, 2480)
end
UpdateUIPanelPositions()
assert(SocialUIFrame:GetLeft() == 1840 and SocialUIFrame:GetTop() == 1150,
    "Collections close layout did not restore the live SocialUIFrame root")
nativeUIPanelLayout = nil
SocialUIFrame:ClearAllPoints()
SocialUIFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 20, 2480)
assert(SocialUIFrame:GetLeft() == 1840 and SocialUIFrame:GetTop() == 1150,
    "SocialUIFrame was not restored synchronously before the next render")
flushTimers()
assert(SocialUIFrame:GetLeft() == 1840 and SocialUIFrame:GetTop() == 1150,
    "a late direct SocialUIFrame anchor reset was not restored on the next frame")

-- Collections closing recalculates the whole panel stack. The same completed
-- layout transaction must preserve Social on Mainhand and a saved World Map on
-- Offhand, without relying solely on the ShowUIPanel path.
local closeCollectionsFrame = makeMockFrame("CollectionsJournal", 700, 800)
local closeMapFrame = makeMockFrame("WorldMapFrame", 900, 760)
WorldMapFrame = closeMapFrame
addon.db.savedWorkspacePositions.WorldMapFrame = {
    x = 120, y = 2380, canvasLeft = 0, canvasBottom = 0,
    canvasWidth = metrics.workspaceWidth, canvasHeight = metrics.workspaceHeight,
}
addon.Canvas:RestoreWorkspacePosition(closeMapFrame)
local closeMapLeft, closeMapTop = closeMapFrame:GetLeft(), closeMapFrame:GetTop()
nativeUIPanelLayout = function()
    SocialUIFrame:ClearAllPoints()
    SocialUIFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 20, 2480)
    closeMapFrame:ClearAllPoints()
    closeMapFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 20, 2050)
end
HideUIPanel(closeCollectionsFrame)
assert(SocialUIFrame:GetLeft() == 1840 and SocialUIFrame:GetTop() == 1150,
    "closing Collections did not preserve SocialUIFrame on Mainhand")
assert(closeMapFrame:GetLeft() == closeMapLeft and closeMapFrame:GetTop() == closeMapTop,
    "closing Collections did not restore the saved Offhand World Map")

-- Forever's panel manager can queue a timer which queues another anchor write
-- after the immediate and first delayed repairs have both completed. Reproduce
-- that second-generation layout and require the bounded map settlement to
-- outlast it without relying on a permanent ticker.
nativeUIPanelLayout = function()
    C_Timer.After(0, function()
        C_Timer.After(0, function()
            closeMapFrame:ClearAllPoints()
            closeMapFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 20, 2050)
        end)
    end)
end
HideUIPanel(closeCollectionsFrame)
flushTimers()
flushTimers()
assert(closeMapFrame:GetLeft() == closeMapLeft and closeMapFrame:GetTop() == closeMapTop,
    "a nested late UIPanel layout escaped the bounded Offhand World Map settlement")
nativeUIPanelLayout = nil
addon.db.savedWorkspacePositions.WorldMapFrame = nil
SocialUIFrame:Hide()
FriendsFrame:Show()
UIPanelWindows.FriendsFrame = { area = "left", pushable = 1 }
addon.db.savedMainPositions.FriendsFrame = { point="TOPLEFT", x=1860, y=1160 }

local collectionsFrame = makeMockFrame("CollectionsFrame", 700, 800)
UIPanelWindows.CollectionsFrame = { area = "left", pushable = 0 }
addon.db.savedMainPositions.CollectionsFrame = { x = 9000, y = -500 }
addon.Canvas.RestoreWorkspacePosition(collectionsFrame)
assert(collectionsFrame:GetLeft() >= metrics.gameLeft + 12
        and collectionsFrame:GetRight() <= metrics.gameRight - 12
        and collectionsFrame:GetTop() <= metrics.gameTop - 12
        and collectionsFrame:GetBottom() >= metrics.gameBottom + 12,
    "stale Mainhand panel coordinates must be clamped back onto the visible game monitor")
print("PASS: dynamic Blizzard panels default to Mainhand and persist explicit monitor placements")

-- A panel whose Blizzard addon loads after login did not exist during the
-- initial persistence pass. RegisterUIPanel must reopen ordinary safe panels
-- when Offhand has an explicit saved/open workspace record.
local lateCollectionsFrame = makeMockFrame("CollectionsJournalFrame", 700, 800)
lateCollectionsFrame:Hide()
addon.db.savedWorkspacePositions.CollectionsJournalFrame = {
    x = 180, y = 1500, canvasLeft = 0, canvasBottom = 0,
    canvasWidth = metrics.workspaceWidth, canvasHeight = metrics.workspaceHeight,
}
addon.db.openWorkspacePanels = addon.db.openWorkspacePanels or {}
addon.db.openWorkspacePanels.CollectionsJournalFrame = true
RegisterUIPanel(lateCollectionsFrame)
flushTimers()
assert(not lateCollectionsFrame:IsShown(),
    "a late panel registration must not re-enter ShowUIPanel in Blizzard's opening turn")
flushTimers()
assert(lateCollectionsFrame:IsShown() and addon.Canvas.IsFrameOnWorkspace(lateCollectionsFrame),
    "a persisted safe panel must reopen after its load-on-demand addon settles")
assert(addon.db.openWorkspacePanels.CollectionsJournalFrame
        and addon.db.savedWorkspacePositions.CollectionsJournalFrame,
    "safe delayed panel restore must preserve open state and workspace position")

-- The crash report path: RegisterUIPanel runs inside the same hardware action
-- that will show the panel natively. If Blizzard shows it before Offhand's
-- settlement timer, the queued restore must not call ShowUIPanel a second time.
local nativeOpenedCollections = makeMockFrame("NativeOpenedCollectionsFrame", 700, 800)
nativeOpenedCollections:Hide()
local nativeShow = nativeOpenedCollections.Show
nativeOpenedCollections.Show = function(self)
    self.showCalls = (self.showCalls or 0) + 1
    nativeShow(self)
end
addon.db.savedWorkspacePositions.NativeOpenedCollectionsFrame = {
    x = 240, y = 1420, canvasLeft = 0, canvasBottom = 0,
    canvasWidth = metrics.workspaceWidth, canvasHeight = metrics.workspaceHeight,
}
addon.db.openWorkspacePanels.NativeOpenedCollectionsFrame = true
RegisterUIPanel(nativeOpenedCollections)
nativeOpenedCollections:Show()
flushTimers()
flushTimers()
assert(nativeOpenedCollections.showCalls == 1,
    "Offhand must not show a panel again when Blizzard's native action already opened it")
assert(addon.Canvas.IsFrameOnWorkspace(nativeOpenedCollections),
    "a natively opened late panel must still restore its workspace position")

local noReloadCollections = makeMockFrame("NoReloadCollectionsFrame", 700, 800)
noReloadCollections:Hide()
addon.db.savedWorkspacePositions.NoReloadCollectionsFrame = {
    x = 220, y = 1450, canvasLeft = 0, canvasBottom = 0,
    canvasWidth = metrics.workspaceWidth, canvasHeight = metrics.workspaceHeight,
}
addon.db.openWorkspacePanels.NoReloadCollectionsFrame = true
addon.db.restoreWorkspaceOnReload = false
RegisterUIPanel(noReloadCollections)
flushTimers()
flushTimers()
assert(not noReloadCollections:IsShown(),
    "late panel restoration must respect the reload-persistence checkbox")
assert(addon.db.savedWorkspacePositions.NoReloadCollectionsFrame,
    "disabling reload restoration must not discard the panel's workspace position")
addon.db.restoreWorkspaceOnReload = true
print("PASS: late safe-panel restore settles without re-entering Blizzard's loader")

-- Rejected legacy snapshots must not consume restore timing slots. A polluted
-- profile previously delayed a valid panel by 0.2 seconds per stale name,
-- producing an approximately eight-second login delay in real profiles.
local promptRestorePanel = makeMockFrame("ZPromptRestorePanel", 700, 800)
promptRestorePanel:Hide()
RegisterUIPanel(promptRestorePanel)
addon.db.savedWorkspacePositions.ZPromptRestorePanel = { x = 190, y = 1500 }
addon.db.openWorkspacePanels.ZPromptRestorePanel = true
for i = 1, 40 do
    local staleName = string.format("AStaleAddonChild%02d", i)
    addon.db.savedWorkspacePositions[staleName] = { x = 10, y = 10 }
    addon.db.openWorkspacePanels[staleName] = true
end
local promptRestoreDelay
local originalQueuePersistentPanelRestore = addon.Canvas.QueuePersistentPanelRestore
addon.Canvas.QueuePersistentPanelRestore = function(self, frame, name, delay)
    if name == "ZPromptRestorePanel" then promptRestoreDelay = delay end
    return originalQueuePersistentPanelRestore(self, frame, name, delay)
end
addon.Canvas:RestorePersistentFrames()
addon.Canvas.QueuePersistentPanelRestore = originalQueuePersistentPanelRestore
assert(promptRestoreDelay and promptRestoreDelay < 3,
    "rejected stale snapshots must not add the former eight-second delay")
addon.db.savedWorkspacePositions.ZPromptRestorePanel = nil
addon.db.openWorkspacePanels.ZPromptRestorePanel = nil
for i = 1, 40 do
    local staleName = string.format("AStaleAddonChild%02d", i)
    addon.db.savedWorkspacePositions[staleName] = nil
    addon.db.openWorkspacePanels[staleName] = nil
end
print("PASS: stale snapshots do not delay valid persistent panels")

-- Spellbook, Macros, Collections, and similar panels do not exist at the first
-- reload restoration pass. Offhand must load only the Blizzard addon belonging
-- to an explicitly saved/open workspace panel, then use the normal delayed
-- panel restoration path after registration has settled.
local loadedBlizzardAddons, requestedBlizzardAddons = {}, {}
C_AddOns = {
    IsAddOnLoaded = function(name) return loadedBlizzardAddons[name] == true end,
    LoadAddOn = function(name)
        requestedBlizzardAddons[name] = (requestedBlizzardAddons[name] or 0) + 1
        loadedBlizzardAddons[name] = true
        if name == "Blizzard_MacroUI" then
            MacroFrame = makeMockFrame("MacroFrame", 700, 800)
            MacroFrame:Hide()
            RegisterUIPanel(MacroFrame)
        elseif name == "Blizzard_Professions" then
            ProfessionsFrame = makeMockFrame("ProfessionsFrame", 700, 800)
            ProfessionsFrame:Hide()
            RegisterUIPanel(ProfessionsFrame)
        end
        return true
    end,
}
addon.db.savedWorkspacePositions.MacroFrame = {
    x = 210, y = 1510, canvasLeft = 0, canvasBottom = 0,
    canvasWidth = metrics.workspaceWidth, canvasHeight = metrics.workspaceHeight,
}
addon.db.openWorkspacePanels.MacroFrame = true
addon.Canvas:RestorePersistentFrames()
flushTimers()
flushTimers()
flushTimers()
assert(requestedBlizzardAddons.Blizzard_MacroUI == 1,
    "reload restoration must request the saved MacroFrame's Blizzard addon exactly once")
assert(MacroFrame and MacroFrame:IsShown() and addon.Canvas.IsFrameOnWorkspace(MacroFrame),
    "a saved/open MacroFrame must reopen on the workspace after its addon loads")

-- New Blizzard modules are learned from UIPanels registered during their
-- ADDON_LOADED turn, providing forward compatibility beyond the seed table.
local futurePanel = makeMockFrame("FutureJournalFrame", 700, 800)
RegisterUIPanel(futurePanel)
addon.Canvas:RecordLoadedPanelAddon("Blizzard_FutureJournal")
assert(addon.db.workspacePanelLoadAddons.FutureJournalFrame == "Blizzard_FutureJournal",
    "new load-on-demand Blizzard UIPanels must remember their owning addon")

addon.db.savedWorkspacePositions.ClassTrainerFrame = { x = 200, y = 1500 }
addon.db.openWorkspacePanels.ClassTrainerFrame = true
addon.db.workspacePanelLoadAddons.ClassTrainerFrame = "Blizzard_TrainerUI"
addon.Canvas:RestorePersistentFrames()
flushTimers()
assert(not requestedBlizzardAddons.Blizzard_TrainerUI,
    "NPC/context-bound panels must retain their position without reopening after reload")

-- The standalone Professions book may reload only after an explicit Offhand
-- drag created both a workspace position and an open-state record.
experimentalProfessionsMovement = true
addon.db.savedWorkspacePositions.ProfessionsFrame = { x = 200, y = 1500 }
addon.db.openWorkspacePanels.ProfessionsFrame = true
addon.db.workspacePanelLoadAddons.ProfessionsFrame = "Blizzard_Professions"
addon.Canvas:RestorePersistentFrames()
flushTimers()
flushTimers()
flushTimers()
flushTimers()
flushTimers()
flushTimers()
assert(requestedBlizzardAddons.Blizzard_Professions == 1,
    "reload restoration must load an explicitly saved/open Professions book exactly once")
assert(ProfessionsFrame and ProfessionsFrame:IsShown(),
    "the current ProfessionsFrame root must reopen after reload")
assert(addon.Canvas.IsFrameOnWorkspace(ProfessionsFrame),
    "the reopened ProfessionsFrame root must use its saved Offhand position")
addon.db.savedWorkspacePositions.ProfessionsFrame = nil
addon.db.openWorkspacePanels.ProfessionsFrame = nil
addon.db.savedWorkspacePositions.TradeSkillFrame = { x = 220, y = 1480 }
addon.db.openWorkspacePanels.TradeSkillFrame = true
addon.db.workspacePanelLoadAddons.TradeSkillFrame = "Blizzard_Professions"
addon.Canvas:RestorePersistentFrames()
flushTimers()
assert(requestedBlizzardAddons.Blizzard_Professions == 1,
    "context-bound Professions windows must not be loaded or reopened after reload")
addon.db.savedWorkspacePositions.TradeSkillFrame = nil
addon.db.openWorkspacePanels.TradeSkillFrame = nil
experimentalProfessionsMovement = false
print("PASS: saved load-on-demand panels restore the explicit Professions book only")

-- FlightMapFrame is context-bound and must never auto-open after reload, but
-- each native flight-master interaction must settle it on Mainhand or at the
-- user's explicit saved position instead of Blizzard's full-canvas center.
local flightMap = makeMockFrame("FlightMapFrame", 1004, 689)
flightMap:Hide()
RegisterUIPanel(flightMap)
flushTimers()
flightMap:ClearAllPoints()
flightMap:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
flightMap:Show()
flushTimers()
assert(flightMap:GetLeft() >= metrics.gameLeft
        and flightMap:GetRight() <= metrics.gameRight
        and flightMap:GetTop() <= metrics.gameTop,
    "a first native Flight Map opening must settle fully inside Mainhand")
flightMap:ClearAllPoints()
flightMap:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 180, 1500)
addon.Canvas.OnPanelDragStop(flightMap)
assert(addon.db.savedWorkspacePositions.FlightMapFrame,
    "dragging the Flight Map must save an explicit workspace position")
flightMap:Hide()
flightMap:ClearAllPoints()
flightMap:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
flightMap:Show()
flushTimers()
assert(addon.Canvas.IsFrameOnWorkspace(flightMap),
    "every later Flight Map interaction must restore the saved position")
flightMap:Hide()
print("PASS: context-bound Flight Map settles per interaction without reload opening")

-- Moving an NPC-bound panel must not detach it from Blizzard's active UIPanel
-- transaction. AuctionHouseFrame in particular stops reopening after a
-- HideUIPanel + direct Show cycle even though the auctioneer bell still plays.
local auctionHouse = makeMockFrame("AuctionHouseFrame", 1000, 700)
auctionHouse.TitleContainer = makeMockFrame("AuctionHouseFrameTitleContainer", 900, 24)
auctionHouse:Hide()
RegisterUIPanel(auctionHouse)
flushTimers()
local activeContextPanel = auctionHouse
local contextPanelHideCalls = 0
GetUIPanel = function(area)
    if area == "left" then return activeContextPanel end
end
HideUIPanel = function(frame)
    contextPanelHideCalls = contextPanelHideCalls + 1
    if activeContextPanel == frame then activeContextPanel = nil end
    frame:Hide()
end
auctionHouse:Show()
auctionHouse:ClearAllPoints()
auctionHouse:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 160, 1500)
addon.Canvas.OnPanelDragStop(auctionHouse)
assert(contextPanelHideCalls == 0 and activeContextPanel == auctionHouse
        and auctionHouse:IsShown(),
    "moving Auction House to Offhand must preserve Blizzard's active NPC panel transaction")
auctionHouse:Hide()
activeContextPanel = nil
auctionHouse:ClearAllPoints()
auctionHouse:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
activeContextPanel = auctionHouse
auctionHouse:Show()
flushTimers()
assert(addon.Canvas.IsFrameOnWorkspace(auctionHouse),
    "a later native Auction House opening must restore its saved Offhand position")
auctionHouse:Hide()
activeContextPanel = nil
GetUIPanel = nil
HideUIPanel = nil
print("PASS: context-bound Auction House keeps its native reopen lifecycle")

-- Forever Professions is fully Blizzard-owned after repeatable client crashes.
-- Registration must not attach drag/show/position behavior, and historical
-- persistence records must be discarded without touching the live frame.
local professionsFrame = makeMockFrame("ProfessionsFrame", 700, 800)
professionsFrame:Hide()
UIPanelWindows.ProfessionsFrame = { area = "left", pushable = 0 }
addon.db.savedWorkspacePositions.ProfessionsFrame = { x = 180, y = 1500 }
addon.db.savedMainPositions.ProfessionsFrame = { x = 1700, y = 1200 }
addon.db.openWorkspacePanels.ProfessionsFrame = true
RegisterUIPanel(professionsFrame)
flushTimers()
flushTimers()
assert(not professionsFrame._OffhandMovable and not professionsFrame:IsShown(),
    "Offhand must not make Forever Professions movable or show it")
assert(not addon.db.savedWorkspacePositions.ProfessionsFrame
        and not addon.db.savedMainPositions.ProfessionsFrame
        and not addon.db.openWorkspacePanels.ProfessionsFrame,
    "historical Forever Professions ownership records must be removed")
assert(addon.Canvas.IsForeverProfessionsPanel(professionsFrame),
    "Forever Professions roots must be recognized as Blizzard-owned")
print("PASS: Forever Professions remains entirely under Blizzard ownership")

-- Professions remains isolated from automatic first-open behavior, while an
-- explicitly moved Offhand instance gains reload and Escape-slot persistence.
experimentalProfessionsMovement = true
local optedInProfessions = makeMockFrame("ProfessionsBookFrame", 700, 800)
optedInProfessions:Hide()
RegisterUIPanel(optedInProfessions)
optedInProfessions:Show()
flushTimers()
assert(optedInProfessions._OffhandExperimentalProfessionsAttached
        and optedInProfessions._OffhandExperimentalProfessionsGrip,
    "opted-in Professions must receive its isolated Blizzard-template title grip after native opening")
assert(optedInProfessions._OffhandExperimentalProfessionsGrip.template == "PanelDragBarTemplate"
        and optedInProfessions._OffhandExperimentalProfessionsMotionStatus == "active",
    "experimental Professions movement must use the guarded Blizzard title template")
assert(not optedInProfessions.mouse,
    "the title grip must not enable mouse input across the Professions panel body")
local professionsMotionDiag = addon.Canvas:GetExperimentalProfessionsMotionDiagnostics()
assert(professionsMotionDiag:find("Enabled=1", 1, true)
        and professionsMotionDiag:find("ProfessionsBookFrame:active/protected=0", 1, true),
    "panel motion diagnostics must expose the active policy without changing the frame")
assert(not optedInProfessions._OffhandMovable,
    "experimental Professions must not enter the generic panel lifecycle")
assert(not (addon.db.openWorkspacePanels
        and addon.db.openWorkspacePanels.ProfessionsBookFrame),
    "experimental Professions must not acquire automatic-open state")
local initialProfessionsPoint = optedInProfessions.points[#optedInProfessions.points]
assert(initialProfessionsPoint and initialProfessionsPoint[1] == "TOPLEFT"
        and initialProfessionsPoint[4] == 2370
        and initialProfessionsPoint[5] == 1126,
    "first opted-in Professions opening must center the reachable title on Mainhand")
assert(not addon.db.savedWorkspacePositions.ProfessionsBookFrame
        and not addon.db.savedMainPositions.ProfessionsBookFrame,
    "automatic first-open centering must not create persistence ownership")

-- A Professions root can become visible and restore its saved Offhand anchor
-- while native Gamepad still owns its control tree. The guarded attachment is
-- correctly refused then, but returning to keyboard UI must retry the missing
-- grip without requiring the user to close or reopen the panel.
local retryProfessions = makeMockFrame("ProfessionsRetryFrame", 700, 800)
_G.ProfessionsRetryFrame = retryProfessions
retryProfessions:Hide()
UIPanelWindows.ProfessionsRetryFrame = { area = "left", pushable = 0 }
nativeGamepad = true
retryProfessions:Show()
addon.Canvas:QueueExperimentalForeverProfessionsMovement(retryProfessions,
    "ProfessionsRetryFrame")
flushTimers()
assert(not retryProfessions._OffhandExperimentalProfessionsAttached,
    "native Gamepad must defer the Professions title grip")
nativeGamepad = false
addon.Canvas:EnableExperimentalForeverProfessionsMovement()
flushTimers()
assert(retryProfessions._OffhandExperimentalProfessionsAttached
        and retryProfessions._OffhandExperimentalProfessionsMotionStatus == "active",
    "keyboard UI settlement must retry a missing grip on a visible Professions panel")
retryProfessions:Hide()

optedInProfessions:ClearAllPoints()
optedInProfessions:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 180, 1500)
local professionsGrip = optedInProfessions._OffhandExperimentalProfessionsGrip
professionsGrip.scripts.OnDragStart(professionsGrip)
professionsGrip.scripts.OnDragStop(professionsGrip)
assert(optedInProfessions.startMovingCalls == 1 and optedInProfessions.stopMovingCalls >= 1,
    "the Blizzard title template must initiate movement before Offhand persists the completed drag")
assert(addon.db.savedWorkspacePositions.ProfessionsBookFrame,
    "experimental Professions dragging must save an explicit workspace position")
assert(addon.db.openWorkspacePanels.ProfessionsBookFrame,
    "saving an experimental Professions position on Offhand must enable reload persistence")

local activeLeftPanel = optedInProfessions
local professionsPanelEvictions = 0
GetUIPanel = function(area)
    if area == "left" then return activeLeftPanel end
end
HideUIPanel = function(frame)
    professionsPanelEvictions = professionsPanelEvictions + 1
    if activeLeftPanel == frame then activeLeftPanel = nil end
    frame:Hide()
end

-- Timer and watcher settlement must not fight Blizzard's active drag. This
-- reproduces the visible half-second snapback that made Professions jerky.
professionsGrip.scripts.OnDragStart(professionsGrip)
optedInProfessions:ClearAllPoints()
optedInProfessions:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 420, 1420)
flushTimers()
flushTimers()
local activeDragPoint = optedInProfessions.points[#optedInProfessions.points]
assert(activeDragPoint and activeDragPoint[4] == 420 and activeDragPoint[5] == 1420
        and activeLeftPanel == optedInProfessions and professionsPanelEvictions == 0,
    "Professions settlement timers and watcher must not restore or evict during an active drag")
professionsGrip.scripts.OnDragStop(professionsGrip)
flushTimers()
assert(activeLeftPanel == optedInProfessions and professionsPanelEvictions == 0
        and optedInProfessions:IsShown(),
    "a completed Offhand Professions drag must not cycle the native UIPanel slot")
flushTimers()
assert(professionsPanelEvictions == 0 and optedInProfessions:IsShown(),
    "Professions watcher settlement must not attempt native slot eviction")

optedInProfessions:ClearAllPoints()
optedInProfessions:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 2100, 1100)
optedInProfessions:Hide()
activeLeftPanel = optedInProfessions
optedInProfessions:Show()
assert(addon.Canvas.IsFrameOnWorkspace(optedInProfessions),
    "a later manual Professions opening must restore its saved position immediately without waiting for timers")
assert(activeLeftPanel == optedInProfessions and professionsPanelEvictions == 0
        and optedInProfessions:IsShown(),
    "a reopened Offhand Professions panel must leave native slot ownership untouched")
-- Simulate Blizzard's native UpdateUIPanelPositions attempting to re-anchor to spanned TOPLEFT
optedInProfessions:ClearAllPoints()
optedInProfessions:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
assert(addon.Canvas.IsFrameOnWorkspace(optedInProfessions),
    "Blizzard UIPanel anchor resets on Professions must be caught synchronously without jumping to top-left")
flushTimers()
assert(addon.Canvas.IsFrameOnWorkspace(optedInProfessions)
        and professionsPanelEvictions == 0,
    "a later manual Professions opening must restore its saved position after settling")

-- Forever closes active UIPanels through HideUIPanel immediately before the
-- same Escape transaction toggles its Game Menu. Reopen only that paired hide;
-- an explicit X/close with no ToggleGameMenu must remain closed.
activeLeftPanel = optedInProfessions
HideUIPanel(optedInProfessions)
addon.Canvas:ObserveForeverProfessionsPanelHide(optedInProfessions)
ToggleGameMenu()
flushTimers()
assert(optedInProfessions:IsShown()
        and addon.Canvas.IsFrameOnWorkspace(optedInProfessions)
        and addon.db.openWorkspacePanels.ProfessionsBookFrame,
    "Escape must restore an explicitly open Offhand Professions book and its saved anchor")

HideUIPanel(optedInProfessions)
addon.Canvas:ObserveForeverProfessionsPanelHide(optedInProfessions)
flushTimers()
assert(not optedInProfessions:IsShown()
        and addon.Canvas._foreverProfessionsEscapePending == nil
        and not addon.db.openWorkspacePanels.ProfessionsBookFrame,
    "an unpaired native Professions close must remain closed instead of auto-reopening")

experimentalProfessionsMovement = false
addon.Canvas:DisableExperimentalForeverProfessionsMovement()
assert(not addon.db.savedWorkspacePositions.ProfessionsBookFrame,
    "disabling experimental Professions movement must clear its saved position")
assert(not optedInProfessions._OffhandExperimentalProfessionsGrip:IsShown()
        and not optedInProfessions._OffhandExperimentalProfessionsGrip.mouse
        and not optedInProfessions._OffhandExperimentalProfessionsGrip.stateDrivers.visibility,
    "disabling experimental Professions movement must deactivate its drag surface")
print("PASS: experimental Forever Professions movement is isolated and reversible")

-- Horizontal layouts also need explicit coverage when the workspace is to the
-- right of Mainhand. Emulate the live client behavior where clearing
-- userPlaced synchronously restores the frame to Mainhand center.
for key in pairs(metrics) do metrics[key] = nil end
metrics.isSpanned = true
metrics.screenWidth, metrics.screenHeight = 4000, 1440
metrics.physicalWidth, metrics.physicalHeight = 4000, 1440
metrics.gameLeft, metrics.gameBottom, metrics.gameRight, metrics.gameTop = 0, 0, 2560, 1440
metrics.gameWidth, metrics.gameHeight = 2560, 1440
metrics.workspaceLeft, metrics.workspaceBottom = 2560, 0
metrics.workspaceRight, metrics.workspaceTop = 4000, 1440
metrics.workspaceWidth, metrics.workspaceHeight = 1440, 1440

local rightWorkspaceFrame = makeMockFrame("RightWorkspaceFrame", 500, 400)
rightWorkspaceFrame.SetUserPlaced = function(self, value)
    self.setUserPlacedFalseCalls = (self.setUserPlacedFalseCalls or 0) + (value == false and 1 or 0)
    if value == false then
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 1280, 720)
    end
end
rightWorkspaceFrame:ClearAllPoints()
rightWorkspaceFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 2850, 1100)
addon.Canvas.OnPanelDragStop(rightWorkspaceFrame)
local rightSaved = addon.db.savedWorkspacePositions.RightWorkspaceFrame
assert(rightSaved and rightSaved.canvasLeft == 2560,
    "Forever must save right-workspace drag coordinates against the workspace rectangle")
assert((rightWorkspaceFrame.setUserPlacedFalseCalls or 0) == 0
        and addon.Canvas.IsFrameOnWorkspace(rightWorkspaceFrame),
    "a Forever panel dropped on the right workspace must not snap back to Mainhand")
rightWorkspaceFrame:ClearAllPoints()
rightWorkspaceFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 1280, 720)
addon.Canvas.RestoreWorkspacePosition(rightWorkspaceFrame)
assert(addon.Canvas.IsFrameOnWorkspace(rightWorkspaceFrame),
    "Forever reload restoration must return a saved frame to the right workspace")

for key in pairs(metrics) do metrics[key] = nil end
for key, value in pairs(originalMetrics) do metrics[key] = value end
print("PASS: Forever horizontal left/right workspace drops survive native userPlaced resets")

-- Forever Cooldown Viewer systems are Blizzard Edit Mode-managed even though
-- they are not protected frames. The generic rescue scanner must never move,
-- hook or make them movable; doing so taints aura tables used by Blizzard.
local cooldownViewer = makeMockFrame("EssentialCooldownViewer", 420, 90)
cooldownViewer.isManagedFrame = true
cooldownViewer.Selection = {}
cooldownViewer.system = 20
cooldownViewer:ClearAllPoints()
cooldownViewer:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 2100, -40)
table.insert(UIParent.children, cooldownViewer)
local cooldownPointCount = #cooldownViewer.points
addon.Canvas:TryMakeFrameDraggable(cooldownViewer)
flushTimers()
assert(not cooldownViewer._OffhandMovable and not cooldownViewer.movable,
    "Forever must not make Cooldown Viewer systems movable")
assert(#cooldownViewer.points == cooldownPointCount
        and cooldownViewer.points[#cooldownViewer.points][1] == "TOPLEFT",
    "Forever void rescue must not reanchor Cooldown Viewer systems")
assert(next(cooldownViewer.scripts) == nil,
    "Forever must not attach scripts to Cooldown Viewer systems")
print("PASS: Forever leaves Blizzard Cooldown Viewer systems entirely native")

-- ============================================================================
-- TEST 8: Game View Monitor Drag Clamping
-- ============================================================================
-- If user drags ExampleAddonWindow on the main game monitor, it must never exceed gameTop - height
ExampleAddonWindow:ClearAllPoints()
ExampleAddonWindow:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2000, 2000) -- Attempt to place in void
addon.Canvas.OnPanelDragStop(ExampleAddonWindow)

local clampedTop = ExampleAddonWindow:GetTop()
assert(clampedTop <= metrics.gameTop, string.format("Clamped frame top (%s) must never exceed gameTop (%s)", tostring(clampedTop), tostring(metrics.gameTop)))
print(string.format("PASS: Game View drag clamping enforces top <= gameTop (%s <= %s)", tostring(clampedTop), tostring(metrics.gameTop)))

-- ============================================================================
-- TEST 9: Blizzard EditModeUtil remains untouched
-- ============================================================================
StanceBar = makeMockFrame("StanceBar", 120, 30)
StanceBar.IsInDefaultPosition = function() return true end
StanceBar.IsInitialized = function() return true end
StanceBar:ClearAllPoints() -- GetPoint(1) returns nil (as occurs during stance transitions)

local nativeBottomHeight = function() return 37 end
EditModeUtil = { GetBottomActionBarHeight = nativeBottomHeight }
addon.HUD:HookFrames()

local ok, height = pcall(function() return EditModeUtil:GetBottomActionBarHeight() end)
assert(ok and height == 37, "Blizzard EditModeUtil behavior must remain intact")
assert(EditModeUtil.GetBottomActionBarHeight == nativeBottomHeight,
    "Offhand must not replace EditModeUtil:GetBottomActionBarHeight")
print("PASS: Blizzard EditModeUtil remains untouched")

-- ============================================================================
-- TEST 10: Bad-self intrinsic widgets in UIParent:GetChildren()
-- ============================================================================
local badSelfWidget = {
    GetName = function(self) error("calling '?' on bad self (Usage: local name = self:GetName())") end,
    IsShown = function(self) return true end,
    IsForbidden = function(self) return false end,
    IsProtected = function(self) return false end,
}
table.insert(UIParent.children, badSelfWidget)

-- Flush timers which invokes RedirectExternalPopups() over UIParent.children
flushTimers()
print("PASS: Bad self intrinsic widgets in UIParent:GetChildren() safely handled without error")

-- ============================================================================
-- TEST 11: Retail Edit Mode and Action Bar Isolation
-- ============================================================================
addon.isRetail = true
addon.isForever = false

local retailActionBar = makeMockFrame("MainActionBar", 500, 45)
retailActionBar.IsInDefaultPosition = function() return true end
retailActionBar.isManagedFrame = false
local originalRetailSetPoint = retailActionBar.SetPoint
local retailMenuBar = makeMockFrame("MainMenuBar", 500, 45)
local originalRetailMenuBarSetPoint = retailMenuBar.SetPoint
local retailMultiBarBottomLeft = makeMockFrame("MultiBarBottomLeft", 500, 45)
local originalRetailMultiBarSetPoint = retailMultiBarBottomLeft.SetPoint
local retailStatusTrackingBarManager = makeMockFrame("StatusTrackingBarManager", 500, 20)
local originalRetailStatusBarSetPoint = retailStatusTrackingBarManager.SetPoint

_G.MainActionBar = retailActionBar
_G.MainMenuBar = retailMenuBar
_G.MultiBarBottomLeft = retailMultiBarBottomLeft
_G.StatusTrackingBarManager = retailStatusTrackingBarManager

local retailPanelWrites = UIParent.attributeWrites or 0
addon.HUD:HookFrames()
addon.HUD:AlignHUDFrames(metrics)

assert((UIParent.attributeWrites or 0) == retailPanelWrites,
    "Retail must not write legacy UIParent panel-layout attributes")
assert(retailActionBar.SetPoint == originalRetailSetPoint,
    "Retail must not install a SetPoint repair hook on MainActionBar")
assert(#retailActionBar.points == 0,
    "Retail must not directly anchor MainActionBar")
assert(retailMenuBar.SetPoint == originalRetailMenuBarSetPoint,
    "Retail must not install a SetPoint repair hook on MainMenuBar")
assert(#retailMenuBar.points == 0,
    "Retail must not directly anchor MainMenuBar")
assert(retailMultiBarBottomLeft.SetPoint == originalRetailMultiBarSetPoint,
    "Retail must not install a SetPoint repair hook on MultiBarBottomLeft")
assert(#retailMultiBarBottomLeft.points == 0,
    "Retail must not directly anchor MultiBarBottomLeft")
assert(retailStatusTrackingBarManager.SetPoint == originalRetailStatusBarSetPoint,
    "Retail must not install a SetPoint repair hook on StatusTrackingBarManager")
assert(#retailStatusTrackingBarManager.points == 0,
    "Retail must not directly anchor StatusTrackingBarManager")

-- Canvas draggable verification on Retail
addon.Canvas:TryMakeFrameDraggable(retailActionBar)
assert(not retailActionBar._OffhandMovable and not retailActionBar.movable,
    "Retail Edit Mode MainActionBar must never be made draggable by Offhand Canvas")

local retailEditModeManager = makeMockFrame("EditModeManagerFrame", 600, 60)
addon.Canvas:TryMakeFrameDraggable(retailEditModeManager)
assert(not retailEditModeManager._OffhandMovable and not retailEditModeManager.movable,
    "Retail EditModeManagerFrame must never be made draggable by Offhand Canvas")

print("PASS: Retail Edit Mode action bars and managers remain strictly untouched")

print("\nALL PARTY FRAMES, EDIT MODE, AND VOID RESCUE TESTS PASSED!")

local popupScanners = 0
local editModeRecoveryScanners = 0
for _, ticker in ipairs(tickers) do
    if ticker.interval == 2 and not ticker.cancelled then popupScanners = popupScanners + 1 end
    if ticker.interval == 0.25 and not ticker.cancelled then
        editModeRecoveryScanners = editModeRecoveryScanners + 1
    end
end
assert(popupScanners == 1, "Repeated HUD setup installed duplicate popup scanners")
assert(editModeRecoveryScanners == 1,
    "Repeated HUD setup installed duplicate Edit Mode recovery scanners")

-- A full-height seam guide deliberately extends above the game viewport.
local guide = makeMockFrame("OffhandSeamGuideLine", 4, 2560)
table.insert(UIParent.children, guide)
guide:SetPoint("TOPLEFT", UIParent, "TOPLEFT", metrics.deckWidth - 2, 0)
guide:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", metrics.deckWidth - 2, 0)
local guidePoints = #guide.points
for i = 1, 3 do flushTimers() end
assert(#guide.points == guidePoints and guide.points[1][1] == "TOPLEFT",
    "Popup recovery must preserve the seam guide's full-height anchors")

