-- Dedicated full-screen Blizzard experiences (Retail Trading Post and modern
-- Retail/Forever Barbershop) normally span the entire virtual screen. When WoW
-- spans multiple displays, that extends across the Offhand workspace and any
-- mixed-height dead void above or beside Mainhand. Keep these full-screen roots
-- inside the same physical rectangle as WorldFrame without replacing Blizzard's
-- interaction scripts.
local _, Offhand = ...

local RetailFullscreen = {}
Offhand.RetailFullscreen = RetailFullscreen

local abs = math.abs
local unpackFn = unpack or table.unpack

local function Near(a, b)
    return a and b and abs(a - b) < 0.001
end

local function CapturePoints(frame)
    local points = {}
    if not frame or not frame.GetNumPoints or not frame.GetPoint then return points end
    for index = 1, frame:GetNumPoints() do
        local p1, p2, p3, p4, p5 = frame:GetPoint(index)
        local n = select("#", frame:GetPoint(index))
        points[#points + 1] = {p1, p2, p3, p4, p5, n = n}
    end
    return points
end

local function WritePoints(frame, points, fallbackParent)
    frame:ClearAllPoints()
    if points and #points > 0 then
        for _, point in ipairs(points) do
            frame:SetPoint(unpackFn(point, 1, point.n or 5))
        end
    elseif fallbackParent ~= nil then
        frame:SetAllPoints(fallbackParent)
    else
        frame:SetAllPoints()
    end
end

local function SamePoints(a, b)
    if not a or not b or #a ~= #b then return false end
    for index, point in ipairs(a) do
        local other = b[index]
        if point[1] ~= other[1] or point[2] ~= other[2] or point[3] ~= other[3]
            or not Near(point[4] or 0, other[4] or 0)
            or not Near(point[5] or 0, other[5] or 0) then return false end
    end
    return true
end

local function HasPoint(frame, point, relativeToExpected, relativePoint, x, y)
    if not frame.GetNumPoints or not frame.GetPoint then return false end
    for index = 1, frame:GetNumPoints() do
        local currentPoint, relativeTo, currentRelativePoint, currentX, currentY = frame:GetPoint(index)
        if currentPoint == point and relativeTo == relativeToExpected
            and currentRelativePoint == relativePoint
            and Near(currentX or 0, x or 0) and Near(currentY or 0, y or 0) then
            return true
        end
    end
    return false
end

local function IsFullScreenBarberShop(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return false end
    if UIPanelWindows and UIPanelWindows.BarberShopFrame
        and UIPanelWindows.BarberShopFrame.area == "full" then
        return true
    end
    if frame.GetAttribute then
        local ok, area = pcall(frame.GetAttribute, frame, "UIPanelLayout-area")
        if ok and area == "full" then return true end
    end
    -- Retail and Forever full-screen Barbershop is parented directly to the
    -- screen root (nil); Classic's floating BarberShopFrame is parented to
    -- UIParent and must not be treated as a full-screen takeover frame.
    if frame.GetParent then
        local ok, parent = pcall(frame.GetParent, frame)
        if ok and parent == nil then return true end
    end
    return false
end

local function UsesIndependentDefaultScale(frame)
    if not frame then return false end
    -- TopLevelParentScaleFrameTemplate copies UIParent:GetScale(), which
    -- already carries Offhand's mixed-height HUD compensation. Only
    -- DefaultScaleFrame roots compute scale from the raw spanned height.
    if frame.OnScaleFrameLoad or frame.OnScaleFrameShow then return false end
    return frame.OnDefaultScaleFrameLoad ~= nil or frame.maxScale ~= nil
end

local function NewEntry(kind, compensateScale)
    return {
        kind = kind,
        compensateScale = compensateScale,
    }
end

RetailFullscreen.entries = {
    perks = NewEntry("perks", true),
    barbershop = NewEntry("barbershop", nil),
    barbershopCustomize = NewEntry("barbershopCustomize", false),
}

local function SyncLegacyFields()
    local perks = RetailFullscreen.entries.perks
    RetailFullscreen.frame = perks.frame
    RetailFullscreen.nativePoints = perks.nativePoints
    RetailFullscreen.nativeScale = perks.nativeScale
    RetailFullscreen.appliedPoints = perks.appliedPoints
    RetailFullscreen.appliedScale = perks.appliedScale
    RetailFullscreen.anchorYielded = perks.anchorYielded
    RetailFullscreen.scaleYielded = perks.scaleYielded
    RetailFullscreen.modified = perks.modified or false
end

function RetailFullscreen:ShouldConstrain(kind)
    local supported = kind == "perks" and Offhand.isRetail
        or (kind ~= "perks" and (Offhand.isRetail or Offhand.isForever))
    if not supported or not Offhand.db or not Offhand.db.enabled
        or not Offhand.Viewport or not Offhand.Viewport.GetMetrics then
        return false
    end
    local metrics = Offhand.Viewport:GetMetrics()
    return metrics and metrics.isSpanned and metrics or false
end

function RetailFullscreen:QueueAfterCombat(callback)
    if self.combatQueued then return end
    self.combatQueued = true
    Offhand:RunOrQueueCombat(function()
        self.combatQueued = false
        callback()
    end)
end

local function RestoreEntry(entry, fallbackParent)
    local frame = entry and entry.frame
    if not frame or not entry.modified then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end

    -- Anchor and scale ownership are independent. A later mover may change
    -- either property while leaving the other one at our applied value.
    local currentPoints = CapturePoints(frame)
    local changed = false
    if entry.appliedPoints and SamePoints(currentPoints, entry.appliedPoints) then
        WritePoints(frame, entry.nativePoints, fallbackParent)
        changed = true
    elseif entry.appliedPoints then
        entry.anchorYielded = not SamePoints(currentPoints, entry.nativePoints)
    end
    if entry.nativeScale and entry.appliedScale and frame.SetScale
        and Near(frame:GetScale(), entry.appliedScale) then
        frame:SetScale(entry.nativeScale)
        changed = true
    elseif entry.appliedScale then
        entry.scaleYielded = not Near(frame:GetScale(), entry.nativeScale)
    end
    entry.appliedPoints, entry.appliedScale = nil, nil
    entry.modified = false
    return changed
end

local function ApplyMainhandBounds(entry, frame, metrics, compensateScale)
    local currentScale = frame.GetScale and frame:GetScale() or nil
    local currentPoints = CapturePoints(frame)
    local nativeReset = SamePoints(currentPoints, entry.nativePoints)
    if nativeReset and (entry.appliedPoints or (compensateScale and Near(currentScale, entry.nativeScale))) then
        entry.scaleYielded = nil
    end
    if entry.appliedPoints and not SamePoints(currentPoints, entry.appliedPoints) then
        entry.anchorYielded = not nativeReset
    elseif nativeReset then
        entry.anchorYielded = nil
    end
    if compensateScale then
        if entry.appliedScale and not Near(currentScale, entry.appliedScale) then
            entry.scaleYielded = not (nativeReset or Near(currentScale, entry.nativeScale))
        end
        if not entry.scaleYielded and currentScale and currentScale > 0
            and (not entry.appliedScale or not Near(currentScale, entry.appliedScale)) then
            entry.nativeScale = currentScale
        end
        local canvasPixelHeight = tonumber(metrics.physicalHeight)
        local gamePixelHeight = tonumber(metrics.gamePixelHeight)
        local heightRatio = canvasPixelHeight and canvasPixelHeight > 0
            and gamePixelHeight and gamePixelHeight > 0
            and gamePixelHeight / canvasPixelHeight or 1
        local desiredScale = entry.nativeScale and entry.nativeScale * heightRatio or currentScale
        if not entry.scaleYielded and desiredScale and desiredScale > 0 and frame.SetScale
            and not Near(currentScale, desiredScale) then
            frame:SetScale(desiredScale)
        end
        if not entry.scaleYielded then entry.appliedScale = desiredScale end
    else
        entry.appliedScale = nil
    end

    local frameScale = frame:GetEffectiveScale()
    local parentScale = UIParent:GetEffectiveScale()
    if not frameScale or frameScale <= 0 or not parentScale or parentScale <= 0 then
        return false, false
    end
    local factor = parentScale / frameScale
    local left, bottom = metrics.gameLeft * factor, metrics.gameBottom * factor
    local right, top = metrics.gameRight * factor, metrics.gameTop * factor

    local boundsChanged = false
    if not entry.anchorYielded and (frame:GetNumPoints() ~= 2
        or not HasPoint(frame, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        or not HasPoint(frame, "TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)) then
        frame:ClearAllPoints()
        Offhand.Viewport:SetPoint(frame, "BOTTOMLEFT", "BOTTOMLEFT",
            metrics.gameLeft, metrics.gameBottom)
        Offhand.Viewport:SetPoint(frame, "TOPRIGHT", "BOTTOMLEFT",
            metrics.gameRight, metrics.gameTop)
        boundsChanged = true
    end
    if not entry.anchorYielded then entry.appliedPoints = CapturePoints(frame) end
    entry.modified = true
    return true, boundsChanged
end

-- CharCustomizeFrame is created in XML with parent="UIParent" and
-- setAllPoints="true". BarberShopMixin:OnLoad reparents it to BarberShopFrame
-- without replacing those UIParent anchors, so it still spans the entire
-- virtual window unless anchored to BarberShopFrame.
local function ApplyAttachedCustomizeFrame(barberFrame)
    local customize = _G.CharCustomizeFrame
    if not customize or (customize.IsForbidden and customize:IsForbidden()) then return false end
    if customize.GetParent then
        local ok, parent = pcall(customize.GetParent, customize)
        if not ok or parent ~= barberFrame then return false end
    end
    local entry = RetailFullscreen.entries.barbershopCustomize
    if entry.frame ~= customize then
        entry.frame = customize
        entry.nativePoints = CapturePoints(customize)
        entry.appliedPoints = nil
        entry.anchorYielded = nil
        entry.modified = false
    end
    local currentPoints = CapturePoints(customize)
    local nativeReset = SamePoints(currentPoints, entry.nativePoints)
    if entry.appliedPoints and not SamePoints(currentPoints, entry.appliedPoints) then
        entry.anchorYielded = not nativeReset
    elseif nativeReset then
        entry.anchorYielded = nil
    end
    local changed = false
    if not entry.anchorYielded and (customize:GetNumPoints() ~= 2
        or not HasPoint(customize, "TOPLEFT", barberFrame, "TOPLEFT", 0, 0)
        or not HasPoint(customize, "BOTTOMRIGHT", barberFrame, "BOTTOMRIGHT", 0, 0)) then
        customize:ClearAllPoints()
        customize:SetAllPoints(barberFrame)
        changed = true
    end
    if not entry.anchorYielded then entry.appliedPoints = CapturePoints(customize) end
    entry.modified = true
    return changed
end

local function RefreshBarberShopCustomizeLayout(barberFrame)
    local customize = _G.CharCustomizeFrame
    if not barberFrame or not customize then return end
    if not (barberFrame.IsShown and barberFrame:IsShown()) then return end
    if customize.IsShown and not customize:IsShown() then return end
    if customize.UpdateOptionsContainer and customize.Options then
        pcall(customize.UpdateOptionsContainer, customize)
    end
end

function RetailFullscreen:Restore()
    if InCombatLockdown and InCombatLockdown() then
        self:QueueAfterCombat(function() RetailFullscreen:Apply() end)
        return
    end
    local perks = self.entries.perks
    perks.frame = perks.frame or _G.PerksProgramFrame
    RestoreEntry(perks, UIParent)

    local barber = self.entries.barbershop
    local customizeChanged = RestoreEntry(self.entries.barbershopCustomize, UIParent)
    local barberParent = barber.frame and barber.frame.GetParent
        and select(2, pcall(barber.frame.GetParent, barber.frame)) or nil
    local barberChanged = RestoreEntry(barber, barberParent)
    if (customizeChanged or barberChanged) and barber.frame then
        RefreshBarberShopCustomizeLayout(barber.frame)
    end
    SyncLegacyFields()
end

function RetailFullscreen:Apply()
    if InCombatLockdown and InCombatLockdown() then
        local hasManaged = (Offhand.isRetail and (self.entries.perks.frame or _G.PerksProgramFrame))
            or ((Offhand.isRetail or Offhand.isForever) and (self.entries.barbershop.frame
                or IsFullScreenBarberShop(_G.BarberShopFrame)))
        if hasManaged then
            self:QueueAfterCombat(function() RetailFullscreen:Apply() end)
        end
        return false
    end

    local appliedAny = false

    -- Retail Trading Post (DefaultScaleFrame).
    local perks = self.entries.perks
    local perksFrame = perks.frame or (Offhand.isRetail and _G.PerksProgramFrame or nil)
    if perksFrame then
        perks.frame = perksFrame
        local perksMetrics = self:ShouldConstrain("perks")
        if perksMetrics then
            if ApplyMainhandBounds(perks, perksFrame, perksMetrics, true) then
                appliedAny = true
            end
        else
            RestoreEntry(perks, UIParent)
        end
    end

    -- Retail & Forever full-screen Barbershop (TopLevelParentScaleFrameTemplate
    -- or DefaultScaleFrame) + attached CharCustomizeFrame.
    local barber = self.entries.barbershop
    local barberFrame = barber.frame
    if not barberFrame and (Offhand.isRetail or Offhand.isForever)
        and IsFullScreenBarberShop(_G.BarberShopFrame) then
        self:AttachBarberShop()
        barberFrame = barber.frame
    end
    if barberFrame then
        local barberMetrics = self:ShouldConstrain("barbershop")
        if barberMetrics then
            local compensate = UsesIndependentDefaultScale(barberFrame)
            local ok, barberChanged = ApplyMainhandBounds(barber, barberFrame, barberMetrics, compensate)
            local customizeChanged = ok and ApplyAttachedCustomizeFrame(barberFrame) or false
            if ok then
                appliedAny = true
                if barberChanged or customizeChanged then
                    RefreshBarberShopCustomizeLayout(barberFrame)
                end
            end
        else
            local customizeChanged = RestoreEntry(self.entries.barbershopCustomize, UIParent)
            local barberParent = barberFrame.GetParent
                and select(2, pcall(barberFrame.GetParent, barberFrame)) or nil
            local barberChanged = RestoreEntry(barber, barberParent)
            if customizeChanged or barberChanged then
                RefreshBarberShopCustomizeLayout(barberFrame)
            end
        end
    end

    SyncLegacyFields()
    return appliedAny
end

function RetailFullscreen:Schedule()
    self.generation = (self.generation or 0) + 1
    local generation = self.generation
    for _, delay in ipairs({0, 0.1, 0.5}) do
        C_Timer.After(delay, function()
            if generation == RetailFullscreen.generation then
                RetailFullscreen:Apply()
            end
        end)
    end
end

local function HookFullScreenLifecycle(frame, kind)
    frame:HookScript("OnShow", function()
        if kind == "barbershop" then
            RetailFullscreen:Apply()
        end
        RetailFullscreen:Schedule()
    end)
    frame:HookScript("OnHide", function()
        if not RetailFullscreen:ShouldConstrain(kind) then
            RetailFullscreen:Restore()
        end
        C_Timer.After(0.1, function()
            local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
                and Offhand.Viewport:GetMetrics() or nil
            if Offhand.RawMouse and Offhand.RawMouse.Refresh then
                Offhand.RawMouse:Refresh(metrics)
            end
        end)
    end)
end

function RetailFullscreen:Attach()
    if not Offhand.isRetail then return false end
    local frame = _G.PerksProgramFrame
    local perks = self.entries.perks
    if not frame or perks.frame == frame then return false end
    perks.frame = frame
    perks.nativePoints = CapturePoints(frame)
    perks.nativeScale = frame.GetScale and frame:GetScale() or nil
    SyncLegacyFields()

    HookFullScreenLifecycle(frame, "perks")
    if frame:IsShown() then self:Schedule() end
    return true
end

function RetailFullscreen:AttachBarberShop()
    if not (Offhand.isRetail or Offhand.isForever) then return false end
    local frame = _G.BarberShopFrame
    local barber = self.entries.barbershop
    if not IsFullScreenBarberShop(frame) then return false end
    if barber.frame == frame then
        if frame:IsShown() then self:Schedule() end
        return false
    end
    barber.frame = frame
    barber.nativePoints = CapturePoints(frame)
    barber.nativeScale = frame.GetScale and frame:GetScale() or nil

    HookFullScreenLifecycle(frame, "barbershop")
    if frame:IsShown() then
        self:Apply()
        self:Schedule()
    end
    return true
end

if Offhand.isRetail or Offhand.isForever then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    pcall(loader.RegisterEvent, loader, "BARBER_SHOP_OPEN")
    loader:SetScript("OnEvent", function(_, event, loadedAddon)
        if event == "BARBER_SHOP_OPEN" then
            RetailFullscreen:AttachBarberShop()
            RetailFullscreen:Schedule()
            return
        end
        if type(loadedAddon) ~= "string" then return end
        if Offhand.isRetail and loadedAddon == "Blizzard_PerksProgram" then
            RetailFullscreen:Attach()
        elseif string.lower(loadedAddon) == "blizzard_barbershopui"
            or string.lower(loadedAddon) == "blizzard_charactercustomize" then
            RetailFullscreen:AttachBarberShop()
        end
    end)
    if Offhand.isRetail then RetailFullscreen:Attach() end
    RetailFullscreen:AttachBarberShop()
end
