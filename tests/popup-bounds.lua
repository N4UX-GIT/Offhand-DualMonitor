local addon = {
    modules = {},
    db = { enabled = true, seamRedirect = true },
}

UIParent = { GetEffectiveScale = function() return 0.5 end }
InCombatLockdown = function() return false end
C_Timer = { After = function(_, fn) fn() end }
addon.Viewport = {
    GetMetrics = function()
        return {
            isSpanned = true, hudScale = 1,
            gameLeft = 1000, gameRight = 3000,
            gameBottom = 100, gameTop = 1100,
            workspaceLeft = 0, workspaceRight = 1000,
            workspaceBottom = 0, workspaceTop = 1200,
        }
    end,
}

local modifiedMenus = {}
Menu = {
    ModifyMenu = function(tag, callback) modifiedMenus[tag] = callback end,
}

local secureHooks = {}
hooksecurefunc = function(target, method, callback)
    if type(target) == "table" then
        local original = target[method]
        target[method] = function(...)
            local result = original and original(...)
            callback(...)
            return result
        end
        secureHooks[target] = callback
        return
    end
    callback = method
    local original = _G[target]
    _G[target] = function(...)
        local result = original and original(...)
        callback(...)
        return result
    end
    secureHooks[target] = callback
end
ToggleDropDownMenu = function() end

