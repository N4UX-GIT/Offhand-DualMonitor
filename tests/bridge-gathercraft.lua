-- Bridges/Gathercraft/Bridge.lua: inert loads, Gathercraft's windows moved from
-- their default spots onto the game rectangle, dragged windows, and world-map
-- pins kept under the holder frame instead of UIParent.
local Client = dofile("tests/support/bridge-client.lua")

local PATH = "Bridges/Gathercraft/Bridge.lua"
local ID = "Gathercraft"

local function Expect(frame, want, message)
    local got = Client.Point(frame)
    assert(got == want, string.format("%s: expected %s, got %s", message, want, got))
end

local function Listed()
    for _, id in ipairs(Client.addon.Bridges:List()) do
        if id == ID then return true end
    end
    return false
end

local function Inert(options, message)
    Client.Reset(options)
    Client.LoadOffhand()
    Client.Load(PATH)
    local frames, timers, tickers, slashes = Client.Counts()
    assert(frames == 0 and timers == 0 and tickers == 0 and slashes == 0,
        message .. ": the bridge must create no frame, timer, ticker or slash command")
    assert(not Listed(), message .. ": the bridge must not register")
end

local function Diag(token, message)
    local text = Client.Diagnostics() or ""
    assert(string.find(text, token, 1, true), string.format("%s: expected %s in %s", message, token, text))
end

-- Gathercraft's windows, anchored as its source does.
local function Window(name, y)
    local f = Client.Frame(name, UIParent)
    f:SetPoint("CENTER", 0, y)
    return f
end

local WINDOWS = {
    GathercraftRunSummary = 120, GathercraftSkillPlan = 120, GathercraftWelcome = 120, GathercraftWhatsNew = 120,
    GathercraftPlanHint = 140, GathercraftPlanGathered = 140, GathercraftPlanZones = 60,
    GathercraftPanel = 200, GathercraftArrow = 300, GathercraftMain = 0,
}

-- A HereBeDragons-Pins-2.0 stand-in: AddWorldMapIcon* store into worldmapPinRegistry[ref][icon].
local function NewPins()
    local Pins = { worldmapPinRegistry = {} }
    local function add(self, ref, icon)
        self.worldmapPinRegistry[ref] = self.worldmapPinRegistry[ref] or {}
        self.worldmapPinRegistry[ref][icon] = true
    end
    Pins.AddWorldMapIconMap = add
    Pins.AddWorldMapIconWorld = add
    return Pins
end

local function UseLibStub(Pins)
    LibStub = setmetatable({}, { __call = function(_, name)
        if name == "HereBeDragons-Pins-2.0" then return Pins end
    end })
end

local function Pin()                                 -- Pins.lua CreatePin
    return CreateFrame("Frame", nil, UIParent)
end

-- 1. Forbidden strings
Client.ForbiddenStrings(PATH)

-- 2. Inert when Gathercraft is not loaded
Inert(nil, "without Gathercraft")

-- 3. Inert on a non-Forever client
Inert({ loaded = { Gathercraft = true }, toc = 120107 }, "on a non-Forever client")

-- 4. Active: every window moves from its default spot to the game rectangle (left half)
Client.Reset({ loaded = { Gathercraft = true } })
Client.LoadOffhand()
local Pins = NewPins()
UseLibStub(Pins)
local frames = {}
for name, y in pairs(WINDOWS) do frames[name] = Window(name, y) end
local pinA, pinB = Pin(), Pin()
Pins:AddWorldMapIconMap("Gathercraft", pinA, 1, 0.5, 0.5)
Pins:AddWorldMapIconWorld("GathercraftRoute", pinB, 0, 100, 200)
Client.Load(PATH)
assert(Listed(), "the bridge must register when Gathercraft is loaded on Forever")
local holder = _G.OffhandGathercraftPins
assert(type(holder) == "table", "the active bridge must create its pin holder")
Client.Tick()
for name, y in pairs(WINDOWS) do
    Expect(frames[name], string.format("CENTER>CENTER -1280.0,%.1f", y), name .. " must move to the game monitor")
end
Diag("GathercraftAnchors=10/10", "diagnostics must count ten moved windows")

-- 8. World-map pins
assert(pinA:GetParent() == holder and pinB:GetParent() == holder,
    "pins already in the registry at load must be adopted by the holder")
