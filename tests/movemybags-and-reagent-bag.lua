-- tests/movemybags-and-reagent-bag.lua
-- Verifies MoveMyBags coexistence (yielding native ContainerFrame drag, layout,
-- persistence, and popup recovery) and non-overlapping Mainhand layout for
-- Combined Bags + Reagent Bag (ContainerFrame6) when MoveMyBags is absent.

StaticPopupDialogs = {}
local timers = {}
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTicker = function() return { Cancel = function() end } end,
}

local loadedAddons = { MoveMyBags = true }
C_AddOns = {
    IsAddOnLoaded = function(name) return loadedAddons[name] == true end,
}
IsAddOnLoaded = function(name) return loadedAddons[name] == true end

local addon = {
    modules = {},
    isRetail = true,
    isForever = false,
    db = {
        enabled = true,
        seamRedirect = true,
        primaryPosition = "LEFT",
        independentWorkspacePanels = true,
        persistentWorkspacePanels = true,
        restoreWorkspaceOnReload = true,
        savedWorkspacePositions = {
            ContainerFrame6 = { x = 2100, y = 400 },
            ContainerFrameCombinedBags = { x = 2300, y = 400 },
        },
        savedMainPositions = {},
        openWorkspacePanels = {
            ContainerFrame6 = true,
            ContainerFrameCombinedBags = true,
        },
        nativeBackpackWorkspacePosition = { x = 2300, y = 400 },
        nativeBackpackWorkspaceOpen = true,
    },
    Print = function() end,
    ApplyFullLayout = function() end,
}
_G.Offhand = addon

UIParent = {
    GetWidth = function() return 3840 end,
    GetHeight = function() return 1080 end,
    GetEffectiveScale = function() return 1.0 end,
    SetAttribute = function() end,
    ClearAllPoints = function() end,
    SetPoint = function() end,
    Show = function() end,
    Hide = function() end,
    GetChildren = function() return end,
}

InCombatLockdown = function() return false end
hooksecurefunc = function(t, name, fn)
    if type(t) == "string" then
        local orig = _G[t]
        if type(orig) == "function" then
            _G[t] = function(...) local r = orig(...); name(...); return r end
        end
        return
    end
    local orig = t[name]
    t[name] = function(...)
        local r = orig and orig(...)
        fn(...)
        return r
    end
end