local function menuFrame()
    local frame = {
        shown = true, left = 2800, right = 3100, top = 200, bottom = 0,
        points = {},
    }
    function frame:GetEffectiveScale() return 0.5 end
    function frame:GetLeft() return self.left end
    function frame:GetRight() return self.right end
    function frame:GetTop() return self.top end
    function frame:GetBottom() return self.bottom end
    function frame:IsShown() return self.shown end
    function frame:IsForbidden() return false end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...)
        self.points[#self.points + 1] = {...}
    end
    return frame
end

local function tooltipFrame(left, right, top, bottom, owner)
    local frame = menuFrame()
    frame.left, frame.right, frame.top, frame.bottom = left, right, top, bottom
    frame.owner, frame.scripts = owner, {}
    function frame:GetOwner() return self.owner end
    function frame:SetOwner(owner, anchor)
        self.owner, self.anchor = owner, anchor
        self.setOwnerCalls = (self.setOwnerCalls or 0) + 1
    end
    function frame:IsObjectType(kind) return kind == "GameTooltip" end
    function frame:HookScript(script, callback) self.scripts[script] = callback end
    return frame
end

local itemOwner = menuFrame()
itemOwner.left, itemOwner.right, itemOwner.top, itemOwner.bottom = 850, 950, 700, 600
GameTooltip = tooltipFrame(900, 1250, 720, 300, itemOwner)
ShoppingTooltip1 = tooltipFrame(1250, 1500, 720, 350, GameTooltip)
ShoppingTooltip2 = tooltipFrame(0, 0, 0, 0, GameTooltip)
ShoppingTooltip2.left, ShoppingTooltip2.right = 1500, 1750
ShoppingTooltip2.top, ShoppingTooltip2.bottom = 720, 350
ShoppingTooltip3 = tooltipFrame(0, 0, 0, 0, GameTooltip)
ShoppingTooltip3.shown = false
GameTooltip_ShowCompareItem = function() end
GameTooltip_SetDefaultAnchor = function(tooltip, owner)
    tooltip:SetOwner(owner, "ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -13, 0)
end
TooltipComparisonManager = {
    tooltip = GameTooltip,
    AnchorShoppingTooltips = function(self)
        ShoppingTooltip1:ClearAllPoints()
        ShoppingTooltip1:SetPoint("TOPLEFT", self.tooltip, "TOPRIGHT", 0, -10)
        ShoppingTooltip2:ClearAllPoints()
        ShoppingTooltip2:SetPoint("TOPLEFT", ShoppingTooltip1, "TOPRIGHT", 0, 0)
    end,
}

assert(loadfile("Core/PopupBounds.lua"))("Offhand", addon)
addon.PopupBounds:Initialize()

-- SetOwner occurs before Retail shows and sizes an item tooltip. Direction
-- selection must therefore work while the tooltip itself is still hidden.
GameTooltip.shown = false
GameTooltip:SetOwner(itemOwner, "ANCHOR_RIGHT")
assert(GameTooltip.setOwnerCalls == 2 and GameTooltip.anchor == "ANCHOR_NONE"
        and GameTooltip._OffhandOwnerDirection == "ANCHOR_LEFT",
    "seam-facing tooltip did not enter stable manual owner mode")
local ownerPoint = GameTooltip.points[1]
assert(ownerPoint and ownerPoint[1] == "TOPRIGHT" and ownerPoint[2] == itemOwner
        and ownerPoint[3] == "TOPLEFT",
    "hidden Retail item tooltip did not receive its inward owner anchor")

-- Retail's Combined Backpack uses the default-anchor helper. Its full-screen
-- point is assigned after SetOwner, so the completed helper must be routed.
GameTooltip_SetDefaultAnchor(GameTooltip, itemOwner)
ownerPoint = GameTooltip.points[1]
assert(GameTooltip.anchor == "ANCHOR_NONE"
        and ownerPoint and ownerPoint[1] == "TOPRIGHT"
        and ownerPoint[2] == itemOwner and ownerPoint[3] == "TOPLEFT",
    "Retail default tooltip anchor overwrote the Offhand seam direction")

assert(GameTooltip.scripts.OnShow and not ShoppingTooltip1.scripts.OnShow
        and not ShoppingTooltip1.scripts.OnSizeChanged,
    "comparison tooltips retained a mid-transaction layout observer")
GameTooltip.shown = true
GameTooltip.scripts.OnShow(GameTooltip)
TooltipComparisonManager:AnchorShoppingTooltips()
local comparisonPoint = ShoppingTooltip1.points[1]
local secondaryPoint = ShoppingTooltip2.points[1]
ownerPoint = GameTooltip.points[1]
assert(comparisonPoint and comparisonPoint[1] == "TOPLEFT"
        and comparisonPoint[2] == GameTooltip
        and comparisonPoint[3] == "TOPRIGHT"
        and secondaryPoint and secondaryPoint[2] == ShoppingTooltip1
        and ownerPoint and ownerPoint[1] == "TOPLEFT"
        and ownerPoint[2] == UIParent and ownerPoint[3] == "BOTTOMLEFT"
        and math.abs(ownerPoint[4] - 138) < 0.01,
    "completed comparison group was not translated inside the workspace")

-- Blizzard can rebuild the native comparison layout repeatedly while item
-- data loads. The completed post-hook must produce the same inward chain with
-- no deferred callback or primary-tooltip movement.
ShoppingTooltip1:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 0, -10)
GameTooltip_ShowCompareItem(GameTooltip)
comparisonPoint = ShoppingTooltip1.points[1]
assert(comparisonPoint and comparisonPoint[1] == "TOPLEFT"
        and comparisonPoint[2] == GameTooltip
        and #GameTooltip.points == 1,
    "legacy comparison refresh rewrote Blizzard's comparison dependency")

-- A second modern refresh must retain Blizzard's acyclic primary -> secondary
-- graph. Reversing these anchors once makes the next native transaction error.
TooltipComparisonManager:AnchorShoppingTooltips()
comparisonPoint = ShoppingTooltip1.points[1]
secondaryPoint = ShoppingTooltip2.points[1]
assert(comparisonPoint and comparisonPoint[2] == GameTooltip
        and secondaryPoint and secondaryPoint[2] == ShoppingTooltip1,
    "comparison refresh retained a circular Offhand anchor graph")

-- An Offhand owner on the other side of the workspace opens rightward even
-- when Blizzard supplied a non-directional default anchor.
local leftOwner = menuFrame()
leftOwner.left, leftOwner.right = 50, 150
GameTooltip_SetDefaultAnchor(GameTooltip, leftOwner)
GameTooltip.left, GameTooltip.right = 150, 450
ShoppingTooltip1.left, ShoppingTooltip1.right = 450, 700
ShoppingTooltip2.left, ShoppingTooltip2.right = 700, 950
ownerPoint = GameTooltip.points[1]
assert(GameTooltip._OffhandOwnerDirection == "ANCHOR_RIGHT"
        and ownerPoint and ownerPoint[1] == "TOPLEFT"
        and ownerPoint[2] == leftOwner and ownerPoint[3] == "TOPRIGHT",
    "default tooltip anchor did not route by the owner's physical workspace side")

-- The completed comparison-manager transaction must also chain away from the
-- seam when the primary tooltip opens rightward.
TooltipComparisonManager:AnchorShoppingTooltips()
comparisonPoint = ShoppingTooltip1.points[1]
assert(comparisonPoint and comparisonPoint[1] == "TOPLEFT"
        and comparisonPoint[2] == GameTooltip
        and comparisonPoint[3] == "TOPRIGHT"
        and ShoppingTooltip2.points[1][2] == ShoppingTooltip1,
    "in-bounds rightward comparison graph was unnecessarily rewritten")

GameTooltip.scripts.OnHide(GameTooltip)
assert(GameTooltip._OffhandManagedOwner == nil
        and GameTooltip._OffhandOwnerDirection == nil,
    "hidden item tooltip retained stale Offhand anchor ownership")

local cursorOwned = tooltipFrame(900, 1250, 720, 300, UIParent)
assert(not addon.PopupBounds:ArrangeTooltipComparisons(cursorOwned)
        and #cursorOwned.points == 0,
    "cursor/world-owned tooltip was incorrectly pinned to Offhand")

local modern = menuFrame()
local acquired
local rootDescription = {
    AddMenuAcquiredCallback = function(_, callback) acquired = callback end,
}
assert(modifiedMenus.MENU_UNIT_TARGET, "modern unit-menu tag was not registered")
modifiedMenus.MENU_UNIT_TARGET(nil, rootDescription)
assert(acquired, "modern menu did not register its acquired-frame callback")
acquired(modern)
local point = modern.points[1]
assert(point and point[1] == "TOPLEFT" and point[2] == UIParent
        and point[3] == "BOTTOMLEFT" and math.abs(point[4] - 2696) < 0.01
        and math.abs(point[5] - 304) < 0.01,
    "modern context menu was not moved up and left inside Mainhand")

local legacy = menuFrame()
DropDownList1 = legacy
ToggleDropDownMenu(1, nil, { unit = "target" })
assert(#legacy.points == 1,
    "legacy unit dropdown was not constrained after Blizzard positioned it")

local unrelated = menuFrame()
DropDownList1 = unrelated
ToggleDropDownMenu(1, nil, {})
assert(#unrelated.points == 0, "unrelated legacy dropdown was moved")

local inside = menuFrame()
inside.left, inside.right, inside.top, inside.bottom = 1500, 1700, 600, 400
assert(not addon.PopupBounds:Constrain(inside) and #inside.points == 0,
    "already visible context menu was unnecessarily reanchored")

-- Model Retail secret numbers through the capability API. Every coordinate
-- and both scale inputs must be rejected before arithmetic or native writes.
do
    local previousSecret, previousScale = issecretvalue, UIParent.GetEffectiveScale
    local secretNumber = 147852
    issecretvalue = function(value) return value == secretNumber end
    for _, field in ipairs({'left', 'right', 'top', 'bottom', 'frameScale', 'uiScale'}) do
        local owner = menuFrame()
        owner.left, owner.right, owner.top, owner.bottom = 850, 950, 700, 600
        if field == 'frameScale' then
            owner.GetEffectiveScale = function() return secretNumber end
        elseif field == 'uiScale' then
            UIParent.GetEffectiveScale = function() return secretNumber end
        else owner[field] = secretNumber end
        local tooltip = tooltipFrame(900, 1250, 720, 300, owner)
        assert(not addon.PopupBounds:RedirectTooltipOwner(tooltip, owner, 'ANCHOR_RIGHT')
            and not tooltip.setOwnerCalls and #tooltip.points == 0,
            'secret '..field..' must preserve Blizzard tooltip ownership and anchors')
        assert(not addon.PopupBounds:Constrain(owner) and #owner.points == 0,
            'secret '..field..' must prevent menu arithmetic and repositioning')
        UIParent.GetEffectiveScale = previousScale
    end
    local root = tooltipFrame(900, 1250, 720, 300, itemOwner)
    root._OffhandManagedOwner, root._OffhandOwnerDirection = itemOwner, 'ANCHOR_LEFT'
    local oldLeft = ShoppingTooltip1.left
    ShoppingTooltip1.left = secretNumber
    assert(not addon.PopupBounds:ArrangeTooltipComparisons(root) and #root.points == 0,
        'unknown comparison bounds must leave the complete tooltip group native')
    ShoppingTooltip1.left = oldLeft
    issecretvalue, UIParent.GetEffectiveScale = previousSecret, previousScale
end

InCombatLockdown = function() return true end
local combat = menuFrame()
assert(not addon.PopupBounds:Constrain(combat) and #combat.points == 0,
    "context menu was mutated during combat")

print("PASS: modern and legacy unit context menus stay inside the physical Mainhand bounds")
