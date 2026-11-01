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

local function PublicNumber(value)
    -- Retail may expose secret coordinates even outside combat (for example
    -- encounter-warning previews in Edit Mode). Never compare or calculate
    -- with these values; leave their tooltip placement to Blizzard.
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function FrameBounds(frame)
    if not Accessible(frame) then return nil end
    local uiScale = 1
    if UIParent and UIParent.GetEffectiveScale then uiScale = UIParent:GetEffectiveScale() end
    local frameScale = frame:GetEffectiveScale()
    if not PublicNumber(uiScale) or not PublicNumber(frameScale)
        or uiScale <= 0 or frameScale <= 0 then return nil end
    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not PublicNumber(left) or not PublicNumber(right)
        or not PublicNumber(top) or not PublicNumber(bottom) then return nil end
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

local classicClampState = setmetatable({}, { __mode = "k" })
local classicClampUpdating
local function SameInsets(a, b)
    if not a or not b then return false end
    for i = 1, 4 do if math.abs(a[i] - b[i]) > 0.01 then return false end end
    return true
end
function PopupBounds:RestoreClassicTooltipClamp(frame)
    local state = classicClampState[frame]
    if not state then return false end
    if InCombatLockdown and InCombatLockdown() then
        if Offhand.RunOrQueueCombat and not state.restoreQueued then
            state.restoreQueued = true
            Offhand:RunOrQueueCombat(function()
                state.restoreQueued = nil
                if classicClampState[frame] ~= state then return end
                if frame.IsShown and frame:IsShown() then PopupBounds:UpdateClassicTooltipClamp(frame)
                else PopupBounds:RestoreClassicTooltipClamp(frame) end
            end)
        end
        return false
    end
    if (frame.IsForbidden and frame:IsForbidden())
        or (frame.IsProtected and frame:IsProtected()) then return false end
    classicClampState[frame] = nil
    if SameInsets({ frame:GetClampRectInsets() }, state.applied) then
        frame:SetClampRectInsets(unpack(state.original))
        if state.changedClamped and frame:IsClampedToScreen() then frame:SetClampedToScreen(false) end
    end
    return true
end
function PopupBounds:UpdateClassicTooltipClamp(frame, preparing)
    if classicClampUpdating
        or (InCombatLockdown and InCombatLockdown()) or not frame
        or not frame.GetClampRectInsets or not frame.SetClampRectInsets
        or not frame.IsClampedToScreen or not frame.SetClampedToScreen then return false end
    if (frame.IsForbidden and frame:IsForbidden())
        or (frame.IsProtected and frame:IsProtected()) then return false end
    local metrics = Active()
    local _, owner = TooltipRootAndOwner(frame)
    local worldOwner = owner and (owner == UIParent or owner == _G.WorldFrame)
    local external = _G.TipTac or _G.TinyTooltip or _G.TinyTooltipReforged
    if not metrics or not owner or frame.IsEmbedded or external
        or (not worldOwner and (Offhand.isRetail or Offhand.isForever
            or not FrameCenterInside(owner, metrics.workspaceLeft, metrics.workspaceBottom,
                metrics.workspaceRight, metrics.workspaceTop))) then
        return self:RestoreClassicTooltipClamp(frame)
    end
    local left = worldOwner and metrics.gameLeft or metrics.workspaceLeft
    local right = worldOwner and metrics.gameRight or metrics.workspaceRight
    local bottom = worldOwner and metrics.gameBottom or metrics.workspaceBottom
    local top = worldOwner and metrics.gameTop or metrics.workspaceTop
    if type(left) ~= "number" or type(right) ~= "number"
        or type(bottom) ~= "number" or type(top) ~= "number" then return false end
    -- SetOwner runs before native item sizing/show. Prepare the policy there,
    -- without using the hidden tooltip's stale or unresolved rectangle.
    local uiScale = UIParent:GetEffectiveScale()
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale()
    if not uiScale or uiScale <= 0 or not frameScale or frameScale <= 0 then return false end
    local margin = 12 * (metrics.hudScale or 1)
    local minX, maxX = left + margin, right - margin
    local minY, maxY = bottom + margin, top - margin
    if not preparing and (not frame.IsShown or frame:IsShown()) then
        local left, right, top, bottom = FrameBounds(frame)
        if not left or right <= left or top <= bottom then return false end
        if right - left > maxX - minX or top - bottom > maxY - minY then
            return self:RestoreClassicTooltipClamp(frame)
        end
    end
    local current = { frame:GetClampRectInsets() }
    local state = classicClampState[frame]
    if state and not SameInsets(current, state.applied) then
        -- A native refresh or another owner supplied a new baseline.
        classicClampState[frame] = nil
        return false
    end
    state = state or { original = current, changedClamped = not frame:IsClampedToScreen() }
    local factor = uiScale / frameScale
    local desired = {
        math.min(state.original[1], -minX * factor),
        math.max(state.original[2], (UIParent:GetWidth() - maxX) * factor),
        math.max(state.original[3], (UIParent:GetHeight() - maxY) * factor),
        math.min(state.original[4], -minY * factor),
    }
    classicClampUpdating = true
    local ok = pcall(function()
        if not SameInsets(current, desired) then frame:SetClampRectInsets(unpack(desired)) end
        if not frame:IsClampedToScreen() then frame:SetClampedToScreen(true) end
    end)
    classicClampUpdating = nil
    if not ok then return false end
    state.applied = desired
    classicClampState[frame] = state
    return true
