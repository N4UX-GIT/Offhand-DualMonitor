-- Bridges/Shared/DefaultAnchors.lua: availability, game rectangle deltas, the
-- default-anchor fitter, the parent holder, registration, and inert load.
local Client = dofile("tests/support/bridge-client.lua")

local function Load(options)
    Client.Reset(options)
    local addon = Client.LoadOffhand()
    return addon, addon.API.GetBridgeNamespace("Shared")
end

local function Delta(Shared, point, ex, ey)
    local dx, dy = Shared.PointDelta(point)
    assert(dx == ex and dy == ey, string.format("PointDelta(%s) must be %s,%s, got %s,%s",
        point, tostring(ex), tostring(ey), tostring(dx), tostring(dy)))
end

-- 1. Forbidden strings
Client.ForbiddenStrings("Bridges/Shared/DefaultAnchors.lua")

-- 2. Inert load
local addon, Shared = Load()
local frames, timers, tickers, slashes = Client.Counts()
assert(frames == 0 and timers == 0 and tickers == 0 and slashes == 0,
    "loading the shared helper must create no frame, timer, ticker or slash command")
assert(#addon.Bridges:List() == 0, "loading the shared helper must register no bridge")
assert(type(Shared.NewAnchorFitter) == "function", "the shared helper must fill the Shared namespace")

-- 3. Available
addon, Shared = Load({ loaded = { Questie = true } })
assert(Shared.Available("Questie") == true, "a loaded addon on the Forever client must be available")
assert(Shared.Available("RareScanner") == false, "an addon that is not loaded must not be available")
assert(Shared.Available(nil) == false and Shared.Available("") == false, "a missing name must not be available")
addon, Shared = Load({ loaded = { Questie = true }, toc = 120107 })
assert(Shared.Available("Questie") == false, "the retail client must not be Forever")
addon, Shared = Load({ loaded = { Questie = true }, toc = 11508 })
assert(Shared.Available("Questie") == false, "the classic client must not be Forever")

-- 4. GameRect, IsSpanned, PointDelta
addon, Shared = Load()
assert(Shared.IsSpanned() == true, "the left half must count as spanned")
local l, b, r, t, sw, sh = Shared.GameRect()
assert(l == 0 and b == 0 and r == 2560 and t == 1440 and sw == 5120 and sh == 1440,
    "GameRect must return the game rectangle and the screen size")
Delta(Shared, "CENTER", -1280, 0)
Delta(Shared, "TOP", -1280, 0)
Delta(Shared, "TOPRIGHT", -2560, 0)
Delta(Shared, "BOTTOMLEFT", 0, 0)
Client.rect = { 2560, 0, 5120, 1440 }
Delta(Shared, "CENTER", 1280, 0)
Delta(Shared, "TOPLEFT", 2560, 0)
Delta(Shared, "RIGHT", 0, 0)
Client.rect = { 0, 0, 2560, 1080 }
assert(select(2, Shared.PointDelta("TOP")) == -360, "TOP must drop to a shorter game monitor's top")
assert(select(2, Shared.PointDelta("CENTER")) == -180, "CENTER must drop to a shorter game monitor's middle")
assert(select(2, Shared.PointDelta("BOTTOM")) == 0, "BOTTOM must stay on a shorter game monitor's bottom")
addon, Shared = Load({ spanned = false })
assert(Shared.IsSpanned() == false, "an unspanned client must not count as spanned")
for _, point in ipairs({ "CENTER", "TOP", "TOPRIGHT", "BOTTOMLEFT", "LEFT", "RIGHT", "BOTTOM" }) do
    Delta(Shared, point, 0, 0)
end

-- 5. Anchor fitter
addon, Shared = Load()
local spots = {
    A = { "CENTER", "CENTER", 0, 120 },
    B = { "TOPRIGHT", "TOPRIGHT", -260, -160 },
    C = { "BOTTOM", "BOTTOM", 0, 128 },
    D = { "TOP", "TOP", 0, -140 },
    E = { "CENTER", "CENTER", 330, 20 },
    F = { "CENTER", "CENTER", 0, 0 },
    G = { "CENTER", "CENTER", 0, 0 },
    Missing = { "CENTER", "CENTER", 0, 0 },
}
local A = Client.Frame("A", UIParent)
A:SetPoint("CENTER", 0, 120)
local B = Client.Frame("B", UIParent)
B:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -260, -160)
local C = Client.Frame("C", UIParent, { protected = true, scale = 0.8, ignoreParentScale = true })
C:SetPoint("BOTTOM", UIParent, 0, 128)
local D = Client.Frame("D", UIParent, { scale = 2 })
D:SetPoint("TOP", UIParent, "TOP", 0, -140)
local E = Client.Frame("E", UIParent)
E:SetPoint("TOPLEFT", 500, -300)
local F = Client.Frame("F", UIParent)
F:SetPoint("CENTER", 0, 0)
F:SetPoint("TOP", 0, 0)
local Other = Client.Frame("Other", UIParent)
local G = Client.Frame("G", UIParent)
G:SetPoint("CENTER", Other, "CENTER", 0, 0)

