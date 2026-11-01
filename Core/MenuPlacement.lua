-- Refresh only the ordinary menu anchors this addon still owns. No native
-- scripts, panel metadata, protected attributes, scale or visibility changes.
local _, Offhand = ...
local Menus = {}
Offhand.MenuPlacement = Menus
local owned = setmetatable({}, {__mode = "k"})
local function Number(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
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
    if not Offhand.db or not Offhand.db.enabled or (InCombatLockdown and InCombatLockdown()) then return end
    for frame, anchor in pairs(owned) do
        local ok, stillOwned = pcall(Matches, frame, anchor)
        if not ok or not stillOwned then owned[frame] = nil
        else self:Center(frame) end
    end
end