end

local tooltipCapture
function PopupBounds:ArmTooltipPresentationCapture()
    if InCombatLockdown and InCombatLockdown() then return false end
    local token = {}
    tooltipCapture = token
    if C_Timer and C_Timer.After then
        C_Timer.After(30, function() if tooltipCapture == token then tooltipCapture = nil end end)
    end
    return true
end

function PopupBounds:GetTooltipPresentationDiagnostics()
    if InCombatLockdown and InCombatLockdown() then return { "deferred:combat" } end
    local reports = {}
    local function Describe(frame)
        if not frame then return "absent" end
        if frame.IsForbidden and frame:IsForbidden() then return "forbidden" end
        local shown = frame.IsShown and frame:IsShown()
        local alpha = frame.GetEffectiveAlpha and frame:GetEffectiveAlpha()
        local left, right, top, bottom = FrameBounds(frame)
        local bounds = left and string.format("%.0f/%.0f/%.0f/%.0f", left, bottom, right - left, top - bottom)
            or "unresolved"
        return string.format("%s,alpha=%s,strata=%s,level=%s,scale=%s,rect=%s", shown and "shown" or "hidden",
            alpha and string.format("%.2f", alpha) or "unknown",
            frame.GetFrameStrata and frame:GetFrameStrata() or "unknown",
            frame.GetFrameLevel and tostring(frame:GetFrameLevel()) or "unknown",
            frame.GetEffectiveScale and string.format("%.3f", frame:GetEffectiveScale()) or "unknown", bounds)
    end
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
        local ok, detail = pcall(function()
            local frame = _G[name]
            if not frame then return "absent" end
            if frame.IsForbidden and frame:IsForbidden() then return "forbidden" end
            local slice = frame.NineSlice
            if slice and slice.IsForbidden and slice:IsForbidden() then
                return Describe(frame) .. ";backdrop=forbidden"
            end
            local _, _, _, centerAlpha
            if slice and slice.GetCenterColor then _, _, _, centerAlpha = slice:GetCenterColor() end
            local clamp = frame.GetClampRectInsets
                and string.format("%.1f/%.1f/%.1f/%.1f", frame:GetClampRectInsets()) or "unavailable"
            return string.format("%s;embedded=%s;backdrop=%s;centerAlpha=%s;clamp=%s",
                Describe(frame), frame.IsEmbedded and "yes" or "no", Describe(slice),
                centerAlpha and string.format("%.2f", centerAlpha) or "unknown", clamp)
        end)
        reports[#reports + 1] = name .. "=" .. (ok and detail or "unavailable")
    end
    return reports
end

local function CaptureVisibleTooltip(frame)
    local token = tooltipCapture
    if not token then return end
    local function Capture()
        if tooltipCapture ~= token or (InCombatLockdown and InCombatLockdown())
            or not frame.IsShown or not frame:IsShown() then return end
        tooltipCapture = nil
        if Offhand.Print then
            for _, report in ipairs(PopupBounds:GetTooltipPresentationDiagnostics()) do
                Offhand:Print("Hovered tooltip presentation: %s.", report)
            end
        end
    end
    -- Let the native item content and NineSlice finish the current show turn.
    if C_Timer and C_Timer.After then C_Timer.After(0, Capture) else Capture() end
end

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
    if not Offhand.isRetail and not Offhand.isForever then return false end
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

    local center = (ownerLeft + ownerRight) / 2
    local desired = center >= (metrics.workspaceLeft + metrics.workspaceRight) / 2
        and "ANCHOR_LEFT" or "ANCHOR_RIGHT"

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
-- which is the complete spanned window. Preserve Blizzard's comparison anchor
-- graph exactly: reversing ShoppingTooltip1/2 can leave the next data refresh
-- trying to anchor each frame to the other. Move only the manually-owned root
-- after the completed comparison transaction, which translates the intact
-- graph as one unit and leaves a small physical margin at the seam.
function PopupBounds:ArrangeTooltipComparisons(frame)
    if not Offhand.isRetail and not Offhand.isForever then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local metrics = Active()
    if not metrics then return false end
    local root, owner = TooltipRootAndOwner(frame)
    if root and owner and (owner == UIParent or owner == _G.WorldFrame) then
        -- Apply native bounds only after the comparison manager has completed
        -- its anchor graph. Do not install intermediate shopping-card observers.
        local changed = self:UpdateClassicTooltipClamp(root)
        for _, name in ipairs(comparisonTooltipNames) do
            local comparison = _G[name]
            if comparison and comparison.IsShown and comparison:IsShown() then
                changed = self:UpdateClassicTooltipClamp(comparison) or changed
            end
        end
        return changed
    end
    if not root or not owner or root._OffhandManagedOwner ~= owner
        or not root._OffhandOwnerDirection then return false end

    local rootLeft, rootRight, rootTop, rootBottom, uiScale, rootScale = FrameBounds(root)
    if not rootLeft then return false end
    local minLeft, maxRight = rootLeft, rootRight
    local maxTop, minBottom = rootTop, rootBottom
    for _, name in ipairs(comparisonTooltipNames) do
        local comparison = _G[name]
        if comparison and comparison ~= root and comparison.IsShown
            and comparison:IsShown() then
            local left, right, top, bottom = FrameBounds(comparison)
            if not left then return false end
            minLeft = math.min(minLeft, left)
            maxRight = math.max(maxRight, right)
            maxTop = math.max(maxTop, top)
            minBottom = math.min(minBottom, bottom)
        end
    end

    local margin = 12 * (tonumber(metrics.hudScale) or 1)
    local minX, maxX = metrics.workspaceLeft + margin, metrics.workspaceRight - margin
    local minY, maxY = metrics.workspaceBottom + margin, metrics.workspaceTop - margin
    local groupWidth, groupHeight = maxRight - minLeft, maxTop - minBottom
    local availableWidth, availableHeight = maxX - minX, maxY - minY
    local targetLeft, targetBottom = minLeft, minBottom

    if groupWidth <= availableWidth then
        targetLeft = math.max(minX, math.min(minLeft, maxX - groupWidth))
    elseif metrics.workspaceRight <= metrics.gameLeft then
        targetLeft = maxX - groupWidth
    else
        targetLeft = minX
    end
    if groupHeight <= availableHeight then
        targetBottom = math.max(minY, math.min(minBottom, maxY - groupHeight))
    else
        targetBottom = minY
    end

    local dx, dy = targetLeft - minLeft, targetBottom - minBottom
    if math.abs(dx) < 0.01 and math.abs(dy) < 0.01 then return false end
    local fromUI = uiScale / rootScale
    return self:SetTooltipPoint(root, "TOPLEFT", UIParent, "BOTTOMLEFT",
        (rootLeft + dx) * fromUI, (rootTop + dy) * fromUI)
end

function PopupBounds:ObserveTooltip(tooltip)
    if not tooltip or tooltip._OffhandBoundsObserved then return false end
    tooltip._OffhandBoundsObserved = true
    if tooltip.HookScript then
        -- Shopping-tooltip OnShow fires while Retail's comparison manager is
        -- still constructing its layout. Reanchoring from that intermediate
        -- callback makes the manager and Offhand visibly alternate. Root
        -- OnShow remains a fallback for clients without a comparison manager;
        -- completed comparison transactions are handled below.
        if tooltip == _G.GameTooltip or tooltip == _G.ItemRefTooltip then
            tooltip:HookScript("OnShow", function(self)
                PopupBounds:UpdateClassicTooltipClamp(self)
                PopupBounds:ArrangeTooltipComparisons(self)
                CaptureVisibleTooltip(self)
            end)
        elseif not Offhand.isRetail and not Offhand.isForever then
            tooltip:HookScript("OnShow", function(self) PopupBounds:UpdateClassicTooltipClamp(self) end)
        end
        tooltip:HookScript("OnHide", function(self)
            PopupBounds:RestoreClassicTooltipClamp(self)
            PopupBounds:ClearManagedTooltip(self)
        end)
        if tooltip == _G.GameTooltip or tooltip == _G.ItemRefTooltip
            or (not Offhand.isRetail and not Offhand.isForever) then
            tooltip:HookScript("OnSizeChanged", function(self) PopupBounds:UpdateClassicTooltipClamp(self) end)
        end
    end
    if tooltip.SetOwner and hooksecurefunc then
        hooksecurefunc(tooltip, "SetOwner", function(self, owner, anchor)
            PopupBounds:UpdateClassicTooltipClamp(self, true)
            if not Offhand.isRetail and not Offhand.isForever then
                return
            end
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

    local left, right, top, bottom, uiScale, frameScale = FrameBounds(frame)
    if not left then return false end
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
    if (Offhand.isRetail or Offhand.isForever) and GameTooltip_ShowCompareItem and hooksecurefunc then
        hooksecurefunc("GameTooltip_ShowCompareItem", function(tooltip)
            PopupBounds:ArrangeTooltipComparisons(tooltip or _G.GameTooltip)
        end)
    end

    -- Current Retail and Forever builds finalize equipped-item cards through
    -- TooltipComparisonManager after the individual ShoppingTooltip OnShow
    -- scripts have fired. Constrain the completed group synchronously by moving
    -- only its root; never rewrite the manager-owned comparison dependencies.
    if (Offhand.isRetail or Offhand.isForever) and TooltipComparisonManager
        and type(TooltipComparisonManager.AnchorShoppingTooltips) == "function"
        and hooksecurefunc then
        hooksecurefunc(TooltipComparisonManager, "AnchorShoppingTooltips",
            function(manager)
                local tooltip = manager and manager.tooltip or _G.GameTooltip
                PopupBounds:ArrangeTooltipComparisons(tooltip)
            end)
    end

    -- Combined Backpack item buttons use GameTooltip_SetDefaultAnchor on
    -- Retail. That helper calls SetOwner(ANCHOR_NONE) and then assigns its own
    -- full-screen BOTTOMRIGHT point, so correcting only SetOwner is overwritten
    -- later in the same function. Reapply the physical-workspace direction
    -- after the complete helper transaction, before the tooltip is shown.
    if (Offhand.isRetail or Offhand.isForever) and GameTooltip_SetDefaultAnchor and hooksecurefunc then
        hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, owner)
            PopupBounds:RedirectTooltipOwner(tooltip, owner, "ANCHOR_NONE")
        end)
    end
end
