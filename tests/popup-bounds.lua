local addon = {
    isRetail = true,
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

-- Classic must retain the native owner's direction on both workspace halves.
-- Do not apply either inward-direction or manual point corrections there.
InCombatLockdown = function() return false end
addon.isRetail = false
local originalTooltipPoint = addon.PopupBounds.SetTooltipPoint
addon.PopupBounds.SetTooltipPoint = function() error("Classic tooltip entered manual point placement") end
for _, owner in ipairs({ itemOwner, leftOwner }) do
    local before = GameTooltip.setOwnerCalls
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    assert(GameTooltip.anchor == "ANCHOR_RIGHT" and GameTooltip.setOwnerCalls == before + 1,
        "Classic must not reset tooltip ownership or reverse direction on either workspace half")
    before = GameTooltip.setOwnerCalls
    GameTooltip_SetDefaultAnchor(GameTooltip, owner)
    assert(GameTooltip.anchor == "ANCHOR_NONE" and GameTooltip.setOwnerCalls == before + 1,
        "Classic's completed native default-anchor transaction must remain untouched")
end
assert(not addon.PopupBounds:ArrangeTooltipComparisons(GameTooltip),
    "Classic comparison groups must remain native rather than moving only the backdrop root")
addon.PopupBounds.SetTooltipPoint = originalTooltipPoint
print("PASS: modern and legacy unit context menus stay inside the physical Mainhand bounds")

-- Forever on a mixed-height span. Simulate the named presentation roots
-- without registering scripts on EllesmereUI or its native Gamepad input.
addon.isForever = true
EllesmereUI = {}
local span = {
    isSpanned = true,
    gameLeft = 1440, gameRight = 4000, gameBottom = 0, gameTop = 1440,
    workspaceLeft = 0, workspaceRight = 1440, workspaceBottom = 0, workspaceTop = 2560,
}
addon.Viewport.GetMetrics = function() return span end

local function ellesmereWindow(left, right, top, bottom)
    local frame = menuFrame()
    frame.left, frame.right, frame.top, frame.bottom = left, right, top, bottom
    frame.scale = 1
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    function frame:GetNumPoints() return #self.points end
    function frame:GetPoint(index) return unpack(self.points[index]) end
    function frame:GetScale() return self.scale end
    function frame:SetScale(value) self.scale = value end
    function frame:GetEffectiveScale() return self.scale * 0.5 end
    function frame:IsVisible() return self.shown end
    function frame:IsProtected() return self.protected end
    return frame
end

EllesmereUIFrame = ellesmereWindow(830, 3170, 2130, 430)
EUIFirstInstallPopup = ellesmereWindow(50, 950, 2210, 1710)
EUIConfirmPopup = ellesmereWindow(1650, 2350, 1690, 1490)
EUIInfoPopup = ellesmereWindow(1650, 2350, 1690, 1490)
EUIInfoPopup.protected = true
InCombatLockdown = function() return true end
addon.PopupBounds:RefreshEllesmereWindows()
assert(EllesmereUIFrame.points[1][1] == "CENTER", "Ellesmere windows must defer during combat")
InCombatLockdown = function() return false end
addon.PopupBounds:RefreshEllesmereWindows()
local settingsPoint = EllesmereUIFrame.points[1]
local fittedScale = EllesmereUIFrame:GetScale()
assert(settingsPoint[1] == "TOPLEFT" and settingsPoint[2] == UIParent
    and math.abs(settingsPoint[4] * fittedScale - 1444) < 0.01
    and math.abs(settingsPoint[5] * fittedScale - 1436) < 0.01
    and math.abs(1700 * fittedScale - 1432) < 0.01,
    "oversized settings must fit inside the physical Mainhand")
assert(EUIFirstInstallPopup.points[1][1] == "CENTER" and EUIInfoPopup.points[1][1] == "CENTER",
    "visible workspace and protected popup anchors must be preserved")
assert(EUIConfirmPopup.points[1][1] == "TOPLEFT" and EUIConfirmPopup:GetScale() == 1,
    "modal in the physical void must be recovered without shrinking it")
addon.PopupBounds:RefreshEllesmereWindows()
assert(EllesmereUIFrame.points[1] == settingsPoint, "refresh must not repeat an active placement")

EllesmereUIFrame:ClearAllPoints()
EllesmereUIFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 1600, 1200)
EUIConfirmPopup.shown = false
span.isSpanned = false
addon.PopupBounds:RefreshEllesmereWindows()
assert(EllesmereUIFrame.points[1][4] == 1600, "Offhand must yield to a later Ellesmere placement")
assert(EUIConfirmPopup.points[1][1] == "CENTER", "hidden modal must recover its original anchor")

