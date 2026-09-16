-- Test GameMenu Escape behavior, AddonList centering, panel offsets, handles, and map fitting
local addon = {
    modules = {},
    db = {
        enabled = true, seamRedirect = true, independentWorkspacePanels = true,
        savedWorkspacePositions = {
            CharacterFrame = { x = 100, y = 200 },
            WorldMapFrame = { x = 20, y = 300 }
        }
    }
}

UIParent = {
    GetEffectiveScale = function() return 1 end,
    GetWidth = function() return 4000 end,
    GetHeight = function() return 2560 end,
    GetLeft = function() return 0 end,
    GetRight = function() return 4000 end,
    GetTop = function() return 2560 end,
    GetBottom = function() return 0 end,
    GetAttribute = function(self, key)
        if key == "DEFAULT_FRAME_WIDTH" then return 384 end
        if key == "RIGHT_OFFSET_BUFFER" then return 0 end
        return self[key] or 0
    end,
    SetAttribute = function(self, key, val) self[key] = val end,
}

local metrics = {
    gameLeft = 1440, gameRight = 4000, gameBottom = 6, gameTop = 1446,
    gameWidth = 2560, gameHeight = 1440, deckWidth = 1440, hudScale = 1,
    isSpanned = true,
}
addon.Viewport = { GetMetrics = function() return metrics end }
addon.Themes = { ApplyBackdrop = function() end }
addon.Print = function() end
addon.RunOrQueueCombat = function(self, fn) fn() end
InCombatLockdown = function() return false end

local cvars = { miniWorldMap = "0", rawMouseEnable = "0" }
GetCVar = function(name) return cvars[name] or "0" end
SetCVar = function(name, val) cvars[name] = tostring(val) end

local timers = {}
C_Timer = {
    After = function(_, fn) table.insert(timers, fn) end,
}
local function flushTimers()
    local t = timers
    timers = {}
    for _, fn in ipairs(t) do fn() end
end

UISpecialFrames = {}
UIPanelWindows = {
    GameMenuFrame = { area = "center", pushable = 0, whileDead = 1 },
    AddonList = { area = "center", pushable = 0, whileDead = 1 },
    CharacterFrame = { area = "left", pushable = 1 },
}

local panelAttributes = {}
function SetUIPanelAttribute(frame, key, val)
    local name = frame:GetName()
    panelAttributes[name] = panelAttributes[name] or {}
    panelAttributes[name][key] = val
end
function GetUIPanelAttribute(frame, key)
    local name = frame:GetName()
    if panelAttributes[name] and panelAttributes[name][key] ~= nil then
        return panelAttributes[name][key]
    end
    if UIPanelWindows[name] then
        return UIPanelWindows[name][key]
    end
    return nil
end

local delegate = { left = nil, center = nil }
function GetUIPanel(key) return delegate[key] end
function SetUIPanel(key, frame) delegate[key] = frame end

local function makeMockFrame(name, w, h)
    local f = {
        name = name, w = w or 200, h = h or 200,
        shown = false, alpha = 1, points = {}, scripts = {}, scale = 1,
    }
    function f:GetName() return self.name end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:SetHeight(h) self.h = h end
    function f:SetWidth(w) self.w = w end
    function f:GetEffectiveScale() return self.scale end
    function f:GetScale() return self.scale end
    function f:SetScale(s) self.scale = s end
    function f:GetLeft() return self.points[1] and self.points[1][4] or 0 end
    function f:GetBottom() return self.points[1] and self.points[1][5] or 0 end
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
    function f:GetAlpha() return self.alpha end
    function f:ClearAllPoints() self.points = {} end
    function f:SetScrollChild(c) self.scrollChild = c end
    function f:SetVerticalScroll(v) self.verticalScroll = v end
    function f:SetPoint(...) table.insert(self.points, {...}) end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpack(self.points[i] or {}) end
    function f:SetUserPlaced() end
    function f:IsUserPlaced() return false end
    function f:SetClampedToScreen() end
    function f:SetMovable() end
    function f:EnableMouse() end
    function f:RegisterForDrag() end
    function f:GetFrameLevel() return 5 end
    function f:SetFrameLevel() end
    function f:IsMaximized() return false end
    function f:Minimize() end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    function f:HookScript(script, fn)
        local orig = self.scripts[script]
        self.scripts[script] = function(s, ...)
            if orig then orig(s, ...) end
            fn(s, ...)
        end
    end
    _G[name] = f
    return f
