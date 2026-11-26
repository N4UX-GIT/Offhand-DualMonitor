--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/Shared/DefaultAnchors.lua: helpers shared by the default-anchor bridges

    Many addons place a frame with one anchor on UIParent's centre, top, bottom
    or a corner. With Offhand that spot lands on the seam between monitors or on
    the far monitor. The helpers here move such a frame to the same spot of the
    game rectangle instead, but only while it is still at the addon's own
    default spot (or where this helper last put it): a frame the player dragged
    somewhere else is always left alone.

    This file creates nothing by itself: no frame, timer, hook or global. It
    only fills the "Shared" bridge namespace, and each bridge file that finds
    its addon loaded uses these helpers to build its own fitter.

    Default-anchor bridges contributed by Kintrok (@DCtheGeek).
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.GetBridgeNamespace) ~= "function"
    or type(API.RegisterBridge) ~= "function" or type(API.GetGameRect) ~= "function" then return end

local Shared = API.GetBridgeNamespace("Shared")

local function WeakKeys()
    return setmetatable({}, { __mode = "k" })
end

function Shared.IsLoaded(name)
    local query = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
    if type(query) ~= "function" then return false end
    local ok, loaded = pcall(query, name)
    return ok and loaded and true or false
end

-- The Forever client reports an interface number from 16000 to 16999.
local function IsForever()
    if type(GetBuildInfo) ~= "function" then return false end
    local ok, _, _, _, toc = pcall(GetBuildInfo)
    toc = tonumber(toc)
    return ok and toc ~= nil and toc >= 16000 and toc < 17000
end

Shared.IsForever = IsForever

function Shared.Available(name)
    return type(name) == "string" and name ~= "" and IsForever() and Shared.IsLoaded(name)
end

-- left, bottom, right, top of the game rectangle, then the screen size, in
-- UIParent units from its bottom-left corner. The whole screen when not spanned.
function Shared.GameRect()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local ok, rect = pcall(API.GetGameRect)
    if ok and type(rect) == "table" and rect.isSpanned
        and type(rect.left) == "number" and type(rect.right) == "number"
        and type(rect.bottom) == "number" and type(rect.top) == "number"
        and rect.right > rect.left and rect.top > rect.bottom then
        return rect.left, rect.bottom, rect.right, rect.top, sw, sh
    end
    return 0, 0, sw, sh, sw, sh
end

function Shared.IsSpanned()
    local l, b, r, t, sw, sh = Shared.GameRect()
    return l > 0 or b > 0 or r < sw or t < sh
end

-- How far a point of the game rectangle is from the same point of the screen.
function Shared.PointDelta(point)
    local l, b, r, t, sw, sh = Shared.GameRect()
    local dx, dy
    if string.find(point, "LEFT", 1, true) then dx = l
    elseif string.find(point, "RIGHT", 1, true) then dx = r - sw
    else dx = (l + r) / 2 - sw / 2 end
    if string.find(point, "BOTTOM", 1, true) then dy = b
    elseif string.find(point, "TOP", 1, true) then dy = t - sh
    else dy = (b + t) / 2 - sh / 2 end
    return dx, dy
end

function Shared.Near(a, b)
    return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.6
end

-- ---------------------------------------------------------------------
-- Anchor fitter: spots = { [frameGlobalName] = { point, relativePoint, x, y } },
-- the other addon's own default single anchor on UIParent.
-- ---------------------------------------------------------------------

local function fit(self, name)
    local f, spot = _G[name], self.spots[name]
    if type(spot) ~= "table" or type(f) ~= "table" or type(f.GetPoint) ~= "function" then return false end
    if f.IsForbidden and f:IsForbidden() then return false end
    if f:GetNumPoints() ~= 1 then return false end
    local point, rel, relPoint, x, y = f:GetPoint(1)
    if point ~= spot[1] or relPoint ~= spot[2] or (rel ~= nil and rel ~= UIParent) then return false end
    local last = self.moved[f]
    local atDefault = Shared.Near(x, spot[3]) and Shared.Near(y, spot[4])
    local atOurs = last ~= nil and Shared.Near(x, last[1]) and Shared.Near(y, last[2])
    if not (atDefault or atOurs) then return false end
    local scale, base = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if type(scale) ~= "number" or scale <= 0 or type(base) ~= "number" or base <= 0 then return false end
    local dx, dy = Shared.PointDelta(spot[2])
    local k = base / scale                           -- SetPoint offsets are in the frame's own units
    local nx, ny = spot[3] + dx * k, spot[4] + dy * k
    if Shared.Near(x, nx) and Shared.Near(y, ny) then return false end   -- already there, or nothing to shift
    if f.IsProtected and f:IsProtected() and InCombatLockdown() then return false end   -- the next Refresh tries again
    f:ClearAllPoints()
    f:SetPoint(spot[1], UIParent, spot[2], nx, ny)
    if Shared.Near(nx, spot[3]) and Shared.Near(ny, spot[4]) then
        self.moved[f] = nil                          -- back at the addon's own default
    else
        self.moved[f] = { nx, ny }
    end
    self.moves = self.moves + 1
    return true
