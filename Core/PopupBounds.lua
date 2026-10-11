-- Keep transient unit context menus inside the physical Mainhand rectangle.
-- Blizzard evaluates overflow against the complete spanned top-level parent,
-- including the Offhand monitor and any physical void between displays.
local _, Offhand = ...
local PopupBounds = {}
Offhand.modules.PopupBounds = PopupBounds
Offhand.PopupBounds = PopupBounds

local unitMenuTags = {
    "MENU_UNIT_TARGET", "MENU_UNIT_PLAYER", "MENU_UNIT_SELF", "MENU_UNIT_PET",
    "MENU_UNIT_FOCUS", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER",
    "MENU_UNIT_FRIEND", "MENU_UNIT_CHAT_ROSTER",
}

local function Active()
    if not Offhand.db or not Offhand.db.enabled or not Offhand.db.seamRedirect then return false end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    return metrics and metrics.isSpanned and metrics or false
end

local function Positionable(frame)
    if not frame or not frame.GetLeft or not frame.GetRight
        or not frame.GetTop or not frame.GetBottom or not frame.GetEffectiveScale
        or not frame.ClearAllPoints or not frame.SetPoint then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end

local function Accessible(frame)
    if not Positionable(frame) then return false end
    if frame.IsShown and not frame:IsShown() then return false end
    return true
end

local function FrameBounds(frame)
    if not Accessible(frame) then return nil end
    local uiScale = UIParent and UIParent.GetEffectiveScale
        and UIParent:GetEffectiveScale() or 1
    local frameScale = frame:GetEffectiveScale()
    if not uiScale or uiScale <= 0 or not frameScale or frameScale <= 0 then return nil end
    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then return nil end
    local toUI = frameScale / uiScale
    return left * toUI, right * toUI, top * toUI, bottom * toUI, uiScale, frameScale
end

local function TooltipRootAndOwner(frame)
    if not frame or not frame.GetOwner then return nil end
    local root, owner, seen = frame, frame:GetOwner(), {}
    while owner and not seen[owner] do
        seen[owner] = true
        local isTooltip = owner.IsObjectType and owner:IsObjectType("GameTooltip")
        if not isTooltip then return root, owner end
        root = owner
        owner = owner.GetOwner and owner:GetOwner() or nil
    end
    return root, owner
end

local function FrameCenterInside(frame, left, bottom, right, top)
    local frameLeft, frameRight, frameTop, frameBottom = FrameBounds(frame)
    if not frameLeft then return false end
    local x, y = (frameLeft + frameRight) / 2, (frameBottom + frameTop) / 2
    return x >= left and x <= right and y >= bottom and y <= top
end

local comparisonTooltipNames = {
    "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3",
}

function PopupBounds:ClearManagedTooltip(frame)
    if not frame then return end
    frame._OffhandManagedOwner = nil
    frame._OffhandOwnerDirection = nil
end

function PopupBounds:SetTooltipPoint(frame, point, relative, relativePoint, x, y)
    if self.placingTooltipPoint or not Positionable(frame) then return false end
    self.placingTooltipPoint = true
    local ok = pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint(point, relative, relativePoint, x, y)
    end)
    self.placingTooltipPoint = nil
    return ok
end

function PopupBounds:PlaceTooltipByDirection(frame, owner, direction)
    if not frame or not owner or not direction then return false end
    if direction == "ANCHOR_LEFT" then
        return self:SetTooltipPoint(frame, "TOPRIGHT", owner, "TOPLEFT", -4, 0)
    end
    return self:SetTooltipPoint(frame, "TOPLEFT", owner, "TOPRIGHT", 4, 0)
end

