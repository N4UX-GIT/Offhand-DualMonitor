-- Actual PopupBounds plus a deterministic native-style clamp/anchor model.
-- This is geometry coverage, not native engine or protected-action acceptance.
local source = arg and arg[1] or "Core/PopupBounds.lua"
local assertions = 0
local function Check(value, message) assertions = assertions + 1; assert(value, message) end
local combat, writes = false, 0
InCombatLockdown = function() return combat end
local metrics = {isSpanned = true, hudScale = 1, gameLeft = 0, gameRight = 650,
    gameBottom = 0, gameTop = 600, workspaceLeft = 650, workspaceRight = 1000, workspaceBottom = 0, workspaceTop = 600}

local function Case(client, uiScale, localScale, workspace, direction, count, raised, scenario)
    local metrics = scenario and scenario.metrics or metrics
    local canvasWidth = scenario and scenario.canvasWidth or 1000
    local canvasHeight = scenario and scenario.canvasHeight or 600
    UIParent = {GetWidth = function() return canvasWidth end, GetHeight = function() return canvasHeight end,
        GetEffectiveScale = function() return uiScale end}
    local addon = {modules = {}, db = {enabled = true, seamRedirect = true},
        Viewport = {GetMetrics = function() return metrics end}}
    addon[client] = true
    assert(loadfile(source))("Offhand", addon)
    local owner = UIParent
    if workspace then owner = {GetEffectiveScale = function() return uiScale end, IsObjectType = function() return false end,
        ClearAllPoints = function() error("item owner anchors changed") end, SetPoint = function() error("item owner anchors changed") end,
        GetLeft = function() return metrics.workspaceLeft + 100 end,
        GetRight = function() return metrics.workspaceLeft + 120 end,
        GetBottom = function() return 300 end, GetTop = function() return 330 end} end
    local width = scenario and scenario.cardWidth or (workspace and 100 or 150)
    local rootX = scenario and scenario.rootLeft or workspace and (direction == "left" and 730 or 800)
        or (direction == "left" and count * width or count > 2 and 100 or 400)
    local function Tooltip(parentOwner, anchor)
        local f = {owner = parentOwner, insets = {0,0,0,0}, clamped = true, width = width, height = 120,
            shown = true, scale = localScale}
        function f:UILeft()
            local x = anchor()
            if self.clamped then
                x = math.max(-self.insets[1] * self.scale, math.min(x, canvasWidth - self.insets[2] * self.scale - self.width))
            end
            return x
        end
        function f:UITop()
            local y = self.relative and self.relative:UITop() or (type(raised) == "number" and raised or raised and 100 or 400)
            if self.clamped then y = math.min(canvasHeight - self.insets[3] * self.scale,
                math.max(y, -self.insets[4] * self.scale + self.height)) end
            return y
        end
        function f:GetLeft() return self:UILeft() / self.scale end
        function f:GetRight() return (self:UILeft() + self.width) / self.scale end
        function f:GetTop() return self:UITop() / self.scale end
        function f:GetBottom() return (self:UITop() - self.height) / self.scale end
        function f:GetScale() return self.scale end
        function f:GetEffectiveScale() return uiScale * self.scale end
        function f:SetScale() error("feasible comparison group changed scale") end
        function f:GetOwner() return self.owner end
        function f:IsObjectType(kind) return kind == "GameTooltip" end
        function f:IsShown() return self.shown end
        function f:IsForbidden() return self.forbidden == true end
        function f:IsProtected() return self.protected == true end
        function f:GetClampRectInsets() return unpack(self.insets) end
        function f:SetClampRectInsets(...) Check(not combat, "clamp changed during combat"); self.insets = {...}; writes = writes + 1 end
        function f:IsClampedToScreen() return self.clamped end
        function f:SetClampedToScreen(value) Check(not combat, "clamping changed during combat"); self.clamped = value; writes = writes + 1 end
        function f:ClearAllPoints() error("native comparison anchor graph changed") end
        function f:SetPoint() error("native comparison anchor graph changed") end
        return f
    end
    local root = Tooltip(owner, function() return rootX end)
    GameTooltip, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3 = root, nil, nil, nil
    local cards, previous = {}, root
    for i = 1, count do
        local relative = previous
        local card = Tooltip(root, function()
            return direction == "left" and (relative:UILeft() - width) or (relative:UILeft() + relative.width)
        end)
        card.scale = localScale * (i % 2 == 0 and .9 or 1.1)
        card.relative, card.height = root, raised and 220 or 120
        function card:GetNumPoints() return 2 end
        function card:GetPoint(index)
            if index == 1 then return "TOP", root, "TOP", 0, 0 end
            if scenario and i == 2 then
                return direction == "left" and "TOPRIGHT" or "TOPLEFT", relative,
                    direction == "left" and "TOPLEFT" or "TOPRIGHT", 0, 0
            end
            return direction == "left" and "RIGHT" or "LEFT", relative,
                direction == "left" and "LEFT" or "RIGHT", 0, 0
        end
        cards[i], previous = card, card
        _G["ShoppingTooltip" .. i] = card
    end
    if scenario and direction == "right" and count == 2 then
        -- Blizzard anchors ShoppingTooltip2 nearest the root on the right.
        ShoppingTooltip1, ShoppingTooltip2 = cards[2], cards[1]
        root.shoppingTooltips = {ShoppingTooltip1, ShoppingTooltip2}
    else
        root.shoppingTooltips = cards
    end
    addon.PopupBounds:UpdateClassicTooltipClamp(root)
    for _, card in ipairs(cards) do addon.PopupBounds:UpdateClassicTooltipClamp(card) end
    local handled = addon.PopupBounds:ArrangeTooltipComparisons(root)
    local regionLeft = workspace and metrics.workspaceLeft or metrics.gameLeft
    local regionRight = workspace and metrics.workspaceRight or metrics.gameRight
    local oversized = (count + 1) * width > regionRight - regionLeft - 24
    local left = oversized and 0 or regionLeft + 12
    local right = oversized and canvasWidth or regionRight - 12
    for _, tip in ipairs({root, unpack(cards)}) do
        Check(tip:UILeft() >= left - .001 and tip:UILeft() + tip.width <= right + .001, "comparison group escaped its physical region")
        if not workspace and not oversized then
            Check(tip:UITop() <= metrics.gameTop - 12 + .001
                and tip:UITop() - tip.height >= metrics.gameBottom + 12 - .001, "comparison group escaped its vertical bounds")
        end
    end
    previous = root
    for _, card in ipairs(cards) do
        Check(math.abs(direction == "left" and (card:UILeft() + width - previous:UILeft())
            or (previous:UILeft() + previous.width - card:UILeft())) < .001, "comparison cards overlap or lost their native adjacency")
        Check(card.insets[1] == 0 and card.insets[2] == 0, "shopping card retained independent regional clamping")
        Check(card.owner == root, "comparison owner changed")
        previous = card
    end
    Check(handled, "completed group was not handled")
    local before = writes
    addon.PopupBounds:ArrangeTooltipComparisons(root)
    Check(writes == before, "unchanged completed group churned clamp writes")
    combat = true
    addon.PopupBounds:ArrangeTooltipComparisons(root)
    Check(writes == before, "comparison transaction changed in combat")
    combat = false
    cards[1].protected = true
    addon.PopupBounds:ArrangeTooltipComparisons(root)
    addon.PopupBounds:UpdateClassicTooltipClamp(root)
    Check(writes == before, "partially protected comparison group was mutated")
    cards[1].protected = nil
    local nativePoint = cards[1].GetPoint
    cards[1].GetPoint = function() return "TOPLEFT", UIParent, "BOTTOMLEFT", 500, 200 end
    addon.PopupBounds:ArrangeTooltipComparisons(root)
    Check(root.insets[1] == 0 and root.insets[2] == 0, "externally anchored comparisons did not yield to the native policy")
    cards[1].GetPoint = nativePoint
    addon.PopupBounds:ArrangeTooltipComparisons(root)
    TipTac = {}
    root.insets = {2,3,4,5}
    addon.PopupBounds:ArrangeTooltipComparisons(root)
    Check(root.insets[1] == 2 and root.insets[2] == 3 and root.insets[3] == 4 and root.insets[4] == 5,
        "yielding to a replacement overwrote another owner's clamp values")
    TipTac, root.insets = nil, {0,0,0,0}
    addon.PopupBounds:ArrangeTooltipComparisons(root)
    -- Hidden cards release root reservations on the next native refresh.
    for _, card in ipairs(cards) do card.shown = false end
    addon.PopupBounds:ArrangeTooltipComparisons(root)
    Check(math.abs(root.insets[2] * localScale - (canvasWidth - regionRight + 12)) < .001,
        "hidden comparisons retained their reserved root width")
    if scenario then
        metrics.isSpanned = false
        addon.PopupBounds:ApplyLayout()
        Check(root.insets[1] == 0 and root.insets[2] == 0, "unspanning did not release owned root bounds")
        metrics.isSpanned = true
        addon.PopupBounds:ApplyLayout()
        Check(root.insets[1] ~= 0, "respanning did not restore the regional clamp")
    end
    addon.db.enabled = false
    addon.PopupBounds:ApplyLayout()
    Check(root.insets[1] == 0 and root.insets[2] == 0, "disabling did not release owned root bounds")
