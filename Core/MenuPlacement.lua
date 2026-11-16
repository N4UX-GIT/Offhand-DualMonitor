-- Refresh only the ordinary menu anchors this addon still owns. No native
-- scripts, panel metadata, protected attributes, scale or visibility changes.
local _, Offhand = ...
local Menus = {}
Offhand.MenuPlacement = Menus
local owned = setmetatable({}, {__mode = "k"})
local function Number(value)
    return not (issecretvalue and issecretvalue(value))
        and type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function Usable(frame)
    if not frame or not frame.IsShown or not frame:IsShown() or not Offhand.db or not Offhand.db.enabled
        or (InCombatLockdown and InCombatLockdown()) then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    if frame.IsProtected and frame:IsProtected() then return false end
    return frame.GetPoint and frame.GetNumPoints and frame.ClearAllPoints and frame.SetPoint
        and frame.GetEffectiveScale and UIParent and UIParent.GetEffectiveScale
end
local function Matches(frame, anchor)
    if frame:GetNumPoints() ~= 1 then return false end
    local p, relative, rp, x, y = frame:GetPoint(1)
    return p == "CENTER" and relative == UIParent and rp == "CENTER"
        and Number(x) and Number(y) and math.abs(x - anchor.x) < 0.01 and math.abs(y - anchor.y) < 0.01
end
function Menus:Center(frame, metrics)
    local ok, centered = pcall(function()
        if not Usable(frame) then return false end
        local m = metrics or Offhand.Viewport and Offhand.Viewport:GetMetrics()
        if not m then return false end
        local parentScale, scale = UIParent:GetEffectiveScale(), frame:GetEffectiveScale()
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        for _, n in ipairs({parentScale, scale, width, height, m.gameLeft or false,
            m.gameRight or false, m.gameBottom or false, m.gameTop or false}) do
            if not Number(n) then return false end
        end
        if parentScale <= 0 or scale <= 0 or width <= 0 or height <= 0 then return false end
        local anchor = {
            x = ((m.gameLeft + m.gameRight) / 2 - width / 2) * parentScale / scale,
            y = ((m.gameBottom + m.gameTop) / 2 - height / 2) * parentScale / scale,
        }
        if not Matches(frame, anchor) then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", anchor.x, anchor.y)
        end
        owned[frame] = anchor
        return true
    end)
    return ok and centered == true
end
function Menus:Refresh()
    self:RecoverForeverTrade()
    if not Offhand.db or not Offhand.db.enabled or (InCombatLockdown and InCombatLockdown()) then return end
    for frame, anchor in pairs(owned) do
        local ok, stillOwned = pcall(Matches, frame, anchor)
        if not ok or not stillOwned then owned[frame] = nil
        else self:Center(frame) end
    end
end

local function FitsDisplay(m, left, top, width, height)
    local function Contained(l, b, r, t)
        return Number(l) and Number(b) and Number(r) and Number(t)
            and left >= l and left + width <= r and top <= t and top - height >= b
    end
    if Contained(m.gameLeft, m.gameBottom, m.gameRight, m.gameTop) then return true end
    if not m.workspaceRegions then
        return Contained(m.workspaceLeft, m.workspaceBottom, m.workspaceRight, m.workspaceTop)
    end
    for _, region in ipairs(m.workspaceRegions) do
        if Contained(region.x, region.y, region.x + region.width, region.y + region.height) then return true end
    end
    return false
end

local function ReadTradeAnchor(frame)
    if frame:GetNumPoints() ~= 1 then return end
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    if issecretvalue and (issecretvalue(point) or issecretvalue(relative) or issecretvalue(relativePoint)) then return end
    if point == "TOPLEFT" and relative == UIParent and Number(x) and Number(y) then
        return { point, relative, relativePoint, x, y }
    end
end

local function SameTradeAnchor(a, b)
    return a and b and a[3] == b[3] and math.abs(a[4] - b[4]) < 0.01 and math.abs(a[5] - b[5]) < 0.01
end

local function SetTradeAnchor(frame, original, desired)
    if SameTradeAnchor(original, desired) then return true end
    local function Apply(point)
        frame:ClearAllPoints()
        frame:SetPoint(unpack(point))
    end
    local wrote = pcall(Apply, desired)
    local read, actual = pcall(ReadTradeAnchor, frame)
    if wrote and read and SameTradeAnchor(actual, desired) then return true end
    if not read or not SameTradeAnchor(actual, original) then pcall(Apply, original) end
    return false
end

