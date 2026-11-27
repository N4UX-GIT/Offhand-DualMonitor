-- Bridges/RareScanner/Bridge.lua: the button, explorer and dialogs follow the game rectangle while
-- they are at RareScanner's defaults, the button's saved spot is kept off the seam (reset hook,
-- combat, legacy seam repair), dragged frames are left alone, and the bridge is inert when not active.
local Client = dofile("tests/support/bridge-client.lua")

local PATH = "Bridges/RareScanner/Bridge.lua"
local ID = "RareScanner"
local DIALOG = "LibDialog-1.0RS_Dialog"

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

local function Saves(n, message)
    local diag = Client.Diagnostics() or ""
    assert(diag:find("RareScannerSaves=" .. n, 1, true), message .. ", got " .. diag)
end

local function Profile(profile, x, y, message)
    assert(profile.scannerXPos == x and profile.scannerYPos == y, string.format("%s: expected %s,%s, got %s,%s",
        message, tostring(x), tostring(y), tostring(profile.scannerXPos), tostring(profile.scannerYPos)))
end

-- The mock AceAddon: LibStub("AceAddon-3.0", true):GetAddon("RareScanner", true) is the addon,
-- whose db.profile is the AceDB profile RareScanner saves the button's spot into.
local function DefineLibStub(rs)
    local lib = {}
    function lib:GetAddon(name)
        if name == "RareScanner" then return rs end
    end
    LibStub = setmetatable({}, { __call = function(_, major)
        if major == "AceAddon-3.0" then return lib end
    end })
end

local function NewAddon()
    local rs = { db = { profile = {} } }
    -- RareScanner.lua: back to the default, then save GetLeft(), GetBottom() at once.
    function rs:ResetPosition()
        local button = _G.RARESCANNER_BUTTON
        button:ClearAllPoints()
        button:SetPoint("BOTTOM", UIParent, 0, 128)
        self.db.profile.scannerXPos, self.db.profile.scannerYPos = button:GetLeft(), button:GetBottom()
    end
    return rs
end

-- RareScanner.lua: a secure 200x50 button at scale 0.8 that ignores its parent's scale. The mock's
-- GetLeft/GetBottom only return fields, so this button works them out from its single anchor, in
-- its own units (k = UIParent scale / button scale = 1.25; the screen is 5120 * 1.25 = 6400 wide).
local function Button()
    local button = Client.Frame("RARESCANNER_BUTTON", UIParent,
        { kind = "Button", protected = true, scale = 0.8, ignoreParentScale = true, shown = false })
    button:SetSize(200, 50)
    button:SetPoint("BOTTOM", UIParent, 0, 128)
    function button:GetLeft()
        local _, _, relPoint, x = self:GetPoint(1)
        local k = UIParent:GetEffectiveScale() / self:GetEffectiveScale()
        if relPoint == "BOTTOM" then return UIParent:GetWidth() * k / 2 + x - self:GetWidth() / 2 end
        return x
    end
    function button:GetBottom()
        local _, _, _, _, y = self:GetPoint(1)
        return y
    end
    return button
end

-- RSEventHandler.lua OnPlayerLogin: the saved spot comes back as BOTTOMLEFT x,y.
local function Login(button, profile)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", profile.scannerXPos, profile.scannerYPos)
end

local function Dialog(index, hidden)
    local dialog = Client.Frame(DIALOG .. index, UIParent, { shown = not hidden })
    dialog:SetSize(320, 100)
    if index == 1 then
        dialog:SetPoint("TOP", UIParent, "TOP", 0, -135)
    else
        dialog:SetPoint("TOP", _G[DIALOG .. (index - 1)], "BOTTOM", 0, 0)
    end
    return dialog
end

local function World(options)
    Client.Reset(options)
    Client.LoadOffhand()
    local rs = NewAddon()
    DefineLibStub(rs)
    return rs, rs.db.profile
end

-- 1. Forbidden strings
Client.ForbiddenStrings(PATH)

-- 2. Inert when RareScanner is not loaded
Inert({}, "RareScanner not loaded")

-- 3. Inert on a non-Forever client
Inert({ loaded = { RareScanner = true }, toc = 120107 }, "retail client")