end

-- Beta 30 report: two equipped ring cards beside a bag tooltip on a narrow,
-- offset portrait workspace. Use normalized geometry with the same physical
-- proportions and exercise both a fitting group and one that needs the canvas.
local portrait = {
    canvasWidth = 3000, canvasHeight = 1920,
    metrics = {isSpanned = true, hudScale = 1, gameLeft = 0, gameRight = 1920,
        gameBottom = 237, gameTop = 1317, workspaceLeft = 1920, workspaceRight = 3000,
        workspaceBottom = 0, workspaceTop = 1920},
}
for _, direction in ipairs({"left", "right"}) do
    portrait.cardWidth = 348
    portrait.rootLeft = direction == "left" and 2214 or 2250
    Case("isForever", .366, 1, true, direction, 2, false, portrait)
    portrait.cardWidth = 357
    portrait.rootLeft = direction == "left" and 2214 or 1929
    Case("isForever", .366, 1, true, direction, 2, false, portrait)
end

for _, client in ipairs({"isRetail", "isForever"}) do
    for _, scale in ipairs({.5, 1, 1.5}) do
        for _, direction in ipairs({"left", "right"}) do
            Case(client, scale, 1.25, false, direction, 2)
            Case(client, scale, 1, false, direction, 4)
            Case(client, scale, .8, true, direction, 1)
        end
    end
end
Case("isForever", .581, 1.25, false, "right", 2, true)
metrics.gameBottom, metrics.gameTop = 150, 500
Case("isForever", .581, .8, false, "left", 2, 300)
print("PASS: " .. assertions .. " grouped comparison bounds, native adjacency, scaling, cleanup, idempotence and safety assertions")