local fitter = Shared.NewAnchorFitter(spots)
assert(fitter.spots == spots and fitter.moves == 0, "a new fitter must keep its spots and start with no moves")
Client.combat = true
fitter:Refresh()
assert(Client.Point(A) == "CENTER>CENTER -1280.0,120.0", "A must move to the game centre: " .. Client.Point(A))
assert(Client.Point(B) == "TOPRIGHT>TOPRIGHT -2820.0,-160.0", "B must move to the game's top right: " .. Client.Point(B))
assert(Client.Point(C) == "BOTTOM>BOTTOM 0.0,128.0", "a protected frame must not move in combat: " .. Client.Point(C))
assert(Client.Point(D) == "TOP>TOP -640.0,-140.0", "D's offset must be in its own scale: " .. Client.Point(D))
assert(Client.Point(E) == "TOPLEFT>TOPLEFT 500.0,-300.0", "a dragged frame must be left alone: " .. Client.Point(E))
assert(Client.Point(F) == "CENTER>CENTER 0.0,0.0 | TOP>TOP 0.0,0.0", "a frame with two anchors must be left alone")
assert(Client.Point(G) == "CENTER>CENTER@Other 0.0,0.0", "a frame anchored to another frame must be left alone")
assert(#(C.hooks.OnShow or {}) == 0, "a protected frame must get no OnShow hook")
assert(#(A.hooks.OnShow or {}) == 1, "an unprotected frame must get one OnShow hook")
Client.combat = false
fitter:Refresh()
assert(Client.Point(C) == "BOTTOM>BOTTOM -1600.0,128.0", "C must move once combat ends: " .. Client.Point(C))
assert(fitter.moves == 4, "four frames must have moved, got " .. fitter.moves)
fitter:Refresh()
assert(fitter.moves == 4 and #(A.hooks.OnShow) == 1, "a second Refresh must change nothing and hook nothing again")
local moved, seen, total = fitter:Count()
assert(moved == 4 and seen == 7 and total == 8,
    string.format("Count must be 4, 7, 8, got %d, %d, %d", moved, seen, total))
assert(Shared.Describe("X", fitter) == "X=4/8", "Describe must read label=moved/total: " .. Shared.Describe("X", fitter))

-- The addon re-anchors A at its default as it opens it again.
A:Hide()
A:ClearAllPoints()
A:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
A:Show()
assert(Client.Point(A) == "CENTER>CENTER -1280.0,120.0", "re-showing A must fit it at once: " .. Client.Point(A))
assert(fitter.moves == 5, "the OnShow fit must count as one move")
Client.RunTimers()
assert(Client.Point(A) == "CENTER>CENTER -1280.0,120.0" and fitter.moves == 5, "the next-frame fit must change nothing")

-- The game rectangle moves: frames follow from where the fitter last put them.
Client.rect = { 2560, 0, 5120, 1440 }
fitter:Refresh()
assert(Client.Point(A) == "CENTER>CENTER 1280.0,120.0", "A must follow the game rectangle: " .. Client.Point(A))
assert(Client.Point(B) == "TOPRIGHT>TOPRIGHT -260.0,-160.0", "B must follow to the screen's top right: " .. Client.Point(B))

-- Unspanned: everything goes back to the addon's own default.
Client.spanned = false
fitter:Refresh()
assert(Client.Point(A) == "CENTER>CENTER 0.0,120.0", "A must go back to its default: " .. Client.Point(A))
assert(Client.Point(C) == "BOTTOM>BOTTOM 0.0,128.0", "C must go back to its default: " .. Client.Point(C))
assert(Client.Point(D) == "TOP>TOP 0.0,-140.0", "D must go back to its default: " .. Client.Point(D))
moved = fitter:Count()
assert(moved == 0, "frames back at their defaults must not count as moved, got " .. moved)

-- The player drags A after the fitter moved it.
Client.spanned = true
Client.rect = { 0, 0, 2560, 1440 }
fitter:Refresh()
assert(Client.Point(A) == "CENTER>CENTER -1280.0,120.0", "A must move again when spanned again")
A:ClearAllPoints()
A:SetPoint("CENTER", UIParent, "CENTER", -900, 300)
fitter:Refresh()
Client.rect = { 2560, 0, 5120, 1440 }
fitter:Refresh()
assert(Client.Point(A) == "CENTER>CENTER -900.0,300.0", "a frame the player dragged must be left alone: " .. Client.Point(A))
assert(fitter:Fit("Missing") == false and fitter:Fit("Nowhere") == false, "a missing frame or spot must not fit")

-- 6. Parent holder
addon, Shared = Load()
local before = Client.Counts()
local holder = Shared.NewParentHolder("OffhandTestHolder")
assert(Client.Counts() == before + 1, "a holder must create exactly one frame")
assert(_G.OffhandTestHolder == holder.frame and holder.frame:GetParent() == UIParent and holder.taken == 0,
    "the holder frame must be named and sit on UIParent")
assert(Client.Point(holder.frame) == "BOTTOMLEFT>BOTTOMLEFT 0.0,0.0", "the holder must sit at UIParent's bottom-left")
local icon = Client.Frame("Icon", UIParent)
local other = Client.Frame("OtherParent", UIParent)
assert(holder:Adopt(icon) == true and icon:GetParent() == holder.frame, "adopting must move the icon under the holder")
icon:SetParent(UIParent)
assert(icon:GetParent() == holder.frame, "SetParent(UIParent) must end under the holder")
icon:SetParent(other)
assert(icon:GetParent() == other, "SetParent to another frame must be kept")
assert(holder:Adopt(icon) == false and holder.taken == 1, "adopting twice must count once")
local loose = Client.Frame("Loose", other)
assert(holder:Adopt(loose) == true and loose:GetParent() == other and holder.taken == 2,
    "adopting an icon not on UIParent must leave its parent")
assert(holder:Adopt("icon") == false and holder:Adopt({}) == false and holder.taken == 2, "a non-frame must be refused")

-- 7. Register
addon, Shared = Load()
local reasons = {}
local bridge = {}
function bridge:Refresh(reason) reasons[#reasons + 1] = reason end
local ok = Shared.Register("Test", bridge)
local ids = addon.Bridges:List()
assert(ok == true and ids[1] == "Test" and bridge.contract == 1, "Register must register with contract 1")
Client.Tick()
assert(reasons[1] == "tick", "a tick must reach the bridge's Refresh")
Client.Geometry()
assert(reasons[2] == "geometry", "a geometry change must reach the bridge's Refresh")
Client.Geometry()
assert(reasons[3] == "geometry", "the geometry callback must stay registered")
local broken, second = {}, {}
function broken:Refresh() error("boom") end
function second:Refresh(reason) second.reason = reason end
assert(Shared.Register("Broken", broken) == true and Shared.Register("Second", second) == true)
Client.Tick("layout")
assert(type(Client.Errors().Broken) == "string" and Client.Errors().Broken:find("boom", 1, true),
    "a failing Refresh must be recorded")
assert(second.reason == "layout", "a failing bridge must not stop the next one")
Client.Geometry()
assert(second.reason == "geometry", "a failing geometry Refresh must not stop the next one")
local failed, why = Shared.Register("Bad", "not a table")
assert(failed == false and why == "bridge", "registering a non-table must fail")

-- Holds and Count forget a frame the player moved after the fitter did.
do
    local _, Fresh = Load()
    local held = Client.Frame("HeldWindow", UIParent)
    held:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    local fitter = Fresh.NewAnchorFitter({ HeldWindow = { "CENTER", "CENTER", 0, 120 } })
    assert(fitter:Holds("HeldWindow") == false, "an untouched frame is not held")
    fitter:Refresh()
    assert(fitter:Holds("HeldWindow") == true and fitter:Count() == 1, "a moved frame is held")
    held:ClearAllPoints()
    held:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -200)
    assert(fitter:Holds("HeldWindow") == false and fitter:Count() == 0,
        "a frame dragged after the fitter moved it is no longer held or counted")
    fitter:Refresh()
    assert(Client.Point(held) == "TOPLEFT>TOPLEFT 300.0,-200.0", "the dragged frame stays where the player put it")
    assert(Fresh.IsForever() == true, "the Forever test is exposed for bridges that register before their addon")
end

print("PASS: shared default-anchor helper, holder, registration and inert load")
