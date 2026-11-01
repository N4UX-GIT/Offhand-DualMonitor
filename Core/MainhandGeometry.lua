--[[
    Offhand: Multi-Monitor Setup Addon
    Core/MainhandGeometry.lua: Mainhand rectangle and public geometry service
--]]

local _, Offhand = ...

local Mainhand = Offhand.Mainhand or {}
Offhand.Mainhand = Mainhand
Offhand.API = Offhand.API or {}

local Geometry = {}
Offhand.MainhandGeometry = Geometry

local anchor
local geometrySignature
local geometryRevision = 0
local geometryCallbacks = {}
local updatePending = false

function Geometry.Number(value)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return value
end

function Geometry.IsPlayerCombatRestricted()
    if InCombatLockdown and InCombatLockdown() then return true end
    if UnitAffectingCombat then
        local ok, active = pcall(UnitAffectingCombat, "player")
        if ok and active then return true end
    end
    return false
end

function Geometry.ValidMetrics(metrics)
    return type(metrics) == "table"
        and Geometry.Number(metrics.gameLeft) and Geometry.Number(metrics.gameBottom)
        and Geometry.Number(metrics.gameRight) and Geometry.Number(metrics.gameTop)
        and metrics.gameRight > metrics.gameLeft
        and metrics.gameTop > metrics.gameBottom
end

function Geometry.GetCurrentRect()
    local width = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
    local height = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    local active = Offhand.db and Offhand.db.enabled and metrics and metrics.isSpanned
        and Geometry.ValidMetrics(metrics) or false
    if active then
        return {
            left = metrics.gameLeft, bottom = metrics.gameBottom,
            right = metrics.gameRight, top = metrics.gameTop,
            width = metrics.gameRight - metrics.gameLeft,
            height = metrics.gameTop - metrics.gameBottom,
            screenWidth = width, screenHeight = height,
            isSpanned = true,
        }
    end
    return {
        left = 0, bottom = 0, right = width, top = height,
        width = width, height = height,
        screenWidth = width, screenHeight = height,
        isSpanned = false,
    }
end

function Geometry.Signature(rect)
    return string.format("%.1f:%.1f:%.1f:%.1f:%.1f:%.1f:%s",
        rect.left, rect.bottom, rect.right, rect.top,
        UIParent:GetWidth(), UIParent:GetHeight(), rect.isSpanned and "1" or "0")
end

function Geometry.CopyRect(rect)
    local copy = {}
    for key, value in pairs(rect or {}) do copy[key] = value end
    return copy
end

function Geometry.IsAnchor(frame)
    return frame == anchor
end

function Geometry.GetRevision()
    return geometryRevision
end

function Mainhand:CreateAnchor()
    if anchor or not CreateFrame or not UIParent then return anchor end
    anchor = CreateFrame("Frame", "OffhandMainhandFrame", UIParent)
    anchor:SetFrameStrata("BACKGROUND")
    anchor:SetFrameLevel(0)
    if anchor.EnableMouse then anchor:EnableMouse(false) end
    anchor:SetAllPoints(UIParent)
    Offhand.mainhandFrame = anchor
    return anchor
end

local function NotifyGeometry(rect, reason)
    for owner, callback in pairs(geometryCallbacks) do
        local ok, keep = pcall(callback, Geometry.CopyRect(rect),
            reason or "update", geometryRevision)
        if not ok or keep == false then geometryCallbacks[owner] = nil end
    end
end

function Mainhand:Update(reason)
    local region = self:CreateAnchor()
    if not region then return false end
    local rect = Geometry.GetCurrentRect()
    local signature = Geometry.Signature(rect)
    if signature == geometrySignature then return false end

    if InCombatLockdown and InCombatLockdown() then
        if not updatePending then
            updatePending = true
            local apply = function()
                updatePending = false
                Mainhand:Update("combat-ended")
            end
            if Offhand.RunOrQueueCombat then Offhand:RunOrQueueCombat(apply) end
        end
        return false
    end
    updatePending = false

    region:ClearAllPoints()
    region:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rect.left, rect.bottom)
    region:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", rect.right, rect.top)
    geometrySignature = signature
    geometryRevision = geometryRevision + 1
    self.rect = rect
    NotifyGeometry(rect, reason)
    return true
end

function Mainhand:GetRect()
    if not self.rect then self:Update("read") end
    return Geometry.CopyRect(self.rect or Geometry.GetCurrentRect())
end

function Mainhand:GetGeometrySignature()
    return Geometry.Signature(self:GetRect())
end

function Mainhand:GetGeometryRevision()
    return geometryRevision
end

function Offhand.API.GetMainhandFrame()
    return Mainhand:CreateAnchor()
end

function Offhand.API.GetMainhandRect()
    return Mainhand:GetRect()
end

function Offhand.API.GetGeometryRevision()
    return Mainhand:GetGeometryRevision()
end

function Offhand.API.RegisterGeometryCallback(owner, callback)
    if owner == nil or type(callback) ~= "function" then return false end
    geometryCallbacks[owner] = callback
    return true
end

function Offhand.API.UnregisterGeometryCallback(owner)
    geometryCallbacks[owner] = nil
end

function Offhand.API.AnchorToMainhand(frame, point, relativePoint, x, y)
    if not frame or not frame.ClearAllPoints or not frame.SetPoint then return false, "frame" end
    if frame.IsForbidden and frame:IsForbidden() then return false, "forbidden" end
    if frame.IsProtected and frame:IsProtected() then return false, "protected" end
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    local region = Mainhand:CreateAnchor()
    if not region then return false, "unavailable" end
    point = point or "CENTER"
    relativePoint = relativePoint or point
    frame:ClearAllPoints()
    frame:SetPoint(point, region, relativePoint, x or 0, y or 0)
    return true
end
