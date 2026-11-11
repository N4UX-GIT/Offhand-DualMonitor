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
local tooltipAnchorPoints = {TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
    RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true}

local function IsComparisonCard(root, frame)
    if type(root.shoppingTooltips) == "table" then
        for _, card in ipairs(root.shoppingTooltips) do if card == frame then return true end end
    else
        for _, name in ipairs(comparisonTooltipNames) do if _G[name] == frame then return true end end
    end
    return false
end

local classicClampState = setmetatable({}, { __mode = "k" })
local classicClampUpdating
local comparisonClampState = setmetatable({}, { __mode = "k" })
local comparisonClampUpdating
local tooltipFitState = setmetatable({}, { __mode = "k" })
local tooltipFitYielded = setmetatable({}, { __mode = "k" })
local tooltipFitUpdating
function PopupBounds:PreservesTooltipFitScale(frame)
    if tooltipFitUpdating == frame or tooltipFitYielded[frame] then return true end
    local state = tooltipFitState[frame]
    local current = state and frame.GetScale and frame:GetScale()
    return state and PublicNumber(current)
        and math.abs(current - state.applied) <= 0.00001 or false
end
local function RestoreTooltipFit(frame)
    local state = tooltipFitState[frame]
    if not state or tooltipFitUpdating
        or (InCombatLockdown and InCombatLockdown()) then return false end
    if (frame.IsForbidden and frame:IsForbidden())
        or (frame.IsProtected and frame:IsProtected()) then return false end
    local current = frame.GetScale and frame:GetScale()
    if not PublicNumber(current) or math.abs(current - state.applied) > 0.00001 then
        tooltipFitState[frame] = nil
        return false
    end
    tooltipFitUpdating = frame
    local ok = pcall(frame.SetScale, frame, state.original)
    tooltipFitUpdating = nil
    if ok then tooltipFitState[frame] = nil end
    return ok
end

local function FitNativeTooltip(frame, width, height, availableWidth, availableHeight)
    if not Offhand.isRetail and not Offhand.isForever then return false end
    local known = frame == _G.GameTooltip or frame == _G.ItemRefTooltip
    for _, name in ipairs(comparisonTooltipNames) do known = known or frame == _G[name] end
    if not known or tooltipFitYielded[frame] or not frame.GetScale or not frame.SetScale then return false end
    local current = frame:GetScale()
    if not PublicNumber(current) or current <= 0 then return false end
    local state = tooltipFitState[frame]
    if state and math.abs(current - state.applied) > 0.00001 then
        tooltipFitState[frame], tooltipFitYielded[frame] = nil, true
        return false
    end
    local original = state and state.original or current
    local baselineWidth, baselineHeight = width * original / current, height * original / current
    local desired = original * math.min(1, availableWidth / baselineWidth, availableHeight / baselineHeight)
    if desired <= 0 or math.abs(current - desired) < 0.00001 then return true end
    tooltipFitUpdating = frame
    local ok = pcall(frame.SetScale, frame, desired)
    tooltipFitUpdating = nil
    if not ok then return false end
    if math.abs(desired - original) < 0.00001 then tooltipFitState[frame] = nil
    else tooltipFitState[frame] = {original = original, applied = desired} end
    return true
end

local function SameInsets(a, b)
    if not a or not b then return false end
    for i = 1, 4 do if math.abs(a[i] - b[i]) > 0.01 then return false end end
    return true
end
function PopupBounds:RestoreClassicTooltipClamp(frame)
    local state = classicClampState[frame]
    if not state and not tooltipFitState[frame] then return false end
    if InCombatLockdown and InCombatLockdown() then
        local pending = state or tooltipFitState[frame]
        if Offhand.RunOrQueueCombat and not pending.restoreQueued then
            pending.restoreQueued = true
            Offhand:RunOrQueueCombat(function()
                pending.restoreQueued = nil
                if state and classicClampState[frame] ~= state then return end
                if not state and tooltipFitState[frame] ~= pending then return end
                if frame.IsShown and frame:IsShown() then PopupBounds:UpdateClassicTooltipClamp(frame)
                else PopupBounds:RestoreClassicTooltipClamp(frame) end
            end)
        end
        return false
    end
    if (frame.IsForbidden and frame:IsForbidden())
        or (frame.IsProtected and frame:IsProtected()) then return false end
    local fitRestored = RestoreTooltipFit(frame)
    if not state then return fitRestored end
    classicClampState[frame] = nil
    if SameInsets({ frame:GetClampRectInsets() }, state.applied) then
        frame:SetClampRectInsets(unpack(state.original))
        if state.changedClamped and frame:IsClampedToScreen() then frame:SetClampedToScreen(false) end
    end
    return true
