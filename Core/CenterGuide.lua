-- Addon-owned alignment marks in the Mainhand viewport.
local _, Offhand = ...
local Guide = {}
Offhand.CenterGuide = Guide

local function CreateLine(frame, r, g, b, a)
    local line = frame:CreateTexture(nil, "OVERLAY")
    if line.SetColorTexture then line:SetColorTexture(r, g, b, a)
    else line:SetTexture(r, g, b, a) end
    return line
end

local function CreateGuide(self)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:EnableMouse(false)
    frame:Hide()
    self.vertical = CreateLine(frame, 1, 0.82, 0, 0.9)
    self.horizontal = CreateLine(frame, 1, 0.82, 0, 0.9)
    self.quarters = {
        CreateLine(frame, 1, 1, 1, 0.35), CreateLine(frame, 1, 1, 1, 0.35),
        CreateLine(frame, 1, 1, 1, 0.35), CreateLine(frame, 1, 1, 1, 0.35),
    }
    self.frame = frame
end

local function SetVertical(frame, line, x, width)
    line:ClearAllPoints()
    line:SetPoint("TOP", frame, "TOPLEFT", x, 0)
    line:SetPoint("BOTTOM", frame, "BOTTOMLEFT", x, 0)
    line:SetWidth(width)
end

local function SetHorizontal(frame, line, y, height)
    line:ClearAllPoints()
    line:SetPoint("LEFT", frame, "BOTTOMLEFT", 0, y)
    line:SetPoint("RIGHT", frame, "BOTTOMRIGHT", 0, y)
    line:SetHeight(height)
end

local function CanShow(metrics)
    return Offhand.db and Offhand.db.enabled and metrics and metrics.isSpanned
        and metrics.physicalHeight > 0 and metrics.screenHeight > 0
        and metrics.gameRight > metrics.gameLeft and metrics.gameTop > metrics.gameBottom
end

local function Layout(self, metrics)
    local frame = self.frame
    local width = metrics.gameRight - metrics.gameLeft
    local height = metrics.gameTop - metrics.gameBottom
    local pixel = metrics.screenHeight / metrics.physicalHeight
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", metrics.gameLeft, metrics.gameBottom)
    frame:SetSize(width, height)

    SetVertical(frame, self.vertical, width / 2, 2 * pixel)
    SetHorizontal(frame, self.horizontal, height / 2, 2 * pixel)
    SetVertical(frame, self.quarters[1], width / 4, pixel)
    SetVertical(frame, self.quarters[2], width * 3 / 4, pixel)
    SetHorizontal(frame, self.quarters[3], height / 4, pixel)
    SetHorizontal(frame, self.quarters[4], height * 3 / 4, pixel)
end

function Guide:Refresh(metrics)
    if not self.frame or not self.frame:IsShown() then return end
    if CanShow(metrics) then Layout(self, metrics)
    else self.frame:Hide() end
end

function Guide:Toggle()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
        return true
    end
    local metrics = Offhand.db and Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not CanShow(metrics) then return false end
    if not self.frame then CreateGuide(self) end
    Layout(self, metrics)
    self.frame:Show()
    return true
end
