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
    screenHeight = 2560, screenWidth = 4000,
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
    WorldMapFrame = { area = "left", pushable = 0, maximizePoint = "TOP" },
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
    function f:GetTop() return self:GetBottom()+self:GetHeight() end
    function f:SetSize(w,h) self.w=w; self.h=h end
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
assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasFrameState.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelRegistry.lua"))("Offhand", addon)
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", addon)
assert(loadfile("Core/SeamRedirect.lua"))("Offhand", addon)

-- Initialize Canvas and SeamRedirect
addon.Canvas:EnableFreeDragging()
addon.SeamRedirect:HookFrames()

-- TEST 1: UIPanelWindows for GameMenuFrame, AddonList and saved workspace panels must be demodalized
assert(UIPanelWindows.GameMenuFrame.area == nil, "GameMenuFrame area must be nil in UIPanelWindows")
assert(UIPanelWindows.AddonList.area == nil, "AddonList area must be nil in UIPanelWindows")
assert(UIPanelWindows.CharacterFrame.area == nil, "CharacterFrame area must be nil because it has a saved workspace position")
assert(UIPanelWindows.WorldMapFrame ~= nil
        and UIPanelWindows.WorldMapFrame.area == nil
        and GetUIPanelAttribute(WorldMapFrame, "maximizePoint") == "TOP",
    "World Map demodalization must preserve Blizzard's maximizePoint metadata")

local function inSpecial(name)
    for _, n in ipairs(UISpecialFrames) do
        if n == name then return true end
    end
    return false
end
assert(not inSpecial("CharacterFrame"), "CharacterFrame on workspace must NOT be in UISpecialFrames")
assert(inSpecial("AddonList"), "AddonList must be registered in UISpecialFrames")

-- Retail reload restoration must detach CharacterFrame before its native show
-- begins. Evicting it from the UIPanel slot inside OnShow re-enters Blizzard's
-- PaperDoll collapse/expand lifecycle and can strand CharacterStatsPane outside
-- the expanded frame until the player closes and reopens it.
addon.isRetail = true
addon.db.persistentWorkspacePanels = true
addon.db.restoreWorkspaceOnReload = true
addon.db.openWorkspacePanels = { CharacterFrame = true }
CharacterFrame:Hide()
CharacterFrame.points = {}
UIPanelWindows.CharacterFrame.area = "left"
SetUIPanelAttribute(CharacterFrame, "area", "left")
delegate.left = nil
local characterHideCalls, characterToggleCalls, characterRefreshCalls = 0, 0, 0
local originalHideUIPanel = HideUIPanel
HideUIPanel = function(frame, ...)
    if frame == CharacterFrame then characterHideCalls = characterHideCalls + 1 end
    return originalHideUIPanel(frame, ...)
end
CharacterFrame.RefreshDisplay = function()
    characterRefreshCalls = characterRefreshCalls + 1
end
ToggleCharacter = function(tab, onlyShow)
    characterToggleCalls = characterToggleCalls + 1
    assert(tab == "PaperDollFrame" and onlyShow == true,
        "Retail reload restoration must request the native PaperDoll view without toggling it closed")
    CharacterFrame:Show()
    CharacterFrame:RefreshDisplay()
end
assert(addon.Canvas:QueuePersistentPanelRestore(CharacterFrame, "CharacterFrame", 0),
    "Retail CharacterFrame reload restoration was not queued")
flushTimers()
flushTimers()
assert(CharacterFrame:IsShown() and delegate.left == nil,
    "Retail CharacterFrame must reopen independently at its saved workspace position")
assert(characterToggleCalls == 1 and characterHideCalls == 0,
    "Retail CharacterFrame reload restoration must not hide/show inside its native opening transaction")
assert(characterRefreshCalls >= 2,
    "Retail CharacterFrame must receive Blizzard's native display refresh after PaperDoll expansion settles")
HideUIPanel = originalHideUIPanel
ToggleCharacter = nil
CharacterFrame.RefreshDisplay = nil
CharacterFrame:Hide()
addon.isRetail = nil

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
assert(cp[1] == "TOPLEFT" and cp[4] == 100 and cp[5] == math.max(200, CharacterFrame:GetHeight()+12), "CharacterFrame must restore saved position")

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
print("BP4:", bp[4], "EXPECTED:", metrics.gameRight - 16); assert(bp[4] == metrics.gameRight - 16, "ContainerFrame1 x must be anchored to gaming monitor right edge")

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

