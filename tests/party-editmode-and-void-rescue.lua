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
    GetAttribute = function(self, key) return self[key] or 0 end,
    SetAttribute = function(self, key, val) self[key] = val end,
    children = {},
    GetChildren = function(self) return unpack(self.children) end,
}

local metrics = {
    screenWidth = 4000, screenHeight = 2560,
    physicalWidth = 4000, physicalHeight = 2560,
    deckWidth = 1440, gameWidth = 2560, gameHeight = 1440,
    gameLeft = 1440, gameBottom = 6, gameRight = 4000, gameTop = 1446,
    gamePixelLeft = 1440, gamePixelBottom = 6, gamePixelWidth = 2560, gamePixelHeight = 1440,
    hudScale = 1, bezel = 0, preset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
    actualAR = 2560 / 1440, arMode = "16_9", isSpanned = true,
}

addon.Viewport = { GetMetrics = function() return metrics end }
addon.Print = function() end
addon.RunOrQueueCombat = function(self, fn) fn() end
InCombatLockdown = function() return false end

local timers = {}
local tickers = {}
C_Timer = {
    After = function(_, fn) table.insert(timers, fn) end,
    NewTicker = function(_, fn) table.insert(tickers, fn); return { Cancel = function() end } end,
}
local function flushTimers()
    local t = timers
    timers = {}
    for _, fn in ipairs(t) do fn() end
    for _, fn in ipairs(tickers) do fn() end
end

local frames = {}
local function makeMockFrame(name, w, h)
    local f = {
        name = name, w = w or 200, h = h or 100,
        shown = true, alpha = 1, points = {}, scripts = {}, scale = 1,
        userPlaced = false, movable = false, clamped = false, mouse = false,
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
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i)
        i = i or 1
        local p = self.points[i]
        if p then return p[1], p[2], p[3], p[4], p[5] end
        return nil
    end
    function f:SetPoint(pt, rel, relPt, x, y)
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
    function f:SetClampedToScreen(c) self.clamped = c end
    function f:EnableMouse(m) self.mouse = m end
    function f:RegisterForDrag() end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    function f:HookScript(event, fn)
        local orig = self.scripts[event]
        self.scripts[event] = function(...)
            if orig then orig(...) end
            fn(...)
        end
    end
    function f:GetScript(event) return self.scripts[event] end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:IsForbidden() return false end
    function f:IsProtected() return false end
    frames[name] = f
    _G[name] = f
    return f
end