end
function PopupBounds:UpdateClassicTooltipClamp(frame, preparing)
    if classicClampUpdating or tooltipFitUpdating or comparisonClampUpdating
        or (InCombatLockdown and InCombatLockdown()) or not frame
        or not frame.GetClampRectInsets or not frame.SetClampRectInsets
        or not frame.IsClampedToScreen or not frame.SetClampedToScreen then return false end
    if (frame.IsForbidden and frame:IsForbidden())
        or (frame.IsProtected and frame:IsProtected()) then return false end
    local metrics = Active()
    local root, owner = TooltipRootAndOwner(frame)
    -- Modern shopping cards belong to one native anchor chain. Restrict only
    -- its root; independently clamping a card can slide it over its neighbour.
    if (Offhand.isRetail or Offhand.isForever) and root and root ~= frame then
        return self:RestoreClassicTooltipClamp(frame)
    end
    if metrics and Offhand.WorkspaceRegions then metrics=Offhand.WorkspaceRegions:ForFrame(metrics,owner or frame) end
    local worldOwner = owner and (owner == UIParent or owner == _G.WorldFrame)
    local external = _G.TipTac or _G.TinyTooltip or _G.TinyTooltipReforged
    local mainhandOwner = worldOwner or (metrics and (Offhand.isRetail or Offhand.isForever)
        and FrameCenterInside(owner, metrics.gameLeft, metrics.gameBottom, metrics.gameRight, metrics.gameTop))
    local workspaceOwner = metrics and FrameCenterInside(owner, metrics.workspaceLeft, metrics.workspaceBottom,
        metrics.workspaceRight, metrics.workspaceTop)
    if not metrics or not owner or frame.IsEmbedded or external
        or (not mainhandOwner and not workspaceOwner) then
        comparisonClampState[frame] = nil
        return self:RestoreClassicTooltipClamp(frame)
    end
    local left = mainhandOwner and metrics.gameLeft or metrics.workspaceLeft
    local right = mainhandOwner and metrics.gameRight or metrics.workspaceRight
    local bottom = mainhandOwner and metrics.gameBottom or metrics.workspaceBottom
    local top = mainhandOwner and metrics.gameTop or metrics.workspaceTop
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
    local group = comparisonClampState[frame]
    if group then
        for _, card in ipairs(group.cards) do
            if (card.IsForbidden and card:IsForbidden()) or (card.IsProtected and card:IsProtected()) then return false end
            if not IsComparisonCard(frame, card) or not card.IsShown or not card:IsShown() or TooltipRootAndOwner(card) ~= frame then
                comparisonClampState[frame], group = nil, nil
                break
            end
        end
        if group then
            -- Oversized groups retain the native full-window policy rather
            -- than compressing independent cards into an overlapping stack.
            if group.nativeOnly or group.width > maxX - minX or group.height > maxY - minY then return self:RestoreClassicTooltipClamp(frame) end
            minX, maxX = minX + group.left, maxX - group.right
            minY, maxY = minY + group.bottom, maxY - group.top
        end
    end
    if not preparing and (not frame.IsShown or frame:IsShown()) then
        local left, right, top, bottom = FrameBounds(frame)
        if not left or right <= left or top <= bottom then return false end
        local fitted = FitNativeTooltip(frame, right - left, top - bottom, maxX - minX, maxY - minY)
        if not fitted and (right - left > maxX - minX or top - bottom > maxY - minY) then
            return self:RestoreClassicTooltipClamp(frame)
        end
        frameScale = frame:GetEffectiveScale()
        if not PublicNumber(frameScale) or frameScale <= 0 then return false end
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

