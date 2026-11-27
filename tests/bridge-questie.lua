-- Bridges/Questie/Bridge.lua: default anchors, LibPopupStack dialogs, the
-- QuestieTrace consent prompt, map icons, the tracker width cap and quest item
-- button tooltips, and inert load.
local Client = dofile("tests/support/bridge-client.lua")

local PATH = "Bridges/Questie/Bridge.lua"

local function Registered(id)
    for _, entry in ipairs(Client.addon.Bridges:List()) do
        if entry == id then return true end
    end
    return false
end

local function AssertPoint(frame, expected, message)
    local actual = Client.Point(frame)
    assert(actual == expected, message .. ": expected " .. expected .. ", got " .. actual)
end

local function Close(a, b)
    return type(a) == "number" and math.abs(a - b) < 1e-9
end

local function RunHooks(frame, script, ...)
    for _, hook in ipairs(frame.hooks[script] or {}) do hook(frame, ...) end
end

-- 1. Forbidden strings
Client.ForbiddenStrings(PATH)

-- 2. Inert when Questie is not loaded
Client.Reset()
Client.LoadOffhand()
Client.Load(PATH)
local frames, timers, tickers, slashes = Client.Counts()
assert(frames == 0 and timers == 0 and tickers == 0 and slashes == 0,
    "without Questie the bridge must create no frame, timer, ticker or slash command")
assert(not Registered("Questie"), "without Questie the bridge must not register")

-- 3. Inert on a non-Forever client
Client.Reset({ loaded = { Questie = true }, toc = 120107 })
Client.LoadOffhand()
Client.Load(PATH)
frames, timers, tickers, slashes = Client.Counts()
assert(frames == 0 and timers == 0 and tickers == 0 and slashes == 0,
    "on a non-Forever client the bridge must create no frame, timer, ticker or slash command")
assert(not Registered("Questie"), "on a non-Forever client the bridge must not register")

-- 4. Active: the mock Questie world (5120x1440, game on the left half)
Client.Reset({ loaded = { Questie = true } })
Client.LoadOffhand()

Questie = { db = { profile = { trackerWidthRatio = 0.2 } } }
GetScreenWidth = function() return UIParent:GetWidth() end
local modules = { QuestieTracker = {}, TrackerLayout = {} }
QuestieLoader = {}
function QuestieLoader:ImportModule(name)
    modules[name] = modules[name] or { private = {} }
    return modules[name]
end

local libs = {}
LibStub = setmetatable({}, { __call = function(_, name) return libs[name] end })

-- LibPopupStack-1.0: places each frame at its wanted spot unless the cached anchor already matches.
local popup = { frames = {}, anchors = {} }
function popup:Layout()
    for _, frame in ipairs(self.frames) do
        local fx, fy = frame.libX, frame.libY
        local a = self.anchors[frame]
        if not a or a.x ~= fx or a.y ~= fy then
            frame:ClearAllPoints()
            frame:SetPoint("TOP", UIParent, "BOTTOMLEFT", fx, fy)
            self.anchors[frame] = { x = fx, y = fy }
        end
    end
end
libs["LibPopupStack-1.0"] = popup

local Choose = Client.Frame("QuestieTutorialChooseObjectiveType", UIParent)
Choose:SetPoint("CENTER", 0, 50)

local seen, seenSelf = {}, nil
function modules.QuestieTracker:UpdateWidth(width)
    seen[#seen + 1] = Questie.db.profile.trackerWidthRatio
    seenSelf = self
    if width == "fail" then error("tracker boom") end
    if width == "nested" then modules.TrackerLayout.UpdateLineWidth("line", 5) end
    return width, nil, "last"
end

-- Questie's item button OnEnter: the side from half of GetScreenWidth().
local function QuestieOnEnter(self)
    local cx = self:GetCenter()
    if cx < (GetScreenWidth() or UIParent:GetWidth()) / 2 then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 8, -25)
    else
        GameTooltip:SetOwner(self, "ANCHOR_LEFT", -8, -25)
    end
end
local function ItemButton(index, center)
    local btn = Client.Frame("Questie_ItemButton" .. index, UIParent, { kind = "Button", protected = true })
    btn.left, btn.right = center - 10, center + 10
    btn.OnEnter = QuestieOnEnter
    return btn
