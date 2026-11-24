local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local ns = shared
if type(shared) == "table" and shared.API and shared.API.GetBridgeNamespace then
    ns = shared.API.GetBridgeNamespace("DaylightUI")
end
if type(ns) ~= "table" or not ns.active or not ns.layout then return end

local DUI = ns.DUI
local Movers, EditMode = DUI.Movers, DUI.EditMode
local area, AREA = ns.area, ns.AREA
local Refresh, Print, signature, gameRect, pointDelta = ns.Refresh, ns.Print, ns.signature, ns.gameRect, ns.pointDelta

local PREFIX = "DaylightUI"          -- every frame DaylightUI names starts so
local SETTLE = { 3, 2 }              -- seconds in the world before, then between, the layout checks

-- ---------------------------------------------------------------------
-- Movers: a default hung from the screen hangs from the area instead.
-- ---------------------------------------------------------------------

-- Defaults kept as centre offsets from the screen's centre.
if type(Movers.DEFAULTS) == "table" then
    local centreDefaults = Movers.DEFAULTS
    Movers.DEFAULTS = setmetatable({}, { __index = function(_, key)
        local d = centreDefaults[key]
        if type(d) ~= "table" then return d end
        local dx, dy = pointDelta("CENTER")
        return { d[1] + dx, d[2] + dy }
    end })
end

local placed = {}            -- frames a mover places: left alone below

-- A default against the screen ({ point, nil or "UIParent", relPoint, x, y })
-- against the area instead; one against another frame is left as it is.
local function onArea(d)
    if type(d) ~= "table" then return d end
    local rel = d[2]
    if rel == nil or rel == "UIParent" or rel == UIParent then
        return { d[1], AREA, d[3], d[4], d[5] }
    end
    return d
end

-- DaylightUI's modules register their movers from PLAYER_LOGIN on, after
-- this file has run, so every one of them comes through here.
if type(Movers.Register) == "function" then
    local register = Movers.Register
    function Movers.Register(frame, key, label, default, opts)
        Refresh()
        -- A default can be a function giving one (the action bars', the quest
        -- tracker's): what it gives is moved each time.
        if type(default) == "function" then
            local give = default
            default = function() return onArea(give()) end
        else
            default = onArea(default)
        end
        if type(opts) == "table" and opts.proxy then
            -- An action bar's default spot, for its handle: worked out from the
            -- screen's bottom edge.
            local home = opts.home
            if home and type(key) == "string" and string.sub(key, 1, 11) == "actionbars." then
                opts.home = function()
                    local x, y = home()
                    if not x then return nil end
                    local dx, dy = pointDelta("BOTTOM")
                    return x + dx, y + dy
                end
            end
        else
            placed[frame] = true
        end
        return register(frame, key, label, default, opts)
    end
end

-- ---------------------------------------------------------------------
-- DaylightUI's other frames (its windows and pop-ups): one set against a
-- point of the screen ("CENTER" to "CENTER") goes against the area's. A
-- place given in plain screen offsets isn't touched. The top banners (zone
-- title, level-up, reputation) hang "CENTER" from the screen's "TOP" every
-- animation frame, so they go against the area's whatever the points.
-- ---------------------------------------------------------------------

-- The banners' names, and the frames found by them (keyed by frame).
local BANNERS = { DaylightUIZoneTitle = true, DaylightUILevelUp = true, DaylightUIRepBanner = true }
local banners = {}

local redirecting = false

local function redirect(self)
    if redirecting or placed[self] then return end
    if InCombatLockdown() and self:IsProtected() then return end
    redirecting = true
    pcall(function()
        for i = 1, self:GetNumPoints() do
            local point, rel, relPoint, x, y = self:GetPoint(i)
            if rel == UIParent and (point == relPoint or banners[self]) then
                self:SetPoint(point, area, relPoint, x, y)
            end
        end
    end)
    redirecting = false
end

local watched = {}

local function watch(frame)
    if type(frame) ~= "table" or not frame.SetPoint or watched[frame] or frame == area then return end
    watched[frame] = true
    hooksecurefunc(frame, "SetPoint", redirect)
end

-- Full-screen overlays that cover UIParent with SetAllPoints (which the
-- SetPoint redirect never sees) so their TOP/BOTTOM/CENTER children belong on
-- the game rectangle instead of spanning into Offhand or L/T-shaped voids.
local COVERS = { DaylightUIAfkScreen = true, DaylightUICdmEditor = true }
local covering = false
local covered = {}