-- A persistent map does not receive Blizzard's normal OnShow refocus after a
-- zone transition. Offhand must reproduce that native map-ID/zoom refresh.
WorldMapFrame.mapID = 10
WorldMapFrame.zoomResets = 0
WorldMapFrame.GetMapID = function(self) return self.mapID end
WorldMapFrame.SetMapID = function(self, mapID) self.mapID = mapID end
WorldMapFrame.ResetZoom = function(self) self.zoomResets = self.zoomResets + 1 end
MapUtil = { GetDisplayableMapForPlayer = function() return 20 end }
addon.Canvas:RequestPersistentWorldMapRefocus()
flushTimers()
assert(WorldMapFrame.mapID == 20 and WorldMapFrame.zoomResets == 1,
    "persistent workspace map must refocus to the player's new zone")

local queuedMapRefocus
local previousRunOrQueueCombat = addon.RunOrQueueCombat
addon.RunOrQueueCombat = function(_, fn) queuedMapRefocus = fn end
InCombatLockdown = function() return true end
MapUtil.GetDisplayableMapForPlayer = function() return 25 end
addon.Canvas:RequestPersistentWorldMapRefocus()
flushTimers()
assert(queuedMapRefocus and WorldMapFrame.mapID == 20,
    "zone refocus must defer without touching MapCanvas during combat")
InCombatLockdown = function() return false end
queuedMapRefocus()
assert(WorldMapFrame.mapID == 25 and WorldMapFrame.zoomResets == 2,
    "deferred map refocus must complete after combat")
addon.RunOrQueueCombat = previousRunOrQueueCombat

MapUtil.GetDisplayableMapForPlayer = function() return 30 end
WorldMapFrame:Hide()
addon.Canvas:RequestPersistentWorldMapRefocus()
flushTimers()
assert(WorldMapFrame.mapID == 25,
    "hidden maps must not be opened or refocused by a zone transition")
WorldMapFrame:Show()

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
WorldMapFrame:SetScale(0.75)
beforeScale=0.75
WorldMapFrame.scripts.OnMouseWheel(WorldMapFrame,1)
assert(WorldMapFrame:GetScale()>beforeScale, "Ctrl-wheel did not increase map scale")
assert(WorldMapFrame:GetWidth()==beforeWidth and WorldMapFrame:GetHeight()==beforeHeight,
    "Map scaling mutated the native canvas dimensions")
print("PASS: active Canvas map scale, native dimensions and combat guard")

-- Blizzard's full-screen map must remain maximized. Once the player minimizes
-- it, Offhand may restore the saved windowed scale and clamp stale geometry.
addon.db.savedWorkspacePositions.WorldMapFrame=nil
addon.db.savedMainPositions.WorldMapFrame={x=9000,y=-500}
WorldMapFrame.maximized=false
WorldMapFrame.IsMaximized=function(self) return self.maximized end
WorldMapFrame.Minimize=function(self) self.maximized=false; self:SetSize(702,534) end
WorldMapFrame.Maximize=function(self) self.maximized=true; self:SetSize(4000,2560) end
WorldMapFrame._OffhandWindowedHook=nil
addon.Canvas:ConfigureWorldMap()
local windowedScale = WorldMapFrame:GetScale()
WorldMapFrame:Maximize()
flushTimers()
assert(WorldMapFrame:IsMaximized(), "Offhand immediately collapsed Blizzard's full-screen map")
assert(WorldMapFrame:GetWidth()==4000 and WorldMapFrame:GetHeight()==2560
        and WorldMapFrame:GetScale()==windowedScale,
    "Offhand changed Blizzard's maximized map geometry")
WorldMapFrame:Minimize()
flushTimers()
assert(not WorldMapFrame:IsMaximized(), "Native minimize did not return to the windowed map")
local p=WorldMapFrame.points[1]; local scale=WorldMapFrame:GetScale()
assert(p[4]*scale>=metrics.gameLeft and p[4]*scale+WorldMapFrame:GetWidth()*scale<=metrics.gameRight)
assert(p[5]*scale<=metrics.gameTop and p[5]*scale-WorldMapFrame:GetHeight()*scale>=metrics.gameBottom)
assert(WorldMapFrame:GetWidth()==702 and WorldMapFrame:GetHeight()==534,"Native windowed map size changed")
print("PASS: native maximized map, windowed restore, stale position, full bounding-box fit")