-- 4. Active, game on the left half: BOTTOM delta -1280,0 (button: -1280 * 1.25 = -1600),
-- CENTER delta -1280,0, TOP delta -1280,0.
local rs, profile = World({ loaded = { RareScanner = true } })
local button = Button()
local explorer = Client.Frame("RSExplorerFrame", UIParent, { shown = false })
explorer:SetSize(1305, 785)
explorer:SetPoint("CENTER")
local dialog1, dialog2 = Dialog(1), Dialog(2)
Client.Load(PATH)
assert(Registered(), "the bridge must register when RareScanner is loaded on Forever")
Client.Tick()
Expect(button, "BOTTOM>BOTTOM -1600.0,128.0", "the button must move to the bottom of the game rectangle")
Expect(explorer, "CENTER>CENTER -1280.0,0.0", "the explorer must move to the centre of the game rectangle")
Expect(dialog1, "TOP>TOP -1280.0,-135.0", "the first dialog must move to the top of the game rectangle")
Expect(dialog2, "TOP>BOTTOM@" .. DIALOG .. "1 0.0,0.0", "a dialog under the first one must be left alone")
assert(profile.scannerXPos == nil and profile.scannerYPos == nil, "moving the button alone must save nothing")
assert(Client.Diagnostics():find("RareScannerAnchors=3/6 RareScannerSaves=0", 1, true),
    "diagnostics must count the moved frames, got " .. tostring(Client.Diagnostics()))

-- The explorer at its default moves as it shows; dialogs re-anchored by the library move as they show.
explorer:ClearAllPoints()
explorer:SetPoint("CENTER")
explorer:Show()
Expect(explorer, "CENTER>CENTER -1280.0,0.0", "the explorer must move on Show()")
dialog1:Hide()
dialog1:ClearAllPoints()
dialog1:SetPoint("TOP", UIParent, "TOP", 0, -135)
dialog1:Show()
Expect(dialog1, "TOP>TOP -1280.0,-135.0", "a dialog re-anchored by the library must move as it shows")
dialog1:ClearAllPoints()
dialog1:SetPoint("TOP", UIParent, "TOP", 0, -135)   -- _RefreshDialogAnchors on a dismiss, no Show
Client.Tick()
Expect(dialog1, "TOP>TOP -1280.0,-135.0", "a dialog re-anchored on a dismiss must move on the next tick")

-- 8a. The reset hook moves the button and saves the moved spot (left 3200 - 1600 - 100 = 1500).
for _ = 1, 3 do Client.Tick() end
rs:ResetPosition()
Expect(button, "BOTTOM>BOTTOM -1600.0,128.0", "a reset must move the button at once")
Profile(profile, 1500, 128, "a reset must save the moved spot, not the seam")
Saves(1, "a reset must save once although the hook was retried on many refreshes")

-- 8b. A reset in combat saves only after combat (RareScanner itself saves the seam: 3100,128).
Client.combat = true
rs:ResetPosition()
Expect(button, "BOTTOM>BOTTOM 0.0,128.0", "the secure button must not move in combat")
Profile(profile, 3100, 128, "RareScanner saves the seam spot during the reset")
Client.Tick()
Expect(button, "BOTTOM>BOTTOM 0.0,128.0", "the secure button must wait for combat to end")
Profile(profile, 3100, 128, "nothing may be saved in combat")
Client.combat = false
Client.Tick()
Expect(button, "BOTTOM>BOTTOM -1600.0,128.0", "the button must move after combat")
Profile(profile, 1500, 128, "the moved spot must be saved after combat")
Saves(2, "the reset in combat must be saved once")
Client.Tick()
Saves(2, "a saved reset must not be saved again")

-- 5. A frame created after the bridge loaded is picked up by the next tick
local dialog3 = Client.Frame(DIALOG .. "3", UIParent)
dialog3:SetPoint("TOP", UIParent, "TOP", 0, -135)
Client.Tick()
Expect(dialog3, "TOP>TOP -1280.0,-135.0", "a dialog created later must be moved by the next tick")

-- 6. Dragged frames are left alone; unspanned puts moved frames back
explorer:ClearAllPoints()
explorer:SetPoint("CENTER", UIParent, "CENTER", 200, 50)
Client.Tick()
Expect(explorer, "CENTER>CENTER 200.0,50.0", "an explorer the player dragged must be left alone")
Client.spanned = false
Client.Tick()
Expect(button, "BOTTOM>BOTTOM 0.0,128.0", "unspanned must put the button back at RareScanner's default")
Expect(dialog1, "TOP>TOP 0.0,-135.0", "unspanned must put the dialog back at the library's default")
Expect(dialog3, "TOP>TOP 0.0,-135.0", "unspanned must put the later dialog back too")
Expect(explorer, "CENTER>CENTER 200.0,50.0", "unspanned must leave the dragged explorer alone")
Saves(2, "putting the button back must save nothing")

