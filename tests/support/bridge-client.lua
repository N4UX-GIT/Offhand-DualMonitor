--[[
    Mock WoW client for bridge tests. Usage, from the repository root:

        local Client = dofile("tests/support/bridge-client.lua")
        Client.Reset({ loaded = { Questie = true } })
        local addon = Client.LoadOffhand()
        Client.Load("Bridges/Questie/Questie.lua")

    Client.Reset(options)   (re)creates the mock world as globals. options, all optional:
        width (5120), height (1440): UIParent's size
        rect = { left, bottom, right, top } of the game rectangle ({ 0, 0, 2560, 1440 }: the left half)
        spanned (true), toc (16001), loaded = set of loaded addon names ({}), combat (false)
      Globals: UIParent, CreateFrame, hooksecurefunc, InCombatLockdown, C_Timer (After queues,
      NewTicker records and returns { Cancel, IsCancelled }), C_AddOns.IsAddOnLoaded, GetBuildInfo
      ("1.60.1", "12345", "Nov 1 2026", toc), EnumerateFrames, SlashCmdList = {}, LibStub = nil,
      DEFAULT_CHAT_FRAME (messages in Client.chat), GetCursorPosition (0, 0), GameTooltip
      (SetOwner(owner, anchor, x, y) and SetAnchorType(anchor, x, y) record .owner and .anchor;
      GetOwner). Named frame globals from the previous Reset are cleared.
      Mutable afterwards: Client.combat, Client.spanned, Client.rect, Client.loaded, Client.toc,
      Client.uiScale (UIParent's effective scale, 1).
    Client.Frame(name, parent, options) and CreateFrame(kind, name, parent, template) return a
      registered mock frame (also _G[name] when named). options: protected, scale (1),
      ignoreParentScale, kind ("Frame"), shown (true). Tests may set frame.left/bottom/right/top
      for GetLeft/GetBottom/GetRight/GetTop/GetCenter (0 otherwise). SetPoint takes every real
      form; a nil relative frame means the parent (UIParent when none) and a nil relative point
      means the point itself. Show() on a hidden frame runs OnShow then its hooks; Hide() likewise.
    Client.LoadOffhand()    loads the real Core/Bridges.lua and Bridges/Shared/DefaultAnchors.lua
      into a fresh addon table with a mock MainhandGeometry and RegisterGeometryCallback /
      UnregisterGeometryCallback; sets _G.Offhand and Client.addon; returns the addon.
    Client.Load(path)       runs a bridge file as Offhand would: loadfile(path)("Offhand", Client.addon).
    Client.Tick(reason)     Client.addon.Bridges:Refresh(reason or "tick").
    Client.Geometry()       calls every geometry callback as callback(rectCopy, "test", 1) in pcall;
      drops those that error or return false.
    Client.RunTimers()      runs queued C_Timer.After callbacks (and the ones they queue, 20 rounds).
    Client.RunTickers()     calls every live ticker's function once.
    Client.Fire(event, ...) calls OnEvent (then its hooks) of every frame registered for event.
    Client.Point(frame)     "TOP>BOTTOMLEFT 1280.0,1305.0", "none", anchors joined with " | ";
      a relative frame other than UIParent shows as "@Name" (or "@unnamed") after the relative point.
    Client.Counts()         frames (created since Reset, not UIParent/GameTooltip), queued timers,
      live tickers, keys in SlashCmdList.
    Client.Diagnostics()    Client.addon.Bridges:GetDiagnostics().
    Client.Errors()         Client.addon.Bridges.errors (id -> message).
    Client.ForbiddenStrings(path) asserts the file parses and holds none of the strings a bridge
      file must not contain (Offhand internals, em/en dashes, tabs).
--]]

local Client = {}

local all, created, named, timers, tickers, callbacks = {}, {}, {}, {}, {}, {}

local function pack(...)
    return { n = select("#", ...), ... }
end

-- ---------------------------------------------------------------------
-- Mock frames
-- ---------------------------------------------------------------------

local Methods = {}
local FrameMeta = { __index = Methods }

local function RunScript(frame, script, ...)
    local fn = frame.scripts[script]
    if fn then fn(frame, ...) end
    for _, hook in ipairs(frame.hooks[script] or {}) do hook(frame, ...) end
end

function Methods:GetName() return self.name end
function Methods:GetObjectType() return self.kind end
function Methods:IsForbidden() return false end
function Methods:IsProtected() return self.protected == true end
function Methods:GetParent() return self.parent end
function Methods:SetParent(parent)
    if type(parent) == "string" then parent = _G[parent] end
    local old = self.parent
    if old then
        for i, child in ipairs(old.children) do
            if child == self then table.remove(old.children, i); break end
        end
    end
    self.parent = parent
    if parent then parent.children[#parent.children + 1] = self end
end
function Methods:GetChildren() return unpack(self.children) end
function Methods:GetNumChildren() return #self.children end
function Methods:GetNumPoints() return #self.points end
function Methods:GetPoint(i)
    local p = self.points[i or 1]
    if p then return p[1], p[2], p[3], p[4], p[5] end
end
function Methods:SetPoint(point, a, b, c, d)
    local rel, relPoint, x, y
    if type(a) == "number" then
        x, y = a, b
    else
        rel = a
        if type(b) == "number" then x, y = b, c else relPoint, x, y = b, c, d end
    end
    if type(rel) == "string" then rel = _G[rel] end
    if rel == nil then rel = self.parent or UIParent end
    for i, p in ipairs(self.points) do
        if p[1] == point then table.remove(self.points, i); break end
    end
    self.points[#self.points + 1] = { point, rel, relPoint or point, x or 0, y or 0 }
end
function Methods:ClearAllPoints() self.points = {} end
function Methods:SetAllPoints(target)
    target = target or self.parent or UIParent
    self.points = { { "TOPLEFT", target, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0 } }
end
function Methods:SetSize(w, h) self.width, self.height = w, h end
function Methods:SetWidth(w) self.width = w end
function Methods:SetHeight(h) self.height = h end
function Methods:GetWidth() return self.width end
function Methods:GetHeight() return self.height end
function Methods:GetSize() return self.width, self.height end
function Methods:SetScale(scale) self.scale = scale end
function Methods:GetScale() return self.scale end
function Methods:GetEffectiveScale()
    if self == UIParent then return Client.uiScale end
    local parent = self.parent
    if self.ignoreParentScale or not parent then return self.scale end
    return self.scale * parent:GetEffectiveScale()
end
function Methods:SetIgnoreParentScale(ignore) self.ignoreParentScale = ignore and true or false end
function Methods:SetFrameStrata(strata) self.strata = strata end
function Methods:GetFrameStrata() return self.strata end
function Methods:SetAlpha(alpha) self.alpha = alpha end
function Methods:GetAlpha() return self.alpha end
function Methods:Show()
    if self.shown then return end
    self.shown = true
    RunScript(self, "OnShow")
end
function Methods:Hide()
    if not self.shown then return end
    self.shown = false
    RunScript(self, "OnHide")
end
function Methods:IsShown() return self.shown end
function Methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Methods:SetScript(script, fn) self.scripts[script] = fn end
function Methods:GetScript(script) return self.scripts[script] end
function Methods:HookScript(script, fn)
    self.hooks[script] = self.hooks[script] or {}
    table.insert(self.hooks[script], fn)
end
function Methods:RegisterEvent(event) self.events[event] = true end
function Methods:UnregisterEvent(event) self.events[event] = nil end
function Methods:SetMovable(movable) self.movable = movable end
function Methods:EnableMouse(enable) self.mouse = enable end
function Methods:CreateFontString()
    local text = {}
    function text:SetText(value) self.text = value end
    function text:GetText() return self.text end
    return text
end
function Methods:GetLeft() return self.left or 0 end
function Methods:GetBottom() return self.bottom or 0 end
function Methods:GetRight() return self.right or 0 end
function Methods:GetTop() return self.top or 0 end
function Methods:GetCenter()
    return ((self.left or 0) + (self.right or 0)) / 2, ((self.bottom or 0) + (self.top or 0)) / 2
end

local function NewFrame(name, parent, options, counted)
    options = options or {}
    if type(parent) == "string" then parent = _G[parent] end
    local frame = setmetatable({
        name = name, kind = options.kind or "Frame", children = {}, points = {},
        width = 0, height = 0, scale = options.scale or 1,
        ignoreParentScale = options.ignoreParentScale and true or false,
        protected = options.protected and true or false, shown = options.shown ~= false,
        strata = "MEDIUM", alpha = 1, scripts = {}, hooks = {}, events = {},
    }, FrameMeta)
    if parent then frame:SetParent(parent) end
    all[#all + 1] = frame
    if counted then created[#created + 1] = frame end
    if name then
        _G[name] = frame
        named[#named + 1] = name
    end
    return frame
end

function Client.Frame(name, parent, options)
    return NewFrame(name, parent, options, true)
end

-- ---------------------------------------------------------------------
-- The world
-- ---------------------------------------------------------------------

function Client.Reset(options)
    options = options or {}
    for _, name in ipairs(named) do _G[name] = nil end
    all, created, named, timers, tickers, callbacks = {}, {}, {}, {}, {}, {}
    Client.addon = nil
    Client.combat = options.combat and true or false
    Client.spanned = options.spanned ~= false
    local rect = options.rect or { 0, 0, 2560, 1440 }
    Client.rect = { rect[1], rect[2], rect[3], rect[4] }
    Client.toc = options.toc or 16001
    Client.loaded = options.loaded or {}
    Client.uiScale = 1
    Client.chat = {}

    UIParent = NewFrame("UIParent")
    UIParent:SetSize(options.width or 5120, options.height or 1440)

    CreateFrame = function(kind, name, parent)
        return NewFrame(name, parent, { kind = kind }, true)
    end
    hooksecurefunc = function(target, method, hook)
        if type(target) == "string" then
            local original = _G[target]
            _G[target] = function(...)
                local results = pack(original(...))
                method(...)
                return unpack(results, 1, results.n)
            end
            return
        end
        local original = target[method]
        target[method] = function(...)
            local results = pack(original(...))
            hook(...)
            return unpack(results, 1, results.n)
        end
    end
    InCombatLockdown = function() return Client.combat == true end
    C_Timer = {
        After = function(_, fn) timers[#timers + 1] = fn end,
        NewTicker = function(interval, fn)
            local ticker = { interval = interval, fn = fn, cancelled = false }
            function ticker:Cancel() self.cancelled = true end
            function ticker:IsCancelled() return self.cancelled end
            tickers[#tickers + 1] = ticker
            return ticker
        end,
    }
    C_AddOns = { IsAddOnLoaded = function(name) return Client.loaded[name] == true end }
    GetBuildInfo = function() return "1.60.1", "12345", "Nov 1 2026", Client.toc end
    EnumerateFrames = function(previous)
        if not previous then return all[1] end
        for i, frame in ipairs(all) do
            if frame == previous then return all[i + 1] end
        end
    end
    SlashCmdList = {}
    LibStub = nil
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) Client.chat[#Client.chat + 1] = text end }
    GetCursorPosition = function() return 0, 0 end

    GameTooltip = NewFrame("GameTooltip", UIParent, { kind = "GameTooltip", shown = false })
    function GameTooltip:SetOwner(owner, anchor, x, y)
        self.owner, self.anchor, self.offsetX, self.offsetY = owner, anchor, x, y
    end
    function GameTooltip:GetOwner() return self.owner end
    function GameTooltip:SetAnchorType(anchor, x, y)
        self.anchor, self.offsetX, self.offsetY = anchor, x, y
    end
end

local function CurrentRect()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if not Client.spanned then
        return { left = 0, bottom = 0, right = sw, top = sh, width = sw, height = sh,
            screenWidth = sw, screenHeight = sh, isSpanned = false }
    end
    local r = Client.rect
    return { left = r[1], bottom = r[2], right = r[3], top = r[4], width = r[3] - r[1], height = r[4] - r[2],
        screenWidth = sw, screenHeight = sh, isSpanned = true }
end

function Client.LoadOffhand()
    local addon = { AddonWindowCatalog = {} }
    assert(loadfile("Core/Bridges.lua"))("Offhand", addon)
    addon.MainhandGeometry = { GetCurrentRect = CurrentRect }
    function addon.API.RegisterGeometryCallback(owner, callback)
        if owner == nil or type(callback) ~= "function" then return false end
        for _, entry in ipairs(callbacks) do
            if entry[1] == owner then entry[2] = callback; return true end
        end
        callbacks[#callbacks + 1] = { owner, callback }
        return true
    end
    function addon.API.UnregisterGeometryCallback(owner)
        for i, entry in ipairs(callbacks) do
            if entry[1] == owner then table.remove(callbacks, i); return end
        end
    end
    _G.Offhand = addon
    Client.addon = addon
    assert(loadfile("Bridges/Shared/DefaultAnchors.lua"))("Offhand", addon)
    return addon
end

function Client.Load(path)
    return assert(loadfile(path))("Offhand", Client.addon)
end

function Client.Tick(reason)
    Client.addon.Bridges:Refresh(reason or "tick")
end

function Client.Geometry()
    local keep = {}
    for _, entry in ipairs(callbacks) do
        local ok, result = pcall(entry[2], CurrentRect(), "test", 1)
        if ok and result ~= false then keep[#keep + 1] = entry end
    end
    callbacks = keep
end

function Client.RunTimers()
    for _ = 1, 20 do
        if #timers == 0 then return end
        local batch = timers
        timers = {}
        for _, fn in ipairs(batch) do fn() end
    end
end

function Client.RunTickers()
    for _, ticker in ipairs(tickers) do
        if not ticker.cancelled then ticker.fn(ticker) end
    end
end

function Client.Fire(event, ...)
    for _, frame in ipairs(all) do
        if frame.events[event] then RunScript(frame, "OnEvent", event, ...) end
    end
end

-- ---------------------------------------------------------------------
-- Inspection
-- ---------------------------------------------------------------------

local function Offset(value)
    if value == 0 then value = 0 end   -- no "-0.0"
    return string.format("%.1f", value)
end

function Client.Point(frame)
    local parts = {}
    for _, p in ipairs(frame.points) do
        local rel = ""
        if p[2] ~= UIParent then
            rel = "@" .. (type(p[2]) == "table" and p[2].name or "unnamed")
        end
        parts[#parts + 1] = string.format("%s>%s%s %s,%s", p[1], p[3], rel, Offset(p[4]), Offset(p[5]))
    end
    if #parts == 0 then return "none" end
    return table.concat(parts, " | ")
end

function Client.Counts()
    local live, slashes = 0, 0
    for _, ticker in ipairs(tickers) do
        if not ticker.cancelled then live = live + 1 end
    end
    for _ in pairs(SlashCmdList) do slashes = slashes + 1 end
    return #created, #timers, live, slashes
end

function Client.Diagnostics()
    return Client.addon.Bridges:GetDiagnostics()
end

function Client.Errors()
    return Client.addon.Bridges.errors
end

local FORBIDDEN = {
    { "Offhand.db", "Offhand.db" },
    { "Offhand.Viewport", "Offhand.Viewport" },
    { "Offhand.Canvas", "Offhand.Canvas" },
    { "Offhand.isForever", "Offhand.isForever" },
    { "\226\128\148", "an em dash" },
    { "\226\128\147", "an en dash" },
    { "\t", "a tab" },
}

function Client.ForbiddenStrings(path)
    assert(loadfile(path), path .. " must parse")
    local handle = assert(io.open(path, "rb"), "missing " .. path)
    local text = handle:read("*a")
    handle:close()
    for _, entry in ipairs(FORBIDDEN) do
        assert(not text:find(entry[1], 1, true), path .. " must not contain " .. entry[2])
    end
end

return Client