-- MoveAny owns WorldMapFrame on Retail as well as Forever. Offhand must leave
-- its live scale and anchor untouched so the M/L bindings have one map owner.
addon.isRetail = true
MoveAny = {}
local moveAnyFaderRemovals = 0
PlayerMovementFrameFader = {
    RemoveFrame = function(frame)
        assert(frame == WorldMapFrame,
            "MoveAny compatibility removed the wrong movement-fader frame")
        moveAnyFaderRemovals = moveAnyFaderRemovals + 1
    end,
}
assert(addon.Canvas:ShouldYieldWorldMap(WorldMapFrame),
    "Retail must yield WorldMapFrame ownership when MoveAny is loaded")
assert(addon.Canvas:GetCompatibilityDiagnostics()
        == "MoveAny=loaded | WorldMapOwner=MoveAny",
    "Retail diagnostics must identify MoveAny as the live map owner")
WorldMapFrame.scale = 0.68
WorldMapFrame.points = { { "TOPLEFT", UIParent, "BOTTOMLEFT", 1777, 1222 } }
addon.Canvas:ConfigureWorldMap()
addon.Canvas:RestoreWorkspacePosition(WorldMapFrame)
local moveAnyPoint = WorldMapFrame.points[1]
assert(WorldMapFrame.scale == 0.68 and moveAnyPoint
        and moveAnyPoint[4] == 1777 and moveAnyPoint[5] == 1222,
    "Offhand changed MoveAny's Retail World Map geometry")
WorldMapFrame.points = {}
WorldMapFrame:Show()
local moveAnyGetLeft, moveAnyGetTop = WorldMapFrame.GetLeft, WorldMapFrame.GetTop
WorldMapFrame.GetLeft = function(self)
    if #self.points == 0 then return nil end
    return moveAnyGetLeft(self)
end
WorldMapFrame.GetTop = function(self)
    if #self.points == 0 then return nil end
    return moveAnyGetTop(self)
end
addon.db.savedWorkspacePositions.WorldMapFrame = {
    x = 20, y = 300, canvasLeft = 0, canvasBottom = 0,
    canvasWidth = metrics.deckWidth, canvasHeight = metrics.screenHeight,
}
local moveAnyZoomResets = WorldMapFrame.zoomResets
assert(addon.Canvas:RepairYieldedWorldMapAnchor(WorldMapFrame),
    "Offhand did not bootstrap MoveAny's shown but anchorless Retail map")
local repairedMoveAnyPoint = WorldMapFrame.points[1]
assert(repairedMoveAnyPoint and repairedMoveAnyPoint[1] == "TOPLEFT"
        and WorldMapFrame:GetLeft() >= 0 and WorldMapFrame:GetTop() <= metrics.screenHeight,
    "MoveAny's anchorless Retail map was not restored inside a visible monitor")
assert(not addon.Canvas:RepairYieldedWorldMapAnchor(WorldMapFrame),
    "Offhand rewrote an already-positioned MoveAny Retail map")
flushTimers()
assert(WorldMapFrame.zoomResets == moveAnyZoomResets + 1,
    "MoveAny's first anchored MapCanvas did not receive its deferred zoom refresh")
assert(moveAnyFaderRemovals >= 2,
    "persistent MoveAny workspace maps were not removed from the movement fader")

addon.db.openWorkspacePanels = addon.db.openWorkspacePanels or {}
addon.db.openWorkspacePanels.WorldMapFrame = true
WorldMapFrame:Hide()
WorldMapFrame.points = {}
ToggleWorldMap = function()
    if WorldMapFrame:IsShown() then WorldMapFrame:Hide() else WorldMapFrame:Show() end
end
addon.Canvas:RestorePersistentFrames()
flushTimers()
assert(WorldMapFrame:IsShown() and WorldMapFrame:GetLeft() ~= nil,
    "a MoveAny-owned workspace map did not reopen with geometry after reload")
