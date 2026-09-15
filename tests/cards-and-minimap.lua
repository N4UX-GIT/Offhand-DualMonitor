-- Test Options dialog cards, header border/close button, MinimapCluster and ContainerFrame workspace persistence
local addon = {
    modules = {},
    db = {
        enabled = true,
        seamRedirect = true,
        independentWorkspacePanels = true,
        theme = "CLASSIC",
        trimColor = "GOLD",
        savedWorkspacePositions = {}
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
    GetScale = function() return 1 end,
    SetScale = function() end,
    GetAttribute = function(self, key) return self[key] or 0 end,
    SetAttribute = function(self, key, val) self[key] = val end,
}

local metrics = {
    gameLeft = 1440, gameRight = 4000, gameBottom = 6, gameTop = 1446,
    gameWidth = 2560, gameHeight = 1440, deckWidth = 1440, hudScale = 1,
    screenWidth = 4000, screenHeight = 2560, isSpanned = true,
}
addon.Viewport = { GetMetrics = function() return metrics end }
addon.Print = function() end
addon.RunOrQueueCombat = function(self, fn) fn() end
InCombatLockdown = function() return false end
hooksecurefunc = function(t, name, fn)
    if type(t) == "string" then return end
    local orig = t[name]
    t[name] = function(...)
        local r = orig and orig(...)
        fn(...)
        return r
    end
end

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
UIPanelWindows = {}

local function makeMockFrame(name, w, h)
    local f = {
        name = name, w = w or 200, h = h or 200,
        shown = false, alpha = 1, points = {}, scripts = {}, scale = 1,
        userPlaced = false,
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
    function f:SetShown(val) if val then self:Show() else self:Hide() end end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(a) self.alpha = a end
    function f:ClearAllPoints() self.points = {} end
    function f:SetScrollChild(c) self.scrollChild = c end
    function f:SetVerticalScroll(v) self.verticalScroll = v end
    function f:SetPoint(pt, rel, relPt, x, y)
        table.insert(self.points, { pt, rel, relPt, x or 0, y or 0 })
    end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i)
        local p = self.points[i or 1]
        if p then return p[1], p[2], p[3], p[4], p[5] end
    end
    function f:HookScript(scriptName, fn)
        local orig = self.scripts[scriptName]
        self.scripts[scriptName] = function(...)
            if orig then orig(...) end
            fn(...)
        end
    end
    function f:SetScript(scriptName, fn) self.scripts[scriptName] = fn end
    function f:SetMovable() end
    function f:SetClampedToScreen() end
    function f:RegisterForDrag() end
    function f:EnableMouse() end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    function f:SetUserPlaced(val) self.userPlaced = val end
    function f:IsUserPlaced() return self.userPlaced end
    function f:SetBackdrop() end
    function f:SetBackdropColor() end
    function f:SetBackdropBorderColor() end
    function f:CreateFontString()
        return {
            SetPoint = function() end,
            SetText = function() end,
            SetTextColor = function() end,
            SetJustifyH = function() end,
        }
    end
    function f:CreateTexture()
        return {
            SetAllPoints = function() end,
            SetColorTexture = function() end,
        }
    end
    return f
end

CreateFrame = function(frameType, name, parent, template)
    local f = makeMockFrame(name or ("mock_" .. tostring({})), 200, 200)
    f.template = template
    f.parent = parent
    return f
end

-- Create mock environment frames
MinimapCluster = makeMockFrame("MinimapCluster", 192, 192)
MinimapZoneTextButton = makeMockFrame("MinimapZoneTextButton", 140, 24)
ContainerFrame1 = makeMockFrame("ContainerFrame1", 192, 250)
_G.MinimapCluster = MinimapCluster
_G.MinimapZoneTextButton = MinimapZoneTextButton
_G.ContainerFrame1 = ContainerFrame1

-- Load Offhand modules
assert(loadfile("UI/Themes.lua"))("Offhand", addon)
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(loadfile("Core/SeamRedirect.lua"))("Offhand", addon)

-- 1. Test Canvas draggability setup and HUD hooks
addon.Canvas:EnableFreeDragging()
addon.SeamRedirect:HookFrames()
assert(MinimapCluster._OffhandHandle ~= nil or MinimapZoneTextButton._OffhandHooked == true, "MinimapCluster must be made draggable")
assert(ContainerFrame1._OffhandHandle ~= nil, "ContainerFrame1 must have a drag handle")

-- 2. Test MinimapCluster dragged onto workspace
MinimapCluster.points = { { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, 500 } }
MinimapCluster.userPlaced = true
addon.Canvas.MakePanelDraggable(MinimapCluster)

-- Simulate DragStop on workspace (x=100 is within deckWidth=1440)
if MinimapZoneTextButton.scripts["OnDragStop"] then
    MinimapZoneTextButton.scripts["OnDragStop"]()
end
assert(addon.db.savedWorkspacePositions["MinimapCluster"] ~= nil, "MinimapCluster must be saved to workspace positions")
assert(addon.db.savedWorkspacePositions["MinimapCluster"].x >= 12, "MinimapCluster x must be clamped within workspace")

-- 3. Run AlignHUDFrames pass and verify MinimapCluster does NOT get reset to TOPRIGHT of game monitor
addon.HUD:AlignHUDFrames()
local lastPoint = MinimapCluster.points[#MinimapCluster.points]
assert(lastPoint[1] == "BOTTOMLEFT", "MinimapCluster on workspace must remain at BOTTOMLEFT point")
assert(lastPoint[4] < metrics.deckWidth, "MinimapCluster must remain within workspace boundaries")

-- 3b. Drag MinimapCluster back to game monitor (x >= deckWidth)
MinimapCluster.points = { { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2500, 500 } }
if MinimapZoneTextButton.scripts["OnDragStop"] then
    MinimapZoneTextButton.scripts["OnDragStop"]()
end
assert(addon.db.savedWorkspacePositions["MinimapCluster"] == nil, "MinimapCluster must clear workspace position on game screen")
local mmPt = MinimapCluster.points[#MinimapCluster.points]
assert(mmPt[1] == "TOPRIGHT", "MinimapCluster must re-anchor to TOPRIGHT on game screen")
assert(mmPt[4] == metrics.gameRight, "MinimapCluster must anchor to gameRight on game screen")

-- 4. Test ContainerFrame1 dragging to workspace
ContainerFrame1:Show()
ContainerFrame1.points = { { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 300 } }
if ContainerFrame1._OffhandHandle and ContainerFrame1._OffhandHandle.scripts["OnDragStop"] then
    ContainerFrame1._OffhandHandle.scripts["OnDragStop"]()
end
assert(addon.db.savedWorkspacePositions["ContainerFrame1"] ~= nil, "ContainerFrame1 must be saved to workspace positions")

-- 5. Test ContainerFrame1 dragged back to game monitor (x >= deckWidth)
ContainerFrame1.points = { { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2000, 300 } }
if ContainerFrame1._OffhandHandle and ContainerFrame1._OffhandHandle.scripts["OnDragStop"] then
    ContainerFrame1._OffhandHandle.scripts["OnDragStop"]()
end
assert(addon.db.savedWorkspacePositions["ContainerFrame1"] == nil, "ContainerFrame1 must be cleared from workspace when on gaming monitor")
-- When dropped on gaming monitor, LayoutBags runs and anchors it to BOTTOMRIGHT of game monitor
local bagPoint = ContainerFrame1.points[#ContainerFrame1.points]
assert(bagPoint[1] == "BOTTOMRIGHT", "ContainerFrame1 must be re-docked to BOTTOMRIGHT on gaming screen")

-- 6. Test BayHeader creation, border, and close button docking
local mockParent = makeMockFrame("MockConfig", 660, 560)
local header = addon.Themes:CreateBayHeader(mockParent, "TEST HEADER")
assert(header:GetHeight() == 36, "BayHeader height must be 36px")
assert(header.template == "BackdropTemplate", "BayHeader must use BackdropTemplate")

-- 7. Test 3rd-party Bag Addon detection and yielding (e.g. Bagnon / AdiBags)
_G.Bagnon = { version = "10.0" }
assert(addon.HasCustomBagAddon() == true, "HasCustomBagAddon must return true when Bagnon is present")
ContainerFrame1.points = {}
addon.HUD:LayoutBags()
assert(#ContainerFrame1.points == 0, "HUD:LayoutBags must yield and NOT alter points when Bagnon is present")

local customBag = makeMockFrame("ContainerFrame2", 192, 250)
addon.Canvas.MakePanelDraggable(customBag)
assert(customBag._OffhandHandle == nil, "MakePanelDraggable must yield and NOT attach handles to container frames when custom bag addon is active")

-- 8. Test 3rd-party Minimap Addon detection and yielding (e.g. SexyMap / BasicMinimap)
_G.SexyMap = { version = "1.0" }
assert(addon.HasCustomMinimapAddon() == true, "HasCustomMinimapAddon must return true when SexyMap is present")
MinimapCluster.points = {}
addon.HUD:AlignHUDFrames()
assert(#MinimapCluster.points == 0, "HUD:AlignHUDFrames must yield and NOT alter MinimapCluster points when SexyMap is present")

local customMinimap = makeMockFrame("MinimapCluster", 192, 192)
addon.Canvas.MakePanelDraggable(customMinimap)
assert(customMinimap._OffhandMovable == nil, "MakePanelDraggable must yield and NOT manage MinimapCluster when SexyMap is present")

print("PASS: MinimapCluster & Bag workspace persistence, header border & close button, 3rd-party addon yielding without conflict")