end
local function Enter(btn)
    local script = btn:GetScript("OnEnter")
    if script then script(btn) end
    RunHooks(btn, "OnEnter")
end
local anchorCalls = 0
local SetAnchorType = GameTooltip.SetAnchorType
function GameTooltip:SetAnchorType(...)
    anchorCalls = anchorCalls + 1
    return SetAnchorType(self, ...)
end

local Button1 = ItemButton(1, 2000)
Button1:SetScript("OnEnter", Button1.OnEnter)   -- SetItem ran before the bridge loaded

local Icon1 = Client.Frame("QuestieFrame1", UIParent, { kind = "Button" })
local Icon2 = Client.Frame("QuestieFrame2", nil, { kind = "Button" })

local before = Client.Counts()
Client.Load(PATH)
assert(Registered("Questie"), "with Questie loaded on Forever the bridge must register")
assert(Client.Counts() == before + 1, "the active bridge must create exactly one frame (the icon holder)")
timers, tickers, slashes = select(2, Client.Counts())
assert(timers == 0 and tickers == 0 and slashes == 0, "the active bridge must create no timer, ticker or slash command")
local Holder = _G.OffhandQuestieIcons
assert(type(Holder) == "table" and Holder:GetParent() == UIParent, "the icon holder must be named and on UIParent")

Client.Tick()
AssertPoint(Choose, "CENTER>CENTER -1280.0,50.0", "the objective type window must move to the game centre")

-- 5. A frame created after the bridge loaded is picked up by the next tick
local Indicator = Client.Frame("QuestieProfilerIndicator", UIParent, { kind = "Button" })
Indicator:SetPoint("TOP", UIParent, "TOP", 0, -4)
Client.Tick()
AssertPoint(Indicator, "TOP>TOP -1280.0,-4.0", "the profiler indicator must move to the game's top centre")

-- 7. The game on the right half
Client.rect = { 2560, 0, 5120, 1440 }
Client.Tick()
AssertPoint(Choose, "CENTER>CENTER 1280.0,50.0", "the objective type window must follow to the right half")
AssertPoint(Indicator, "TOP>TOP 1280.0,-4.0", "the profiler indicator must follow to the right half")
Client.rect = { 0, 0, 2560, 1440 }
Client.Tick()
AssertPoint(Choose, "CENTER>CENTER -1280.0,50.0", "the objective type window must follow back to the left half")

-- 6. A dragged frame is left alone; unspanned puts moved frames back
Choose:ClearAllPoints()
Choose:SetPoint("CENTER", UIParent, "CENTER", -900, 300)
Client.Tick()
AssertPoint(Choose, "CENTER>CENTER -900.0,300.0", "a dragged window must be left alone")
Client.spanned = false
Client.Tick()
AssertPoint(Indicator, "TOP>TOP 0.0,-4.0", "unspanned, the indicator must go back to Questie's default")
AssertPoint(Choose, "CENTER>CENTER -900.0,300.0", "unspanned, a dragged window must stay where it was dragged")
Client.spanned = true
Client.Tick()
AssertPoint(Indicator, "TOP>TOP -1280.0,-4.0", "spanned again, the indicator must move again")

-- 8a. Dialogs (LibPopupStack-1.0)
local Dialog1 = Client.Frame("QuestieDialog1", UIParent)
Dialog1.libX, Dialog1.libY = 2560, 1305
popup.frames[1] = Dialog1
popup:Layout()
AssertPoint(Dialog1, "TOP>BOTTOMLEFT 1280.0,1305.0", "a seam dialog must move to the game's top centre")
assert(popup.anchors[Dialog1].x == 2560 and popup.anchors[Dialog1].y == 1305,
    "the library's anchors table must be left untouched")
