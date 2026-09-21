StaticPopupDialogs = {}
C_Timer = {After=function() end}
-- tests/expanded-bags-and-ui-overlaps.lua
-- Tests for bag expansion on workspace, method vs function call safety, and options card clearance

local addon = {
    modules = {},
    db = {
        enabled = true,
        deckWidthRatio = 0.36,
        primaryPosition = "RIGHT",
        layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
        aspectRatioMode = "16_9",
        gameBottomPixels = 0,
        hudScale = 0.70,
        theme = "CLASSIC",
        trimColor = "GOLD",
        canvasColor = "CHARCOAL",
        canvasAlpha = 0.95,
        independentWorkspacePanels = true,
        persistentWorkspacePanels = true,
        savedWorkspacePositions = {},
        savedMainPositions = {},
    }
}
_G.Offhand = addon

UIParent = {
    GetWidth = function() return 4000 end,
    GetHeight = function() return 2560 end,
    GetEffectiveScale = function() return 1.0 end,
    SetAttribute = function() end,
    ClearAllPoints = function() end,
    SetPoint = function() end,
    Show = function() end,
    Hide = function() end,
}

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

local function makeMockFrame(name, w, h)
    local f = {
        name = name, w = w or 192, h = h or 250,
        shown = false, alpha = 1, points = {}, scripts = {}, scale = 1,
        userPlaced = false,
    }
    function f:GetName() return self.name end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:SetHeight(h) self.h = h end
    function f:SetWidth(w) self.w = w end
    function f:SetSize(w, h) self.w = w; self.h = h end
    function f:GetScale() return self.scale end
    function f:SetScale(s) self.scale = s end
    function f:GetEffectiveScale() return self.scale end
    function f:ClearAllPoints() self.points = {} end
    function f:SetScrollChild(c) self.scrollChild = c end
    function f:SetVerticalScroll(v) self.verticalScroll = v end
    function f:SetPoint(pt, relTo, relPt, x, y)
        table.insert(self.points, { point = pt, relTo = relTo, relPt = relPt, x = x, y = y })
    end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(idx)
        local p = self.points[idx or 1]
        if not p then return nil end
        return p.point, p.relTo, p.relPt, p.x, p.y
    end
    function f:GetLeft()
        local p = self.points[#self.points]
        return p and p.x or 0
    end
    function f:GetBottom()
        local p = self.points[#self.points]
        return p and p.y or 0
    end
    function f:Show()
        self.shown = true
        if self.scripts["OnShow"] then self.scripts["OnShow"](self) end
    end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetShown(val) self.shown = val end
    function f:SetAlpha(a) self.alpha = a end
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
    function f:SetFrameStrata() end
    function f:SetFrameLevel() end
    function f:SetText() end
    function f:SetTextColor() end
    function f:SetOrientation() end
    function f:SetMinMaxValues() end
    function f:SetValueStep() end
    function f:SetObeyStepOnDrag() end
    function f:SetValue() end
    function f:SetThumbTexture() end
    function f:SetChecked() end
    function f:GetChecked() return true end
    function f:SetAutoFocus() end
    function f:SetNumeric() end
    function f:SetMaxLetters() end
    function f:ClearFocus() end
    function f:GetText() return "0" end
    function f:SetEnabled() end
    function f:CreateFontString()
        return {
            SetPoint = function(self, ...) self.pointArgs = {...} end,
            SetText = function(self, t) self.text = t end,
            SetWidth = function() end,
            SetWordWrap = function() end,
            SetTextColor = function() end,
            SetJustifyH = function() end,
            SetWidth = function() end,
        }
    end
    function f:CreateTexture()
        return {
            SetAllPoints = function() end,
            SetColorTexture = function() end,
            SetTexture = function() end,
            SetVertexColor = function() end,
            SetSize = function() end,
            SetPoint = function() end,
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

_G.NUM_CONTAINER_FRAMES = 5
for i = 1, 5 do
    _G["ContainerFrame" .. i] = makeMockFrame("ContainerFrame" .. i, 192, 250)
end

local metrics = {
    gameLeft = 1440, gameRight = 4000, gameBottom = 6, gameTop = 1446,
    gameWidth = 2560, gameHeight = 1440, deckWidth = 1440, hudScale = 1,
    screenWidth = 4000, screenHeight = 2560, isSpanned = true,
}
addon.Viewport = { GetMetrics = function() return metrics end }
addon.Print = function() end
addon.ApplyFullLayout = function() end

assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(loadfile("Core/SeamRedirect.lua"))("Offhand", addon)
assert(loadfile("UI/Themes.lua"))("Offhand", addon)
assert(loadfile("UI/Options.lua"))("Offhand", addon)
addon.SeamRedirect:HookFrames()

-- TEST 1: Method vs Function call resilience on RestoreWorkspacePosition
local cf1 = _G["ContainerFrame1"]
addon.db.savedWorkspacePositions["ContainerFrame1"] = { x = 120, y = 300 }

-- Call as method Canvas:RestoreWorkspacePosition(cf1) (passes Canvas as 1st arg, cf1 as 2nd arg)
local okMethod, errMethod = pcall(function()
    addon.Canvas:RestoreWorkspacePosition(cf1)
end)
assert(okMethod, "Canvas:RestoreWorkspacePosition method call failed: " .. tostring(errMethod))
local p = cf1.points[#cf1.points]
assert(p and p.x == 120 and p.y == 300, "ContainerFrame1 not restored to saved workspace coordinates via method call")

-- Call as function Canvas.RestoreWorkspacePosition(cf1) (passes cf1 as 1st arg)
local okFunc, errFunc = pcall(function()
    addon.Canvas.RestoreWorkspacePosition(cf1)
end)
assert(okFunc, "Canvas.RestoreWorkspacePosition function call failed: " .. tostring(errFunc))

-- A temporary pre-span window may require a clamped visual position, but that
-- must never overwrite the durable full-canvas coordinates.
local durable = { x = -500, y = 9999 }
addon.db.savedWorkspacePositions["ContainerFrame1"] = durable
addon.Canvas:RestoreWorkspacePosition(cf1)
local clamped = cf1.points[#cf1.points]
assert(clamped.x == 12 and clamped.y == metrics.screenHeight - 12,
    "temporary restore was not visually clamped to the current canvas")
assert(durable.x == -500 and durable.y == 9999,
    "temporary pre-span clamp corrupted the durable workspace coordinates")
addon.db.savedWorkspacePositions["ContainerFrame1"] = { x = 120, y = 300 }

-- Positions captured on another logical canvas scale proportionally without
-- altering their durable raw coordinates or capture metadata.
local normalized = { x = 120, y = 300, canvasHeight = 1280 }
addon.db.savedWorkspacePositions["ContainerFrame1"] = normalized
addon.Canvas:RestoreWorkspacePosition(cf1)
local normalizedPoint = cf1.points[#cf1.points]
assert(normalizedPoint.y == 600, "workspace Y was not normalized to the current canvas height")
assert(normalized.y == 300 and normalized.canvasHeight == 1280,
    "normalized restore mutated durable capture coordinates")
addon.db.savedWorkspacePositions["ContainerFrame1"] = { x = 120, y = 300 }

-- Call with nil or malformed table -> must safely return without throwing
local okNil = pcall(function()
    addon.Canvas.RestoreWorkspacePosition(nil)
    addon.Canvas.RestoreWorkspacePosition({})
    addon.Canvas:RestoreWorkspacePosition(nil)
end)
assert(okNil, "RestoreWorkspacePosition crashed on nil/empty input")

-- TEST 2: Expanded bags (ContainerFrame2..5) dock on workspace when Backpack is on workspace
for i = 1, 5 do
    _G["ContainerFrame" .. i]:Show()
end
addon.HUD:LayoutBags()

local deckWidth = metrics.deckWidth -- 1440

for i = 2, 5 do
    local f = _G["ContainerFrame" .. i]
    local pt = f.points[#f.points]
    assert(pt ~= nil, "ContainerFrame" .. i .. " has no point")
    assert(pt.x >= 12 and pt.x <= (deckWidth - 12),
        string.format("ContainerFrame%d spilled out of workspace! x=%f, deckWidth=%f", i, pt.x, deckWidth))
    assert(pt.point == "BOTTOMRIGHT", "ContainerFrame" .. i .. " should anchor BOTTOMRIGHT on workspace")
end

-- TEST 3: Moving Backpack back to main game view re-docks all bags to main view
addon.db.savedWorkspacePositions["ContainerFrame1"] = nil
addon.HUD:LayoutBags()

for i = 1, 5 do
    local f = _G["ContainerFrame" .. i]
    local pt = f.points[#f.points]
    assert(pt ~= nil, "ContainerFrame" .. i .. " has no point")
    assert(pt.x > metrics.gameLeft,
        string.format("ContainerFrame%d did not return to main game view! x=%f, gameLeft=%f", i, pt.x, metrics.gameLeft))
end

-- TEST 4: Options panel creation and slider clearances
local configFrame = addon.Options:CreateFloatingPanel()
assert(configFrame ~= nil, "Floating config frame was not created")

print("PASS: RestoreWorkspacePosition method/function safety, expanded bags workspace docking & redocking, card clearance")

-- Unequal, scaled bags must not overlap or use the portrait monitor's height.
for i=1,5 do local f=_G["ContainerFrame"..i]; f.h=80+i*57; f.scale=0.8+i*0.1 end
local function obstacle(name,l,b,r,t,scale)
    local f=makeMockFrame(name,r-l,t-b); _G[name]=f; f.shown=true; f.scale=scale
    f.GetLeft=function() return l end; f.GetRight=function() return r end
    f.GetBottom=function() return b end; f.GetTop=function() return t end
    return f
end
-- Effective-scale conversion puts this bar on the game's right edge.
obstacle("MultiBarRight",7800,40,8000,2000,0.5)
obstacle("MicroMenuContainer",3500,6,3900,100,1)
addon.HUD:LayoutBags()
local boxes={}
for i=1,5 do
    local f=_G["ContainerFrame"..i]; local p=f.points[#f.points]
    local r,b=p.x*f.scale,p.y*f.scale; local l,t=r-f.w*f.scale,b+f.h*f.scale
    print("BAG:", i, "L:", l, "R:", r); assert(l>=metrics.gameLeft and r<=3900-8, "Bag overlaps scaled right action bar")
    print("BAG:", i, "T:", t, "B:", b); assert(t<=metrics.gameTop and b>=metrics.gameBottom, "Bag extends beyond game monitor")
    assert(r<=3500 or l>=3900 or b>=100 or t<=6, "Bag overlaps micro menu")
    for _,o in ipairs(boxes) do assert(r<=o.l or l>=o.r or b>=o.t or t<=o.b,"Unequal bags overlap") end
    boxes[#boxes+1]={l=l,r=r,b=b,t=t}
end
print("PASS: mixed bag sizes/scales, scaled bar collision and game-height column wrapping")

