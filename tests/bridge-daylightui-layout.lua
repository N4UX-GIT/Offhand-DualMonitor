-- Built-in Bridges/DaylightUI layout, Edit Mode (2.2.1 & 2.2.3), scenes,
-- catalog/edit-mode bridge integration, legacy stand-down, and inert load.

local DIR = "Bridges/DaylightUI/"
local FILES = { "Core.lua", "Placement.lua", "Scenes.lua", "Map.lua", "Bags.lua", "Init.lua" }

local function ReadFile(path)
    local h = assert(io.open(path, "rb"), "missing " .. path)
    local text = h:read("*a")
    h:close()
    return text
end

for _, name in ipairs(FILES) do
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
    env = { frames = {}, timers = {}, chat = {}, registered = {}, spanned = true, geometry = {},
        loaded = { DaylightUI = true }, reloads = 0, flushes = 0 }
    UIParent = Frame("UIParent")
    UIParent.width, UIParent.height = W, H
    _G.UIParent = UIParent
    _G.OffhandDB = { profiles = {} }
    _G.OffhandDaylightUIDB, _G.DaylightOffhandDB, _G.DaylightOffhandArea = nil, nil, nil
    _G.OffhandDaylightUIArea = nil
    _G.SlashCmdList, _G.StaticPopupDialogs = {}, {}
    _G.SLASH_OFFHANDDAYLIGHTUI1 = nil
    StaticPopup_Show = function(key) env.popup = key end
    ReloadUI = function() env.reloads = env.reloads + 1 end
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) env.chat[#env.chat + 1] = text end }
    InCombatLockdown = function() return env.combat end
    C_Timer = { After = function(_, fn) env.timers[#env.timers + 1] = fn end }
    C_AddOns = { IsAddOnLoaded = function(name) return env.loaded[name] == true end }
    C_EditMode = { ConvertLayoutInfoToString = function() return "SHARE_LAYOUT_STRING" end }
    Enum = { EditModeSystem = { ActionBar = 0 }, EditModeActionBarSystemIndices = { MainBar = 1 },
        EditModeLayoutType = { Account = 1 } }
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

    if options.noDaylightUI then
        DaylightUI = nil
    else
        env.mapMover = { Start = function() end, Scale = function() return 1 end, Apply = function() end }
        local skins = { enabled = true, db = {}, ns = { MapMove = env.mapMover } }
        DaylightUI = {
            loggedIn = true,
            NotifyStyleChanged = function() env.styled = (env.styled or 0) + 1 end,
            On = function(event, fn) env.on = env.on or {}; env.on[event] = fn end,
            Fade = {},
            GetModule = function(_, name) if name == "Skins" then return skins end end,
            Movers = {
                unlocked = false,
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
                Replace = function(text) env.replacedWith = text; return true end,
                Write = function() env.wrote = (env.wrote or 0) + 1; return true end,
                Name = function() return "Daylight" end,
            },
            GameMovers = {
                RollSlot = function() return 5, 6, 200, 100 end,
                Spot = function() return env.rollSpotSaved end,
                Key = function() return "rolls" end,
            },
        }
        if options.legacyImportLayout then
            DaylightUI.EditMode.Replace = nil
            DaylightUI.EditMode.ImportLayout = function(text) env.importedWith = text; return true end
        end
        env.register = DaylightUI.Movers.Register
    end

    local addon = { db = { enabled = true }, AddonWindowCatalog = {} }
    addon.ForeverPersistence = { SaveProfileSnapshot = function(_, inc) if inc then env.flushes = env.flushes + 1 end end }
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
    local targetOffhand = options.offhand or addon
    _G.Offhand = targetOffhand

    for _, f in ipairs(options.before or {}) do f() end
    -- Load the exact way Offhand*.toc loads built-in bridges ("Offhand", Offhand)
    for _, name in ipairs(FILES) do
        assert(loadfile(DIR .. name))("Offhand", targetOffhand)
    end
    env.ns = targetOffhand.API and targetOffhand.API.GetBridgeNamespace
        and targetOffhand.API.GetBridgeNamespace("DaylightUI") or {}
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
-- Without DaylightUI installed: completely inert, zero hooks or frames.
-- ---------------------------------------------------------------------

local inert = Setup({ noDaylightUI = true })
assert(inert.active == false and _G.OffhandDaylightUIArea == nil)
assert(#env.frames == 0 and SlashCmdList.OFFHANDDAYLIGHTUI == nil and #env.addon.Bridges:List() == 0,
    "built-in bridge must stay completely inert when DaylightUI is absent")

-- ---------------------------------------------------------------------
-- Spanned: everything goes onto the left monitor.
-- ---------------------------------------------------------------------

local ns = Setup({ before = { function()
    local early = CreateFrame("Frame", "DaylightUIEarly", UIParent)
    early:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -10)
    env.early = early
end } })
local addon, area = env.addon, _G.OffhandDaylightUIArea
assert(ns.active == true and ns.contract == true and ns.layout == true and ns.area == area and area)
assert(addon.Bridges:Get("DaylightUI"), "the bridge must register")
assert(addon.AddonWindowCatalog.DaylightUI and addon.AddonWindowCatalog.DaylightUI.suitePrefix == "daylightui_",
    "the bridge must register its suite catalog into AddonWindowCatalog")
assert(env.geometry[ns], "the bridge must follow geometry changes")
addon.Bridges:Refresh("tick")
assert(next(addon.Bridges.errors) == nil, "refresh must not fail: " .. tostring(next(addon.Bridges.errors)))
local p, rel, rp, x, y = PointOf(area, 1)
assert(p == "BOTTOMLEFT" and rel == UIParent and rp == "BOTTOMLEFT" and x == 0 and y == 0)
p, rel, rp, x, y = PointOf(area, 2)
assert(p == "TOPRIGHT" and rel == UIParent and rp == "BOTTOMLEFT" and x == 2560 and y == 1440)

-- Bridge reports DaylightUI unlock mode and DaylightUIOptions learn opt-in
assert(addon.Bridges:IsEditModeActive() == false)
DaylightUI.Movers.unlocked = true
assert(addon.Bridges:IsEditModeActive() == true)
DaylightUI.Movers.unlocked = false
local dlOpts = Frame("DaylightUIOptions", UIParent)
assert(addon.Bridges:CanLearnPlacement(dlOpts, "DaylightUIOptions", "DaylightUI", "options/panel.lua") == true)
assert(addon.Bridges:CanLearnPlacement(dlOpts, "DaylightUIInfoPanel", "DaylightUI", "panel.lua") == false)

-- Load-time sweep moved a frame placed before the bridge loaded.
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
assert(hx == 10 - 1280 and hy == 20, "an action bar's default spot shifts from BOTTOM")

-- EditMode Anchor & Base shifting
local EditMode = DaylightUI.EditMode
local _, _, ax, ay = EditMode.Anchor({}, "BOTTOM", "BOTTOM", 0, 12, nil)
assert(ax == -1280 and ay == 12)
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

-- Layout staleness & OffhandDB.bridges.DaylightUI persistence
local main = { anchorInfo = { point = "BOTTOM", relativePoint = "BOTTOM", offsetX = -1280, offsetY = 0 } }
env.ours = { main = main }
local db = ns.DB()
assert(db == _G.OffhandDB.bridges.DaylightUI, "built-in bridge must persist under OffhandDB.bridges.DaylightUI")
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

-- Slash status, Apply prompt, and DaylightUI 2.2.3 EditMode.Replace + FlushDB + ReloadUI
SlashCmdList.OFFHANDDAYLIGHTUI("")
assert(env.chat[#env.chat]:find("/ohdaylight apply", 1, true))
SlashCmdList.OFFHANDDAYLIGHTUI("apply")
assert(env.popup == "OFFHAND_DAYLIGHTUI_APPLY" and StaticPopupDialogs.OFFHAND_DAYLIGHTUI_APPLY)
StaticPopupDialogs.OFFHAND_DAYLIGHTUI_APPLY.OnAccept()
assert(env.replacedWith == "SHARE_LAYOUT_STRING" and env.wrote == 1 and env.flushes == 1 and env.reloads == 1,
    "Apply must use DaylightUI 2.2.3 EditMode.Replace, flush storage, and reload")
assert(_G.OffhandDB.bridges.DaylightUI.rect == ns.signature())

-- Unspanned: the area is the whole screen and DaylightUI's own roll spot.
env.spanned = false
assert(env.geometry[ns]() == true)
p, rel, rp, x, y = PointOf(area, 2)
assert(x == W and y == H, "unspanned must cover the whole screen")
rx, ry = GameMovers.RollSlot()
assert(rx == 5 and ry == 6)
assert(Movers.DEFAULTS.box[1] == 100)

-- DaylightUI 2.2.1 EditMode.ImportLayout fallback
ns = Setup({ legacyImportLayout = true })
env.base = { systems = {} }
SlashCmdList.OFFHANDDAYLIGHTUI("apply")
StaticPopupDialogs.OFFHAND_DAYLIGHTUI_APPLY.OnAccept()
assert(env.importedWith == "SHARE_LAYOUT_STRING" and env.wrote == 1 and env.reloads == 1,
    "Apply must still fall back to DaylightUI 2.2.1 EditMode.ImportLayout")

-- The older DaylightOffhand addon still enabled: stand aside.
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

-- The legacy rectangle is taken over once into OffhandDB.bridges.DaylightUI.
_G.OffhandDB.bridges = nil
_G.DaylightOffhandDB = { rect = "legacy" }
assert(ns.DB().rect == "legacy")

-- An Offhand without the bridge contract: inert.
ns = Setup({ offhand = {} })
assert(DaylightUI.Movers.Register == env.register and _G.OffhandDaylightUIArea == nil)
assert(SlashCmdList.OFFHANDDAYLIGHTUI == nil and #env.addon.Bridges:List() == 0)

print("PASS: built-in DaylightUI bridge inert load, contract purity, 2.2.3 Replace + 2.2.1 fallback, game area, movers, redirects, rolls, staleness, and legacy stand-down")