end

-- Hooks OnShow once so a frame the addon re-anchors as it opens is fitted at
-- once and again on the next frame. Protected frames get no hook.
local function watch(self, name)
    local f = _G[name]
    if type(f) ~= "table" or type(f.HookScript) ~= "function" or self.watched[f] then return end
    self.watched[f] = true
    if f.IsProtected and f:IsProtected() then return end
    f:HookScript("OnShow", function()
        self:Fit(name)
        if C_Timer and C_Timer.After then C_Timer.After(0, function() self:Fit(name) end) end
    end)
end

-- True while the frame still sits where this fitter last put it. A frame the
-- player (or its addon) has moved since is forgotten.
local function holds(self, name)
    local f, spot = _G[name], self.spots[name]
    local last = type(f) == "table" and self.moved[f]
    if not last or type(spot) ~= "table" then return false end
    local ok, still = pcall(function()
        if f:GetNumPoints() ~= 1 then return false end
        local point, rel, relPoint, x, y = f:GetPoint(1)
        return point == spot[1] and relPoint == spot[2] and (rel == nil or rel == UIParent)
            and Shared.Near(x, last[1]) and Shared.Near(y, last[2])
    end)
    if ok and still then return true end
    self.moved[f] = nil
    return false
end

function Shared.NewAnchorFitter(spots)
    local fitter = { spots = spots, moves = 0, moved = WeakKeys(), watched = WeakKeys() }

    function fitter:Fit(name)
        local ok, did = pcall(fit, self, name)
        return ok and did == true
    end

    function fitter:Refresh()
        for name in pairs(self.spots) do
            pcall(watch, self, name)
            self:Fit(name)
        end
    end

    -- True while this fitter holds the frame moved off the addon's default.
    function fitter:Holds(name)
        return holds(self, name)
    end

    function fitter:Count()
        local moved, seen, total = 0, 0, 0
        for name in pairs(self.spots) do
            total = total + 1
            local f = _G[name]
            if type(f) == "table" then
                seen = seen + 1
                if holds(self, name) then moved = moved + 1 end
            end
        end
        return moved, seen, total
    end

    return fitter
end

-- ---------------------------------------------------------------------
-- Parent holder: keeps adopted frames off UIParent itself.
-- ---------------------------------------------------------------------

function Shared.NewParentHolder(name)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(1, 1)
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    local adopted = WeakKeys()
    local holder = { frame = frame, taken = 0 }

    function holder:Adopt(icon)
        if type(icon) ~= "table" or adopted[icon] then return false end
        if type(icon.SetParent) ~= "function" or type(icon.GetParent) ~= "function" then return false end
        adopted[icon] = true
        self.taken = self.taken + 1
        hooksecurefunc(icon, "SetParent", function(frame, parent)
            if parent == UIParent then frame:SetParent(holder.frame) end
        end)
        if icon:GetParent() == UIParent then icon:SetParent(holder.frame) end
        return true
    end

    return holder
end

-- ---------------------------------------------------------------------
-- Registration and diagnostics
-- ---------------------------------------------------------------------

function Shared.Register(id, bridge)
    if type(bridge) ~= "table" then return false, "bridge" end
    bridge.contract = API.BRIDGE_CONTRACT
    local ok, why = API.RegisterBridge(id, bridge)
    if ok and type(API.RegisterGeometryCallback) == "function" and type(bridge.Refresh) == "function" then
        API.RegisterGeometryCallback(bridge, function() pcall(bridge.Refresh, bridge, "geometry"); return true end)
    end
    return ok, why
end

function Shared.Describe(label, fitter)
    local moved, _, total = fitter:Count()
    return string.format("%s=%d/%d", tostring(label), moved, total)
end