local function applyCover(frame)
    if covering or type(frame) ~= "table" or not frame.SetAllPoints then return end
    if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
    local _, rel = frame.GetPoint and frame:GetPoint(1)
    if rel == area then return end
    covering = true
    pcall(function()
        frame:ClearAllPoints()
        frame:SetAllPoints(area)
    end)
    covering = false
end

local function cover(frame)
    if type(frame) ~= "table" or not frame.SetAllPoints then return end
    if not covered[frame] then
        covered[frame] = true
        if type(hooksecurefunc) == "function" then
            hooksecurefunc(frame, "SetAllPoints", function(self, target)
                if covering or target == area then return end
                if InCombatLockdown() and self.IsProtected and self:IsProtected() then return end
                covering = true
                pcall(function()
                    self:ClearAllPoints()
                    self:SetAllPoints(area)
                end)
                covering = false
            end)
        end
    end
end

function ns.CoverFrame(frame)
    cover(frame)
    applyCover(frame)
end

-- A DaylightUI frame by its name: watched from now on (and full-screen overlays
-- covered onto the game area).
local function adopt(name, frame)
    if BANNERS[name] and type(frame) == "table" then banners[frame] = true end
    watch(frame)
    if COVERS[name] and type(frame) == "table" and frame.SetAllPoints then cover(frame) end
end

