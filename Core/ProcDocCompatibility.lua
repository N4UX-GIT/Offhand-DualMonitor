-- Optional presentation adapter. ProcDoc retains its alerts and saved settings.
local _, Offhand = ...
local Adapter = {}
Offhand.ProcDocCompatibility = Adapter
local owned, hooked = nil, setmetatable({}, {__mode = "k"})
local yielded = setmetatable({}, {__mode = "k"})
local applying
local function Number(value)
    if issecretvalue and issecretvalue(value) then return false end
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function Point(frame)
    if not frame.GetNumPoints or frame:GetNumPoints() ~= 1 then return nil end
    local point = {frame:GetPoint(1)}
    if not Number(point[4]) or not Number(point[5]) then return nil end
    return point
end
local function Same(a, b)
    if not a or not b then return false end
    for i = 1, 3 do if a[i] ~= b[i] then return false end end
    -- Native GetPoint rounds fractional coordinates (observed on Forever).
    -- Allow that round trip while still yielding to external placement changes.
    return math.abs(a[4] - b[4]) < 0.001 and math.abs(a[5] - b[5]) < 0.001
end
local function Usable(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
        and frame.GetParent and frame:GetParent() == UIParent
        and frame.ClearAllPoints and frame.SetPoint
end
local function Write(frame, point)
    applying = true
    -- Both supported layouts have one CENTER point. Replacing that point is
    -- enough and preserves the prior anchor if the setter rejects the write.
    local ok = pcall(frame.SetPoint, frame, unpack(point, 1, 5))
    applying = nil
    return ok
end
local function Release()
    local previous = owned
    if previous and Usable(previous.frame) and Same(Point(previous.frame), previous.applied) then
        if not Write(previous.frame, previous.original) then return false end
    end
    owned = nil
    return true
end
function Adapter:Refresh(vendorUpdate)
    if applying then return end
    if InCombatLockdown and InCombatLockdown() then self.status = "combat-deferred"; return end
    local db, frame = Offhand.db, _G.ProcDocAlertFrame
    local metrics = db and db.enabled and Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not db or not db.enabled or db.centerProcDocOnMainhand ~= true or not metrics or not metrics.isSpanned then
        if not Release() then self.status = "release-pending"; return end
        if frame then yielded[frame] = nil end
        self.status = "inactive"
        return
    end
    if owned and owned.frame ~= frame and not Release() then self.status = "release-pending"; return end
    if not Usable(frame) then self.status = frame and "external-or-protected" or "missing"; return end
    if vendorUpdate then yielded[frame] = nil end
    if yielded[frame] then self.status = "external-anchor"; return end
    local current = Point(frame)
    if owned and not Same(current, owned.applied) and not vendorUpdate then
        owned, yielded[frame], self.status = nil, true, "external-anchor"
        return
    end
    local original = owned and not vendorUpdate and owned.original or current
    if not original or original[1] ~= "CENTER" or original[3] ~= "CENTER"
        or (original[2] ~= UIParent and original[2] ~= nil) then self.status = "external-anchor"; return end
    local parentScale, scale = UIParent:GetEffectiveScale(), frame:GetEffectiveScale()
    if not Number(parentScale) or not Number(scale) or parentScale <= 0 or scale <= 0 then return end
    local x = ((metrics.gameLeft + metrics.gameRight) / 2 - UIParent:GetWidth() / 2) * parentScale / scale
    local y = ((metrics.gameBottom + metrics.gameTop) / 2 - UIParent:GetHeight() / 2) * parentScale / scale
    local desired = {"CENTER", UIParent, "CENTER", original[4] + x, original[5] + y}
    if not Same(current, desired) and not Write(frame, desired) then self.status = "unavailable"; return end
    owned = {frame = frame, original = original, applied = desired}
    if not hooked[frame] and type(frame.ApplyCenter) == "function" and type(hooksecurefunc) == "function" then
        hooksecurefunc(frame, "ApplyCenter", function() Adapter:Refresh(true) end)
        hooked[frame] = true
    end
    self.status = "active"
end

if CreateFrame then
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event, name)
        if event ~= "ADDON_LOADED" or name == "ProcDoc" then Adapter:Refresh() end
    end)
end