local function SpellTooltipFitsAboveRight(tooltip, owner, insets, x, y)
    local left, right, top, bottom, uiScale, frameScale = FrameBounds(tooltip)
    local _, ownerRight, ownerTop = FrameBounds(owner)
    if not left or not ownerRight then return false end
    local scale = frameScale / uiScale
    local tooltipLeft, tooltipBottom = ownerRight + x * scale, ownerTop + y * scale
    return tooltipLeft >= -insets[1] * scale
        and tooltipLeft + (right - left) <= UIParent:GetWidth() - insets[2] * scale
        and tooltipBottom >= -insets[4] * scale
        and tooltipBottom + (top - bottom) <= UIParent:GetHeight() - insets[3] * scale
end

function PopupBounds:RefreshMovedSpellBookTooltip(panel)
    local tooltip = _G.GameTooltip
    local clamp = tooltip and classicClampState[tooltip]
    if not clamp then return end

    pcall(function()
        local book = panel.SpellBookFrame
        if not book or not tooltip:IsShown() or tooltip:GetNumPoints() ~= 1 then return end
        local owner = tooltip:GetOwner()
        local _, relative = tooltip:GetPoint(1)
        if not owner or relative ~= owner then return end
        local ancestor = owner
        for _ = 1, 12 do
            if ancestor == book then break end
            ancestor = ancestor.GetParent and ancestor:GetParent()
            if not ancestor or ancestor == panel then return end
        end
        if ancestor ~= book then return end

        local previousInsets = clamp.applied
        if not self:UpdateClassicTooltipClamp(tooltip) then return end
        local updatedClamp = classicClampState[tooltip]
        if not updatedClamp or SameInsets(previousInsets, updatedClamp.applied)
            or tooltip:GetOwner() ~= owner or tooltip:GetNumPoints() ~= 1 then return end

        -- Reapply the point to invalidate the rectangle from the old clamp.
        -- Match the interacted tooltip's right side when it fits after the move.
        local point, target, relativePoint, x, y = tooltip:GetPoint(1)
        if target ~= owner or not point or not relativePoint
            or not PublicNumber(x) or not PublicNumber(y) then return end
        if point == "BOTTOMRIGHT" and relativePoint == "TOPLEFT"
            and SpellTooltipFitsAboveRight(tooltip, owner, updatedClamp.applied, -x, y) then
            point, relativePoint, x = "BOTTOMLEFT", "TOPRIGHT", -x
        end
        self:SetTooltipPoint(tooltip, point, owner, relativePoint, x, y)
    end)
end

local tooltipCapture
local settingsTooltipScales=setmetatable({}, {__mode='k'})
local settingsTooltipYielded=setmetatable({}, {__mode='k'})
function PopupBounds:UpdateSettingsTooltipScale(frame,restoreOnly)
    -- Anniversary 2.5.6.70577's SettingsTooltip is a parentless root at scale 1.
    -- Its text otherwise ignores the scaled Options UI. Other tooltip/client
    -- normalization retains its existing contract.
    local toc=tonumber(Offhand.tocVersion) or 0
    if frame~=_G.SettingsTooltip or not frame or toc<20500 or toc>=20600
        or Offhand.isRetail or Offhand.isForever
        or (InCombatLockdown and InCombatLockdown())
        or (frame.IsForbidden and frame:IsForbidden())
        or (frame.IsProtected and frame:IsProtected())
        or not frame.GetScale or not frame.SetScale then return false end
    local state=settingsTooltipScales[frame]
    if state and state.applying then return false end
    local scale=frame:GetScale()
    if type(scale)~='number' or scale<=0 or scale~=scale or scale==math.huge then return false end
    if state and math.abs(scale-state.applied)>0.0001 then
        settingsTooltipScales[frame]=nil;settingsTooltipYielded[frame]=true;return false
    end
    local external=_G.TipTac or _G.TinyTooltip or _G.TinyTooltipReforged
    local metrics=not restoreOnly and not external and Offhand.db and Offhand.db.enabled
        and Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
    if not metrics or not metrics.isSpanned then
        if state then
            state.applying=true
            local ok=pcall(frame.SetScale,frame,state.original)
            settingsTooltipScales[frame]=nil
            return ok
        end
        return false
    end
    if settingsTooltipYielded[frame] or (not state and math.abs(scale-1)>0.0001) then return false end
    local parent=frame.GetParent and frame:GetParent()
    if parent and parent~=UIParent then return false end
    local desired=UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
    local ignores=frame.IsIgnoringParentScale and frame:IsIgnoringParentScale()
    local parentScale=not ignores and parent and parent.GetEffectiveScale and parent:GetEffectiveScale() or 1
    if type(desired)~='number' or desired<=0 or desired~=desired or desired==math.huge
        or type(parentScale)~='number' or parentScale<=0 then return false end
    desired=desired/parentScale
    if math.abs(scale-desired)<=0.0001 then return false end
    state=state or {original=scale}
    state.applied,state.applying=desired,true;settingsTooltipScales[frame]=state
    local ok=pcall(frame.SetScale,frame,desired)
    state.applying=false
    if not ok then settingsTooltipScales[frame]=nil end
    return ok
