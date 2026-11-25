local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local ns = shared
if type(shared) == "table" and shared.API and shared.API.GetBridgeNamespace then
    ns = shared.API.GetBridgeNamespace("DaylightUI")
end
if type(ns) ~= "table" or not ns.active or not ns.layout then return end

local DUI = ns.DUI
local Movers = DUI.Movers
local area, gameRect = ns.area, ns.gameRect

-- ---------------------------------------------------------------------
-- The work scene (fishing, crafting): on the game rectangle.
-- ---------------------------------------------------------------------
-- DaylightUI_QoL (Fishing.lua) draws a scene along the bottom of the
-- screen while you fish or craft: water and a bobber, or an anvil, sparks
-- and a "3 / 20" batch count. Its frame, DaylightUIFishScene, covers
-- UIParent with SetAllPoints (which the SetPoint redirect never sees) and
-- its layout() takes its width, middle and waterline from UIParent's size,
-- so with Offhand the scene is centred on the seam between the monitors,
-- half of it under the other monitor's panels.
--
-- layout() runs at the start of each cast or craft (Scene.Cast and
-- Scene.Craft); right after it, the frame goes over the game rectangle and
-- the numbers layout() worked out are worked out again from that. The
-- per-frame drawing reads them back (f.w, f.mid, f.line), so it follows.

local function workScene()
    if type(DUI.GetModule) ~= "function" then return nil end
    local mod = DUI:GetModule("QoL")
    local fish = type(mod) == "table" and type(mod.ns) == "table" and mod.ns.Fishing
    local scene = type(fish) == "table" and fish.Scene
    if type(scene) ~= "table" then return nil end
    return scene
end

local function fitScene()
    local f = _G.DaylightUIFishScene
    if type(f) ~= "table" or not f.SetAllPoints then return end
    local l, _, r, _, sw = gameRect()
    local spanned = l > 0 or r < sw
    f:ClearAllPoints()
    f:SetAllPoints(spanned and area or UIParent)
    if not spanned then return end
    local W, H = area:GetWidth(), area:GetHeight()
    local oldW, oldH, oldLine = f.w, f.h, f.line
    if not (W and W > 0 and H and H > 0) then return end
    if type(oldW) ~= "number" or oldW <= 0 or type(oldH) ~= "number" or oldH <= 0
        or type(oldLine) ~= "number" then return end
    if math.abs(oldW - W) < 0.5 then return end          -- already fitted since the last layout()
    f.w, f.h, f.line, f.mid = W, H, oldLine * H / oldH, W / 2
    -- The same pieces, the same shares as DaylightUI's layout().
    if f.deep then
        f.deep:ClearAllPoints()
        f.deep:SetPoint("CENTER", f, "BOTTOM", 0, -H * 0.1)
        f.deep:SetSize(W * 1.6, H * 0.62)
    end
    if f.shine then
        f.shine:ClearAllPoints()
        f.shine:SetPoint("CENTER", f, "BOTTOM", 0, -H * 0.06)
        f.shine:SetSize(W * 0.9, H * 0.36)
    end
    if f.flare then
        f.flare:ClearAllPoints()
        f.flare:SetPoint("CENTER", f, "BOTTOMLEFT", f.mid, f.line)
    end
    if type(f.bits) == "table" then
        local k = W / oldW
        for _, t in ipairs(f.bits) do t:SetWidth(t:GetWidth() * k) end
    end
    if f.tide then f.tide:SetHeight(f.line + 3) end
    if f.count then
        f.count:ClearAllPoints()
        f.count:SetPoint("CENTER", f, "BOTTOMLEFT", f.mid, f.line - 40)
    end
end

local sceneWrapped = false

function ns.SceneRefresh()
    if sceneWrapped then return end
    local scene = workScene()
    if not scene then return end
    sceneWrapped = true
    for _, name in ipairs({ "Cast", "Craft" }) do
        local original = scene[name]
        if type(original) == "function" then
            scene[name] = function(...)
                original(...)
                pcall(fitScene)
            end
        end
    end
end