end

CreateFrame = function(frameType, name, parent)
    return makeMockFrame(name or "AnonFrame")
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

-- Mock frames
GameMenuFrame = makeMockFrame("GameMenuFrame", 200, 400)
AddonList = makeMockFrame("AddonList", 500, 550)
CharacterFrame = makeMockFrame("CharacterFrame", 384, 512)
WorldMapFrame = makeMockFrame("WorldMapFrame", 610, 438)
WorldMapTitleButton = makeMockFrame("WorldMapTitleButton", 544, 22)
ContainerFrame1 = makeMockFrame("ContainerFrame1", 192, 250)
ContainerFrame2 = makeMockFrame("ContainerFrame2", 192, 250)

-- Mock Blizzard UI methods
function ShowUIPanel(frame)
    if not frame or frame:IsShown() then return end
    local area = GetUIPanelAttribute(frame, "area")
    if not area then
        frame:Show()
        return
    end
    if area == "center" then
        delegate.center = frame
    elseif area == "left" then
        delegate.left = frame
    end
    frame:Show()
end

function HideUIPanel(frame)
    if not frame or not frame:IsShown() then return end
    local area = GetUIPanelAttribute(frame, "area")
    if not area then
        frame:Hide()
        return
    end
    if delegate.left == frame then delegate.left = nil end
    if delegate.center == frame then delegate.center = nil end
    frame:Hide()
end

function CloseSpecialWindows()
    local found = nil
    for _, name in ipairs(UISpecialFrames) do
        local f = _G[name]
        if f and f:IsShown() then
            f:Hide()
            found = 1
        end
    end
    return found
end

function CloseWindows()
    local found = nil
    if delegate.left and delegate.left:IsShown() then
        HideUIPanel(delegate.left)
        found = 1
    end
    if delegate.center and delegate.center:IsShown() then
        HideUIPanel(delegate.center)
        found = 1
    end
    return found or CloseSpecialWindows()
end

function ToggleGameMenu(clicked)
    if not clicked then
        if CloseWindows() then
            return
        end
    end
    if GameMenuFrame:IsShown() then
        HideUIPanel(GameMenuFrame)
    else
        ShowUIPanel(GameMenuFrame)
    end
end

-- Load Offhand files
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(loadfile("Core/SeamRedirect.lua"))("Offhand", addon)

-- Initialize Canvas and SeamRedirect
addon.Canvas:EnableFreeDragging()
addon.SeamRedirect:HookFrames()

-- TEST 1: UIPanelWindows for GameMenuFrame, AddonList and saved workspace panels must be demodalized
assert(UIPanelWindows.GameMenuFrame.area == nil, "GameMenuFrame area must be nil in UIPanelWindows")
assert(UIPanelWindows.AddonList.area == nil, "AddonList area must be nil in UIPanelWindows")
assert(UIPanelWindows.CharacterFrame.area == nil, "CharacterFrame area must be nil because it has a saved workspace position")

local function inSpecial(name)
    for _, n in ipairs(UISpecialFrames) do
        if n == name then return true end
    end
    return false
end
assert(not inSpecial("CharacterFrame"), "CharacterFrame on workspace must NOT be in UISpecialFrames")
assert(inSpecial("AddonList"), "AddonList must be registered in UISpecialFrames")