-- 7. The game on the right half: BOTTOM delta 1280,0 (button: 1600), TOP delta 1280,0
Client.spanned = true
Client.rect = { 2560, 0, 5120, 1440 }
Client.Tick()
Expect(button, "BOTTOM>BOTTOM 1600.0,128.0", "the button must follow the game to the right half")
Expect(dialog1, "TOP>TOP 1280.0,-135.0", "the dialog must follow the game to the right half")
explorer:ClearAllPoints()
explorer:SetPoint("CENTER")
Client.Tick()
Expect(explorer, "CENTER>CENTER 1280.0,0.0", "the explorer must follow the game to the right half")
rs:ResetPosition()
Profile(profile, 4700, 128, "a reset on the right half must save the right-half spot (3200 + 1600 - 100)")
Saves(3, "the right-half reset must be saved")
assert(next(Client.Errors()) == nil, "the bridge must raise no error")

-- 8c. Legacy seam: a spot saved at the seam comes back at login as BOTTOMLEFT 3100,128
-- (3100 + 200 / 2 = 6400 / 2); it is repaired once, to BOTTOMLEFT 3100 - 1600 = 1500,128.
rs, profile = World({ loaded = { RareScanner = true } })
button = Button()
Client.Load(PATH)
profile.scannerXPos, profile.scannerYPos = 3100, 128
Login(button, profile)
Client.combat = true
Client.Tick()
Expect(button, "BOTTOMLEFT>BOTTOMLEFT 3100.0,128.0", "the legacy repair must wait for combat to end")
Client.combat = false
Client.spanned = false
Client.Tick()
Expect(button, "BOTTOMLEFT>BOTTOMLEFT 3100.0,128.0", "the legacy repair must wait while not spanned")
Client.spanned = true
Client.Tick()
Expect(button, "BOTTOMLEFT>BOTTOMLEFT 1500.0,128.0", "the legacy seam spot must be repaired")
Profile(profile, 1500, 128, "the legacy repair must save the repaired spot")
Saves(1, "the legacy repair must save once")
Login(button, { scannerXPos = 3100, scannerYPos = 128 })
Client.Tick()
Expect(button, "BOTTOMLEFT>BOTTOMLEFT 3100.0,128.0", "the legacy repair must act only once")
Profile(profile, 1500, 128, "the profile must not change after the repair")
Saves(1, "the legacy repair must not save twice")

-- 8d. A button the player dragged to another BOTTOMLEFT spot is not touched
rs, profile = World({ loaded = { RareScanner = true } })
button = Button()
Client.Load(PATH)
profile.scannerXPos, profile.scannerYPos = 400, 300
Login(button, profile)
Client.Tick()
Expect(button, "BOTTOMLEFT>BOTTOMLEFT 400.0,300.0", "a dragged button must not be touched")
profile.scannerXPos, profile.scannerYPos = 2000, 128
Login(button, profile)
Client.Tick()
Expect(button, "BOTTOMLEFT>BOTTOMLEFT 2000.0,128.0", "a dragged button at the default height must not be touched")
Profile(profile, 2000, 128, "a dragged button's saved spot must not be touched")
Saves(0, "a dragged button must save nothing")

-- 8e. The reset hook is installed once AceAddon becomes available
Client.Reset({ loaded = { RareScanner = true } })
Client.LoadOffhand()
button = Button()
Client.Load(PATH)
Client.Tick()
rs = NewAddon()
DefineLibStub(rs)
Client.Tick()
rs:ResetPosition()
Profile(rs.db.profile, 1500, 128, "a reset must be saved once the hook could be installed later")
Saves(1, "the late hook must save once")

-- 9. Diagnostics and errors
local diag = Client.Diagnostics()
assert(type(diag) == "string" and diag:find("RareScannerAnchors=1/6 RareScannerSaves=1", 1, true),
    "diagnostics must show RareScannerAnchors and RareScannerSaves, got " .. tostring(diag))
assert(next(Client.Errors()) == nil, "the bridge must raise no error")

print("PASS: RareScanner bridge (inert load, button/explorer/dialog fit, reset hook, combat, legacy seam, dragged button, right half)")