-- ---------------------------------------------------------------------
-- The campfire scene (and the sleeping bag's count): on the game rectangle.
-- ---------------------------------------------------------------------
-- DaylightUI_QoL (Campfire.lua) is built the same way as the work scene: its
-- frame, DaylightUICampfire, covers UIParent with SetAllPoints and its
-- layout() sizes the glow, the rising lines ("Warmed by the fire"), the
-- buff's mark and the counts from UIParent's size, so with Offhand it all
-- sat on the seam. layout() is local and runs whenever the scene is shown,
-- so the frame is fitted after each of the module's entry points, and a
-- check after its own OnUpdate catches any layout() in between (the
-- drawing reads f.w and f.h back every frame, so it follows).

local function campfire()
    if type(DUI.GetModule) ~= "function" then return nil end
    local mod = DUI:GetModule("QoL")
    local fire = type(mod) == "table" and type(mod.ns) == "table" and mod.ns.Campfire
    return type(fire) == "table" and fire or nil
end

local fireHooked, fireOn = false, nil

local function fitFire()
    local f = _G.DaylightUICampfire
    if type(f) ~= "table" or not f.SetAllPoints then return end
    if not fireHooked then
        fireHooked = true
        f:HookScript("OnUpdate", function() pcall(fitFire) end)
    end
    local l, _, r, _, sw = gameRect()
    local on = (l > 0 or r < sw) and area or UIParent
    if fireOn ~= on then
        fireOn = on
        f:ClearAllPoints()
        f:SetAllPoints(on)
    end
    local W, H = on:GetWidth(), on:GetHeight()
    if not (W and W > 0 and H and H > 0) then return end
    if type(f.w) ~= "number" or type(f.h) ~= "number" then return end       -- no layout() yet
    if math.abs(f.w - W) < 0.5 and math.abs(f.h - H) < 0.5 then return end   -- fitted since the last one
    local C = campfire() or {}
    local wide = type(C.WORDS_WIDE) == "number" and C.WORDS_WIDE or 0.42
    local markAt = type(C.MARK_AT) == "number" and C.MARK_AT or 0.2
    local below = type(C.BAG) == "table" and type(C.BAG.BELOW) == "number" and C.BAG.BELOW or 52
    -- The same pieces, the same shares as DaylightUI's layout().
    if f.dome then
        f.dome:SetSize(W * 1.5, H * 0.9)
        f.dome:ClearAllPoints()
        f.dome:SetPoint("CENTER", f, "BOTTOM", 0, -H * 0.12)
    end
    if f.core then
        f.core:SetSize(W * 0.8, H * 0.5)
        f.core:ClearAllPoints()
        f.core:SetPoint("CENTER", f, "BOTTOM", 0, -H * 0.08)
    end
    if type(f.words) == "table" then
        for _, w in ipairs(f.words) do
            if type(w) == "table" and w.fs then w.fs:SetWidth(W * wide) end
        end
    end
    if f.mark then
        f.mark:ClearAllPoints()
        f.mark:SetPoint("CENTER", f, "BOTTOM", 0, H * markAt)
    end
    if f.count then
        f.count:ClearAllPoints()
        f.count:SetPoint("CENTER", f, "BOTTOM", 0, H * markAt)
    end
    if f.bagTime then
        f.bagTime:ClearAllPoints()
        f.bagTime:SetPoint("CENTER", f, "BOTTOM", 0, H * markAt - below)
    end
    f.w, f.h = W, H
end

local fireWrapped = false

function ns.FireRefresh()
    pcall(fitFire)          -- the /dui campfire preview is called past the wraps below
    if fireWrapped then return end
    local fire = campfire()
    if not fire then return end
    fireWrapped = true
    for _, name in ipairs({ "Check", "BagCheck", "BagStart", "Preview", "PreviewBag" }) do
        local original = fire[name]
        if type(original) == "function" then
            fire[name] = function(...)
                original(...)
                pcall(fitFire)
            end
        end
    end
end

-- ---------------------------------------------------------------------
-- The data bar: its width a share of the game rectangle's.
-- ---------------------------------------------------------------------
-- DaylightUI_InfoPanel (DataBar.lua) sizes the bar along the bottom as a
-- share of UIParent's width (Bar.Zones), so with Offhand it ran across both
-- monitors. Bar.Room, which says whether the bar needs the bottom corners
-- kept clear, works from the same width. Both are called through the
-- table, so the bar is sized again from the area after each Zones, and
-- Room gives its answer from the area's width.

local function dataBar()
    if type(DUI.GetModule) ~= "function" then return nil end
    local mod = DUI:GetModule("InfoPanel")
    local Bar = type(mod) == "table" and type(mod.ns) == "table" and mod.ns.DataBar
    if type(Bar) ~= "table" or type(mod.db) ~= "table" or type(mod.db.databar) ~= "table" then return nil end
    return mod, Bar
end

local function fitBar()
    local mod, Bar = dataBar()
    if not mod then return end
    if not (Bar.frame and Bar.leftArea and Bar.rightArea and Bar.centerArea) then return end      -- not built yet
    if InCombatLockdown() and Bar.frame:IsProtected() then return end
    local c = mod.db.databar
    local pct = tonumber(c.widthPct)
    if not pct then return end
    local W = math.floor(area:GetWidth() * pct / 100)
    if W <= 0 or math.abs(Bar.frame:GetWidth() - W) < 0.5 then return end
    -- The same shares as DaylightUI's Zones(); a middle tab is there when
    -- Zones gave it a width.
    local tabW = Bar.centerArea:GetWidth() > 1.5 and (Bar.TAB_W or 128) or 0
    local side = math.max(1, (W - tabW) / 2 - 2 * (Bar.INSET or 22))
    Bar.frame:SetWidth(W)
    Bar.leftArea:SetWidth(side)
    Bar.rightArea:SetWidth(side)
    for _, key in ipairs({ "left", "center", "right" }) do
        local part = Bar[key]
        if type(part) == "table" and type(part.Layout) == "function" then part.Layout() end
    end
    if Bar.on and type(Movers.SetBottomRoom) == "function" and type(Bar.Room) == "function" then
        pcall(function() Movers.SetBottomRoom(Bar.Room(mod.db)) end)
    end
end

local barWrapped = false

function ns.BarRefresh()
    pcall(fitBar)           -- DaylightUI's first layout can come before the wraps below
    if barWrapped then return end
    local mod, Bar = dataBar()
    if not mod then return end
    barWrapped = true
    local zones = Bar.Zones
    if type(zones) == "function" then
        Bar.Zones = function(...)
            zones(...)
            pcall(fitBar)
        end
    end
    local room = Bar.Room
    if type(room) == "function" then
        Bar.Room = function(db, ...)
            local theirs = room(db, ...)
            local ok, ours = pcall(function()
                local c = db.databar
                if c.enabled ~= true or Movers.Valid(DUI.DB.Positions()[Bar.KEY]) then return 0 end
                return area:GetWidth() * (100 - c.widthPct) / 200 < Bar.CORNER and c.height or 0
            end)
            if ok and type(ours) == "number" then return ours end
            return theirs
        end
    end
end

-- ---------------------------------------------------------------------
-- Loot rolls: one steady spot on the game rectangle.
-- ---------------------------------------------------------------------
-- DaylightUI_Skins (Rolls/Stack.lua) shows its own roll cards and hangs
-- them from GameMovers.RollSlot(). With no spot of the player's own, that
-- is wherever the game's roll container stands. The game lays the container
-- out at the middle of the whole screen (the seam between the monitors);
-- Offhand moves it onto the game monitor; the game's next alert layout puts
-- it back. The cards followed it both ways on every roll change.
--
-- While the screen is spanned and the Loot Rolls handle was never moved,
-- the slot is where Offhand puts roll pop-ups, whatever the container is
-- doing (Offhand.API.GetGroupLootSpot: the spot of Offhand's own Group Loot
-- Rolls mover if that was dragged, else the middle of the game rectangle,
-- 190 HUD units up). A spot dragged to with DaylightUI's handle is kept as
-- it is.

local ROLLS = "GroupLootContainer"
ns.ROLLS = ROLLS

-- The slot's centre in UIParent's units from its bottom-left corner, or nil
-- to leave DaylightUI's own answer alone. h: the slot's height.
local function rollSpot(h)
    local ok, x, y = pcall(Offhand.API.GetGroupLootSpot, h)
    if ok and type(x) == "number" and type(y) == "number" then return x, y end
    return nil
end
ns.rollSpot = rollSpot

local GameMovers = DUI.GameMovers
local rollSlot = type(GameMovers) == "table" and GameMovers.RollSlot
if type(rollSlot) == "function" then
    GameMovers.RollSlot = function(...)
        local x, y, w, h = rollSlot(...)
        local ok, X, Y = pcall(function()
            if type(GameMovers.Spot) == "function" and GameMovers.Spot(ROLLS) then return nil end
            local key = type(GameMovers.Key) == "function" and GameMovers.Key(ROLLS)
            local handle = key and type(Movers.Handle) == "function" and Movers.Handle(key)
            if type(handle) == "table" and handle.moving then return nil end          -- being dragged
            return rollSpot(h)
        end)
        if ok and type(X) == "number" and type(Y) == "number" then
            return X - UIParent:GetWidth() / 2, Y - UIParent:GetHeight() / 2, w, h
        end
        return x, y, w, h
    end
end

-- ---------------------------------------------------------------------
-- The vendor and trainer windows: Offhand's placing isn't a takeover.
-- ---------------------------------------------------------------------
-- DaylightUI (Windows/Follow.lua) keeps the game's vendor and trainer
-- windows shown but out of sight under a holder scaled to a thousandth, and
-- shows its own window instead. It takes an offset of 10000 or more from
-- the screen to mean another addon moved the game's window away to use it
-- itself, and then closes its own. Offhand places the game's window on the
-- game monitor in real screen terms, which under that holder is an offset
-- a thousand times larger: DaylightUI's window closed, the game's stayed
-- see-through, and no vendor window showed at all.
--
-- When the window is still under the holder, not shrunk, and its real spot
-- is on the screen, it hasn't been taken: Away says no, and Home gives no
-- spot (the offset isn't one DaylightUI can read), so DaylightUI's window
-- opens at its own default place or the one it was dragged to.

local Followers = type(DUI.Win) == "table" and DUI.Win.Followers
if type(Followers) == "table" and type(Followers.Away) == "function" and type(Followers.Home) == "function" then
    local function placedUnderHolder(f)
        if type(f) ~= "table" or not f.GetParent or f:GetParent() ~= Followers.aside then return false end
        local scale = f:GetScale()
        if type(scale) ~= "number" or scale < (Followers.SHRUNK or 0.01) then return false end
        local point, rel, _, x, y = f:GetPoint(1)
        if point == nil or (rel ~= nil and rel ~= UIParent) then return false end
        local far = Followers.AWAY or 10000
        if type(x) ~= "number" or type(y) ~= "number" or (math.abs(x) < far and math.abs(y) < far) then return false end
        local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local left, top = f:GetLeft(), f:GetTop()
        if type(left) ~= "number" or type(top) ~= "number" then return false end
        left, top = left * k, top * k
        return left >= -1 and left <= UIParent:GetWidth() + 1 and top >= -1 and top <= UIParent:GetHeight() + 1
    end

    local away = Followers.Away
    Followers.Away = function(def, kind, ...)
        local gone = away(def, kind, ...)
        if gone then
            local ok, placed = pcall(function()
                local get = def.frames[kind]
                return def.parked[kind] == true and placedUnderHolder(get and get())
            end)
            if ok and placed then return false end
        end
        return gone
    end

    local home = Followers.Home
    Followers.Home = function(g, ...)
        local ok, placed = pcall(placedUnderHolder, g)
        if ok and placed then return nil end
        return home(g, ...)
    end
end

-- ---------------------------------------------------------------------
-- The Cooldown Manager layout editor: on the game rectangle.
-- ---------------------------------------------------------------------
-- DaylightUI_ActionBars (CdmEditor.lua) covers UIParent with SetAllPoints
-- on DaylightUICdmEditor (which Placement.lua redirects onto area). Its live
-- layout frame DaylightUICdmLayout1/2 is already centered on area by the
-- SetPoint redirect, so both live pieces and editor previews share area's
-- center. Cursor(), Tether.PointAt(), FrameRects() and ShowGuides() read
-- UIParent's center directly, so translate them by pointDelta("CENTER")
-- so dragging, dropping, chooser popups, tethering and snap guides align
-- pixel-for-pixel with Mainhand.

local function cdmModules()
    if type(DUI.GetModule) ~= "function" then return nil end
    local ok, mod = pcall(DUI.GetModule, DUI, "ActionBars")
    local ab = ok and type(mod) == "table" and type(mod.ns) == "table" and mod.ns or nil
    if not ab then return nil end
    return ab.CdmEditor, ab.CdmTether
end

local cdmEditorWrapped, cdmTetherWrapped, cdmMoversWrapped = false, false, false
local cdmChooserHooked = {}
local cdmChooserClamping = false

local function clampChooser(chooser)
    if cdmChooserClamping or InCombatLockdown() then return end
    local point, rel, relPoint, x, y = chooser:GetPoint(1)
    if point ~= "TOP" or rel ~= _G.DaylightUICdmEditor or relPoint ~= "CENTER"
        or type(x) ~= "number" or type(y) ~= "number" then return end
    local l, b, r, t = gameRect()
    local aw, ah = r - l, t - b
    if type(aw) ~= "number" or aw <= 0 or type(ah) ~= "number" or ah <= 0 then return end
    local hw, hh = aw / 2, ah / 2
    local cx = math.max(-hw + 130, math.min(x, hw - 130))
    local cy = math.max(-hh + 136, math.min(y, hh - 34))
    if math.abs(cx - x) < 0.5 and math.abs(cy - y) < 0.5 then return end
    cdmChooserClamping = true
    pcall(function()
        chooser:ClearAllPoints()
        chooser:SetPoint("TOP", rel, "CENTER", cx, cy)
    end)
    cdmChooserClamping = false
end

function ns.CdmRefresh()
    local overlay = _G.DaylightUICdmEditor
    if type(overlay) == "table" and overlay.SetAllPoints and ns.CoverFrame then
        pcall(ns.CoverFrame, overlay)
    end
    local Ed, Tether = cdmModules()
    if type(Ed) == "table" and not cdmEditorWrapped then
        cdmEditorWrapped = true
        if type(Ed.Cursor) == "function" then
            local cursor = Ed.Cursor
            Ed.Cursor = function(...)
                local x, y = cursor(...)
                if type(x) ~= "number" or type(y) ~= "number" then return x, y end
                local dx, dy = ns.pointDelta("CENTER")
                return x - dx, y - dy
            end
        end
        if type(Ed.Draw) == "function" then
            local draw = Ed.Draw
            Ed.Draw = function(...)
                local a, b, c = draw(...)
                local ch = type(Ed.Chooser) == "function" and Ed.Chooser() or nil
                if type(ch) == "table" and ch.SetPoint then
                    if not cdmChooserHooked[ch] and type(hooksecurefunc) == "function" then
                        cdmChooserHooked[ch] = true
                        hooksecurefunc(ch, "SetPoint", clampChooser)
                    end
                    clampChooser(ch)
                end
                return a, b, c
            end
        end
    end
    if type(Tether) == "table" and not cdmTetherWrapped then
        cdmTetherWrapped = true
        if type(Tether.PointAt) == "function" then
            local pointAt = Tether.PointAt
            Tether.PointAt = function(...)
                local x, y = pointAt(...)
                if type(x) ~= "number" or type(y) ~= "number" then return x, y end
                local dx, dy = ns.pointDelta("CENTER")
                return x - dx, y - dy
            end
        end
    end
    if type(Ed) == "table" and type(Movers) == "table" and not cdmMoversWrapped then
        cdmMoversWrapped = true
        if type(Movers.FrameRects) == "function" then
            local frameRects = Movers.FrameRects
            Movers.FrameRects = function(...)
                local out = frameRects(...)
                if type(out) ~= "table" then return out end
                local dx, dy = ns.pointDelta("CENTER")
                if dx == 0 and dy == 0 then return out end
                for _, r in ipairs(out) do
                    if type(r) == "table" and type(r.l) == "number" and type(r.r) == "number"
                        and type(r.b) == "number" and type(r.t) == "number"
                        and (r.r > r.l or r.t > r.b) then
                        r.l, r.r = r.l - dx, r.r - dx
                        r.b, r.t = r.b - dy, r.t - dy
                    end
                end
                return out
            end
        end
        if type(Movers.ShowGuides) == "function" then
            local showGuides = Movers.ShowGuides
            Movers.ShowGuides = function(gx, gy, ...)
                if type(Ed.IsOpen) == "function" and Ed.IsOpen() then
                    local dx, dy = ns.pointDelta("CENTER")
                    if type(gx) == "number" then gx = gx + dx end
                    if type(gy) == "number" then gy = gy + dy end
                end
                return showGuides(gx, gy, ...)
            end
        end
    end
end