local pinC, other = Pin(), Pin()
Pins:AddWorldMapIconMap("GathercraftTarget", pinC, 1, 0.2, 0.2)
Pins:AddWorldMapIconMap("Questie", other, 1, 0.2, 0.2)
assert(pinC:GetParent() == holder, "a pin added later must be adopted by the hook")
assert(other:GetParent() == UIParent, "a pin of another addon's ref must be left on UIParent")
local canvas = Client.Frame("WorldMapCanvas", UIParent)
pinA:SetParent(canvas)
assert(pinA:GetParent() == canvas, "a pin the map takes must stay under the map")
pinA:SetParent(UIParent)
assert(pinA:GetParent() == holder, "a pin returned to UIParent must end under the holder")
local pinD = Pin()
Pins.worldmapPinRegistry.Gathercraft[pinD] = true    -- not through the hooked functions
Client.Tick()
assert(pinD:GetParent() == UIParent, "with the hooks installed a tick must not walk the registry")
Client.Tick("layout")
assert(pinD:GetParent() == holder, "a layout refresh must sweep the registry")
Diag("GathercraftPins=4", "diagnostics must count four pins taken over")

-- 7. The game on the right half: the moved windows follow
Client.rect = { 2560, 0, 5120, 1440 }
Client.Tick()
Expect(frames.GathercraftMain, "CENTER>CENTER 1280.0,0.0", "the main window must follow the game to the right half")
Expect(frames.GathercraftArrow, "CENTER>CENTER 1280.0,300.0", "the arrow must follow the game to the right half")
Client.rect = { 0, 0, 2560, 1440 }
Client.Tick()

-- 6. A dragged window is left alone; unspanned puts moved windows back
local panel = frames.GathercraftPanel
panel:ClearAllPoints()
panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 200, 1000)
Client.Tick()
Expect(panel, "TOPLEFT>BOTTOMLEFT 200.0,1000.0", "a dragged window must be left alone")
Client.spanned = false
Client.Tick()
Expect(frames.GathercraftMain, "CENTER>CENTER 0.0,0.0", "unspanned, the main window must go back to its default")
Expect(frames.GathercraftPlanZones, "CENTER>CENTER 0.0,60.0", "unspanned, the zones list must go back to its default")
Expect(panel, "TOPLEFT>BOTTOMLEFT 200.0,1000.0", "unspanned, a dragged window must stay where the player put it")
assert(next(Client.Errors()) == nil, "the bridge must raise no error")

-- 5. A window created after the bridge loaded is picked up by the next tick
Client.Reset({ loaded = { Gathercraft = true } })
Client.LoadOffhand()
Client.Load(PATH)
local welcome = Window("GathercraftWelcome", 120)
Client.Tick()
Expect(welcome, "CENTER>CENTER -1280.0,120.0", "a window created later must be moved by the next tick")

-- 8. Until the hooks are installed every refresh, a tick too, tries again
local pinE = Pin()
Pins = NewPins()
Pins:AddWorldMapIconMap("Gathercraft", pinE, 1, 0.5, 0.5)
UseLibStub(Pins)
Client.Tick()
assert(pinE:GetParent() == _G.OffhandGathercraftPins, "a tick must install the hooks and sweep when they are missing")
local pinF = Pin()
Pins:AddWorldMapIconWorld("GathercraftRouteHead", pinF, 0, 1, 1)
assert(pinF:GetParent() == _G.OffhandGathercraftPins, "the hooks installed from a tick must adopt new pins")

-- 7. The game on the right half from the start
Client.Reset({ loaded = { Gathercraft = true }, rect = { 2560, 0, 5120, 1440 } })
Client.LoadOffhand()
local main, hint = Window("GathercraftMain", 0), Window("GathercraftPlanHint", 140)
Client.Load(PATH)
Client.Tick()
Expect(main, "CENTER>CENTER 1280.0,0.0", "right half: the main window must move to the game monitor")
Expect(hint, "CENTER>CENTER 1280.0,140.0", "right half: the plan hint must move to the game monitor")

-- 9. Diagnostics and errors
Diag("GathercraftAnchors=2/10", "diagnostics must count two moved windows")
Diag("GathercraftPins=0", "diagnostics must count no pins without HereBeDragons")
assert(next(Client.Errors()) == nil, "the bridge must raise no error")

print("PASS: Gathercraft bridge")
