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
ShoppingTooltip2.shown = false
ShoppingTooltip3 = tooltipFrame(0, 0, 0, 0, GameTooltip)
ShoppingTooltip3.shown = false
GameTooltip_ShowCompareItem = function() end

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

assert(GameTooltip.scripts.OnShow and ShoppingTooltip1.scripts.OnShow
        and not ShoppingTooltip1.scripts.OnSizeChanged,
    "Blizzard item tooltips did not receive stable layout observers")
GameTooltip.shown = true
GameTooltip.scripts.OnShow(GameTooltip)
ShoppingTooltip1.scripts.OnShow(ShoppingTooltip1)
local comparisonPoint = ShoppingTooltip1.points[1]
assert(comparisonPoint and comparisonPoint[1] == "TOPRIGHT"
        and comparisonPoint[2] == GameTooltip
        and comparisonPoint[3] == "TOPLEFT"
        and comparisonPoint[5] == -10,
    "equipped-item comparison did not anchor inward from the primary tooltip")

-- Blizzard can rebuild the native comparison layout repeatedly while item
-- data loads. The completed post-hook must produce the same inward chain with
-- no deferred callback or primary-tooltip movement.
ShoppingTooltip1:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 0, -10)
GameTooltip_ShowCompareItem(GameTooltip)
comparisonPoint = ShoppingTooltip1.points[1]
assert(comparisonPoint and comparisonPoint[1] == "TOPRIGHT"
        and comparisonPoint[2] == GameTooltip
        and #GameTooltip.points == 1,
    "comparison refresh moved the primary tooltip or retained the seam-facing side")

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

InCombatLockdown = function() return true end
local combat = menuFrame()
assert(not addon.PopupBounds:Constrain(combat) and #combat.points == 0,
    "context menu was mutated during combat")

print("PASS: modern and legacy unit context menus stay inside the physical Mainhand bounds")