-- Blizzard chooses tooltip direction against the complete spanned UIParent.
-- Reverse the native left/right owner anchor while it is being assigned so an
-- Offhand item opens toward the middle of that physical display. The later
-- group constraint remains responsible for long text and comparison cards.
function PopupBounds:RedirectTooltipOwner(frame, owner, anchor)
    if self.redirectingTooltipOwner or (InCombatLockdown and InCombatLockdown()) then return false end
    local metrics = Active()
    if not metrics or not Positionable(frame) or not owner or owner == UIParent then
        self:ClearManagedTooltip(frame)
        return false
    end
    -- Comparison tooltips are already attached to the primary tooltip. Moving
    -- their owner anchor independently makes Blizzard's comparison layout and
    -- our group bounds correction fight each other.
    if owner.IsObjectType and owner:IsObjectType("GameTooltip") then return false end
    local ownerLeft, ownerRight = FrameBounds(owner)
    if not ownerLeft or not FrameCenterInside(owner,
        metrics.workspaceLeft, metrics.workspaceBottom,
        metrics.workspaceRight, metrics.workspaceTop) then
        self:ClearManagedTooltip(frame)
        return false
    end

    anchor = tostring(anchor or "")
    local center = (ownerLeft + ownerRight) / 2
    local desired
    if center >= (metrics.workspaceLeft + metrics.workspaceRight) / 2
        and anchor == "ANCHOR_RIGHT" then
        desired = "ANCHOR_LEFT"
    elseif center < (metrics.workspaceLeft + metrics.workspaceRight) / 2
        and anchor == "ANCHOR_LEFT" then
        desired = "ANCHOR_RIGHT"
    end
    if not desired then
        -- Preserve an established direction across data refreshes that use an
        -- internal non-directional anchor token for the same owner.
        if frame._OffhandManagedOwner == owner and frame._OffhandOwnerDirection
            and anchor ~= "ANCHOR_LEFT" and anchor ~= "ANCHOR_RIGHT" then
            return self:PlaceTooltipByDirection(frame, owner,
                frame._OffhandOwnerDirection)
        end
        self:ClearManagedTooltip(frame)
        return false
    end

    -- Direct SetPoint correction leaves Blizzard's directional owner mode
    -- active, so Retail can reapply that native anchor during every item-data
    -- refresh and visibly alternate across the seam. Switch the primary
    -- tooltip to Blizzard's supported manual-owner mode once, then establish
    -- the inward point. Native content and comparison layout remain intact,
    -- while no competing automatic owner anchor remains active.
    self.redirectingTooltipOwner = true
    local ownerChanged = pcall(frame.SetOwner, frame, owner, "ANCHOR_NONE")
    self.redirectingTooltipOwner = nil
    if not ownerChanged then
        self:ClearManagedTooltip(frame)
        return false
    end
    frame._OffhandManagedOwner = owner
    frame._OffhandOwnerDirection = desired
    return self:PlaceTooltipByDirection(frame, owner, desired)
end

-- Blizzard chooses the side for equipped-item comparisons from GetScreenWidth,
-- which is the complete spanned window. Rebuild only the already-shown
-- comparison chain after Blizzard's comparison transaction completes. This is
-- deterministic and synchronous: unlike the former deferred group clamp, it
-- cannot trigger a resize/reposition feedback loop across rendered frames.
function PopupBounds:ArrangeTooltipComparisons(frame)
    if InCombatLockdown and InCombatLockdown() then return false end
    local root, owner = TooltipRootAndOwner(frame)
    if not root or not owner or root._OffhandManagedOwner ~= owner
        or root._OffhandOwnerDirection ~= "ANCHOR_LEFT" then return false end

    local previous, arranged = root, false
    for _, name in ipairs(comparisonTooltipNames) do
        local comparison = _G[name]
        if comparison and comparison ~= root and comparison.IsShown
            and comparison:IsShown() then
            local comparisonRoot = TooltipRootAndOwner(comparison)
            if comparisonRoot == root then
                local y = previous == root and -10 or 0
                if self:SetTooltipPoint(comparison, "TOPRIGHT", previous,
                    "TOPLEFT", 0, y) then
                    previous, arranged = comparison, true
                end
            end
        end
    end
    return arranged
end

