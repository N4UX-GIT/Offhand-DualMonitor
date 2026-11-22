-- Offhand DaylightUI bridge: DaylightUI places everything against UIParent,
-- which with Offhand spans every monitor. This makes it use Offhand's game
-- rectangle (the Mainhand monitor) instead, without changing either addon's
-- files:
--
--   * frames DaylightUI places itself (its movers' defaults, its pop-ups) are
--     anchored to a frame of ours that covers the game rectangle;
--   * frames the game places (action bars, cooldown viewers...) are in
--     DaylightUI's Edit Mode layout, whose screen-edge offsets are shifted
--     onto the game rectangle when the layout is written.
--
-- A position the player has dragged a frame to is kept as it is: DaylightUI
-- saves those in plain screen terms, which are right on any monitor.
-- With Offhand off (or WoW not spanned) the rectangle is the whole screen and
-- nothing changes. Offhand is reached only through Offhand.API (the bridge
-- contract, Core/Bridges.lua in Offhand); with an Offhand too old to offer it
-- the bridge does nothing.

local ADDON_NAME, ns = ...
local Offhand = ns.Offhand or _G.Offhand
ns.Offhand = Offhand

local API = type(Offhand) == "table" and Offhand.API
ns.contract = type(API) == "table" and API.BRIDGE_CONTRACT == 1
    and type(API.RegisterBridge) == "function" and type(API.GetGameRect) == "function"
    and type(API.OwnsWorldMapPlacement) == "function" and type(API.GetGroupLootSpot) == "function"
    and type(API.RegisterGeometryCallback) == "function" or false
if not ns.contract then return end

local AREA = "OffhandDaylightUIArea"
local LABEL = "|cffffbd0aOffhand|r DaylightUI bridge:"

ns.AREA = AREA

function ns.Print(msg) DEFAULT_CHAT_FRAME:AddMessage(LABEL .. " " .. tostring(msg)) end

-- The older personal DaylightOffhand addon wraps the same DaylightUI
-- functions; with both running everything would be shifted twice.
local function LegacyLoaded()
    if _G.DaylightOffhandArea ~= nil then return true end
    local checker = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not checker then return false end
    local ok, loaded = pcall(checker, "DaylightOffhand")
    return ok and loaded and true or false
end

local DUI = _G.DaylightUI
ns.DUI = DUI
ns.legacy = LegacyLoaded()
ns.layout = not ns.legacy and type(DUI) == "table" and type(DUI.Movers) == "table"
    and type(DUI.EditMode) == "table" or false

-- The saved variables, made on first use. A rectangle the older addon last
-- rebuilt the layout for is taken over once, while both are loaded.
function ns.DB()
    if type(_G.OffhandDaylightUIDB) ~= "table" then _G.OffhandDaylightUIDB = {} end
    local db = _G.OffhandDaylightUIDB
    local legacy = _G.DaylightOffhandDB
    if db.rect == nil and type(legacy) == "table" and type(legacy.rect) == "string" then
        db.rect = legacy.rect
    end
    return db
end

-- ---------------------------------------------------------------------
-- The game rectangle, in UIParent's units from its bottom-left corner.
-- ---------------------------------------------------------------------

-- left, bottom, right, top, then UIParent's width and height.
function ns.gameRect()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local ok, rect = pcall(API.GetGameRect)
    if ok and type(rect) == "table" and rect.isSpanned
        and type(rect.left) == "number" and type(rect.right) == "number"
        and type(rect.bottom) == "number" and type(rect.top) == "number"
        and rect.right > rect.left and rect.top > rect.bottom then
        return rect.left, rect.bottom, rect.right, rect.top,
            type(rect.screenWidth) == "number" and rect.screenWidth or sw,
            type(rect.screenHeight) == "number" and rect.screenHeight or sh
    end
    return 0, 0, sw, sh, sw, sh
end

function ns.signature()
    return string.format("%.1f:%.1f:%.1f:%.1f:%.1f:%.1f", ns.gameRect())
end

function ns.round(v) return math.floor(v * 10 + 0.5) / 10 end

-- How far a point of the game rectangle is from the same point of the
-- screen ("BOTTOM": its bottom middle from the screen's).
function ns.pointDelta(point)
    local l, b, r, t, sw, sh = ns.gameRect()
    local dx, dy
    if string.find(point, "LEFT", 1, true) then dx = l
    elseif string.find(point, "RIGHT", 1, true) then dx = r - sw
    else dx = (l + r) / 2 - sw / 2 end
    if string.find(point, "BOTTOM", 1, true) then dy = b
    elseif string.find(point, "TOP", 1, true) then dy = t - sh
    else dy = (b + t) / 2 - sh / 2 end
    return ns.round(dx), ns.round(dy)
end

-- ---------------------------------------------------------------------
-- The frame standing in for the screen.
-- ---------------------------------------------------------------------

function ns.Refresh() end
if not ns.layout then return end

local area = CreateFrame("Frame", AREA, UIParent)
area:SetAllPoints(UIParent)
ns.area = area

local placedFor

-- Puts the area over the game rectangle when that has changed. Protected
-- frames hang off it, so only out of combat (ns.pending: placing again once
-- combat ends).
function ns.Refresh()
    local sig = ns.signature()
    if sig == placedFor then return end
    if InCombatLockdown() then
        ns.pending = true
        return
    end
    placedFor = sig
    local l, b, r, t = ns.gameRect()
    area:ClearAllPoints()
    area:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
    area:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", r, t)
    -- DaylightUI lays everything out again (its movers, the quest tracker's
    -- spot under the panel).
    if DUI.loggedIn then DUI.NotifyStyleChanged() end
end