WorldMapFrame.mapID = 30
MapUtil.GetDisplayableMapForPlayer = function() return 40 end
addon.Canvas:RequestPersistentWorldMapRefocus()
flushTimers()
assert(WorldMapFrame.mapID == 40,
    "a MoveAny-owned persistent map did not follow the player's new zone")
WorldMapFrame.GetLeft, WorldMapFrame.GetTop = moveAnyGetLeft, moveAnyGetTop
PlayerMovementFrameFader = nil
MoveAny = nil
assert(not addon.Canvas:ShouldYieldWorldMap(WorldMapFrame),
    "Offhand must resume Retail World Map ownership when MoveAny is absent")

-- ClassicUI Forever supports Retail and owns both WorldMapFrame and
-- CharacterFrame placement. Offhand must dynamically leave their live anchors
-- and saved records untouched while the addon is loaded.
local loadedCompatibilityAddons = { ClassicUIForever = true }
C_AddOns = {
    IsAddOnLoaded = function(name) return loadedCompatibilityAddons[name] == true end,
}
addon.Canvas:EnableFreeDragging()
assert(addon.Canvas:ShouldYieldWorldMap(WorldMapFrame),
    "Retail must yield WorldMapFrame ownership to ClassicUI Forever")
assert(UIPanelWindows.WorldMapFrame.area == "left"
        and UIPanelWindows.CharacterFrame.area == "left"
        and GetUIPanelAttribute(WorldMapFrame, "maximizePoint") == "TOP",
    "ClassicUI Forever ownership must restore Blizzard's complete panel registration")
assert(addon.Canvas:GetCompatibilityDiagnostics()
        == "MoveAny=absent | ClassicUIForever=loaded | WorldMapOwner=ClassicUIForever | CharacterFrameOwner=ClassicUIForever",
    "diagnostics must identify both ClassicUI Forever-owned frames")

WorldMapFrame.points = { { "TOPLEFT", UIParent, "BOTTOMLEFT", 1810, 1180 } }
CharacterFrame.points = { { "TOPLEFT", UIParent, "BOTTOMLEFT", 2050, 1050 } }
local classicMapPosition = addon.db.savedWorkspacePositions.WorldMapFrame
local classicCharacterPosition = addon.db.savedWorkspacePositions.CharacterFrame
addon.Canvas:ConfigureWorldMap()
addon.Canvas:RestoreWorkspacePosition(WorldMapFrame)
addon.Canvas:RestoreWorkspacePosition(CharacterFrame)
addon.Canvas.OnPanelDragStop(WorldMapFrame)
addon.Canvas.OnPanelDragStop(CharacterFrame)
assert(WorldMapFrame.points[1][4] == 1810 and WorldMapFrame.points[1][5] == 1180,
    "Offhand changed ClassicUI Forever's World Map geometry")
assert(CharacterFrame.points[1][4] == 2050 and CharacterFrame.points[1][5] == 1050,
    "Offhand changed ClassicUI Forever's CharacterFrame geometry")
assert(addon.db.savedWorkspacePositions.WorldMapFrame == classicMapPosition
        and addon.db.savedWorkspacePositions.CharacterFrame == classicCharacterPosition,
    "yielding to ClassicUI Forever must preserve dormant Offhand coordinates")

loadedCompatibilityAddons.ClassicUIForever = nil
assert(not addon.Canvas:ShouldYieldWorldMap(WorldMapFrame),
    "Offhand must resume World Map ownership when ClassicUI Forever is disabled")

-- Forever Leatrix Maps 1.60.20 restyles Blizzard's built-in coordinate overlay.
-- A live UIParent scale transition must refresh those three known labels
-- without changing Leatrix's map geometry or unrelated map text.
loadedCompatibilityAddons.Leatrix_Maps = true
assert(addon.Canvas:ShouldYieldWorldMap(WorldMapFrame),
    "Offhand must yield World Map geometry to Leatrix Maps")
assert(addon.Canvas:GetCompatibilityDiagnostics():find(
        "WorldMapOwner=LeatrixMaps", 1, true),
    "compatibility diagnostics must identify Leatrix as the map owner")