local tradePlacement
function Menus:RecoverForeverTrade()
    if not Offhand.isForever or Offhand._loggingOut or (InCombatLockdown and InCombatLockdown())
        or (Offhand.IsGamepadUIEnabled and Offhand:IsGamepadUIEnabled()) then return false end
    local canvas = Offhand.Canvas
    if canvas and canvas.CanManagePanelsFromAddon and not canvas.CanManagePanelsFromAddon() then return false end
    local frame, db = _G.TradeFrame, Offhand.db
    if tradePlacement and tradePlacement.frame ~= frame then tradePlacement = nil end
    if not frame or not db then return false end
    local ok, recovered = pcall(function()
        local policy, frameState = Offhand.HUDTransientPolicy, Offhand.CanvasFrameState
        if not policy.CanPosition(frame) or (frame.IsUserPlaced and frame:IsUserPlaced())
            or (frameState and frameState.IsDragging(frame)) then return false end
        local current = ReadTradeAnchor(frame)
        local state = tradePlacement
        if state and not SameTradeAnchor(current, state.applied) then
            tradePlacement, state = nil, nil
        end
        if not current then return false end
        local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
        if not db.enabled or not db.seamRedirect or not m or not m.isSpanned or not frame:IsShown()
            or (frame.IsVisible and not frame:IsVisible()) then
            if state and SetTradeAnchor(frame, current, state.native) then tradePlacement = nil end
            return false
        end
        if not state and current[3] ~= "TOPLEFT" then return false end
        if (db.savedWorkspacePositions and db.savedWorkspacePositions.TradeFrame)
            or (db.savedMainPositions and db.savedMainPositions.TradeFrame)
            or (Offhand.WorkspaceRouting and Offhand.WorkspaceRouting:HasRule("TradeFrame", m)) then return false end

        local scale, uiScale = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
        local left, top, width, height = frame:GetLeft(), frame:GetTop(), frame:GetWidth(), frame:GetHeight()
        if not Number(scale) or not Number(uiScale) or not Number(left) or not Number(top)
            or not Number(width) or not Number(height) or scale <= 0 or uiScale <= 0
            or width <= 0 or height <= 0 then return false end
        local factor = scale / uiScale
        if (not state and FitsDisplay(m, left * factor, top * factor, width * factor, height * factor))
            or width * factor > m.gameRight - m.gameLeft or height * factor > m.gameTop - m.gameBottom then
            return false
        end
        -- Blizzard uses TOPLEFT offsets for its UIPanel slots. Keep the same
        -- offsets inside Mainhand and yield when another owner changes the anchor.
        local native = state and state.native or current
        local x = math.max(m.gameLeft / factor, math.min(m.gameRight / factor - width, m.gameLeft / factor + native[4]))
        local y = math.min(m.gameTop / factor, math.max(m.gameBottom / factor + height, m.gameTop / factor + native[5]))
        local desired = { "TOPLEFT", UIParent, "BOTTOMLEFT", x, y }
        if not SetTradeAnchor(frame, current, desired) then return false end
        tradePlacement = { frame = frame, native = native, applied = desired }
        return true
    end)
    return ok and recovered == true
end

-- Cooldown Settings is an ordinary registered UIPanel, not a cooldown HUD
-- system. Keep the broad HUD ownership guards intact and observe its dedicated
-- Blizzard event, without scripts or bookkeeping on the native frame tree.
function Menus:RecoverForeverCooldownSettings(frame)
    local ok, recovered = pcall(function()
        if not Offhand.isForever or frame ~= _G.CooldownViewerSettings or not Usable(frame)
            or (Offhand.db and Offhand.db.seamRedirect == false)
            or (Offhand.IsGamepadUIEnabled and Offhand:IsGamepadUIEnabled()) then return false end
        local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
        if not m or not m.isSpanned then return false end
        local factor = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local left, top, width, height = frame:GetLeft(), frame:GetTop(), frame:GetWidth(), frame:GetHeight()
        for _, value in ipairs({factor, left, top, width, height}) do
            if not Number(value) then return false end
        end
        if factor <= 0 or width <= 0 or height <= 0 then return false end
        left, top, width, height = left*factor, top*factor, width*factor, height*factor
        if FitsDisplay(m, left, top, width, height) then return false end
        return self:Center(frame, m)
    end)
    return ok and recovered == true
end

function Menus:InstallForeverSettingsRecovery()
    if not Offhand.isForever or self.settingsRecoveryInstalled or not EventRegistry
        or type(EventRegistry.RegisterCallback) ~= "function" then return false end
    self.settingsRecoveryInstalled = true
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", function(_, frame)
        self.settingsRecoveryGeneration = (self.settingsRecoveryGeneration or 0)+1
        local generation = self.settingsRecoveryGeneration
        -- Native ShowUIPanel can place the root after OnShow. Wait for that
        -- transaction, then inspect the live bounds rather than its stock anchor.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if generation == self.settingsRecoveryGeneration then self:RecoverForeverCooldownSettings(frame) end
            end)
        end
    end, self)
    return true
end