end

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
    local function ScaleDetails(frame)
        local function Number(v)return type(v)=='number' and v==v and math.abs(v)<math.huge and string.format('%.3f',v) or 'unknown' end
        local parent=frame.GetParent and frame:GetParent()
        local parentAllowed=parent and not (parent.IsForbidden and parent:IsForbidden())
        local parentName=parentAllowed and parent.GetName and parent:GetName() or 'unknown'
        local fontHeight
        if frame.GetRegions then
            local regions={frame:GetRegions()}
            for i=1,math.min(32,#regions) do
                local region=regions[i]
                if region and not (region.IsForbidden and region:IsForbidden()) and region.GetFont then
                    local _,height=region:GetFont();fontHeight=height;break
                end
            end
        end
        return string.format('localScale=%s;parent=%s;parentScale=%s;uiScale=%s;ignoreParentScale=%s;fontHeight=%s',
            Number(frame.GetScale and frame:GetScale()),tostring(parentName),
            Number(parentAllowed and parent.GetEffectiveScale and parent:GetEffectiveScale()),
            Number(UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()),
            frame.IsIgnoringParentScale and tostring(frame:IsIgnoringParentScale()) or 'unknown',Number(fontHeight))
    end
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "SettingsTooltip" }) do
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
            return string.format("%s;embedded=%s;backdrop=%s;centerAlpha=%s;clamp=%s;%s",
                Describe(frame), frame.IsEmbedded and "yes" or "no", Describe(slice),
                centerAlpha and string.format("%.2f", centerAlpha) or "unknown", clamp,ScaleDetails(frame))
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
    if metrics and Offhand.WorkspaceRegions then metrics=Offhand.WorkspaceRegions:ForFrame(metrics,owner or frame) end
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
local function ComparisonEnvelope(root, cards)
    local left, right, top, bottom = FrameBounds(root)
    if not left then return end
    local bounds = {[root] = {left = left, right = right, top = top, bottom = bottom}}
    local allowed, visiting = {}, {}
    for _, card in ipairs(cards) do allowed[card] = true end
    local function Fractions(point)
        return point:find("LEFT", 1, true) and 0 or point:find("RIGHT", 1, true) and 1 or .5,
            point:find("BOTTOM", 1, true) and 0 or point:find("TOP", 1, true) and 1 or .5
    end
    local function Resolve(card)
        if bounds[card] then return bounds[card] end
        if not allowed[card] or visiting[card] or not card.GetPoint or not card.GetNumPoints then return end
        local l, r, t, b, uiScale, frameScale = FrameBounds(card)
        if not l then return end
        local ok, count = pcall(card.GetNumPoints, card)
        if not ok or not PublicNumber(count) or count < 1 or count > 8 or count % 1 ~= 0 then return end
        visiting[card] = true
        local x, y, xPriority, yPriority
        for index = 1, count do
            local read, point, relative, relativePoint, dx, dy = pcall(card.GetPoint, card, index)
            if not read or (issecretvalue and (issecretvalue(point) or issecretvalue(relativePoint)
                    or issecretvalue(relative) or issecretvalue(dx) or issecretvalue(dy)))
                or type(point) ~= "string" or type(relativePoint) ~= "string"
                or not PublicNumber(dx or 0) or not PublicNumber(dy or 0) then visiting[card] = nil; return end
            if not tooltipAnchorPoints[point] or not tooltipAnchorPoints[relativePoint] then visiting[card] = nil; return end
            local parent = relative == root and bounds[root] or Resolve(relative)
            if not parent then visiting[card] = nil; return end
            local px, py = Fractions(point)
            local rx, ry = Fractions(relativePoint)
            local cx = parent.left + rx * (parent.right - parent.left) + (dx or 0) * frameScale / uiScale - px * (r - l)
            local cy = parent.bottom + ry * (parent.top - parent.bottom) + (dy or 0) * frameScale / uiScale - py * (t - b)
            -- Native TOP + RIGHT anchors constrain separate axes. Prefer the
            -- edge-specific point over the other point's implicit centre.
            local xp, yp = px ~= .5 and 1 or 0, py ~= .5 and 1 or 0
            if xPriority == nil or xp > xPriority then x, xPriority = cx, xp
            elseif xp == xPriority and math.abs(cx - x) > .1 then visiting[card] = nil; return end
            if yPriority == nil or yp > yPriority then y, yPriority = cy, yp
            elseif yp == yPriority and math.abs(cy - y) > .1 then visiting[card] = nil; return end
        end
        visiting[card] = nil
        bounds[card] = {left = x, right = x + r - l, bottom = y, top = y + t - b}
        return bounds[card]
    end
    local minLeft, maxRight, maxTop, minBottom = left, right, top, bottom
    for _, card in ipairs(cards) do
        local rect = Resolve(card)
        if not rect then return end
        minLeft, maxRight = math.min(minLeft, rect.left), math.max(maxRight, rect.right)
        maxTop, minBottom = math.max(maxTop, rect.top), math.min(minBottom, rect.bottom)
    end
    return {cards = cards, left = left - minLeft, right = maxRight - right,
        top = maxTop - top, bottom = bottom - minBottom, width = maxRight - minLeft, height = maxTop - minBottom}