EllesmereUIFrame = ellesmereWindow(830, 3170, 2130, 430)
span.isSpanned = true
addon.PopupBounds:RefreshEllesmereWindows()
span.isSpanned = false
addon.PopupBounds:RefreshEllesmereWindows()
assert(EllesmereUIFrame.points[1][1] == "CENTER" and EllesmereUIFrame:GetScale() == 1,
    "span restore must release an unchanged settings anchor and temporary scale")

UIParent.GetWidth = function() return 4000 end
UIParent.GetHeight = function() return 2560 end
local toolbar = ellesmereWindow(1428, 2572, 2560, 2440)
local hoverZone = {}
EllesmereUnlockMode = {
    IsVisible = function(self) return self.visible end,
    GetChildren = function() return hoverZone, toolbar end,
    visible = true,
}
function hoverZone:GetParent() return EllesmereUnlockMode end
toolbar.GetParent = hoverZone.GetParent
toolbar._hoverZone = hoverZone
EllesmereUI.GetUnlockModeTopBarAnchor = function() return hoverZone end
-- Follow the anchor and scale so a changed native canvas is observable.
function toolbar:GetWidth() return 1144 end
function toolbar:GetHeight() return 120 end
function toolbar:GetLeft()
    local x = self.points[1][4]
    return UIParent:GetWidth() / (2 * self.scale) + x - self:GetWidth() / 2
end
function toolbar:GetRight() return self:GetLeft() + self:GetWidth() end
function toolbar:GetTop() return UIParent:GetHeight() / self.scale + self.points[1][5] end
function toolbar:GetBottom() return self:GetTop() - self:GetHeight() end
toolbar:ClearAllPoints()
toolbar:SetPoint("TOP", UIParent, "TOP", 0, 20)
span.isSpanned = true
addon.PopupBounds:RefreshEllesmereWindows()
assert(toolbar.points[1][5] == 20, "Unlock Mode's native entrance animation must settle first")
toolbar:ClearAllPoints()
toolbar:SetPoint("TOP", UIParent, "TOP", 0, 0)
addon.PopupBounds:RefreshEllesmereWindows()
assert(toolbar.points[1][4] == -1280 and toolbar.points[1][5] == 0 and toolbar:GetScale() == 1,
    "the toolbar must fit the portrait display while preserving the physical hover edge")
UIParent.GetWidth = function() return 4040 end
span.workspaceRight, span.gameLeft, span.gameRight = 700, 700, 4040
addon.PopupBounds:RefreshEllesmereWindows()
assert(toolbar:GetLeft() * toolbar:GetScale() >= 0
    and toolbar:GetRight() * toolbar:GetScale() <= 700,
    "an owned toolbar must refit when span geometry settles or resizes")
local settledPoint, settledScale = toolbar.points[1], toolbar:GetScale()
addon.PopupBounds:RefreshEllesmereWindows()
assert(toolbar.points[1] == settledPoint and toolbar:GetScale() == settledScale,
    "stable toolbar geometry must not rewrite anchors or accumulate scale")
EllesmereUnlockMode.visible = false
toolbar.shown = false
addon.PopupBounds:RefreshEllesmereWindows()
assert(toolbar.points[1][4] == 0 and toolbar:GetScale() == 1,
    "the Unlock Mode anchor and original scale must return to EllesmereUI on close")
print("PASS: Forever Ellesmere windows and Unlock Mode toolbar fit physical display bounds")