function PopupBounds:ObserveTooltip(tooltip)
    if not tooltip or tooltip._OffhandBoundsObserved then return false end
    tooltip._OffhandBoundsObserved = true
    if tooltip.HookScript then
        tooltip:HookScript("OnShow", function(self)
            PopupBounds:ArrangeTooltipComparisons(self)
        end)
        tooltip:HookScript("OnHide", function(self) PopupBounds:ClearManagedTooltip(self) end)
    end
    if tooltip.SetOwner and hooksecurefunc then
        hooksecurefunc(tooltip, "SetOwner", function(self, owner, anchor)
            if not PopupBounds.redirectingTooltipOwner then
                PopupBounds:RedirectTooltipOwner(self, owner, anchor)
            end
        end)
    end
    return true
end

function PopupBounds:Constrain(frame)
    if InCombatLockdown and InCombatLockdown() then return false end
    local metrics = Active()
    if not metrics or not Accessible(frame) then return false end

    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local frameScale = frame:GetEffectiveScale()
    if not uiScale or uiScale <= 0 or not frameScale or frameScale <= 0 then return false end
    local toUI = frameScale / uiScale
    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then return false end
    left, right, top, bottom = left * toUI, right * toUI, top * toUI, bottom * toUI
    local width, height = right - left, top - bottom
    if width <= 0 or height <= 0 then return false end

    local margin = 4 * (tonumber(metrics.hudScale) or 1)
    local minLeft, maxRight = metrics.gameLeft + margin, metrics.gameRight - margin
    local minBottom, maxTop = metrics.gameBottom + margin, metrics.gameTop - margin
    local newLeft = math.max(minLeft, math.min(left, maxRight - width))
    local newTop = math.min(maxTop, math.max(top, minBottom + height))
    if math.abs(newLeft - left) < 0.01 and math.abs(newTop - top) < 0.01 then return false end

    local fromUI = uiScale / frameScale
    local ok = pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", newLeft * fromUI, newTop * fromUI)
    end)
    return ok
end

function PopupBounds:Queue(frame)
    if not frame then return end
    local function constrain()
        if frame.IsShown and not frame:IsShown() then return end
        PopupBounds:Constrain(frame)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, constrain) else constrain() end
end

local function LegacyUnitMenu(dropdown)
    if not dropdown then return false end
    return dropdown.unit ~= nil or dropdown.which ~= nil
        or dropdown == _G.PlayerFrameDropDown or dropdown == _G.TargetFrameDropDown
        or dropdown == _G.FocusFrameDropDown
end

function PopupBounds:Initialize()
    if self.initialized then return end
    self.initialized = true

    -- Mainline and current Classic branches expose the acquired menu frame as a
    -- supported proxy. Registering against unit-menu tags avoids scanning _G or
    -- touching unrelated addon menus.
    if Menu and Menu.ModifyMenu then
        for _, tag in ipairs(unitMenuTags) do
            pcall(Menu.ModifyMenu, tag, function(_, rootDescription)
                if rootDescription and rootDescription.AddMenuAcquiredCallback then
                    rootDescription:AddMenuAcquiredCallback(function(menuFrame)
                        PopupBounds:Queue(menuFrame)
                    end)
                end
            end)
        end
    end

    -- Legacy UnitPopup uses the shared DropDownList frames. Observe the native
    -- open transaction and move only unit menus after Blizzard has sized them.
    if ToggleDropDownMenu and hooksecurefunc then
        hooksecurefunc("ToggleDropDownMenu", function(_, _, dropdown)
            if not LegacyUnitMenu(dropdown) then return end
            for index = 1, 3 do
                local menuFrame = _G["DropDownList" .. index]
                if menuFrame and (not menuFrame.IsShown or menuFrame:IsShown()) then
                    PopupBounds:Queue(menuFrame)
                end
            end
        end)
    end

    -- Known Blizzard tooltip roots are sufficient for item/comparison routing;
    -- avoid another recurring global scan.
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip",
        "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3" }) do
        PopupBounds:ObserveTooltip(_G[name])
    end

    -- Retail anchors all comparison cards before returning from this function.
    -- A post-hook therefore corrects the completed layout in the same UI
    -- transaction, without a timer or a visible native/corrected alternation.
    if GameTooltip_ShowCompareItem and hooksecurefunc then
        hooksecurefunc("GameTooltip_ShowCompareItem", function(tooltip)
            PopupBounds:ArrangeTooltipComparisons(tooltip or _G.GameTooltip)
        end)
    end
end
