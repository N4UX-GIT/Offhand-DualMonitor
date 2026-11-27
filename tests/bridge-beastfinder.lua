-- Bridges/Beastfinder/Bridge.lua: the new beast card follows the game rectangle while it is at
-- Beastfinder's default, dragged cards are left alone, and the bridge is inert when not active.
local Client = dofile("tests/support/bridge-client.lua")

local PATH = "Bridges/Beastfinder/Bridge.lua"
local ID = "Beastfinder"
local CARD = "BeastfinderNewBeastCard"

local function Registered()
    for _, id in ipairs(Client.addon.Bridges:List()) do
        if id == ID then return true end
    end
    return false
end

local function Inert(options, label)
    Client.Reset(options)
    Client.LoadOffhand()
    Client.Load(PATH)
    local frames, timers, tickers, slashes = Client.Counts()
    assert(frames == 0 and timers == 0 and tickers == 0 and slashes == 0,
        label .. ": the bridge must create no frame, timer, ticker or slash command")
    assert(not Registered(), label .. ": the bridge must not register")
end

local function Expect(frame, want, message)
    local got = Client.Point(frame)
    assert(got == want, string.format("%s: expected %s, got %s", message, want, got))
end

-- Beastfinder's A.PlaceToast: the card at its default spot.
local function Place(card)
    card:ClearAllPoints()
    card:SetPoint("TOP", UIParent, "TOP", 0, -170)
end

local function Card()
    local card = Client.Frame(CARD, UIParent, { shown = false })
    card:SetSize(320, 64)
    Place(card)
    return card
end

-- 1. Forbidden strings
Client.ForbiddenStrings(PATH)

-- 2. Inert when Beastfinder is not loaded
Inert({}, "Beastfinder not loaded")

-- 3. Inert on a non-Forever client
Inert({ loaded = { Beastfinder = true }, toc = 120107 }, "retail client")

-- 4. Active: the card moves to the top of the game rectangle (left half: TOP delta -1280,0)
Client.Reset({ loaded = { Beastfinder = true } })
Client.LoadOffhand()
local card = Card()
Client.Load(PATH)
assert(Registered(), "the bridge must register when Beastfinder is loaded on Forever")
Client.Tick()
Expect(card, "TOP>TOP -1280.0,-170.0", "the card must move to the top of the game rectangle")

-- Beastfinder places the card at its default again as it paints it; showing it moves it at once.
Place(card)
card:Show()
Expect(card, "TOP>TOP -1280.0,-170.0", "the card must move as it shows")

-- A scaled card: offsets are in the card's own units (k = 1 / 1.25 = 0.8).
card:SetScale(1.25)
Place(card)
Client.Tick()
Expect(card, "TOP>TOP -1024.0,-170.0", "a scaled card must move by the delta in its own units")
card:SetScale(1)
Place(card)
Client.Tick()
Expect(card, "TOP>TOP -1280.0,-170.0", "the card must move again at scale 1")
assert(Client.Diagnostics():find("BeastfinderAnchors=1/1", 1, true), "diagnostics must count the moved card")

-- 5. A card created after the bridge loaded is picked up by the next tick
Client.Reset({ loaded = { Beastfinder = true } })
Client.LoadOffhand()
Client.Load(PATH)
assert(Client.Diagnostics():find("BeastfinderAnchors=0/1", 1, true), "no card yet: nothing moved")
card = Card()
Client.Tick()
Expect(card, "TOP>TOP -1280.0,-170.0", "a card created later must be moved by the next tick")
Place(card)
card:Show()
Expect(card, "TOP>TOP -1280.0,-170.0", "a card created later must get the OnShow hook too")

-- 6. A dragged card is left alone; unspanned puts a moved card back
card:ClearAllPoints()
card:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 900, 1200)
Client.Tick()
Expect(card, "TOPLEFT>BOTTOMLEFT 900.0,1200.0", "a card the player dragged must be left alone")
card:ClearAllPoints()
card:SetPoint("TOP", UIParent, "TOP", 300, -170)
Client.Tick()
Expect(card, "TOP>TOP 300.0,-170.0", "a card dragged along the top must be left alone")
Place(card)
Client.Tick()
Expect(card, "TOP>TOP -1280.0,-170.0", "the card back at the default must move again")
Client.spanned = false
Client.Tick()
Expect(card, "TOP>TOP 0.0,-170.0", "unspanned must put the card back at Beastfinder's default")
assert(Client.Diagnostics():find("BeastfinderAnchors=0/1", 1, true), "a card back at its default is not moved")

-- 7. The game on the right half (TOP delta 1280,0)
Client.spanned = true
Client.rect = { 2560, 0, 5120, 1440 }
Client.Tick()
Expect(card, "TOP>TOP 1280.0,-170.0", "the card at the default must follow the game to the right half")
Client.rect = { 0, 0, 2560, 1440 }
Client.Geometry()
Expect(card, "TOP>TOP -1280.0,-170.0", "a geometry change must move the card from the bridge's own spot")
Client.rect = { 2560, 0, 5120, 1440 }
Client.Geometry()
Expect(card, "TOP>TOP 1280.0,-170.0", "the card at the bridge's own spot must follow the game to the right half")

-- 9. Diagnostics and errors
local diag = Client.Diagnostics()
assert(type(diag) == "string" and diag:find("BeastfinderAnchors=1/1", 1, true),
    "diagnostics must show BeastfinderAnchors, got " .. tostring(diag))
assert(next(Client.Errors()) == nil, "the bridge must raise no error")

print("PASS: Beastfinder bridge (inert load, card fit, OnShow, scale, dragged card, unspanned, right half)")