-- TEST 2: Pressing Escape on clean state opens Game Menu centered on gaming monitor
ToggleGameMenu()
flushTimers()
assert(GameMenuFrame:IsShown(), "GameMenuFrame must be shown after first Escape")
local p = GameMenuFrame.points[#GameMenuFrame.points]
assert(p and p[1] == "CENTER", "GameMenuFrame must be centered")
local expectedCX = (metrics.gameLeft + metrics.gameRight) / 2 - UIParent:GetWidth()/2
assert(math.abs(p[4] - expectedCX) < 0.01, "GameMenuFrame centerX must match primary monitor center")

-- TEST 3: AddonList from Game Menu shows centered on gaming monitor
AddonList:Show()
flushTimers()
assert(AddonList:IsShown(), "AddonList must be shown")
local ap = AddonList.points[#AddonList.points]
assert(ap and ap[1] == "CENTER", "AddonList must be centered")
assert(math.abs(ap[4] - expectedCX) < 0.01, "AddonList centerX must match primary monitor center")
AddonList:Hide()

-- Close GameMenuFrame
ToggleGameMenu()
assert(not GameMenuFrame:IsShown(), "GameMenuFrame must close on Escape")

-- TEST 4: Opening CharacterFrame places it at saved workspace position, bypassing FramePositionDelegate
CharacterFrame.points = {}
CharacterFrame:Show()
assert(CharacterFrame:IsShown(), "CharacterFrame must be shown")
assert(delegate.left == nil, "CharacterFrame must NOT occupy delegate.left")
local cp = CharacterFrame.points[#CharacterFrame.points]
assert(cp[1] == "BOTTOMLEFT" and cp[4] == 100 and cp[5] == 200, "CharacterFrame must restore saved position")

-- Verify elevated drag handle exists for CharacterFrame and panels
assert(CharacterFrame._OffhandHandle ~= nil, "CharacterFrame must have an elevated title drag handle")

-- TEST 5: Pressing Escape while CharacterFrame is on workspace DOES NOT close CharacterFrame
ToggleGameMenu()
flushTimers()
assert(CharacterFrame:IsShown(), "CharacterFrame on workspace must remain open when Escape is pressed!")
assert(GameMenuFrame:IsShown(), "GameMenuFrame must open on gaming monitor without closing workspace panels")

-- TEST 6: Pressing Escape AGAIN closes GameMenuFrame, workspace CharacterFrame remains open
ToggleGameMenu()
assert(not GameMenuFrame:IsShown(), "GameMenuFrame must close on subsequent Escape press")
assert(CharacterFrame:IsShown(), "CharacterFrame must still remain open on workspace!")
CharacterFrame:Hide()

-- TEST 7: Bag opening flicker prevention
ContainerFrame1:Show()
assert(ContainerFrame1:GetAlpha() == 1, "ContainerFrame1 must have alpha 1 after LayoutBags completes")
local bp = ContainerFrame1.points[#ContainerFrame1.points]
assert(bp[1] == "BOTTOMRIGHT", "ContainerFrame1 must be anchored BOTTOMRIGHT")
assert(bp[4] == metrics.gameRight - 16, "ContainerFrame1 x must be anchored to gaming monitor right edge")

-- TEST 8: UIPanel LEFT_OFFSET must be set to m.gameLeft + 16 so panels open on the gaming monitor with padding
assert(UIParent:GetAttribute("LEFT_OFFSET") == metrics.gameLeft + 16, "UIParent LEFT_OFFSET must match gameLeft + 16")

-- TEST 9: WorldMapFrame auto-fit to workspace width & persistence on Escape
WorldMapFrame:Show()
assert(not inSpecial("WorldMapFrame"), "WorldMapFrame on workspace must NOT be in UISpecialFrames")
local mapWidth = WorldMapFrame:GetWidth() * WorldMapFrame:GetScale()
assert(mapWidth <= metrics.deckWidth, "WorldMapFrame scaled width must not exceed workspace width")
assert(mapWidth >= metrics.deckWidth - 25, "WorldMapFrame Auto-Fit must fill workspace width")

-- Pressing Escape while map is on workspace does NOT close map
ToggleGameMenu()
flushTimers()
assert(WorldMapFrame:IsShown(), "WorldMapFrame on workspace must remain open when Escape is pressed!")
ToggleGameMenu() -- close GameMenuFrame

-- TEST 10: Dragging WorldMapFrame out onto the main gaming monitor
WorldMapFrame.points = { { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1800, 500 } }
if WorldMapTitleButton and WorldMapTitleButton.scripts["OnDragStop"] then
    WorldMapTitleButton.scripts["OnDragStop"]()
end
assert(addon.db.savedWorkspacePositions["WorldMapFrame"] == nil, "WorldMapFrame must be cleared from savedWorkspacePositions when on gaming monitor")
assert(WorldMapFrame:GetScale() == 1, "WorldMapFrame scale must reset to 1.0 on gaming monitor")
assert(addon.db.savedMainPositions["WorldMapFrame"] ~= nil, "WorldMapFrame position on gaming monitor must be saved in savedMainPositions")
assert(addon.db.savedMainPositions["WorldMapFrame"].x == 1800, "Saved main x must match 1800")
assert(inSpecial("WorldMapFrame"), "WorldMapFrame on gaming monitor MUST be registered in UISpecialFrames")

-- On gaming monitor, pressing Escape DOES close WorldMapFrame
ToggleGameMenu()
assert(not WorldMapFrame:IsShown(), "WorldMapFrame on gaming monitor must close when Escape is pressed")

-- TEST 11: Reopening WorldMapFrame on gaming monitor
WorldMapFrame.points = {}
WorldMapFrame:Show()
assert(WorldMapFrame:IsShown(), "WorldMapFrame must reopen reliably on gaming monitor")
assert(WorldMapFrame:GetScale() == 1, "WorldMapFrame scale must remain 1.0 on gaming monitor")
local mainPoint = WorldMapFrame.points[#WorldMapFrame.points]
assert(mainPoint and mainPoint[4] == 1800, "WorldMapFrame must restore saved position on gaming monitor")

-- TEST 12: Dragging WorldMapFrame back to secondary workspace
WorldMapFrame.points = { { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 200 } }
if WorldMapTitleButton and WorldMapTitleButton.scripts["OnDragStop"] then
    WorldMapTitleButton.scripts["OnDragStop"]()
end
assert(addon.db.savedWorkspacePositions["WorldMapFrame"] ~= nil, "WorldMapFrame must be saved to workspace positions when dragged to workspace")
assert(addon.db.savedMainPositions["WorldMapFrame"] == nil, "WorldMapFrame main position must be cleared when on workspace")
local deckMapWidth = WorldMapFrame:GetWidth() * WorldMapFrame:GetScale()
assert(deckMapWidth <= metrics.deckWidth, "WorldMapFrame scaled width must not exceed workspace width")
assert(deckMapWidth >= metrics.deckWidth - 25, "WorldMapFrame must scale up to fill workspace width")
assert(not inSpecial("WorldMapFrame"), "WorldMapFrame on workspace must NOT be in UISpecialFrames")

-- Escape on workspace does not close WorldMapFrame
ToggleGameMenu()
flushTimers()
assert(WorldMapFrame:IsShown(), "WorldMapFrame on workspace must remain open through Escape")

print("PASS: escape menu centering, AddonList, gaming monitor panel offsets, universal handles, map fitting, drag out/in reopen, bag flicker, workspace escape persistence")

-- Map wheel scaling is a layout mutation and must not run during combat.
local beforeScale=WorldMapFrame:GetScale()
local beforeWidth=WorldMapFrame:GetWidth()
local beforeHeight=WorldMapFrame:GetHeight()
IsControlKeyDown=function() return true end
InCombatLockdown=function() return true end
WorldMapFrame.scripts.OnMouseWheel(WorldMapFrame,1)
addon.Canvas:ConfigureWorldMap()
assert(WorldMapFrame:GetScale()==beforeScale, "Map changed scale during combat")
InCombatLockdown=function() return false end
WorldMapFrame.scripts.OnMouseWheel(WorldMapFrame,1)
assert(WorldMapFrame:GetScale()>beforeScale, "Ctrl-wheel did not increase map scale")
assert(WorldMapFrame:GetWidth()==beforeWidth and WorldMapFrame:GetHeight()==beforeHeight,
    "Map scaling mutated the native canvas dimensions")
print("PASS: active Canvas map scale, native dimensions and combat guard")