local refreshedLabels = 0
local function coordinateRegion(text)
    return {
        GetObjectType = function() return "FontString" end,
        GetText = function() return text end,
        GetFont = function() return "Fonts\\FRIZQT__.TTF", 13, "" end,
        GetFontObject = function() return "GameFontNormalLarge" end,
        SetFont = function(self, file, height, flags)
            assert(file == "Fonts\\FRIZQT__.TTF" and height == 13 and flags == "",
                "coordinate refresh changed the label's font tuple")
            refreshedLabels = refreshedLabels + 1
        end,
        SetFontObject = function(self, object)
            assert(object == "GameFontNormalLarge",
                "coordinate refresh changed the label's font object")
        end,
    }
end
WorldMapFrame.overlayFrames = {{
    PlayerCoords = {Label = coordinateRegion("Player: 49.2, 62.7")},
    CursorCoords = {Label = coordinateRegion("Cursor: 51.0, 44.8")},
    CrosshairCoords = {Label = coordinateRegion("Crosshair: 50.0, 50.0")},
}}
local originalScale, originalPoint = WorldMapFrame.scale, WorldMapFrame.points[1]
assert(addon.Canvas:RefreshLeatrixMapCoordinateFonts() == 3 and refreshedLabels == 3,
    "Leatrix's built-in coordinate labels were not refreshed after a live span")
assert(WorldMapFrame.scale == originalScale and WorldMapFrame.points[1] == originalPoint,
    "Leatrix coordinate refresh changed World Map geometry")
assert(addon.Canvas:GetCompatibilityDiagnostics():find(
        "LeatrixMaps=loaded | CoordinateFontRefresh=3", 1, true),
    "compatibility diagnostics did not report the Leatrix font refresh")

-- Geometry ownership and visibility ownership are deliberately separate.
-- Leatrix keeps its exact anchor/scale while Offhand detaches a workspace map
-- from Escape and the active UIPanel slot, then reopens it after a reload.
local dormantMapPosition = addon.db.savedWorkspacePositions.WorldMapFrame
addon.db.savedWorkspacePositions.WorldMapFrame = nil
addon.db.openWorkspacePanels = addon.db.openWorkspacePanels or {}
WorldMapFrame.points = { { "TOPLEFT", UIParent, "BOTTOMLEFT", 200, 1180 } }
WorldMapFrame.scale = 0.83
WorldMapFrame:Show()
delegate.left = WorldMapFrame
table.insert(UISpecialFrames, "WorldMapFrame")
local leatrixPoint = WorldMapFrame.points[1]
assert(addon.Canvas:PreserveLeatrixWorldMapOpenState(WorldMapFrame),
    "a Leatrix-owned workspace map must retain Offhand open-state handling")
assert(WorldMapFrame.points[1] == leatrixPoint and WorldMapFrame.scale == 0.83,
    "Offhand changed Leatrix-owned map geometry while preserving visibility")
assert(addon.db.openWorkspacePanels.WorldMapFrame and delegate.left == nil
        and not inSpecial("WorldMapFrame"),
    "Leatrix map persistence must detach both Escape and the active panel slot")
addon.Canvas:ConfigureWorldMap()
addon.Canvas:RestoreWorkspacePosition(WorldMapFrame)
addon.Canvas.OnPanelDragStop(WorldMapFrame)
assert(WorldMapFrame.points[1] == leatrixPoint and WorldMapFrame.scale == 0.83,
    "a generic Offhand path rewrote Leatrix-owned map geometry")
WorldMapFrame:Hide()
addon.Canvas:RestorePersistentFrames()
flushTimers()
assert(WorldMapFrame:IsShown() and addon.db.openWorkspacePanels.WorldMapFrame
        and WorldMapFrame.points[1] == leatrixPoint and WorldMapFrame.scale == 0.83,
    "a Leatrix-owned map did not preserve its open state across restoration")
WorldMapFrame.points = { { "TOPLEFT", UIParent, "BOTTOMLEFT", 1900, 1180 } }
addon.Canvas:PreserveLeatrixWorldMapOpenState(WorldMapFrame)
assert(not addon.db.openWorkspacePanels.WorldMapFrame and inSpecial("WorldMapFrame"),
    "moving a Leatrix-owned map to Mainhand must restore native Escape behavior")
