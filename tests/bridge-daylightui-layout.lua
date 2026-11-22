-- The DaylightUI bridge (Bridges/DaylightUI) against a small mock client: its
-- TOC, contract purity, registration through Core/Bridges.lua, the game-area
-- frame, DaylightUI's mover defaults, Edit Mode offsets, frame redirects
-- (load-time sweep and CreateFrame hook), loot rolls, layout staleness, the
-- legacy DaylightOffhand stand-down and an Offhand without the contract.
local DIR = "Bridges/DaylightUI/"

local function ReadFile(path)
    local handle = assert(io.open(path, "rb"))
    local text = handle:read("*a")
    handle:close()
    return text
end

local function TocField(text, field)
    return text:match("\n## " .. field .. ":%s*([^\r\n]*)") or text:match("^## " .. field .. ":%s*([^\r\n]*)")
end

-- TOC and contract purity.
local toc = ReadFile(DIR .. "Offhand_DaylightUI.toc")
assert(TocField(toc, "Dependencies") == "Offhand, DaylightUI")
assert(TocField(toc, "X%-Offhand%-Bridge%-Contract") == "1")
assert(TocField(toc, "Group") == "Offhand")
assert(TocField(toc, "SavedVariables") == "OffhandDaylightUIDB")
assert(TocField(toc, "Version") == TocField(ReadFile("Offhand.toc"), "Version"), "bridge version must follow Offhand's")
local files = {}
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^##") then files[#files + 1] = line end
end
assert(#files == 6 and files[1] == "Core.lua" and files[6] == "Init.lua")
for _, name in ipairs(files) do
    assert(loadfile(DIR .. name), name .. " must parse")
    local source = ReadFile(DIR .. name)
    for _, forbidden in ipairs({ 'CreateFrame("Frame", "DaylightOffhandArea"', "SLASH_DAYLIGHTOFFHAND",
        "DAYLIGHTOFFHAND_APPLY", "Offhand.db", "Offhand.Viewport", "Offhand.Canvas", "Offhand.isForever" }) do
        assert(not source:find(forbidden, 1, true), name .. " must not contain " .. forbidden)
    end
end

-- ---------------------------------------------------------------------
-- Mock client
-- ---------------------------------------------------------------------

local W, H = 5120, 1440
local env

local function Frame(name, parent)
    local f = { name = name, parent = parent, points = {}, scripts = {}, hooked = {} }
    function f:GetName() return self.name end
    function f:IsForbidden() return false end
    function f:IsProtected() return self.protected end
    function f:GetParent() return self.parent end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i)
        local p = self.points[i or 1]
        if p then return p[1], p[2], p[3], p[4], p[5] end
    end
    function f:SetPoint(point, rel, relPoint, x, y)
        if type(rel) == "string" then rel = _G[rel] end
        for i, p in ipairs(self.points) do
            if p[1] == point then table.remove(self.points, i); break end
        end
        self.points[#self.points + 1] = { point, rel or UIParent, relPoint or point, x or 0, y or 0 }
    end
    function f:ClearAllPoints() self.points, self.all = {}, nil end
    function f:SetAllPoints(target)
        self.points = { { "TOPLEFT", target, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0 } }
        self.all = target
    end
    function f:SetWidth(v) self.width = v end
    function f:GetWidth() return self.width or 0 end
    function f:GetHeight() return self.height or 0 end
    function f:HookScript(script, fn) self.hooked[script] = fn end
    function f:SetScript(script, fn) self.scripts[script] = fn end
    function f:RegisterEvent() end
    return f
end

local function Setup(options)
    options = options or {}
    env = { frames = {}, timers = {}, chat = {}, registered = {}, spanned = true, geometry = {}, loaded = {} }
    UIParent = Frame("UIParent")
    UIParent.width, UIParent.height = W, H
    _G.UIParent = UIParent
    _G.OffhandDaylightUIDB, _G.DaylightOffhandDB, _G.DaylightOffhandArea = nil, nil, nil
    _G.OffhandDaylightUIArea = nil
    _G.SlashCmdList, _G.StaticPopupDialogs = {}, {}
    _G.SLASH_OFFHANDDAYLIGHTUI1 = nil
    StaticPopup_Show = function(key) env.popup = key end
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) env.chat[#env.chat + 1] = text end }
    InCombatLockdown = function() return env.combat end
    C_Timer = { After = function(_, fn) env.timers[#env.timers + 1] = fn end }
    C_AddOns = { IsAddOnLoaded = function(name) return env.loaded[name] == true end }
    Enum = { EditModeSystem = { ActionBar = 0 }, EditModeActionBarSystemIndices = { MainBar = 1 } }
    CreateFrame = function(_, name, parent)
        local f = Frame(name, parent)
        env.frames[#env.frames + 1] = f
        if name then _G[name] = f end
        return f
    end
    hooksecurefunc = function(target, method, hook)
        if type(target) == "string" then
            local original = _G[target]
            _G[target] = function(...)
                local a, b, c, d, e = original(...)
                method(...)
                return a, b, c, d, e
            end
            return
        end
        local original = target[method]
        target[method] = function(...)
            local a, b, c, d, e = original(...)
            hook(...)
            return a, b, c, d, e
        end
    end
    EnumerateFrames = function(previous)
        if not previous then return env.frames[1] end
        for i, f in ipairs(env.frames) do
            if f == previous then return env.frames[i + 1] end
        end
    end

    -- DaylightUI
    env.mapMover = { Start = function() end, Scale = function() return 1 end, Apply = function() end }
    local skins = { enabled = true, db = {}, ns = { MapMove = env.mapMover } }
    DaylightUI = {
        loggedIn = true,
        NotifyStyleChanged = function() env.styled = (env.styled or 0) + 1 end,
        On = function(event, fn) env.on = env.on or {}; env.on[event] = fn end,
        Fade = {},
        GetModule = function(_, name) if name == "Skins" then return skins end end,
        Movers = {
            DEFAULTS = { box = { 100, 50 }, named = "x" },
            Register = function(frame, key, label, default, opts)
                env.registered[key] = { frame = frame, default = default, opts = opts }
            end,
            LockButton = function() end,
        },
        EditMode = {
            Anchor = function(entry, point, relPoint, x, y, relativeTo) return point, relPoint, x, y, relativeTo end,
            Base = function() return env.base, true end,
            IsActive = function() return true end,
            Ours = function() return env.ours end,
            FindSystem = function(layout, system, index)
                if system == 0 and index == 1 then return layout.main end
            end,
            Write = function() return true end,
            Name = function() return "Daylight" end,
        },
        GameMovers = {
            RollSlot = function() return 5, 6, 200, 100 end,
            Spot = function() return env.rollSpotSaved end,
            Key = function() return "rolls" end,
        },
    }
    env.register = DaylightUI.Movers.Register

    -- Offhand: the real contract over a switchable game rectangle.
    local addon = { db = { enabled = true } }
    addon.MainhandGeometry = { GetCurrentRect = function()
        if env.spanned then
            return { left = 0, bottom = 0, right = 2560, top = 1440, width = 2560, height = 1440,
                screenWidth = W, screenHeight = H, isSpanned = true }
        end
        return { left = 0, bottom = 0, right = W, top = H, width = W, height = H,
            screenWidth = W, screenHeight = H, isSpanned = false }
    end }
    assert(loadfile("Core/Bridges.lua"))("Offhand", addon)
    addon.API.RegisterGeometryCallback = function(owner, callback) env.geometry[owner] = callback end
    env.addon = addon
    _G.Offhand = options.offhand or addon

    for _, f in ipairs(options.before or {}) do f() end
    env.ns = {}
    for _, name in ipairs(files) do
        assert(loadfile(DIR .. name))("Offhand_DaylightUI", env.ns)
    end
    return env.ns
end

local function PointOf(frame, index)
    local p = frame.points[index or 1]
    return p and p[1], p and p[2], p and p[3], p and p[4], p and p[5]
end

local function Fire(event, ...)
    for _, f in ipairs(env.frames) do
        if f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

-- ---------------------------------------------------------------------
-- Spanned: everything goes onto the left monitor.
-- ---------------------------------------------------------------------

local ns = Setup({ before = { function()
    local early = CreateFrame("Frame", "DaylightUIEarly", UIParent)
    early:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -10)
    env.early = early
end } })
local addon, area = env.addon, _G.OffhandDaylightUIArea
assert(ns.contract == true and ns.layout == true and ns.area == area and area)
assert(addon.Bridges:Get("DaylightUI"), "the bridge must register")
assert(env.geometry[ns], "the bridge must follow geometry changes")
addon.Bridges:Refresh("tick")
assert(next(addon.Bridges.errors) == nil, "refresh must not fail: " .. tostring(next(addon.Bridges.errors)))
local p, rel, rp, x, y = PointOf(area, 1)
assert(p == "BOTTOMLEFT" and rel == UIParent and rp == "BOTTOMLEFT" and x == 0 and y == 0)
p, rel, rp, x, y = PointOf(area, 2)
assert(p == "TOPRIGHT" and rel == UIParent and rp == "BOTTOMLEFT" and x == 2560 and y == 1440)

-- The load-time sweep moved a frame placed before the bridge loaded.
p, rel, rp, x, y = PointOf(env.early)
assert(p == "TOPRIGHT" and rel == area and rp == "TOPRIGHT" and x == -10 and y == -10, "sweep must redirect early frames")
ns.Sweep(); ns.Sweep()
assert(#env.early.points == 1 and env.early.points[1][2] == area, "the sweep must be idempotent")

-- Mover defaults.
local Movers = DaylightUI.Movers
assert(Movers.DEFAULTS.box[1] == 100 - 1280 and Movers.DEFAULTS.box[2] == 50)
assert(Movers.DEFAULTS.named == "x")
Movers.Register(CreateFrame("Frame"), "screen", "Screen", { "BOTTOM", nil, "BOTTOM", 0, 10 })
local d = env.registered.screen.default
assert(d[1] == "BOTTOM" and d[2] == "OffhandDaylightUIArea" and d[3] == "BOTTOM" and d[5] == 10)
Movers.Register(CreateFrame("Frame"), "named", "Named", { "TOP", "UIParent", "TOP", 0, 0 })
assert(env.registered.named.default[2] == "OffhandDaylightUIArea")
local other = { "TOP", "SomeFrame", "BOTTOM", 0, 0 }
Movers.Register(CreateFrame("Frame"), "other", "Other", other)
assert(env.registered.other.default == other, "a default against another frame is left alone")
Movers.Register(CreateFrame("Frame"), "given", "Given", function() return { "LEFT", nil, "LEFT", 4, 0 } end)
assert(env.registered.given.default()[2] == "OffhandDaylightUIArea", "a function default must be wrapped")
Movers.Register({}, "actionbars.bar1", "Bar 1", nil, { proxy = true, home = function() return 10, 20 end })
local hx, hy = env.registered["actionbars.bar1"].opts.home()
assert(hx == 10 - 1280 and hy == 20, "an action bar's home must move to the game area")

-- Edit Mode offsets.
local EditMode = DaylightUI.EditMode
local _, _, ax, ay = EditMode.Anchor({}, "BOTTOM", "BOTTOM", 0, 10)
assert(ax == -1280 and ay == 10)
_, _, ax = EditMode.Anchor({}, "TOPRIGHT", "TOPRIGHT", -5, 0)
assert(ax == -5 - 2560)
_, _, ax = EditMode.Anchor({}, "CENTER", "CENTER", 30, 0)
assert(ax == 30, "a centre offset is plain screen terms")
_, _, ax = EditMode.Anchor({}, "BOTTOM", "BOTTOM", 30, 0, "UIParent")
assert(ax == 30, "an explicit relativeTo is plain screen terms")
env.base = { systems = {
    { isInDefaultPosition = false, anchorInfo = { relativeTo = "UIParent", relativePoint = "RIGHT", offsetX = 5, offsetY = 1 } },
    { isInDefaultPosition = true, anchorInfo = { relativeTo = "UIParent", relativePoint = "RIGHT", offsetX = 5, offsetY = 1 } },
} }
local layout = EditMode.Base()
assert(layout.systems[1].anchorInfo.offsetX == 5 - 2560 and layout.systems[2].anchorInfo.offsetX == 5)

-- Frames made after load: the CreateFrame hook.
local late = CreateFrame("Frame", "DaylightUILate", UIParent)
late:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -1, -1)
assert(late.points[1][2] == area)
local edge = CreateFrame("Frame", "DaylightUIEdge", UIParent)
edge:SetPoint("CENTER", UIParent, "TOP", 0, -100)
assert(edge.points[1][2] == UIParent, "plain screen offsets are left alone")
local banner = CreateFrame("Frame", "DaylightUIZoneTitle", UIParent)
banner:SetPoint("CENTER", UIParent, "TOP", 0, -100)
assert(banner.points[1][2] == area, "banners always hang from the area")
local placedFrame = CreateFrame("Frame", "DaylightUIPlaced", UIParent)
Movers.Register(placedFrame, "placed", "Placed", { "CENTER", nil, "CENTER", 0, 0 })
placedFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
assert(placedFrame.points[1][2] == UIParent, "a mover's own frame is left alone")
local afk = CreateFrame("Frame", "DaylightUIAfkScreen", UIParent)
afk:SetAllPoints(UIParent)
assert(afk.all == area, "the AFK screen must cover the area")

-- Protected frames placed before load wait for the end of combat.
env.combat = true
local guarded = CreateFrame("Frame", "DaylightUIGuarded", UIParent)
guarded.protected = true
guarded.points = { { "TOP", UIParent, "TOP", 0, 0 } }
ns.Sweep()
assert(guarded.points[1][2] == UIParent and ns.sweepPending)
env.combat = false
Fire("PLAYER_REGEN_ENABLED")
assert(guarded.points[1][2] == area and not ns.sweepPending)

-- Loot rolls.
local GameMovers = DaylightUI.GameMovers
local rx, ry, rw, rh = GameMovers.RollSlot()
assert(rx == 1280 - W / 2 and ry == 190 + 50 - H / 2 and rw == 200 and rh == 100, "rolls hang at Offhand's spot")
env.rollSpotSaved = true
rx, ry = GameMovers.RollSlot()
assert(rx == 5 and ry == 6, "a spot of DaylightUI's handle is kept")
env.rollSpotSaved = nil

-- Layout staleness.
local main = { anchorInfo = { point = "BOTTOM", relativePoint = "BOTTOM", offsetX = -1280, offsetY = 0 } }
env.ours = { main = main }
local db = ns.DB()
db.rect = ns.signature()
assert(ns.layoutStale() == false)
db.rect = "elsewhere"
assert(ns.layoutStale() == true)
db.rect = nil
assert(ns.layoutStale() == false and db.rect == ns.signature(), "a layout already moved over is kept and remembered")
db.rect, main.anchorInfo.offsetX = nil, 0
assert(ns.layoutStale() == true and db.rect == nil)
main.anchorInfo = nil
assert(ns.layoutStale() == true, "an unreadable main bar keeps the old answer")

-- Slash status and Apply prompt.
SlashCmdList.OFFHANDDAYLIGHTUI("")
assert(env.chat[#env.chat]:find("/ohdaylight apply", 1, true))
SlashCmdList.OFFHANDDAYLIGHTUI("apply")
assert(env.popup == "OFFHAND_DAYLIGHTUI_APPLY" and StaticPopupDialogs.OFFHAND_DAYLIGHTUI_APPLY)

-- Unspanned: the area is the whole screen and DaylightUI's own roll spot.
env.spanned = false
assert(env.geometry[ns]() == true)
p, rel, rp, x, y = PointOf(area, 2)
assert(x == W and y == H, "unspanned must cover the whole screen")
rx, ry = GameMovers.RollSlot()
assert(rx == 5 and ry == 6)
assert(Movers.DEFAULTS.box[1] == 100)

-- ---------------------------------------------------------------------
-- The older DaylightOffhand addon still enabled: stand aside.
-- ---------------------------------------------------------------------

ns = Setup({ before = { function() _G.DaylightOffhandArea = Frame("DaylightOffhandArea") end } })
assert(ns.layout == false and ns.legacy == true)
assert(DaylightUI.Movers.Register == env.register, "the legacy addon's wraps must not be doubled")
assert(_G.OffhandDaylightUIArea == nil)
assert(env.addon.Bridges:Get("DaylightUI"))
env.addon.Bridges:Refresh("tick")
assert(next(env.addon.Bridges.errors) == nil)
assert(ns.Map:GetDiagnostics() == "DaylightMap=DaylightUI")
Fire("PLAYER_LOGIN")
assert(env.chat[#env.chat]:find("older DaylightOffhand addon", 1, true))
SlashCmdList.OFFHANDDAYLIGHTUI("")
assert(env.chat[#env.chat]:find("world map: DaylightMap=DaylightUI", 1, true))

-- The legacy rectangle is taken over once.
_G.OffhandDaylightUIDB, _G.DaylightOffhandDB = nil, { rect = "legacy" }
assert(ns.DB().rect == "legacy")

-- ---------------------------------------------------------------------
-- An Offhand without the bridge contract: inert.
-- ---------------------------------------------------------------------

ns = Setup({ offhand = {} })
assert(ns.contract == false and ns.Map == nil and ns.Bags == nil)
assert(DaylightUI.Movers.Register == env.register and _G.OffhandDaylightUIArea == nil)
assert(SlashCmdList.OFFHANDDAYLIGHTUI == nil and #env.addon.Bridges:List() == 0)

print("PASS: DaylightUI bridge TOC, contract purity, game area, movers, Edit Mode, redirects, rolls, staleness, legacy stand-down and inert load")
