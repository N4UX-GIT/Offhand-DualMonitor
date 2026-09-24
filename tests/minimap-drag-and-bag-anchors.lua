-- tests/minimap-drag-and-bag-anchors.lua
-- Validates:
-- 1. MinimapCluster dragging does not snap back to TOPRIGHT mid-drag or after drag stop.
-- 2. MinimapCluster SetPoint calls do NOT queue or trigger HUD layout resets.
-- 3. MinimapBorderTop, MinimapZoneTextButton, and MinimapCluster are all hooked for dragging.
-- 4. UpdateContainerFrameAnchors is overridden and avoids anchor family connection crashes.
-- 5. Bag expansion (ContainerFrame2..5) anchors each frame cleanly without cyclic references.

local addon = {
    modules = {},
    db = {
        enabled = true,
        deckWidthRatio = 0.36,
        primaryPosition = "RIGHT",
        layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
        aspectRatioMode = "16_9",
        gameBottomPixels = 0,
        hudScale = 1.0,
        savedWorkspacePositions = {},
        savedMainPositions = {},
    }
}
_G.Offhand = addon

local metrics = {
    gameLeft = 1440, gameRight = 4000, gameBottom = 6, gameTop = 1446,
    gameWidth = 2560, gameHeight = 1440, deckWidth = 1440, hudScale = 1,
    screenWidth = 4000, screenHeight = 2560, isSpanned = true,
}
addon.Viewport = { GetMetrics = function() return metrics end }
addon.Print = function() end
addon.RunOrQueueCombat = function(self, fn) fn() end
InCombatLockdown = function() return false end

UIParent = {
    GetWidth = function() return 4000 end,
    GetHeight = function() return 2560 end,
    GetEffectiveScale = function() return 1.0 end,
    GetScale = function() return 1.0 end,
}

local timers = {}
C_Timer = {
    After = function(_, fn) table.insert(timers, fn) end,
}
local function flushTimers()
    local t = timers
    timers = {}
    for _, fn in ipairs(t) do fn() end
end

hooksecurefunc = function(t, name, fn)
    if type(t) == "string" then return end
    local orig = t[name]
    t[name] = function(...)
        local r = orig and orig(...)
        fn(...)
        return r
    end
end