addon.db.savedWorkspacePositions.WorldMapFrame = dormantMapPosition
WorldMapFrame.overlayFrames = nil
loadedCompatibilityAddons.Leatrix_Maps = nil
-- OpenMap 0.7.2 has its own drag handle and restores its private saved anchor
-- after SetPoint/SetScale. Offhand must yield with or without Leatrix present.
loadedCompatibilityAddons.OpenMap = true
for _, withLeatrix in ipairs({false, true}) do
    loadedCompatibilityAddons.Leatrix_Maps = withLeatrix or nil
    assert(addon.Canvas:ShouldYieldWorldMap(WorldMapFrame),
        "OpenMap must own World Map geometry")
    assert(addon.Canvas:GetCompatibilityDiagnostics():find("WorldMapOwner=OpenMap", 1, true),
        "diagnostics must expose OpenMap even when Leatrix is also loaded")
    WorldMapFrame.points = {{"TOPLEFT", UIParent, "BOTTOMLEFT", 200, 1180}}
    WorldMapFrame.scale = 0.83
    WorldMapFrame:Show()
    local openMapPoint = WorldMapFrame.points[1]
    assert(addon.Canvas:PreserveExternalWorldMapOpenState(WorldMapFrame))
    addon.Canvas:ConfigureWorldMap()
    addon.Canvas:RestoreWorkspacePosition(WorldMapFrame)
    addon.Canvas.OnPanelDragStop(WorldMapFrame)
    WorldMapFrame:Hide()
    addon.Canvas:RestorePersistentFrames()
    flushTimers()
    assert(WorldMapFrame:IsShown() and addon.db.openWorkspacePanels.WorldMapFrame
        and WorldMapFrame.points[1] == openMapPoint and WorldMapFrame.scale == 0.83,
        "Offhand must preserve open intent without replacing OpenMap geometry")
end
loadedCompatibilityAddons.Leatrix_Maps = nil
loadedCompatibilityAddons.OpenMap = nil
C_AddOns = nil
addon.isRetail = nil
print("PASS: Retail MoveAny and ClassicUI Forever ownership handoff")

-- Forever system Options must be placed directly on Mainhand, and opening it
-- must not consume a tracked workspace backpack.
addon.isForever = true
addon.db.persistentWorkspacePanels = true
addon.db.openWorkspacePanels = addon.db.openWorkspacePanels or {}
local combinedBag = makeMockFrame("ContainerFrameCombinedBags", 520, 620)
addon.db.savedWorkspacePositions.ContainerFrameCombinedBags = {x=100, y=900}
addon.db.openWorkspacePanels.ContainerFrameCombinedBags = true
-- CloseSpecialWindows can hide only the combined parent while Blizzard still
-- considers its bags logically open; OpenAllBags then performs no Show.
local nativeOpenAttempts = 0
OpenAllBags = function() nativeOpenAttempts = nativeOpenAttempts + 1 end
local settingsPanel = makeMockFrame("SettingsPanel", 980, 760)
settingsPanel:SetPoint("CENTER", UIParent, "CENTER", 900, 900)
addon.Canvas:HookMainhandSystemPanels()
combinedBag:Show()
settingsPanel:Show()
-- Forever performs this cleanup after the panel has begun showing.
combinedBag:Hide()
assert(addon.Canvas:RestoreWorkspaceBagClosedDuringSystemPanelOpen(),
    "Forever must queue recovery for a Settings-triggered workspace bag closure")
flushTimers()
local settingsPoint = settingsPanel.points[#settingsPanel.points]
local expectedCY = (metrics.gameBottom + metrics.gameTop) / 2 - UIParent:GetHeight()/2
assert(settingsPoint and settingsPoint[1] == "CENTER",
    "Forever SettingsPanel must receive a deterministic Mainhand center anchor")
assert(math.abs(settingsPoint[4] - expectedCX) < 0.01
    and math.abs(settingsPoint[5] - expectedCY) < 0.01,
    "Forever SettingsPanel must be centered inside the game rectangle")
assert(not combinedBag:IsShown(),
    "Settings recovery must not directly show a native backpack whose opener declined")
assert(addon.db.openWorkspacePanels.ContainerFrameCombinedBags == true
        and addon.db.nativeBackpackWorkspaceOpen == true,
    "Settings cleanup must retain tracked open intent for a later native retry")
print("PASS: Forever SettingsPanel Mainhand placement and safe native backpack recovery")

