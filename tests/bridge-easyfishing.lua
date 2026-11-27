-- Bridges/EasyFishing/Bridge.lua: inert loads, EasyFishing's frames moved from
-- their default spots onto the game rectangle, the unnamed skill-up popup found
-- by shape and placed at the game rectangle's top-centre, dragged frames, the
-- lure badge on the cast button, and the secure cast button in combat.
local Client = dofile("tests/support/bridge-client.lua")

local PATH = "Bridges/EasyFishing/Bridge.lua"
local ID = "EasyFishing"

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

-- EasyFishing's named frames, anchored as its source does.
local function Named(name, x, y, protected)
    local f = Client.Frame(name, UIParent, { protected = protected, kind = protected and "Button" or "Frame" })
    f:SetPoint("CENTER", UIParent, "CENTER", x, y)
    return f
end

-- Tackle.lua ShowSkillUp, with overrides for the decoys.
local function Popup(options)
    options = options or {}
    local f = CreateFrame("Frame", options.name, UIParent)
    f:SetSize(options.width or 300, 40)
    f:SetPoint("TOP", UIParent, "TOP", 0, -170)
    f:SetFrameStrata(options.strata or "HIGH")
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    if not options.noUpdate then
        f:SetScript("OnUpdate", function(self, elapsed) self.t = self.t + elapsed end)
    end
    if not options.noTimer then f.t = 0 end
    return f
end

-- 1. Forbidden strings
Client.ForbiddenStrings(PATH)

-- 2. Inert when EasyFishing is not loaded
Inert(nil, "without EasyFishing")

-- 3. Inert on a non-Forever client
Inert({ loaded = { EasyFishing = true }, toc = 120107 }, "on a non-Forever client")

-- 4. Active: every frame moves from its default spot to the game rectangle (left half)
Client.Reset({ loaded = { EasyFishing = true } })
Client.LoadOffhand()
local session = Named("EasyFishingSessionWindow", 330, 20)
local button = Named("EasyFishingButton", 0, -140, true)
local indicator = Named("EasyFishingIndicator", 0, -90)
local badge = Named("EasyFishingLureBadge", 60, -140, true)
local glow = Named("EasyFishingGlow", 0, -60)
local settings = Client.Frame("EasyFishingSettings", UIParent)
settings:SetPoint("CENTER")
local console = Client.Frame("EasyFishingDebugConsole", UIParent)
console:SetPoint("CENTER")
local popup = Popup()
local before = Client.Counts()
Client.Load(PATH)
assert(Client.Counts() == before + 1, "the active bridge must create exactly one frame (its event frame)")
assert(Listed(), "the bridge must register when EasyFishing is loaded on Forever")
Client.Tick()
Expect(session, "CENTER>CENTER -950.0,20.0", "the session window must move to the game monitor")
Expect(button, "CENTER>CENTER -1280.0,-140.0", "the cast button must move to the game monitor")
Expect(indicator, "CENTER>CENTER -1280.0,-90.0", "the indicator must move to the game monitor")
Expect(badge, "CENTER>CENTER -1220.0,-140.0", "the lure badge at its own default must move to the game monitor")
Expect(glow, "CENTER>CENTER -1280.0,-60.0", "the glow preview must move to the game monitor")
Expect(settings, "CENTER>CENTER -1280.0,0.0", "the settings window must move to the game monitor")
Expect(console, "CENTER>CENTER -1280.0,0.0", "the debug console must move to the game monitor")
Diag("EasyFishingAnchors=7/7", "diagnostics must count seven moved frames")

-- 8. The skill-up popup: never searched from a tick, found by shape on a skill-up
Expect(popup, "TOP>TOP 0.0,-170.0", "the popup must not be searched for from a tick")
Diag("EasyFishingPopup=-", "diagnostics must show the popup as not found yet")
local decoys = {
    Popup({ width = 250 }),
    Popup({ name = "SomeNamedToast" }),
    Popup({ strata = "MEDIUM" }),
    Popup({ noTimer = true }),
    Popup({ noUpdate = true }),
}
Client.Fire("CHAT_MSG_SKILL")
Expect(popup, "TOP>BOTTOMLEFT 1280.0,1270.0", "the popup must move to the game monitor's top-centre on a skill-up")
for i, decoy in ipairs(decoys) do
    Expect(decoy, "TOP>TOP 0.0,-170.0", "decoy " .. i .. " must not be taken for the popup")