local function makeMockFrame(name, w, h)
    local f = {
        name = name, w = w or 192, h = h or 192,
        shown = false, alpha = 1, points = {}, scripts = {}, scale = 1,
        userPlaced = false,
    }
    function f:SetSize(w,h) self.w=w; self.h=h end
    function f:GetTop() return self:GetBottom()+self.h end
    function f:GetName() return self.name end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:SetHeight(h) self.h = h end
    function f:SetWidth(w) self.w = w end
    function f:GetEffectiveScale() return self.scale end
    function f:GetScale() return self.scale end
    function f:SetScale(s) self.scale = s end
    function f:ClearAllPoints() self.points = {} end
    function f:SetScrollChild(c) self.scrollChild = c end
    function f:SetVerticalScroll(v) self.verticalScroll = v end
    function f:SetPoint(pt, relTo, relPt, x, y)
        table.insert(self.points, { point = pt, relTo = relTo, relPt = relPt, x = x or 0, y = y or 0 })
    end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i)
        local p = self.points[i or 1]
        if p then return p.point, p.relTo, p.relPt, p.x, p.y end
    end
    function f:GetLeft()
        local p = self.points[#self.points]
        return p and p.x or 0
    end
    function f:GetBottom()
        local p = self.points[#self.points]
        return p and p.y or 0
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
    function f:GetAlpha() return self.alpha end
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
    return f
end

CreateFrame = function(frameType, name, parent, template)
    local f = makeMockFrame(name or ("mock_" .. tostring({})), 192, 192)
    f.template = template
    f.parent = parent
    return f
end

MinimapCluster = makeMockFrame("MinimapCluster", 192, 192)
MinimapZoneTextButton = makeMockFrame("MinimapZoneTextButton", 140, 24)
MinimapBorderTop = makeMockFrame("MinimapBorderTop", 192, 32)
_G["MinimapCluster"] = MinimapCluster
_G["MinimapZoneTextButton"] = MinimapZoneTextButton
_G["MinimapBorderTop"] = MinimapBorderTop

_G.NUM_CONTAINER_FRAMES = 5
for i = 1, 5 do
    _G["ContainerFrame" .. i] = makeMockFrame("ContainerFrame" .. i, 192, 250)
end
ContainerFrameCombinedBags = makeMockFrame("ContainerFrameCombinedBags", 320, 220)
_G["ContainerFrameCombinedBags"] = ContainerFrameCombinedBags

local origBlizzardCalled = false
_G.UpdateContainerFrameAnchors = function()
    origBlizzardCalled = true
end

assert(loadfile("UI/Themes.lua"))("Offhand", addon)
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(loadfile("Core/SeamRedirect.lua"))("Offhand", addon)

addon.Canvas:EnableFreeDragging()
addon.SeamRedirect:HookFrames()

assert(_G.UpdateContainerFrameAnchors ~= nil, "UpdateContainerFrameAnchors must be defined")
assert(addon.HUD.bagHooksInstalled == true, "Bag hooks must be marked installed")

assert(MinimapZoneTextButton._OffhandHooked == true, "MinimapZoneTextButton must be hooked")
assert(MinimapBorderTop._OffhandHooked == true, "MinimapBorderTop must be hooked")
assert(MinimapCluster._OffhandHooked == true, "MinimapCluster itself must be hooked")

addon.HUD:AlignHUDFrames()
local pt = MinimapCluster.points[#MinimapCluster.points]
assert(pt.point == "TOPRIGHT", "Initial MinimapCluster point must be TOPRIGHT")
assert(pt.x == metrics.gameRight, "Initial MinimapCluster x must be gameRight")

MinimapZoneTextButton.scripts["OnDragStart"](MinimapZoneTextButton)
assert(MinimapCluster._OffhandDragging == true, "MinimapCluster._OffhandDragging must be true during drag")

local pointCountBefore = #MinimapCluster.points
addon.HUD:AlignHUDFrames()
assert(#MinimapCluster.points == pointCountBefore, "AlignHUDFrames must NOT touch MinimapCluster while actively dragging")

MinimapCluster.points = { { point = "BOTTOMLEFT", relTo = UIParent, relPt = "BOTTOMLEFT", x = 200, y = 800 } }
MinimapZoneTextButton.scripts["OnDragStop"](MinimapZoneTextButton)

assert(MinimapCluster._OffhandDragging == false, "MinimapCluster._OffhandDragging must be reset after drag stop")
assert(addon.db.savedWorkspacePositions["MinimapCluster"] ~= nil, "MinimapCluster must be saved to workspace positions")
assert(addon.db.savedWorkspacePositions["MinimapCluster"].x >= 12, "MinimapCluster x must be clamped within deck")

flushTimers()
local postDragPt = MinimapCluster.points[#MinimapCluster.points]
assert(postDragPt.point == "TOPLEFT", "MinimapCluster on workspace must remain at BOTTOMLEFT point")
assert(postDragPt.x < metrics.deckWidth, "MinimapCluster must remain on workspace after timers fire")

local cf1 = _G["ContainerFrame1"]
cf1:Show()
cf1.points = { { point = "BOTTOMLEFT", relTo = UIParent, relPt = "BOTTOMLEFT", x = 100, y = 400 } }
if cf1._OffhandHandle and cf1._OffhandHandle.scripts["OnDragStop"] then
    cf1._OffhandHandle.scripts["OnDragStop"]()
end
assert(addon.db.savedWorkspacePositions["ContainerFrame1"] ~= nil, "ContainerFrame1 must be saved to workspace")

local combined = _G.ContainerFrameCombinedBags
assert(combined.TitleContainer == nil, "Combined bag title must begin unavailable to exercise delayed creation")
combined.TitleContainer = makeMockFrame("ContainerFrameCombinedBagsTitleContainer", 320, 32)
combined:Show()
assert(combined.TitleContainer._OffhandPersistenceHooked == true,
    "Delayed combined bag TitleContainer must be hooked when the parent first shows")
combined.TitleContainer.scripts["OnDragStart"](combined.TitleContainer)
assert(combined._OffhandDragging == true, "Combined bag must be marked as dragging from its native title")
combined.points = { { point = "BOTTOMLEFT", relTo = UIParent, relPt = "BOTTOMLEFT", x = 120, y = 500 } }
combined.TitleContainer.scripts["OnDragStop"](combined.TitleContainer)
assert(addon.db.savedWorkspacePositions["ContainerFrameCombinedBags"] ~= nil,
    "Combined bag native title drag must save the workspace position")
assert(combined._OffhandDragging == false, "Combined bag drag state must clear after its native title drag")

addon.db.savedWorkspacePositions["ContainerFrameCombinedBags"] = nil
combined.points = { { point = "BOTTOMLEFT", relTo = UIParent, relPt = "BOTTOMLEFT", x = 140, y = 520 } }
combined:Hide()
assert(addon.db.savedWorkspacePositions["ContainerFrameCombinedBags"] == nil and not combined:IsShown(),
    "Closing a combined bag must not run drag-stop persistence or resurrect it")

addon.isForever = true
local mirrored
addon.ForeverPersistence = {
    SaveWorkspacePosition = function(_, name, position, width, height)
        mirrored = { name = name, x = position.x, y = position.y, width = width, height = height }
    end,
    ClearPosition = function() mirrored = nil end,
}
combined:Show()
combined.points = { { point = "BOTTOMLEFT", relTo = UIParent, relPt = "BOTTOMLEFT", x = 260, y = 640 } }
combined:SetSize(410, 275)
assert(addon.Canvas:CaptureForeverFramePosition(combined) == true,
    "Forever read-only sampler must capture an Edit Mode bag move")
assert(mirrored and mirrored.name == "ContainerFrameCombinedBags" and mirrored.x == 260,
    "Forever Edit Mode capture must mirror the new combined bag position")
assert(mirrored.width == 410 and mirrored.height == 275,
    "Forever Edit Mode capture must mirror the resized combined bag dimensions")

local editModeChat = makeMockFrame("ChatFrame1", 560, 340)
editModeChat:Show()
editModeChat.points = { { point = "BOTTOMLEFT", relTo = UIParent, relPt = "BOTTOMLEFT", x = 180, y = 420 } }
assert(addon.Canvas:CaptureForeverFramePosition(editModeChat) == true,
    "Forever read-only sampler must capture an Edit Mode chat move")
assert(mirrored and mirrored.name == "ChatFrame1" and mirrored.x == 180,
    "Forever Edit Mode capture must mirror the new chat position")
assert(mirrored.width == 560 and mirrored.height == 340,
    "Forever Edit Mode capture must mirror the resized chat dimensions")

for i = 2, 5 do
    _G["ContainerFrame" .. i]:Show()
end

origBlizzardCalled = false
_G.UpdateContainerFrameAnchors()
assert(origBlizzardCalled == false, "Blizzard's original UpdateContainerFrameAnchors must be intercepted by Offhand")

for i = 1, 5 do
    local frame = _G["ContainerFrame" .. i]
    local lastP = frame.points[#frame.points]
    assert(lastP ~= nil, "ContainerFrame" .. i .. " must have points")
    local expectedPoint = (i == 1) and "TOPLEFT" or "BOTTOMRIGHT"
    assert(lastP.point == expectedPoint, "ContainerFrame" .. i .. " must be anchored " .. expectedPoint)
    assert(lastP.relTo == UIParent, "ContainerFrame" .. i .. " must be anchored to UIParent (no relative chaining cycles)")
    assert(lastP.x < metrics.deckWidth, "ContainerFrame" .. i .. " must be on workspace")
    assert(frame:GetAlpha() == 1, "ContainerFrame" .. i .. " must have alpha 1")
end

_G.Bagnon = { version = "1.0" }
assert(addon.HasCustomBagAddon() == true, "HasCustomBagAddon must return true when Bagnon is present")
origBlizzardCalled = false
_G.UpdateContainerFrameAnchors()
assert(origBlizzardCalled == true, "UpdateContainerFrameAnchors must yield and invoke original function when custom bag addon is active")

print("PASS: Minimap drag resilience, UpdateContainerFrameAnchors override, and bag expansion cycle prevention verified!")