if type(hooksecurefunc) == "function" then
    hooksecurefunc("CreateFrame", function(_, name)
        if type(name) == "string" and string.sub(name, 1, #PREFIX) == PREFIX then
            adopt(name, _G[name])
        end
    end)
end

-- Offhand loads after DaylightUI's modules, so frames they make as their files
-- load were made before the hook above. One pass over the frames finds them,
-- and a place one was given already goes onto the area. A protected frame
-- can't be moved in combat: ns.sweepPending asks for the pass again once
-- combat ends.
function ns.Sweep()
    if type(EnumerateFrames) ~= "function" then return end
    local skipped = false
    local combat = InCombatLockdown()
    local frame = EnumerateFrames()
    while frame do
        local current = frame
        pcall(function()
            if current.IsForbidden and current:IsForbidden() then return end
            local name = current.GetName and current:GetName()
            if type(issecretvalue) == "function" and issecretvalue(name) then return end
            if type(name) ~= "string" or string.sub(name, 1, #PREFIX) ~= PREFIX then return end
            adopt(name, current)
            if combat and current:IsProtected() then skipped = true end
            if COVERS[name] then
                if current.GetNumPoints and current:GetNumPoints() > 0 then applyCover(current) end
            else
                redirect(current)
            end
        end)
        frame = EnumerateFrames(frame)
    end
    ns.sweepPending = skipped or nil
end

-- The "Welcome back" text at login: an unnamed frame, made on the first
-- call and moved "CENTER" to "CENTER" by a tween.
local Fade = DUI.Fade
if type(Fade) == "table" and type(Fade.Welcome) == "function" then
    local welcome = Fade.Welcome
    Fade.Welcome = function(...)
        welcome(...)
        local f = Fade.welcome
        if type(f) == "table" and f.SetPoint then
            pcall(watch, f)
            pcall(redirect, f)
        end
    end
end

-- Unlock mode's Lock bar: DaylightUI 2.2.3+ wraps the buttons in lockButton.bar
-- (a draggable pill) and adds lockButton.tab (the folded Show tab). Keep the
-- Lock button attached inside b.bar, place b.bar on the game area when using
-- its default spot (or if a saved spot lands inside an L/T-shaped dead void),
-- preserve user-dragged spots on visible monitors, and keep b.tab on the area.
-- Falls back to moving b directly on older DaylightUI (2.2.1) without b.bar.
local function hasSavedUnlockBarSpot()
    local db = DUI.DB
    if type(db) ~= "table" or type(db.Root) ~= "function" then return false end
    local ok, root = pcall(db.Root)
    local spot = ok and type(root) == "table" and root.unlockBarSpot
    return type(spot) == "table" and type(spot[1]) == "number" and type(spot[2]) == "number"
end

local function isPointVisible(x, y)
    local fn = Offhand and Offhand.API and Offhand.API.IsPointVisible
    if type(fn) == "function" then
        local ok, visible = pcall(fn, x, y)
        if ok then return visible == true end
    end
    local l, b, r, t = gameRect()
    return x >= l and x <= r and y >= b and y <= t
end

local unlockBarHooked = {}
local unlockBarRedirecting = false

local function redirectUnlockBar(bar)
    if unlockBarRedirecting or InCombatLockdown() then return end
    local point, rel, relPoint, x, y = bar:GetPoint(1)
    if point ~= "TOP" or rel ~= UIParent or relPoint ~= "TOP" then return end
    if hasSavedUnlockBarSpot() then
        local _, _, _, _, sw, sh = gameRect()
        if isPointVisible(sw / 2 + (x or 0), sh + (y or 0)) then return end
        x, y = 0, -16
    end
    unlockBarRedirecting = true
    pcall(function()
        bar:ClearAllPoints()
        bar:SetPoint("TOP", area, "TOP", x or 0, y or -16)
    end)
    unlockBarRedirecting = false
end

if type(DUI.On) == "function" and type(Movers.LockButton) == "function" then
    DUI.On("UnlockChanged", function(unlocked)
        if not unlocked or InCombatLockdown() then return end
        local b = Movers.LockButton()
        if not b then return end
        if type(b.bar) == "table" and b.bar.SetPoint then
            if not unlockBarHooked[b.bar] and type(hooksecurefunc) == "function" then
                unlockBarHooked[b.bar] = true
                hooksecurefunc(b.bar, "SetPoint", redirectUnlockBar)
            end
            redirectUnlockBar(b.bar)
            if type(b.tab) == "table" and b.tab.SetPoint then
                watch(b.tab)
                redirect(b.tab)
            end
            return
        end
        local _, _, _, x, y = b:GetPoint(1)
        b:ClearAllPoints()
        b:SetPoint("TOP", area, "TOP", x or 0, y or -16)
    end)
end

-- ---------------------------------------------------------------------
-- The Edit Mode layout.
-- ---------------------------------------------------------------------

-- A part's default spot (the action bars': given against a screen edge,
-- with no frame named). A spot dragged to in unlock mode comes as a centre
-- offset, and the quest tracker's names UIParent: both are plain screen
-- terms already.
if type(EditMode.Anchor) == "function" then
    local anchor = EditMode.Anchor
    function EditMode.Anchor(entry, point, relPoint, x, y, relativeTo)
        if relativeTo == nil and type(x) == "number" and type(y) == "number" and type(relPoint) == "string"
            and not (point == "CENTER" and relPoint == "CENTER") then
            local dx, dy = pointDelta(relPoint)
            x, y = x + dx, y + dy
        end
        return anchor(entry, point, relPoint, x, y, relativeTo)
    end
end

-- The bundled layout, built on a single screen: everything it places
-- against the screen moves onto the game rectangle.
if type(EditMode.Base) == "function" then
    local base = EditMode.Base
    function EditMode.Base()
        local layout, bundled = base()
        if bundled and type(layout) == "table" then
            for _, entry in ipairs(layout.systems or {}) do
                local a = entry.anchorInfo
                if entry.isInDefaultPosition == false and type(a) == "table" and a.relativeTo == "UIParent"
                    and type(a.relativePoint) == "string"
                    and type(a.offsetX) == "number" and type(a.offsetY) == "number" then
                    local dx, dy = pointDelta(a.relativePoint)
                    a.offsetX, a.offsetY = a.offsetX + dx, a.offsetY + dy
                end
            end
        end
        return layout, bundled
    end
end

-- Whether the layout in use was written for another rectangle: the one we
-- last rebuilt it for isn't this one, or action bar 1, while in its default
-- spot (the bottom middle), isn't at this one's. Never rebuilt by this
-- bridge: on the whole screen nothing needs moving; on a game rectangle
-- action bar 1 decides (a layout the older DaylightOffhand addon already
-- moved over is kept, and remembered), and stale when it can't be read.
local function layoutStale()
    if type(EditMode.IsActive) ~= "function" or type(EditMode.Ours) ~= "function" then return false end
    local ok, active = pcall(EditMode.IsActive)
    if not (ok and active) then return false end
    local ours = EditMode.Ours()
    if not ours then return false end
    local db = ns.DB()
    local rect = db.rect
    local unproven = false
    if rect then
        if rect ~= signature() then return true end
    else
        local l, b, r, t, sw, sh = gameRect()
        if l ~= 0 or b ~= 0 or r ~= sw or t ~= sh then unproven = true end
    end
    local AB = Enum and Enum.EditModeSystem and Enum.EditModeSystem.ActionBar
    local idx = Enum and Enum.EditModeActionBarSystemIndices and Enum.EditModeActionBarSystemIndices.MainBar
    local entry = AB ~= nil and idx ~= nil and type(EditMode.FindSystem) == "function"
        and EditMode.FindSystem(ours, AB, idx)
    local a = entry and entry.anchorInfo
    if type(a) == "table" and a.point == "BOTTOM" and a.relativePoint == "BOTTOM" and type(a.offsetX) == "number" then
        local stale = math.abs(a.offsetX - (pointDelta("BOTTOM"))) > 1
        if unproven and not stale then db.rect = signature() end
        return stale
    end
    return unproven
end
ns.layoutStale = layoutStale

-- Rebuilds DaylightUI's layout for the rectangle: the bundled layout
-- (moved over, above) put in place as ours, then every part written into
-- it, and the reload a layout write needs.
-- Supports both DaylightUI 2.2.3+ (EditMode.Replace) and 2.2.1 (EditMode.ImportLayout).
local function Apply()
    if InCombatLockdown() then
        Print("can't change the layout in combat.")
        return
    end
    local layout, bundled
    if type(EditMode.Base) == "function" then
        layout, bundled = EditMode.Base()
    end
    local toText = C_EditMode and C_EditMode.ConvertLayoutInfoToString
    local replaceLayout = type(EditMode.Replace) == "function" and EditMode.Replace
        or (type(EditMode.ImportLayout) == "function" and EditMode.ImportLayout)
    if bundled and layout and type(toText) == "function" and replaceLayout then
        if layout.layoutName == nil and type(EditMode.Name) == "function" then
            layout.layoutName = EditMode.Name()
        end
        if layout.layoutType == nil and Enum and Enum.EditModeLayoutType then
            layout.layoutType = Enum.EditModeLayoutType.Account
        end
        local ok, text = pcall(toText, layout)
        local done, why = false, "the game couldn't share it"
        if ok and type(text) == "string" then
            local callOk, res, err = pcall(replaceLayout, text)
            if callOk then
                done, why = res, err
            else
                done, why = false, tostring(res)
            end
        end
        if not done then
            Print("couldn't rebuild the whole layout (" .. tostring(why) .. "); moving the action bars only.")
        end
    end
    if type(EditMode.Write) ~= "function" then
        Print("couldn't write the layout: DaylightUI EditMode.Write is unavailable.")
        return
    end
    local callOk, ok, why = pcall(EditMode.Write)
    if not callOk or not ok then
        Print("couldn't write the layout: " .. tostring(callOk and why or ok) .. ".")
        return
    end
    ns.DB().rect = signature()
    if ns.FlushDB then ns.FlushDB() end
    ReloadUI()
end

local function Ask()
    StaticPopupDialogs.OFFHAND_DAYLIGHTUI_APPLY = StaticPopupDialogs.OFFHAND_DAYLIGHTUI_APPLY or {
        text = "DaylightUI's action bars and game frames are laid out for a different screen area than Offhand's game monitor. Move them onto it? (Rebuilds the DaylightUI Edit Mode layout and reloads.)",
        button1 = "Apply and reload", button2 = LATER or "Later",
        OnAccept = Apply,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("OFFHAND_DAYLIGHTUI_APPLY")
end
ns.Ask = Ask

local function ResetMoversNow()
    if InCombatLockdown() then
        Print("can't reset DaylightUI frame positions in combat.")
        return
    end
    Refresh()
    if type(Movers) == "table" and type(Movers.ResetAll) == "function" then
        local ok, err = pcall(Movers.ResetAll)
        if not ok then
            Print("couldn't reset DaylightUI frame positions: " .. tostring(err) .. ".")
            return
        end
        if ns.FlushDB then ns.FlushDB() end
        Print("DaylightUI frame positions reset to Mainhand defaults.")
    end
end

local function AskResetMovers()
    StaticPopupDialogs.OFFHAND_DAYLIGHTUI_RESET_MOVERS = StaticPopupDialogs.OFFHAND_DAYLIGHTUI_RESET_MOVERS or {
        text = "Reset all manually dragged DaylightUI frame positions back to their Mainhand defaults? (Equivalent to /dui reset.)",
        button1 = RESET or "Reset", button2 = CANCEL or "Cancel",
        OnAccept = ResetMoversNow,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("OFFHAND_DAYLIGHTUI_RESET_MOVERS")
end
ns.ResetMovers = AskResetMovers

-- Once in the world and the rectangle has stopped changing (Offhand sets
-- the UI's scale as it starts): ask, once a session.
local asked, checking = false, false

function ns.Check()
    if asked or checking then return end
    checking = true
    C_Timer.After(SETTLE[1], function()
        local before = signature()
        C_Timer.After(SETTLE[2], function()
            checking = false
            Refresh()
            if asked or InCombatLockdown() or signature() ~= before then return end
            if layoutStale() then
                asked = true
                Ask()
            end
        end)
    end)
end

ns.Sweep()