end
Client.RunTimers()
Client.Tick()
Client.Tick()
Expect(popup, "TOP>BOTTOMLEFT 1280.0,1270.0", "the popup must stay at the game monitor's top-centre")
Diag("EasyFishingPopup=1", "the popup must not be rewritten while it is already in place")

-- 7. The game on the right half: the popup and the moved frames follow
Client.rect = { 2560, 0, 5120, 1440 }
Client.Tick()
Expect(popup, "TOP>BOTTOMLEFT 3840.0,1270.0", "the popup must follow the game to the right half")
Expect(session, "CENTER>CENTER 1610.0,20.0", "the session window must follow the game to the right half")
Expect(indicator, "CENTER>CENTER 1280.0,-90.0", "the indicator must follow the game to the right half")
Diag("EasyFishingPopup=2", "following the game rectangle is one more placement")
Client.rect = { 0, 0, 2560, 1440 }
Client.Tick()

-- 6. A dragged frame is left alone; unspanned puts moved frames and the popup back
session:ClearAllPoints()
session:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 100, 800)
Client.Tick()
Expect(session, "TOPLEFT>BOTTOMLEFT 100.0,800.0", "a dragged frame must be left alone")
Client.spanned = false
Client.Tick()
Expect(popup, "TOP>TOP 0.0,-170.0", "unspanned, the popup must get EasyFishing's own anchor back")
Expect(button, "CENTER>CENTER 0.0,-140.0", "unspanned, the cast button must go back to its default")
Expect(glow, "CENTER>CENTER 0.0,-60.0", "unspanned, the glow preview must go back to its default")
Expect(session, "TOPLEFT>BOTTOMLEFT 100.0,800.0", "unspanned, a dragged frame must stay where the player put it")
Diag("EasyFishingPopup=4", "restoring the popup is one more placement")
Client.Tick()
Diag("EasyFishingPopup=4", "an unspanned popup at EasyFishing's own anchor must not be rewritten")
popup:ClearAllPoints()
popup:SetPoint("TOP", UIParent, "TOP", 0, -170)
Client.spanned = true
Client.Tick()
Expect(popup, "TOP>BOTTOMLEFT 1280.0,1270.0", "spanned again, the popup must return to the game monitor")
assert(next(Client.Errors()) == nil, "the bridge must raise no error")

-- 5. A frame created after the bridge loaded is picked up by the next tick
Client.Reset({ loaded = { EasyFishing = true } })
Client.LoadOffhand()
Client.Load(PATH)
settings = Client.Frame("EasyFishingSettings", UIParent)
settings:SetPoint("CENTER")
Client.Tick()
Expect(settings, "CENTER>CENTER -1280.0,0.0", "a frame created later must be moved by the next tick")

-- 7. The game on the right half from the start
Client.Reset({ loaded = { EasyFishing = true }, rect = { 2560, 0, 5120, 1440 } })
Client.LoadOffhand()
button = Named("EasyFishingButton", 0, -140, true)
settings = Client.Frame("EasyFishingSettings", UIParent)
settings:SetPoint("CENTER")
Client.Load(PATH)
Client.Tick()
Expect(button, "CENTER>CENTER 1280.0,-140.0", "right half: the cast button must move to the game monitor")
Expect(settings, "CENTER>CENTER 1280.0,0.0", "right half: the settings window must move to the game monitor")

-- 8. The lure badge hanging off the cast button is left alone; the secure cast
-- button waits for combat to end.
Client.Reset({ loaded = { EasyFishing = true }, combat = true })
Client.LoadOffhand()
button = Named("EasyFishingButton", 0, -140, true)
badge = Client.Frame("EasyFishingLureBadge", UIParent, { protected = true, kind = "Button" })
badge:SetPoint("LEFT", button, "RIGHT", 12, 0)
Client.Load(PATH)
Client.Tick()
Expect(button, "CENTER>CENTER 0.0,-140.0", "the secure cast button must not move in combat")
Client.combat = false
Client.Tick()
Expect(button, "CENTER>CENTER -1280.0,-140.0", "the secure cast button must move once combat ends")
Expect(badge, "LEFT>RIGHT@EasyFishingButton 12.0,0.0", "the lure badge on the cast button must be left alone")

-- 9. Diagnostics and errors
Diag("EasyFishingAnchors=1/7", "diagnostics must count the moved cast button")
Diag("EasyFishingPopup=-", "diagnostics must show the popup as not found yet")
assert(next(Client.Errors()) == nil, "the bridge must raise no error")

print("PASS: EasyFishing bridge")