popup:Layout()
AssertPoint(Dialog1, "TOP>BOTTOMLEFT 1280.0,1305.0", "a second layout must keep the dialog on the game monitor")
local Dialog2 = Client.Frame("QuestieDialog2", UIParent)
Dialog2.libX, Dialog2.libY = 1800, 1100
popup.frames[2] = Dialog2
popup:Layout()
AssertPoint(Dialog2, "TOP>BOTTOMLEFT 1800.0,1100.0", "a dialog placed beside a Blizzard popup must be left alone")
assert(#popup.frames == 2, "the library's frames list must be left untouched")

-- 8b. QuestieTrace consent prompt (created after the bridge loaded)
local Consent = Client.Frame("QuestieTraceConsentFrame", UIParent)
Consent:SetPoint("TOP", UIParent, "BOTTOMLEFT", 2560, 1305)
Consent.popupAnchorX, Consent.popupAnchorY = 2560, 1305
Client.Tick()
AssertPoint(Consent, "TOP>BOTTOMLEFT 1280.0,1305.0", "the consent prompt must move to the game's top centre")
assert(Consent.popupAnchorX == 2560 and Consent.popupAnchorY == 1305, "the consent prompt's cache must be left untouched")
Client.Tick()
assert(#Consent.hooks.OnShow == 1 and #Consent.hooks.OnUpdate == 1, "the consent prompt must be hooked once")
Consent:ClearAllPoints()
Consent:SetPoint("TOP", UIParent, "BOTTOMLEFT", 1800, 1100)
Consent.popupAnchorX, Consent.popupAnchorY = 1800, 1100
RunHooks(Consent, "OnUpdate", 0.1)
AssertPoint(Consent, "TOP>BOTTOMLEFT 1800.0,1100.0", "a consent prompt beside a Blizzard popup must be left alone")
Consent:ClearAllPoints()
Consent:SetPoint("TOP", UIParent, "BOTTOMLEFT", 2560, 1305)
Consent.popupAnchorX, Consent.popupAnchorY = 2560, 1305
Consent:Hide()
Consent:Show()
AssertPoint(Consent, "TOP>BOTTOMLEFT 1280.0,1305.0", "the consent prompt must move again when shown")

-- 8c. Map icons
assert(Icon1:GetParent() == Holder, "an icon on UIParent must move under the holder at load")
assert(Icon2:GetParent() == nil, "an icon not on UIParent must keep its parent")
Icon2:SetParent(UIParent)
assert(Icon2:GetParent() == Holder, "an icon sent back to UIParent must end under the holder")
local MapCanvas = Client.Frame("MapCanvas", UIParent)
Icon1:SetParent(MapCanvas)
assert(Icon1:GetParent() == MapCanvas, "an icon pinned to the map must keep the map as its parent")
local Icon3 = Client.Frame("QuestieFrame3", UIParent, { kind = "Button" })
Client.Tick()
assert(Icon3:GetParent() == Holder, "an icon created later must be adopted by the next tick")

-- 8d. Tracker width cap (UpdateLineWidth appears only after the bridge loaded)
assert(Client.Diagnostics():find("QuestieWidth=1/2", 1, true), "only UpdateWidth must be wrapped so far: " .. Client.Diagnostics())
function modules.TrackerLayout.UpdateLineWidth(line, margin)
    seen[#seen + 1] = Questie.db.profile.trackerWidthRatio
    return line, margin
end
Client.Tick()
assert(Client.Diagnostics():find("QuestieWidth=2/2", 1, true), "both width functions must be wrapped: " .. Client.Diagnostics())
local wrappedWidth = modules.QuestieTracker.UpdateWidth
Client.Tick("layout")
assert(modules.QuestieTracker.UpdateWidth == wrappedWidth, "a width function must be wrapped only once")

seen = {}
local count = select("#", modules.QuestieTracker:UpdateWidth(300))
local a, b, c = modules.QuestieTracker:UpdateWidth(300)
assert(count == 3 and a == 300 and b == nil and c == "last", "return values, including a nil in the middle, must pass through")
assert(seenSelf == modules.QuestieTracker, "the method's self must pass through")
assert(Close(seen[1], 0.1) and Close(seen[2], 0.1), "the original must see the ratio scaled to the game share")
assert(Questie.db.profile.trackerWidthRatio == 0.2, "the profile must hold the saved ratio after the call")

seen = {}
local ok, message = pcall(modules.QuestieTracker.UpdateWidth, modules.QuestieTracker, "fail")
assert(not ok and tostring(message):find("tracker boom", 1, true), "an error in the original must propagate")
assert(Questie.db.profile.trackerWidthRatio == 0.2, "the profile must hold the saved ratio after an error")
assert(Close(seen[1], 0.1), "the failing call must have seen the scaled ratio")
seen = {}
modules.QuestieTracker:UpdateWidth(10)
assert(Close(seen[1], 0.1), "after an error the next call must scale again")

seen = {}
modules.QuestieTracker:UpdateWidth("nested")
assert(#seen == 2 and Close(seen[1], 0.1) and Close(seen[2], 0.1), "nested wrapped calls must scale once")
assert(Questie.db.profile.trackerWidthRatio == 0.2, "the profile must hold the saved ratio after a nested call")

seen = {}
local line, margin = modules.TrackerLayout.UpdateLineWidth("row", 12)
assert(line == "row" and margin == 12 and Close(seen[1], 0.1), "UpdateLineWidth must scale and pass values through")

Client.spanned = false
seen = {}
modules.QuestieTracker:UpdateWidth(10)
assert(seen[1] == 0.2, "unspanned calls must see the saved ratio")
Client.spanned = true

-- 8e. Quest item button tooltips
local Button2 = ItemButton(2, 500)
local Button3 = ItemButton(3, 4000)
Client.Tick()
Button2:SetScript("OnEnter", Button2.OnEnter)   -- SetItem runs after the bridge hooked the field
Button3:SetScript("OnEnter", Button3.OnEnter)
assert(#Button1.hooks.OnEnter == 1 and #Button2.hooks.OnEnter == 1, "each button's script must be hooked once")

anchorCalls = 0
Enter(Button1)
assert(GameTooltip.owner == Button1 and GameTooltip.anchor == "ANCHOR_LEFT" and GameTooltip.offsetX == -8
    and GameTooltip.offsetY == -25, "a button right of the game centre must get ANCHOR_LEFT: " .. tostring(GameTooltip.anchor))
assert(anchorCalls >= 1, "the corrected side must go through SetAnchorType")

anchorCalls = 0
Enter(Button2)
assert(GameTooltip.anchor == "ANCHOR_RIGHT" and GameTooltip.offsetX == 8 and anchorCalls == 0,
    "a button left of the game centre must be untouched")

Enter(Button3)
assert(GameTooltip.anchor == "ANCHOR_LEFT" and anchorCalls == 0, "a button on the other monitor must be untouched")

local Other = Client.Frame("OtherOwner", UIParent)
GameTooltip:SetOwner(Other, "ANCHOR_RIGHT", 8, -25)
RunHooks(Button1, "OnEnter")
assert(GameTooltip.owner == Other and GameTooltip.anchor == "ANCHOR_RIGHT" and anchorCalls == 0,
    "another tooltip owner must be untouched")

-- Buttons are hooked only out of combat
Client.combat = true
local Button4 = ItemButton(4, 2000)
Client.Tick()
assert(Button4.hooks.OnEnter == nil and Button4.OnEnter == QuestieOnEnter, "a button must not be hooked in combat")
Client.combat = false
Client.Tick()
assert(#Button4.hooks.OnEnter == 1 and Button4.OnEnter ~= QuestieOnEnter, "the button must be hooked after combat")
Client.Tick()
assert(#Button4.hooks.OnEnter == 1, "a button must be hooked only once")
Button4:SetScript("OnEnter", Button4.OnEnter)
Enter(Button4)
assert(GameTooltip.owner == Button4 and GameTooltip.anchor == "ANCHOR_LEFT", "the hooked field must correct the side")

-- 9. Diagnostics and errors
local diag = Client.Diagnostics()
-- The objective-type window was dragged above, so only the indicator still counts as moved.
assert(diag:find("QuestieAnchors=1/2 QuestieIcons=3 QuestieWidth=2/2 QuestieTooltips=3", 1, true),
    "diagnostics must show the bridge's tokens: " .. diag)
assert(next(Client.Errors()) == nil, "the bridge must record no error")

print("PASS: Questie bridge anchors, dialogs, consent prompt, icons, tracker width and item tooltips")