end

local function NativeComparisonBounds(root)
    if not root.GetClampRectInsets or not root.SetClampRectInsets
        or not root.IsClampedToScreen or not root.SetClampedToScreen then return false end
    local cards = {}
    local candidates = type(root.shoppingTooltips) == "table" and root.shoppingTooltips or nil
    for index = 1, candidates and #candidates or #comparisonTooltipNames do
        local card = candidates and candidates[index] or _G[comparisonTooltipNames[index]]
        if card and ((card.IsForbidden and card:IsForbidden()) or (card.IsProtected and card:IsProtected())) then return true end
        if card and card ~= root and card.IsShown and card:IsShown()
            and TooltipRootAndOwner(card) == root then
            cards[#cards + 1] = card
        end
    end
    -- Validate the complete transaction before restoring any owned bounds.
    for _, tooltip in ipairs({root, unpack(cards)}) do
        if tooltip.IsEmbedded or (tooltip.IsForbidden and tooltip:IsForbidden())
            or (tooltip.IsProtected and tooltip:IsProtected()) or not FrameBounds(tooltip) then return true end
    end
    if #cards == 0 then
        comparisonClampState[root] = nil
        PopupBounds:UpdateClassicTooltipClamp(root)
        return true
    end
    local previous, current = comparisonClampState[root], ComparisonEnvelope(root, cards)
    local unchanged = previous and current and #previous.cards == #cards
    if unchanged and not previous.nativeOnly then
        for index, card in ipairs(cards) do
            if previous.cards[index] ~= card or classicClampState[card] or tooltipFitState[card] then unchanged = false end
        end
        for _, key in ipairs({"left", "right", "top", "bottom", "width", "height"}) do
            if math.abs(previous[key] - current[key]) > 0.01 then unchanged = false end
        end
    elseif previous and previous.nativeOnly then unchanged = false end
    if unchanged then PopupBounds:UpdateClassicTooltipClamp(root); return true end
    comparisonClampState[root] = nil
    comparisonClampUpdating = true
    local ok, state = pcall(function()
        PopupBounds:RestoreClassicTooltipClamp(root)
        for _, card in ipairs(cards) do PopupBounds:RestoreClassicTooltipClamp(card) end
        return ComparisonEnvelope(root, cards) or {cards = cards, nativeOnly = true}
    end)
    comparisonClampUpdating = nil
    if ok then
        comparisonClampState[root] = state
        PopupBounds:UpdateClassicTooltipClamp(root)
    end
    return true
end

function PopupBounds:ArrangeTooltipComparisons(frame)
    if not Offhand.isRetail and not Offhand.isForever then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local metrics = Active()
    if not metrics then return false end
    local root, owner = TooltipRootAndOwner(frame)
    if Offhand.WorkspaceRegions then metrics=Offhand.WorkspaceRegions:ForFrame(metrics,owner or frame) end
    local external = _G.TipTac or _G.TinyTooltip or _G.TinyTooltipReforged
    if root and external then
        comparisonClampState[root] = nil
        self:RestoreClassicTooltipClamp(root)
        return false
    end
    if not root or not owner or external or root.IsEmbedded
        or (root.IsForbidden and root:IsForbidden()) or (root.IsProtected and root:IsProtected()) then return false end
    local inside = owner == UIParent or owner == _G.WorldFrame
        or FrameCenterInside(owner, metrics.gameLeft, metrics.gameBottom, metrics.gameRight, metrics.gameTop)
        or FrameCenterInside(owner, metrics.workspaceLeft, metrics.workspaceBottom, metrics.workspaceRight, metrics.workspaceTop)
    if inside and NativeComparisonBounds(root) then return true end
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

function PopupBounds:ApplyLayout()
    if not Active() then
        for _, name in ipairs({"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3"}) do
            local tooltip = _G[name]
            if tooltip then
                comparisonClampState[tooltip] = nil
                self:RestoreClassicTooltipClamp(tooltip)
            end
        end
        return
    end
    for _, name in ipairs({"GameTooltip", "ItemRefTooltip"}) do
        local tooltip = _G[name]
        if tooltip and not (tooltip.IsForbidden and tooltip:IsForbidden()) and tooltip.IsShown and tooltip:IsShown() then
            self:ArrangeTooltipComparisons(tooltip)
        end
    end
end

function PopupBounds:ObserveTooltip(tooltip)
    if not tooltip or tooltip._OffhandBoundsObserved then return false end
    tooltip._OffhandBoundsObserved = true
    if tooltip.HookScript then
        if tooltip == _G.SettingsTooltip then
            tooltip:HookScript('OnShow',function(self)
                CaptureVisibleTooltip(self)
            end)
        end
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
            comparisonClampState[self] = nil
            if self==_G.SettingsTooltip then
                PopupBounds:UpdateSettingsTooltipScale(self,true)
                settingsTooltipYielded[self]=nil
            end
            PopupBounds:RestoreClassicTooltipClamp(self)
            tooltipFitYielded[self] = nil
            PopupBounds:ClearManagedTooltip(self)
        end)
        if tooltip == _G.GameTooltip or tooltip == _G.ItemRefTooltip
            or (not Offhand.isRetail and not Offhand.isForever) then
            tooltip:HookScript("OnSizeChanged", function(self) PopupBounds:UpdateClassicTooltipClamp(self) end)
        end
    end
    if tooltip.SetOwner and hooksecurefunc then
        hooksecurefunc(tooltip, "SetOwner", function(self, owner, anchor)
            comparisonClampState[self] = nil
            -- Settings builds its lines immediately after SetOwner. Scaling on
            -- show, even next turn, leaves native wrapping/height inconsistent
            -- on Anniversary. Prepare scale before native text construction.
            if self==_G.SettingsTooltip then PopupBounds:UpdateSettingsTooltipScale(self) end
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

-- These are EllesmereUI presentation roots. Its HUD, movers, dimmers and
-- input handlers keep their own layout. The full UIParent can include space
-- with no physical display, so fit these windows once per presentation.
local ellesmereWindows = {
    "EllesmereUIFrame", "EUIFirstInstallPopup", "EUIStyleChoicePopup",
    "EUIConfirmPopup", "EUIInfoPopup", "EUIInputPopup",
}
local ellesmerePlacement = setmetatable({}, { __mode = "k" })
local unlockToolbar
local unlockPlacement

local function Fits(left, right, top, bottom, minLeft, maxRight, maxTop, minBottom)
    return left >= minLeft and right <= maxRight and top <= maxTop and bottom >= minBottom
end

local function SetWindowPoint(frame, point)
    frame:ClearAllPoints()
    frame:SetPoint(unpack(point, 1, 5))
end

local function OwnsEllesmerePlacement(frame, placement)
    if not placement.original or frame:GetNumPoints() ~= 1
        or frame:GetScale() ~= placement.scale then return false end
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    local applied = placement.applied
    return point == applied[1] and relative == applied[2] and relativePoint == applied[3]
        and PublicNumber(x) and PublicNumber(y)
        and math.abs(x - applied[4]) < 0.01 and math.abs(y - applied[5]) < 0.01
end

local function RestoreEllesmereWindow(frame, placement)
    if OwnsEllesmerePlacement(frame, placement) then
        if placement.scale ~= placement.originalScale then frame:SetScale(placement.originalScale) end
        SetWindowPoint(frame, placement.original)
    end
end

local function GetUnlockToolbar(overlay)
    if unlockToolbar and unlockToolbar:GetParent() == overlay then return unlockToolbar end
    local getAnchor = _G.EllesmereUI.GetUnlockModeTopBarAnchor
    if type(getAnchor) ~= "function" then return end
    local hoverZone = getAnchor(_G.EllesmereUI)
    if not hoverZone or hoverZone:GetParent() ~= overlay then return end
    for _, child in ipairs({overlay:GetChildren()}) do
        if child._hoverZone == hoverZone then
            unlockToolbar = child
            return child
        end
    end
end

local function RefreshEllesmereUnlockToolbar(metrics)
    local overlay = _G.EllesmereUnlockMode
    if not overlay then return end
    local frame = overlay:IsVisible() and GetUnlockToolbar(overlay) or unlockToolbar
    if not frame or frame:IsForbidden() or frame:IsProtected() then return end
    if not metrics or not frame:IsVisible() then
        if unlockPlacement then RestoreEllesmereWindow(frame, unlockPlacement) end
        unlockPlacement = nil
        return
    end
    -- Window/UI scale and topology can settle after the first span callback.
    -- Ownership alone does not mean that the old physical target still fits.
    local geometry = { UIParent:GetWidth(), UIParent:GetHeight(), UIParent:GetEffectiveScale(),
        metrics.gameLeft, metrics.gameRight, metrics.gameBottom, metrics.gameTop,
        metrics.workspaceLeft, metrics.workspaceRight, metrics.workspaceBottom, metrics.workspaceTop,
        frame:GetWidth(), frame:GetHeight() }
    for index = 1, 13 do if not PublicNumber(geometry[index]) then return end end
    if unlockPlacement and OwnsEllesmerePlacement(frame, unlockPlacement) then
        local same = unlockPlacement.geometry ~= nil
        for index = 1, 13 do
            if not same or math.abs(geometry[index] - unlockPlacement.geometry[index]) > 0.01 then
                same = false
                break
            end
        end
        if same then return end
        -- Refit from the vendor's original size, never from our shrunken size.
        RestoreEllesmereWindow(frame, unlockPlacement)
    end
    unlockPlacement = nil

    -- Wait for EllesmereUI to finish sliding the banner in or resizing it.
    -- Its hover handler uses the real UIParent top, so keep the banner flush
    -- with that edge and choose a physical display that reaches it.
    if frame:GetNumPoints() ~= 1 then return end
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    if point ~= "TOP" or relative ~= UIParent or relativePoint ~= "TOP"
        or not PublicNumber(x) or not PublicNumber(y) or x ~= 0 or y ~= 0 then return end
    local left, right, top, bottom, uiScale, frameScale = FrameBounds(frame)
    if not left or right <= left or top <= bottom then return end
    if Fits(left, right, top, bottom, metrics.gameLeft, metrics.gameRight, metrics.gameTop, metrics.gameBottom)
        or Fits(left, right, top, bottom, metrics.workspaceLeft, metrics.workspaceRight,
            metrics.workspaceTop, metrics.workspaceBottom) then return end

    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local minLeft, maxRight, minBottom
    if math.abs(metrics.gameTop - screenHeight) < 1 then
        minLeft, maxRight, minBottom = metrics.gameLeft, metrics.gameRight, metrics.gameBottom
    elseif math.abs(metrics.workspaceTop - screenHeight) < 1 then
        minLeft, maxRight, minBottom = metrics.workspaceLeft, metrics.workspaceRight, metrics.workspaceBottom
    else
        return
    end
    local scale = frame:GetScale()
    local ratio = math.min(1, (maxRight - minLeft - 8) / (right - left),
        (screenHeight - minBottom) / (top - bottom))
    if ratio <= 0 or not PublicNumber(scale) or scale <= 0 then return end
    local offset = ((minLeft + maxRight - screenWidth) / 2) * uiScale / (frameScale * ratio)
    local applied = {"TOP", UIParent, "TOP", offset, 0}
    if ratio < 1 then frame:SetScale(scale * ratio) end
    SetWindowPoint(frame, applied)
    unlockPlacement = {
        original = {point, relative, relativePoint, x, y},
        originalScale = scale, scale = frame:GetScale(), applied = applied, geometry = geometry,
    }
end

local function GetEllesmereMetrics()
    local viewport = Offhand.Viewport
    local metrics = Offhand.db and Offhand.db.enabled and viewport and viewport:GetMetrics()
    return metrics and metrics.isSpanned and metrics or false
end

local function FitEllesmereWindow(frame, metrics)
    local left, right, top, bottom, uiScale, frameScale = FrameBounds(frame)
    if not left or right <= left or top <= bottom then return end
    if Fits(left, right, top, bottom, metrics.gameLeft, metrics.gameRight, metrics.gameTop, metrics.gameBottom)
        or Fits(left, right, top, bottom, metrics.workspaceLeft, metrics.workspaceRight,
            metrics.workspaceTop, metrics.workspaceBottom) then return {} end
    if frame:GetNumPoints() ~= 1 then return {} end
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    if not point or (relative and relative ~= UIParent)
        or (not relative and frame:GetParent() ~= UIParent)
        or not PublicNumber(x) or not PublicNumber(y) then return {} end

    local scale = frame:GetScale()
    local minLeft, maxRight = metrics.gameLeft + 4, metrics.gameRight - 4
    local minBottom, maxTop = metrics.gameBottom + 4, metrics.gameTop - 4
    if not PublicNumber(scale) or scale <= 0 or maxRight <= minLeft or maxTop <= minBottom then return {} end
    local width, height = right - left, top - bottom
    local ratio = math.min(1, (maxRight - minLeft) / width, (maxTop - minBottom) / height)
    local fromUI = uiScale / (frameScale * ratio)
    local newLeft = math.max(minLeft, math.min(left, maxRight - width * ratio))
    local newTop = math.min(maxTop, math.max(top, minBottom + height * ratio))
    local applied = {"TOPLEFT", UIParent, "BOTTOMLEFT", newLeft * fromUI, newTop * fromUI}
    if ratio < 1 then frame:SetScale(scale * ratio) end
    SetWindowPoint(frame, applied)
    return {
        original = {point, relative or UIParent, relativePoint or point, x, y},
        originalScale = scale, scale = frame:GetScale(), applied = applied,
    }
end

function PopupBounds:RefreshEllesmereWindows()
    if not Offhand.isForever or not _G.EllesmereUI
        or (InCombatLockdown and InCombatLockdown()) then return end
    local metrics
    local overlay = _G.EllesmereUnlockMode
    if unlockPlacement or (overlay and overlay:IsVisible()) then
        metrics = GetEllesmereMetrics()
        RefreshEllesmereUnlockToolbar(metrics)
    end
    for _, name in ipairs(ellesmereWindows) do
        local frame = _G[name]
        if frame and frame.IsProtected and not frame:IsProtected()
            and frame.IsForbidden and not frame:IsForbidden() then
            local placement = ellesmerePlacement[frame]
            local visible = frame:IsVisible()
            if visible or placement then
                if metrics == nil then metrics = GetEllesmereMetrics() end
                if metrics and visible then
                    if not placement then ellesmerePlacement[frame] = FitEllesmereWindow(frame, metrics) end
                elseif placement then
                    RestoreEllesmereWindow(frame, placement)
                    ellesmerePlacement[frame] = nil
                end
            end
        end
    end
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

    -- Observe from Offhand's own timer. These windows can raise Forever's
    -- gamepad cursor from their show handlers and may be created lazily.
    if Offhand.isForever and _G.EllesmereUI and C_Timer and C_Timer.NewTicker then
        self.ellesmereTicker = C_Timer.NewTicker(0.2, function() self:RefreshEllesmereWindows() end)
    end

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
