--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/ProcDoc/Bridge.lua: built-in bridge for ProcDoc alert centering

    This is the former Core/ProcDocCompatibility.lua moved behind the bridge
    contract; its behaviour is unchanged. It reads Offhand's enabled state, the
    game rectangle and its own opt-in setting (stored under its old key,
    centerProcDocOnMainhand) through Offhand.API only, offers that setting on
    the Pop-ups & alerts card, and reports ProcDocCenter=<status> at the end of
    the compatibility diagnostics.

    Like the core module it registers on every client before ProcDoc exists
    and keeps its own ADDON_LOADED and PLAYER_REGEN_ENABLED refreshes, so a
    ProcDoc that loads after Offhand is still centred.
--]]

-- Optional presentation adapter. ProcDoc retains its alerts and saved settings.
local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function"
    or type(API.GetGameRect) ~= "function" or type(API.IsEnabled) ~= "function"
    or type(API.GetBridgeSetting) ~= "function" or type(API.SetBridgeSetting) ~= "function"
    or type(API.GetText) ~= "function" or type(API.GetBridgeNamespace) ~= "function" then return end

local SETTING = "centerProcDocOnMainhand"
local Adapter = API.GetBridgeNamespace("ProcDoc")
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
    local enabled, frame = API.IsEnabled(), _G.ProcDocAlertFrame
    local rect = enabled and API.GetGameRect()
    if not enabled or API.GetBridgeSetting("ProcDoc", SETTING) ~= true or not rect or not rect.isSpanned then
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
    local x = ((rect.left + rect.right) / 2 - UIParent:GetWidth() / 2) * parentScale / scale
    local y = ((rect.bottom + rect.top) / 2 - UIParent:GetHeight() / 2) * parentScale / scale
    local desired = {"CENTER", UIParent, "CENTER", original[4] + x, original[5] + y}
    if not Same(current, desired) and not Write(frame, desired) then self.status = "unavailable"; return end
    owned = {frame = frame, original = original, applied = desired}
    if not hooked[frame] and type(frame.ApplyCenter) == "function" and type(hooksecurefunc) == "function" then
        hooksecurefunc(frame, "ApplyCenter", function() Adapter:Refresh(true) end)
        hooked[frame] = true
    end
    self.status = "active"
end

local bridge = {
    contract = API.BRIDGE_CONTRACT,
    data = {
        settings = {
            [SETTING] = { legacyKey = SETTING, default = false },
        },
        diagnostics = {
            { slot = "compat.tail", label = "ProcDocCenter",
                value = function() return Adapter.status or "inactive" end },
        },
    },
}

-- The layout pass ran the adapter just ahead of the bridges' layout refresh;
-- no other refresh reached it.
function bridge:Refresh(reason)
    if reason == "layout" then Adapter:Refresh() end
end

-- The opt-in checkbox of the Pop-ups & alerts card, shown while ProcDoc is
-- loaded and enabled for this character.
function bridge:GetSettingsContributions(slot)
    if slot ~= "alerts" then return nil end
    local description = API.GetText("PROCDOC_MAINHAND_DESC")
    return { {
        id = "procDocCenter", kind = "check", addon = "ProcDoc", width = 600, height = 32,
        text = API.GetText("PROCDOC_MAINHAND"), tooltip = description, help = description,
        get = function() return API.GetBridgeSetting("ProcDoc", SETTING) == true end,
        set = function(value)
            API.SetBridgeSetting("ProcDoc", SETTING, value == true)
            Adapter:Refresh()
        end,
    } }
end

if not API.RegisterBridge("ProcDoc", bridge) then return end

if CreateFrame then
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event, name)
        if event ~= "ADDON_LOADED" or name == "ProcDoc" then Adapter:Refresh() end
    end)
end