CreateFrame = function(frameType, name, parent)
    local f = makeMockFrame(name or ("AnonFrame_" .. tostring(#UIParent.children + 1)), 200, 100)
    table.insert(UIParent.children, f)
    return f
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
ExampleAddonWindow = makeMockFrame("ExampleAddonWindow", 220, 300)
table.insert(UIParent.children, ExampleAddonWindow)

ToggleGameMenu = function()
    if GameMenuFrame:IsShown() then
        GameMenuFrame:Hide()
    else
        GameMenuFrame:Show()
    end
end
ShowUIPanel = function(frame) frame:Show() end

-- Load Offhand core scripts
local seamChunk = loadfile("Core/SeamRedirect.lua")
assert(seamChunk, "Core/SeamRedirect.lua must compile cleanly")
seamChunk("Offhand", addon)

local canvasChunk = loadfile("Core/Canvas.lua")
assert(canvasChunk, "Core/Canvas.lua must compile cleanly")
canvasChunk("Offhand", addon)

addon.HUD:HookFrames()

-- ============================================================================
-- TEST 1: Party Frame Default Positioning inside the 3D Game Viewport
-- ============================================================================
addon.HUD:AlignHUDFrames(metrics)

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
assert(PartyMemberFrame1._OffhandHandle == nil, "PartyMemberFrame1 must NOT have an overlaid drag handle so unit targeting/healing is never blocked")
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
MainActionBar = makeMockFrame("MainActionBar", 500, 45)
MainActionBar.IsInDefaultPosition = function() return true end
local originalMainSetPoint = MainActionBar.SetPoint
local EditModeManagerFrame = makeMockFrame("EditModeManagerFrame", 600, 60)
local EditModeSystemSettingsDialog = makeMockFrame("EditModeSystemSettingsDialog", 400, 300)
local EditModeUnsavedChangesDialog = makeMockFrame("EditModeUnsavedChangesDialog", 350, 150)
Enum = {
    EditModeSystem = { ActionBar = 1 },
    EditModeActionBarSystemIndices = { MainBar = 1 },
}
local layoutData = {
    activeLayout = 1,
    layouts = {
        {layoutName = "Modern", layoutType = 0},
        {
            layoutName = "Offhand",
            layoutType = 1,
            systems = {
                {system = 1, systemIndex = 1, isInDefaultPosition = true},
            },
        },
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
addon.HUD:HookFrames()
addon.HUD:AlignHUDFrames(metrics)

assert(MainActionBar.SetPoint == originalMainSetPoint,
    "Forever must not install a SetPoint repair hook on MainActionBar")
assert(#MainActionBar.points == 0,
    "Forever must not directly anchor MainActionBar")

-- Forever can load Blizzard_EditMode after Offhand's canvas initialization.
-- Protected unit frames must still be rejected when the manager did not exist
-- at the time draggable-frame discovery first ran.
local party2PointCount = #PartyMemberFrame2.points
addon.Canvas.MakePanelDraggable(PartyMemberFrame2)
addon.Canvas:TryMakeFrameDraggable(EditModeManagerFrame)
addon.Canvas.RestoreWorkspacePosition(PartyMemberFrame2)
addon.Canvas.OnPanelDragStop(PartyMemberFrame2)
assert(not PartyMemberFrame2._OffhandMovable and not PartyMemberFrame2.movable,
    "Forever must not make party frames movable")
assert(not EditModeManagerFrame._OffhandMovable and not EditModeManagerFrame.movable,
    "Forever must not make EditModeManagerFrame movable")
assert(#PartyMemberFrame2.points == party2PointCount,
    "Forever must not restore or save party-frame anchors through Canvas")

ShowUIPanel(EditModeManagerFrame)
flushTimers()

local editPt = EditModeManagerFrame.points[#EditModeManagerFrame.points]
assert(editPt == nil, "Forever must not reanchor EditModeManagerFrame")
assert(selectedLayout == nil,
    "Forever must not auto-select an Offhand layout whose main action bar is still in its full-canvas default position")
assert(addon.HUD.editModeGuidanceShown,
    "Forever must guide the player to configure an unpositioned Offhand Edit Mode layout")

-- Even after the player has configured the layout, Forever must leave profile
-- selection to Blizzard Edit Mode. A delayed switch can move or hide bars.
layoutData.layouts[2].systems[1].isInDefaultPosition = false
addon.HUD.editModeLoadScheduled = nil
addon.HUD:HookFrames()
flushTimers()
assert(selectedLayout == nil and layoutData.activeLayout == 1,
    "Forever must not change the active Edit Mode layout after reload")

-- Edit Mode dialogs also remain entirely Blizzard-owned.
EditModeUnsavedChangesDialog:Show()
flushTimers()
local dialogPt = EditModeUnsavedChangesDialog.points[#EditModeUnsavedChangesDialog.points]
assert(dialogPt == nil, "Forever must not reanchor Edit Mode dialogs")
print("PASS: Forever yields action bars, manager and dialogs to Blizzard Edit Mode")

-- ============================================================================
-- TEST 6: GameMenuFrame Centering & Escape Dismissal
-- ============================================================================
ToggleGameMenu()
flushTimers()
local menuPt = GameMenuFrame.points[#GameMenuFrame.points]
assert(menuPt, "GameMenuFrame must be anchored")
assert(menuPt[1] == "CENTER", "GameMenuFrame point must be CENTER")
assert(math.abs(menuPt[4] + 2000 - 2720) < 1, "GameMenuFrame X must be centered at 2720")
assert(math.abs(menuPt[5] + 1280 - 726) < 1, "GameMenuFrame Y must be centered at 726")
ToggleGameMenu() -- Dismiss cleanly
assert(not GameMenuFrame:IsShown(), "GameMenuFrame must dismiss cleanly on toggle")
print("PASS: GameMenuFrame centers on Game Viewport and dismisses cleanly")

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

print("\nALL PARTY FRAMES, EDIT MODE, AND VOID RESCUE TESTS PASSED!")

assert(#tickers == 1, "Repeated HUD setup installed duplicate scanners")

-- A full-height seam guide deliberately extends above the game viewport.
local guide = makeMockFrame("OffhandSeamGuideLine", 4, 2560)
table.insert(UIParent.children, guide)
guide:SetPoint("TOPLEFT", UIParent, "TOPLEFT", metrics.deckWidth - 2, 0)
guide:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", metrics.deckWidth - 2, 0)
local guidePoints = #guide.points
for i = 1, 3 do flushTimers() end
assert(#guide.points == guidePoints and guide.points[1][1] == "TOPLEFT",
    "Popup recovery must preserve the seam guide's full-height anchors")

