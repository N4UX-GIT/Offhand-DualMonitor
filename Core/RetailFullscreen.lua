-- Retail full-screen experiences normally fill UIParent. When WoW is spanned,
-- that includes the Offhand workspace and any unused canvas around Mainhand.
-- Keep the Trading Post's dedicated full-screen frame inside the same physical
-- rectangle as WorldFrame without replacing Blizzard's interaction scripts.
local _, Offhand = ...

local RetailFullscreen = {}
Offhand.RetailFullscreen = RetailFullscreen

local abs = math.abs

local function Near(a, b)
    return a and b and abs(a - b) < 0.001
end

local function CapturePoints(frame)
    local points = {}
    if not frame.GetNumPoints or not frame.GetPoint then return points end
    for index = 1, frame:GetNumPoints() do
        points[#points + 1] = {frame:GetPoint(index)}
    end
    return points
end

local function HasPoint(frame, point, relativePoint, x, y)
    if not frame.GetNumPoints or not frame.GetPoint then return false end
    for index = 1, frame:GetNumPoints() do
        local currentPoint, relativeTo, currentRelativePoint, currentX, currentY = frame:GetPoint(index)
        if currentPoint == point and relativeTo == UIParent
            and currentRelativePoint == relativePoint
            and Near(currentX, x) and Near(currentY, y) then
            return true
        end
    end
    return false
end

function RetailFullscreen:ShouldConstrain()
    if not Offhand.isRetail or not Offhand.db or not Offhand.db.enabled
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

function RetailFullscreen:Restore()
    local frame = self.frame or _G.PerksProgramFrame
    if not frame or not self.modified then return end
    if InCombatLockdown and InCombatLockdown() then
        self:QueueAfterCombat(function() RetailFullscreen:Restore() end)
        return
    end

    if self.nativeScale and frame.SetScale then
        frame:SetScale(self.nativeScale)
    end
    self.appliedScale = nil
    frame:ClearAllPoints()
    if self.nativePoints and #self.nativePoints > 0 then
        for _, point in ipairs(self.nativePoints) do
            frame:SetPoint(unpack(point))
        end
    else
        frame:SetAllPoints(UIParent)
    end
    self.modified = false
end

function RetailFullscreen:Apply()
    local frame = self.frame or _G.PerksProgramFrame
    if not frame then return false end

    local metrics = self:ShouldConstrain()
    if not metrics then
        self:Restore()
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        self:QueueAfterCombat(function() RetailFullscreen:Apply() end)
        return false
    end

    -- DefaultScaleFrame calculates its native physical size against the full
    -- spanned canvas height. Preserve that Blizzard-selected scale, but adjust
    -- it so the Trading Post has the same physical size it would have on the
    -- Mainhand monitor by itself. This is a no-op for side-by-side displays
    -- with equal heights and compensates mixed-height or stacked canvases.
    local currentScale = frame.GetScale and frame:GetScale() or nil
    if currentScale and currentScale > 0
        and (not self.appliedScale or not Near(currentScale, self.appliedScale)) then
        self.nativeScale = currentScale
    end
    local canvasPixelHeight = tonumber(metrics.physicalHeight)
    local gamePixelHeight = tonumber(metrics.gamePixelHeight)
    local heightRatio = canvasPixelHeight and canvasPixelHeight > 0
        and gamePixelHeight and gamePixelHeight > 0
        and gamePixelHeight / canvasPixelHeight or 1
    local desiredScale = self.nativeScale and self.nativeScale * heightRatio or currentScale
    if desiredScale and desiredScale > 0 and frame.SetScale
        and not Near(currentScale, desiredScale) then
        frame:SetScale(desiredScale)
    end
    self.appliedScale = desiredScale

    local frameScale = frame:GetEffectiveScale()
    local parentScale = UIParent:GetEffectiveScale()
    if not frameScale or frameScale <= 0 or not parentScale or parentScale <= 0 then
        return false
    end
    local factor = parentScale / frameScale
    local left, bottom = metrics.gameLeft * factor, metrics.gameBottom * factor
    local right, top = metrics.gameRight * factor, metrics.gameTop * factor

    if frame:GetNumPoints() ~= 2
        or not HasPoint(frame, "BOTTOMLEFT", "BOTTOMLEFT", left, bottom)
        or not HasPoint(frame, "TOPRIGHT", "BOTTOMLEFT", right, top) then
        frame:ClearAllPoints()
        Offhand.Viewport:SetPoint(frame, "BOTTOMLEFT", "BOTTOMLEFT",
            metrics.gameLeft, metrics.gameBottom)
        Offhand.Viewport:SetPoint(frame, "TOPRIGHT", "BOTTOMLEFT",
            metrics.gameRight, metrics.gameTop)
    end
    self.modified = true
    return true
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

function RetailFullscreen:Attach()
    local frame = _G.PerksProgramFrame
    if not frame or self.frame == frame then return false end
    self.frame = frame
    self.nativePoints = CapturePoints(frame)
    self.nativeScale = frame.GetScale and frame:GetScale() or nil

    frame:HookScript("OnShow", function()
        RetailFullscreen:Schedule()
    end)
    frame:HookScript("OnHide", function()
        if not RetailFullscreen:ShouldConstrain() then
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

    if frame:IsShown() then self:Schedule() end
    return true
end

if Offhand.isRetail then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(_, _, loadedAddon)
        if loadedAddon == "Blizzard_PerksProgram" then
            RetailFullscreen:Attach()
        end
    end)
    RetailFullscreen:Attach()
end
