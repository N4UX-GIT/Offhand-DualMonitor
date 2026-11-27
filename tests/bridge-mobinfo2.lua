-- Bridges/MobInfo2/Bridge.lua: the tooltip anchor follows the game rectangle while it is at
-- MobInfo2's default, dragged and saved spots are left alone, and the bridge is inert when not active.
local Client = dofile("tests/support/bridge-client.lua")

local PATH = "Bridges/MobInfo2/Bridge.lua"
local ID = "MobInfo2"
local ANCHOR = "MI2_TooltipAnchor"

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

-- Frames/MI2_Tooltip.xml: <Anchor point="TOPRIGHT"><Offset x="-4" y="-200"/></Anchor> on UIParent.
local function Anchor()
    local anchor = Client.Frame(ANCHOR, UIParent)
    anchor:SetSize(25, 18)
    anchor:SetPoint("TOPRIGHT", -4, -200)
    return anchor
end

-- MI2_Slash.lua, /mi2 resetpos
local function ResetPos(anchor)
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -4, -200)
end

-- 1. Forbidden strings
Client.ForbiddenStrings(PATH)

-- 2. Inert when MobInfo2 is not loaded
Inert({}, "MobInfo2 not loaded")

-- 3. Inert on a non-Forever client
Inert({ loaded = { MobInfo2 = true }, toc = 120107 }, "retail client")

-- 4. Active: the anchor moves to the game rectangle's top right corner (left half: TOPRIGHT delta -2560,0)
Client.Reset({ loaded = { MobInfo2 = true } })
Client.LoadOffhand()
local anchor = Anchor()
Client.Load(PATH)
assert(Registered(), "the bridge must register when MobInfo2 is loaded on Forever")
Client.Tick()
Expect(anchor, "TOPRIGHT>TOPRIGHT -2564.0,-200.0", "the anchor must move to the game's top right corner")
Client.Tick()
Expect(anchor, "TOPRIGHT>TOPRIGHT -2564.0,-200.0", "a later tick must keep the anchor where it is")

-- MI2_TooltipAnchorOnLeave saves the current point; MobInfo2.lua restores it at the next login with
-- SetPoint(point, nil, point, x, y). That saved bridged spot is not the default and stays as it is.
local a, _, _, x, y = anchor:GetPoint()
local saved = { a, x, y }
assert(saved[1] == "TOPRIGHT" and saved[2] == -2564 and saved[3] == -200,
    "MobInfo2 must read the bridged spot as the anchor's current point")
Client.Reset({ loaded = { MobInfo2 = true } })
Client.LoadOffhand()
anchor = Anchor()
anchor:SetPoint(saved[1], nil, saved[1], saved[2], saved[3])
Client.Load(PATH)
Client.Tick()
Expect(anchor, "TOPRIGHT>TOPRIGHT -2564.0,-200.0", "the restored saved spot must be left as it is")
Client.spanned = false
Client.Tick()
Expect(anchor, "TOPRIGHT>TOPRIGHT -2564.0,-200.0", "a saved spot is MobInfo2's own, even unspanned")
Client.spanned = true

-- /mi2 resetpos puts the anchor back at the default; the next tick moves it again.
ResetPos(anchor)
Client.Tick()
Expect(anchor, "TOPRIGHT>TOPRIGHT -2564.0,-200.0", "the anchor must move again after /mi2 resetpos")

-- 5. An anchor created after the bridge loaded is picked up by the next tick
Client.Reset({ loaded = { MobInfo2 = true } })
Client.LoadOffhand()
Client.Load(PATH)
assert(Client.Diagnostics():find("MobInfo2Anchors=0/1", 1, true), "no anchor yet: nothing moved")
anchor = Anchor()
Client.Tick()
Expect(anchor, "TOPRIGHT>TOPRIGHT -2564.0,-200.0", "an anchor created later must be moved by the next tick")

-- 6. A dragged anchor is left alone; unspanned puts a moved anchor back
anchor:ClearAllPoints()
anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -300, -500)
Client.Tick()
Expect(anchor, "TOPRIGHT>TOPRIGHT -300.0,-500.0", "an anchor the player dragged must be left alone")
anchor:ClearAllPoints()
anchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 2000, 1240)
Client.Tick()
Expect(anchor, "TOPLEFT>BOTTOMLEFT 2000.0,1240.0", "an anchor with another anchor shape must be left alone")
ResetPos(anchor)
Client.Tick()
Expect(anchor, "TOPRIGHT>TOPRIGHT -2564.0,-200.0", "the anchor back at the default must move again")
Client.spanned = false
Client.Tick()
Expect(anchor, "TOPRIGHT>TOPRIGHT -4.0,-200.0", "unspanned must put the anchor back at MobInfo2's default")
assert(Client.Diagnostics():find("MobInfo2Anchors=0/1", 1, true), "an anchor back at its default is not moved")

-- 7. The game on the right half: its top right corner is the screen's (TOPRIGHT delta 0,0)
Client.spanned = true
Client.Tick()
Expect(anchor, "TOPRIGHT>TOPRIGHT -2564.0,-200.0", "spanned again on the left half the anchor must move")
Client.rect = { 2560, 0, 5120, 1440 }
Client.Tick()
Expect(anchor, "TOPRIGHT>TOPRIGHT -4.0,-200.0", "with the game on the right half the anchor must return to the default")
Client.Tick()
Expect(anchor, "TOPRIGHT>TOPRIGHT -4.0,-200.0", "the default spot is already on the right-half game monitor")
Client.rect = { 0, 0, 2560, 1080 }
Client.Geometry()
Expect(anchor, "TOPRIGHT>TOPRIGHT -2564.0,-560.0", "a shorter game monitor must lower the anchor to its top")

-- 9. Diagnostics and errors
local diag = Client.Diagnostics()
assert(type(diag) == "string" and diag:find("MobInfo2Anchors=1/1", 1, true),
    "diagnostics must show MobInfo2Anchors, got " .. tostring(diag))
assert(next(Client.Errors()) == nil, "the bridge must raise no error")

print("PASS: MobInfo2 bridge (inert load, anchor fit, saved spot, resetpos, dragged anchor, unspanned, right half)")