local function makeFrame(name, w, h)
    local f = {
        name = name, w = w or 192, h = h or 250,
        shown = false, alpha = 1, points = {}, scripts = {}, scale = 1,
        userPlaced = false, movable = false, clamped = false,
        setPointCalls = 0, setUserPlacedCalls = 0,
    }
    function f:GetName() return self.name end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:GetScale() return self.scale end
    function f:SetScale(s) self.scale = s end
    function f:GetEffectiveScale() return self.scale end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(pt, relTo, relPt, x, y)
        self.setPointCalls = self.setPointCalls + 1
        self.points[#self.points + 1] = { point = pt, relTo = relTo, relPt = relPt, x = x, y = y }
    end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(idx)
        local p = self.points[idx or 1]
        if not p then return nil end
        return p.point, p.relTo, p.relPt, p.x, p.y
    end
    function f:GetLeft()
        local p = self.points[#self.points]
        if not p then return 0 end
        if p.point == "BOTTOMRIGHT" then return p.x - self.w end
        return p.x
    end
    function f:GetRight() return self:GetLeft() + self.w end
    function f:GetBottom()
        local p = self.points[#self.points]
        if not p then return 0 end
        if p.point == "TOPLEFT" then return p.y - self.h end
        return p.y
    end
    function f:GetTop() return self:GetBottom() + self.h end
    function f:Show()
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:SetAlpha(a) self.alpha = a end
    function f:GetAlpha() return self.alpha end
    function f:GetScript(scriptName) return self.scripts[scriptName] end
    function f:SetScript(scriptName, fn) self.scripts[scriptName] = fn end
    function f:HookScript(scriptName, fn)
        local orig = self.scripts[scriptName]
        self.scripts[scriptName] = function(...)
            if orig then orig(...) end
            fn(...)
        end
    end
    function f:SetMovable(v) self.movable = v end
    function f:IsMovable() return self.movable end
    function f:SetClampedToScreen(v) self.clamped = v end
    function f:RegisterForDrag() end
    function f:EnableMouse() end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    function f:SetUserPlaced(v) self.setUserPlacedCalls = self.setUserPlacedCalls + 1; self.userPlaced = v end
    function f:IsUserPlaced() return self.userPlaced end
    function f:SetFrameStrata() end
    function f:SetFrameLevel() end
    function f:GetFrameLevel() return 10 end
    function f:RegisterEvent() end
    function f:CreateTexture()
        return { SetAllPoints = function() end, SetColorTexture = function() end }
    end
    return f
end

CreateFrame = function(_, name) return makeFrame(name or "anon", 100, 100) end

_G.NUM_CONTAINER_FRAMES = 13
for i = 1, 13 do
    _G["ContainerFrame" .. i] = makeFrame("ContainerFrame" .. i, 192, 260)
end
_G.ContainerFrameCombinedBags = makeFrame("ContainerFrameCombinedBags", 380, 460)

local openAllBagsCalls = 0
_G.OpenAllBags = function() openAllBagsCalls = openAllBagsCalls + 1 end
_G.ToggleAllBags = function() openAllBagsCalls = openAllBagsCalls + 1 end
_G.ContainerFrame_GenerateFrame = function() end

local metrics = {
    gameLeft = 0, gameRight = 1920, gameBottom = 0, gameTop = 1080,
    gameWidth = 1920, gameHeight = 1080, deckWidth = 1920,
    workspaceLeft = 1920, workspaceRight = 3840, workspaceBottom = 0, workspaceTop = 1080,
    workspaceWidth = 1920, workspaceHeight = 1080,
    hudScale = 1, screenWidth = 3840, screenHeight = 1080, isSpanned = true,
}
addon.Viewport = { GetMetrics = function() return metrics end }

assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasFrameState.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelRegistry.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPersistence.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasBackpackState.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasForeverBags.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasForeverMap.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasChat.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasProfessions.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelMotion.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasMapPresentation.lua"))("Offhand", addon)
dofile("tests/support/core-bridges.lua").Load(addon, { "Bridges/MoveMyBags/Bridge.lua" })
assert(loadfile("Core/CanvasPanelLifecycle.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelPlacement.lua"))("Offhand", addon)
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", addon)
assert(loadfile("Core/HUDTransientPolicy.lua"))("Offhand", addon)
assert(loadfile("Core/HUDRecovery.lua"))("Offhand", addon)
assert(loadfile("Core/HUDTransientFrames.lua"))("Offhand", addon)
assert(loadfile("Core/SeamRedirect.lua"))("Offhand", addon)

-- TEST 1: MoveMyBags is detected as an active bag owner and yields all native bags.
assert(addon.HasCustomBagAddon() == true, "HasCustomBagAddon must detect MoveMyBags")
local owners = addon.CanvasCompatibility.GetActiveBagOwners()
local foundMoveMyBags = false
for _, owner in ipairs(owners) do
    if owner == "MoveMyBags" then foundMoveMyBags = true end
end
assert(foundMoveMyBags, "CanvasCompatibility.GetActiveBagOwners must report MoveMyBags")

addon.SeamRedirect:HookFrames()
addon.Canvas:EnableFreeDragging()
addon.Canvas:TryMakeFrameDraggable(ContainerFrame6)
addon.Canvas:TryMakeFrameDraggable(ContainerFrameCombinedBags)

assert(ContainerFrame6:GetScript("OnDragStart") == nil and not ContainerFrame6._OffhandMovable,
    "Offhand must not attach OnDragStart to ContainerFrame6 while MoveMyBags is loaded")
assert(ContainerFrameCombinedBags:GetScript("OnDragStart") == nil and not ContainerFrameCombinedBags._OffhandMovable,
    "Offhand must not attach OnDragStart to ContainerFrameCombinedBags while MoveMyBags is loaded")

-- Simulate MoveMyBags placing Reagent Bag (ContainerFrame6) on Mainhand next to Combined Bag.
ContainerFrameCombinedBags.moveMyBags = "attached"
ContainerFrame6.moveMyBags = "attached"
ContainerFrameCombinedBags:ClearAllPoints()
ContainerFrameCombinedBags:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1450, 120)
ContainerFrame6:ClearAllPoints()
ContainerFrame6:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1220, 120)
ContainerFrameCombinedBags:Show()
ContainerFrame6:Show()

local combinedWrites = ContainerFrameCombinedBags.setPointCalls
local reagentWrites = ContainerFrame6.setPointCalls
local reagentUserPlacedWrites = ContainerFrame6.setUserPlacedCalls

-- Even with stale Offhand workspace snapshots in savedWorkspacePositions / openWorkspacePanels,
-- Offhand must not pull ContainerFrame6 back to Offhand or call OpenAllBags.
addon.HUD:LayoutBags()
addon.Canvas:RestoreWorkspacePosition(ContainerFrame6)
addon.Canvas:RestoreWorkspacePosition(ContainerFrameCombinedBags)
addon.Canvas:RepairShownWorkspacePanels()
addon.Canvas:RestorePersistentFrames("reload")
addon.Canvas.OnPanelDragStop(ContainerFrame6)
for _, fn in ipairs(timers) do fn() end

assert(ContainerFrame6.setPointCalls == reagentWrites,
    "Offhand must not overwrite MoveMyBags' ContainerFrame6 placement even with stale workspace data")
assert(ContainerFrameCombinedBags.setPointCalls == combinedWrites,
    "Offhand must not overwrite MoveMyBags' ContainerFrameCombinedBags placement")
assert(ContainerFrame6.setUserPlacedCalls == reagentUserPlacedWrites,
    "Offhand must not reset SetUserPlaced on ContainerFrame6 while MoveMyBags owns it")
assert(openAllBagsCalls == 0,
    "RestorePersistentFrames must not auto-open native bags while MoveMyBags owns them")
assert(addon.HUDCompatibility.ShouldPreservePopupPosition(ContainerFrame6, "ContainerFrame6"),
    "Popup recovery must preserve MoveMyBags container frames even when IsUserPlaced is false")
assert(addon.HUDCompatibility.ShouldPreservePopupPosition(ContainerFrameCombinedBags, "ContainerFrameCombinedBags"),
    "Popup recovery must preserve MoveMyBags combined bag even when IsUserPlaced is false")
assert(addon.db.savedWorkspacePositions.ContainerFrame6 ~= nil,
    "Yielding to MoveMyBags must keep historical Offhand coordinates dormant rather than deleting them")

print("PASS: MoveMyBags coexistence yields native bag drag, layout, persistence, and popup recovery")

-- TEST 2: Native bags WITHOUT MoveMyBags: Combined Bag + Reagent Bag on Mainhand must not overlap,
-- and saved Mainhand positions must be respected by LayoutBags().
loadedAddons.MoveMyBags = false
ContainerFrame6.moveMyBags = nil
ContainerFrameCombinedBags.moveMyBags = nil
addon.db.savedWorkspacePositions = {}
addon.db.savedMainPositions = {}
addon.db.nativeBackpackWorkspacePosition = nil
addon.db.nativeBackpackWorkspaceOpen = nil

assert(addon.HasCustomBagAddon() == false, "HasCustomBagAddon must clear when MoveMyBags is unloaded")
addon.HUD:LayoutBags()

local cbPt = ContainerFrameCombinedBags.points[#ContainerFrameCombinedBags.points]
local rgPt = ContainerFrame6.points[#ContainerFrame6.points]
assert(cbPt and rgPt, "Both Combined Bag and Reagent Bag must be positioned by LayoutBags")
local cbRight = cbPt.x
local cbLeft = cbRight - ContainerFrameCombinedBags:GetWidth()
local rgRight = rgPt.x
local rgLeft = rgRight - ContainerFrame6:GetWidth()
assert(rgRight <= cbLeft - 4,
    string.format("Reagent Bag (right=%.1f) must dock beside Combined Bag (left=%.1f), not overlap it", rgRight, cbLeft))
assert(rgLeft >= metrics.gameLeft and cbRight <= metrics.gameRight,
    "Both Mainhand bags must remain inside Mainhand bounds")

-- TEST 3: Saved Mainhand position on Combined Bag or Reagent Bag survives HUD:LayoutBags().
addon.db.savedMainPositions.ContainerFrameCombinedBags = { point = "TOPLEFT", x = 900, y = 700 }
addon.db.savedMainPositions.ContainerFrame6 = { point = "TOPLEFT", x = 680, y = 700 }
addon.HUD:LayoutBags()
local cbSavedPt = ContainerFrameCombinedBags.points[#ContainerFrameCombinedBags.points]
local rgSavedPt = ContainerFrame6.points[#ContainerFrame6.points]
assert(cbSavedPt.point == "TOPLEFT" and cbSavedPt.x == 900 and cbSavedPt.y == 700,
    "LayoutBags must preserve saved Mainhand position for ContainerFrameCombinedBags")
assert(rgSavedPt.point == "TOPLEFT" and rgSavedPt.x == 680 and rgSavedPt.y == 700,
    "LayoutBags must preserve saved Mainhand position for ContainerFrame6")

print("PASS: Native Combined Bag + Reagent Bag Mainhand layout avoids overlap and preserves saved Mainhand placement")
