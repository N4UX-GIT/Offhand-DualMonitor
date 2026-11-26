-- Bridges/ForeverLedger/Bridge.lua: inert loads, ForeverLedger's windows moved
-- from their default spots onto the game rectangle, dragged windows and the
-- docked side panel left alone, and the side panel re-centred on open.
local Client = dofile("tests/support/bridge-client.lua")

local PATH = "Bridges/ForeverLedger/Bridge.lua"
local ID = "ForeverLedger"

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

-- ForeverLedger's own frames, anchored as its source does.
local function Window(name)                          -- UI.lua themedWindow
    local f = Client.Frame(name, UIParent)
    f:SetSize(400, 300)
    f:SetPoint("CENTER")
    f:Hide()
    return f
end

local function Customers()                           -- Customers.lua
    local f = Window("ForeverLedgerCustomers")
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -260, -160)
    return f
end

local function Disenchant()                          -- QuickDisenchant.lua
    local f = Window("ForeverLedgerDisenchant")
    f:ClearAllPoints()
    f:SetPoint("CENTER", 220, 0)
    return f
end

local function Tracker()                             -- Sessions.lua, scaled by ForeverLedger's UI scale
    local f = Client.Frame("ForeverLedgerSessionTracker", UIParent)
    f:SetScale(0.8)
    f:SetPoint("TOP", UIParent, "TOP", 0, -140)
    return f
end

local function SidePanel()                           -- BuyQueue.lua place(), away from the auction house
    local f = Client.Frame("ForeverLedgerSidePanel", UIParent)
    f:SetPoint("CENTER")
    return f
end

-- 1. Forbidden strings
Client.ForbiddenStrings(PATH)

-- 2. Inert when ForeverLedger is not loaded
Inert(nil, "without ForeverLedger")

-- 3. Inert on a non-Forever client
Inert({ loaded = { ForeverLedger = true }, toc = 120107 }, "on a non-Forever client")

-- 4. Active: every window moves from its default spot to the game rectangle (left half)
Client.Reset({ loaded = { ForeverLedger = true } })
Client.LoadOffhand()
local customers, disenchant, tracker, side = Customers(), Disenchant(), Tracker(), SidePanel()
Client.Load(PATH)
assert(Listed(), "the bridge must register when ForeverLedger is loaded on Forever")
Client.Tick()
Expect(customers, "TOPRIGHT>TOPRIGHT -2820.0,-160.0", "the customers window must move to the game monitor's top-right")
Expect(disenchant, "CENTER>CENTER -1060.0,0.0", "the disenchant window must move to the game monitor's centre")
Expect(tracker, "TOP>TOP -1600.0,-140.0", "the scaled session tracker must move to the game monitor's top")
Expect(side, "CENTER>CENTER -1280.0,0.0", "the side panel must move to the game monitor's centre")
assert(string.find(Client.Diagnostics(), "ForeverLedgerAnchors=4/4", 1, true), "diagnostics must count four moved windows")

-- 7. The game on the right half (geometry change follows the windows the bridge moved)
Client.rect = { 2560, 0, 5120, 1440 }
Client.Geometry()
Expect(disenchant, "CENTER>CENTER 1500.0,0.0", "the disenchant window must follow the game to the right half")
Expect(tracker, "TOP>TOP 1600.0,-140.0", "the session tracker must follow the game to the right half")
Expect(customers, "TOPRIGHT>TOPRIGHT -260.0,-160.0", "the customers window is at its default on the right half")
Client.rect = { 0, 0, 2560, 1440 }
Client.Tick()
Expect(customers, "TOPRIGHT>TOPRIGHT -2820.0,-160.0", "the customers window must come back to the left half")

-- 6. A dragged window is left alone; unspanned puts moved windows back
disenchant:ClearAllPoints()
disenchant:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 300, 900)
Client.Tick()
Expect(disenchant, "TOPLEFT>BOTTOMLEFT 300.0,900.0", "a dragged window must be left alone")
Client.spanned = false
Client.Tick()
Expect(customers, "TOPRIGHT>TOPRIGHT -260.0,-160.0", "unspanned, the customers window must go back to its default")
Expect(tracker, "TOP>TOP 0.0,-140.0", "unspanned, the session tracker must go back to its default")
Expect(side, "CENTER>CENTER 0.0,0.0", "unspanned, the side panel must go back to its default")
Expect(disenchant, "TOPLEFT>BOTTOMLEFT 300.0,900.0", "unspanned, a dragged window must stay where the player put it")
assert(next(Client.Errors()) == nil, "the bridge must raise no error")

-- 5. A window created after the bridge loaded is picked up by the next tick
Client.Reset({ loaded = { ForeverLedger = true } })
Client.LoadOffhand()
Client.Load(PATH)
customers = Customers()
Expect(customers, "TOPRIGHT>TOPRIGHT -260.0,-160.0", "a new window starts at ForeverLedger's default")
Client.Tick()
Expect(customers, "TOPRIGHT>TOPRIGHT -2820.0,-160.0", "a window created later must be moved by the next tick")

-- 7. The game on the right half from the start
Client.Reset({ loaded = { ForeverLedger = true }, rect = { 2560, 0, 5120, 1440 } })
Client.LoadOffhand()
disenchant, tracker = Disenchant(), Tracker()
Client.Load(PATH)
Client.Tick()
Expect(disenchant, "CENTER>CENTER 1500.0,0.0", "right half: the disenchant window must move to the game monitor's centre")
Expect(tracker, "TOP>TOP 1600.0,-140.0", "right half: the session tracker must move to the game monitor's top")

-- 8. The side panel docked beside the auction house is left alone, then moved
-- at once when ForeverLedger re-centres it on UIParent and shows it.
Client.Reset({ loaded = { ForeverLedger = true } })
Client.LoadOffhand()
local auctionHouse = Client.Frame("AuctionHouseFrame", UIParent)
side = Client.Frame("ForeverLedgerSidePanel", auctionHouse)
side:SetPoint("TOPLEFT", auctionHouse, "TOPRIGHT", 4, 0)
side:SetPoint("BOTTOMLEFT", auctionHouse, "BOTTOMRIGHT", 4, 0)
Client.Load(PATH)
Client.Tick()
local docked = "TOPLEFT>TOPRIGHT@AuctionHouseFrame 4.0,0.0 | BOTTOMLEFT>BOTTOMRIGHT@AuctionHouseFrame 4.0,0.0"
Expect(side, docked, "the side panel docked beside the auction house must be left alone")
side:Hide()
side:ClearAllPoints()
side:SetParent(UIParent)
side:SetPoint("CENTER")
Expect(side, "CENTER>CENTER 0.0,0.0", "the side panel is re-centred on UIParent by ForeverLedger")
side:Show()
Expect(side, "CENTER>CENTER -1280.0,0.0", "the re-centred side panel must move as soon as it is shown")
Client.RunTimers()
Expect(side, "CENTER>CENTER -1280.0,0.0", "the side panel must stay on the game monitor after the next frame")

-- 9. Diagnostics and errors
assert(string.find(Client.Diagnostics(), "ForeverLedgerAnchors=1/4", 1, true),
    "diagnostics must show ForeverLedgerAnchors=1/4, got " .. tostring(Client.Diagnostics()))
assert(next(Client.Errors()) == nil, "the bridge must raise no error")

print("PASS: ForeverLedger bridge")
