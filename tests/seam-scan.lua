-- Core/SeamScan.lua and UI/SeamScanReview.lua: the seam scan records third-party addon frames that
-- are not wholly on the game display, classifies them, keeps a bounded saved log, never writes to a
-- scanned frame, and Keep on game display places a frame through the learned windows service.
local addon = {isForever = true, db = {enabled = true}}
local combat, clock = false, 1000
local printed = {}
local roots, controls, tickers = {}, {}, {}
local parent = {}
function parent:GetEffectiveScale() return 1 end
function parent:GetNumChildren()
    if self.count then return self.count end
    return #roots
end
function parent:GetChildren()
    if self.throw then error("stack overflow") end
    return unpack(roots)
end
function parent:GetSourceLocation() return "Interface/FrameXML/UIParent.xml:1" end
function parent:GetWidth() return 1000 end
function parent:GetHeight() return 600 end
UIParent = parent
UIPanelWindows = {}
DONE, NONE = "Done", "None"
local loaded = {ExampleAddon = true, OtherAddon = true, BridgedAddon = true}
C_AddOns = {IsAddOnLoaded = function(name) return loaded[name] == true end}
InCombatLockdown = function() return combat end
time = function() return clock end
C_Timer = {NewTicker = function(interval, fn)
    local ticker = {interval = interval, fn = fn}
    tickers[#tickers + 1] = ticker
    return ticker
end}

local function Noop() end
CreateFrame = function(kind, _, owner, template)
    local control = {kind = kind, owner = owner, template = template, scripts = {}, events = {}, shown = true}
    function control:CreateFontString()
        local font = {}
        function font:SetText(value) self.text = value end
        return setmetatable(font, {__index = function() return Noop end})
    end
    function control:SetScript(key, handler) self.scripts[key] = handler end
    function control:RegisterEvent(event) self.events[event] = true end
    function control:UnregisterEvent(event) self.events[event] = nil end
    function control:SetText(label) self.label = label end
    function control:SetEnabled(flag) self.enabled = flag end
    function control:Show() self.shown = true end
    function control:Hide() self.shown = false end
    function control:IsShown() return self.shown end
    controls[#controls + 1] = control
    return setmetatable(control, {__index = function() return Noop end})
end

local metrics = {
    isSpanned = true, gameLeft = 500, gameBottom = 0, gameRight = 1000, gameTop = 600,
    workspaceLeft = 0, workspaceBottom = 0, workspaceWidth = 500, workspaceHeight = 600,
}
addon.Viewport = {GetMetrics = function() return metrics end}
addon.UIControls = {StyleSurface = Noop}
function addon:Print(text, ...) printed[#printed + 1] = string.format(text, ...) end
for _, file in ipairs({"Locales/enUS.lua", "Core/WorkspaceRegions.lua", "Core/HUDCompatibility.lua",
    "Core/CanvasCompatibility.lua", "Core/AddonWindowCatalog.lua", "Core/Bridges.lua",
    "Core/CanvasAddonEscape.lua", "Core/LearnedAddonWindows.lua", "Core/SeamScan.lua",
    "UI/SeamScanReview.lua"}) do
    assert(loadfile(file))("Offhand", addon)
end
local L = addon.L
local windows, scan, review = addon.LearnedAddonWindows, addon.SeamScan, addon.SeamScanReview
local function LoginFrame()
    for index = #controls, 1, -1 do
        if controls[index].events.PLAYER_LOGIN then return controls[index] end
    end
end
assert(LoginFrame(), "the scan must wait for PLAYER_LOGIN before starting its ticker")

-- Mock frames count every write a scan could make.
local WRITES = {"ClearAllPoints", "SetPoint", "SetParent", "Hide", "HookScript", "SetScript"}
local function Frame(name, options)
    options = options or {}
    local frame = {shown = options.shown ~= false, writes = 0, children = {}, movable = options.movable ~= false,
        protected = options.protected, userPlaced = options.userPlaced, scale = 1,
        source = options.source or "Interface\\AddOns\\ExampleAddon\\Windows.lua:12",
        left = options.left or 400, top = options.top or 500,
        width = options.width or 300, height = options.height or 300}
    frame.points = options.points or {{"TOPLEFT", parent, "BOTTOMLEFT", frame.left, frame.top}}
    function frame:GetName() return name end
    function frame:GetParent() return parent end
    function frame:GetObjectType() return "Frame" end
    function frame:IsMovable() return self.movable end
    function frame:GetSourceLocation() return self.source end
    function frame:IsProtected() return self.protected == true end
    function frame:IsForbidden() return false end
    function frame:IsVisible() return self.shown end
    function frame:IsShown() return self.shown end
    function frame:GetEffectiveAlpha()
        if self.failAlpha then error("secret alpha") end
        return 1
    end
    function frame:GetFrameStrata() return "MEDIUM" end
    function frame:GetHighestFrameLevel() return 12 end
    function frame:IsUserPlaced() return self.userPlaced == true end
    function frame:GetChildren() return unpack(self.children) end
    function frame:GetNumChildren() return #self.children end
    function frame:GetNumPoints() return #self.points end
    function frame:GetPoint(i) return unpack(self.points[i]) end
    function frame:GetLeft() return self.left end
    function frame:GetTop() return self.top end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:GetEffectiveScale() return self.scale end
    for _, method in ipairs(WRITES) do
        frame[method] = function(self, ...)
            self.writes = self.writes + 1
            if method == "ClearAllPoints" then self.points = {} end
            if method == "SetPoint" then
                local point, relative, relativePoint, x, y = ...
                self.points = {{point, relative, relativePoint, x, y}}
                if point == "TOPLEFT" and relativePoint == "BOTTOMLEFT" then self.left, self.top = x, y end
            end
        end
    end
    if name then _G[name] = frame end
    roots[#roots + 1] = frame
    return frame
end

local function Writes()
    local total = 0
    for _, frame in ipairs(roots) do total = total + frame.writes end
    return total
end

local function Log() return addon.db.seamScanLog or {} end
local function Count()
    local count = 0
    for _ in pairs(Log()) do count = count + 1 end
    return count
end
local function Entry(key)
    for _, entry in ipairs(scan:GetEntries()) do
        if entry.key == key then return entry end
    end
end
local function Printed(text)
    for _, line in ipairs(printed) do
        if line == text then return true end
    end
    return false
end
local function Retire(...)
    for _, frame in ipairs({...}) do frame.shown = false end
end

-- 1-3. Inside the game rectangle nothing is recorded; across the seam and on the other display are.
local inside = Frame("InsideWindow", {left = 600, top = 500, width = 200, height = 200})
local seam = Frame("SeamWindow")
local away = Frame("AwayWindow", {left = 100, top = 500, width = 200, height = 200})
assert(scan:Pass() == 2, "a pass touches the two frames off the game display")
assert(not Log().InsideWindow, "a frame wholly inside the game rectangle is not recorded")
local entry = assert(Entry("SeamWindow"), "a frame across the seam is recorded")
assert(entry.class == "seam" and entry.anchor == "screen" and entry.state == "learnable" and entry.owner == "ExampleAddon"
    and entry.file == "windows.lua" and entry.name == "SeamWindow" and entry.visible == true and entry.sessions == 1,
    "a movable named seam frame with one UIParent anchor is learnable")
assert(Entry("AwayWindow").class == "away", "a frame wholly on the other display is away")

-- 4. Exclusions.
local excluded = {
    Frame("OwnWindow", {source = "Interface/AddOns/Offhand/UI/Window.lua:3"}),
    Frame("NativeWindow", {source = "Interface/AddOns/Blizzard_Example/Window.lua:3"}),
    Frame("PinWindow", {width = 16, height = 16, left = 495}),
    Frame("HolderWindow", {left = 0, width = 520}),
    Frame("HiddenWindow", {shown = false}),
    Frame("MissingWindow", {source = "Interface/AddOns/MissingAddon/Window.lua:3"}),
    Frame("SourcelessWindow", {source = "Interface/FrameXML/Window.lua:3"}),
}
scan:Pass()
for _, frame in ipairs(excluded) do
    assert(not Log()[frame:GetName()], frame:GetName() .. " must not be recorded")
end

-- 16 (first half). The passes so far wrote nothing to any scanned frame.
assert(Writes() == 0, "the scan must never write to a scanned frame")

-- 5-7. States, the bridge field and the unnamed key.
addon.API.RegisterAddonData("BridgedAddon", {placedFrames = {"BridgedWindow", "^BridgedPin%d+$"}})
local bridgedSource = "Interface/AddOns/BridgedAddon/Main.lua:5"
local bridged = Frame("BridgedWindow", {source = bridgedSource})
local pin = Frame("BridgedPin3", {source = bridgedSource})
local gap = Frame("BridgedOptions", {source = bridgedSource, movable = false})
addon.db.savedWorkspacePositions = {OwnedWindow = {x = 1, y = 1}}
local owned = Frame("OwnedWindow")
local userPlaced = Frame("UserPlacedWindow", {userPlaced = true, left = 50})
local userSeam = Frame("UserSeamWindow", {userPlaced = true})
local protected = Frame("ProtectedWindow", {protected = true})
local unnamed = Frame(nil, {source = "Interface/AddOns/OtherAddon/Popup.lua:77"})
local holder = Frame("HolderFrame", {left = 600, top = 100, width = 30, height = 30})
local anchored = Frame("AnchoredWindow", {points = {{"TOPLEFT", holder, "BOTTOMLEFT", 0, 0}}})
local fixed = Frame("FixedWindow", {movable = false})
scan:Pass()
assert(Entry("BridgedWindow").state == "bridged" and Entry("BridgedPin3").state == "bridged",
    "exact and pattern placed frames are bridged")
assert(Entry("BridgedWindow").bridge == "BridgedAddon", "an addon with a registered bridge is named")
assert(Entry("OwnedWindow").state == "owned", "a saved workspace position leaves the frame owned")
assert(Entry("UserPlacedWindow").class == "away" and Entry("UserPlacedWindow").state == "owned",
    "a dragged frame wholly on the other display is left to the player")
assert(Entry("UserSeamWindow").class == "seam" and Entry("UserSeamWindow").state == "learnable",
    "a dragged frame across the seam is still offered")
assert(Entry("ProtectedWindow").state == "manual" and Entry("ProtectedWindow").reason == "protected")
local unnamedKey = "OtherAddon/popup.lua:77"
assert(Entry(unnamedKey) and Entry(unnamedKey).state == "manual" and Entry(unnamedKey).reason == "unnamed"
    and Entry(unnamedKey).name == nil, "an unnamed frame is keyed by owner/file:line")
assert(Entry("AnchoredWindow").anchor == "frame" and Entry("AnchoredWindow").reason == "anchor")
assert(Entry("FixedWindow").anchor == "screen" and Entry("FixedWindow").reason == "fixed")
assert(Entry("BridgedOptions").state == "manual" and Entry("BridgedOptions").bridge == "BridgedAddon")
local summary = scan:GetSummary()
assert(summary.gaps == 1 and summary.bridged == 2 and summary.owned == 2,
    "a manual window of a bridged addon is a bridge gap")
assert(Writes() == 0, "classifying never writes to a scanned frame")
Retire(bridged, pin, gap, owned, userPlaced, userSeam, protected, unnamed, anchored, fixed)

-- 11. A throwing frame counts a fault and the pass goes on.
local broken = Frame("BrokenWindow")
broken.failAlpha = true
local after = Frame("AfterBrokenWindow")
local faults = scan:GetDiagnostics():match("faults=(%d+)")
scan:Pass()
assert(tonumber(scan:GetDiagnostics():match("faults=(%d+)")) == tonumber(faults) + 1, "a throwing frame is one fault")
assert(Entry("AfterBrokenWindow"), "a fault does not stop the pass")
Retire(broken, after)

-- 10. Overflow records nothing; a later good pass clears it.
local late = Frame("LateWindow")
local before = Count()
parent.count = 5000
assert(scan:Pass() == 0 and scan:GetDiagnostics():find("children=overflow", 1, true) and Count() == before,
    "too many UIParent children is an overflow")
parent.count = nil
parent.throw = true
assert(scan:Pass() == 0 and scan:GetDiagnostics():find("children=overflow", 1, true) and Count() == before,
    "a throwing GetChildren is an overflow")
parent.throw = nil
scan:Pass()
assert(scan:GetDiagnostics():find("children=" .. #roots .. " |", 1, true) and Log().LateWindow,
    "a good pass clears the overflow")
Retire(late)

-- 12. CanScan false: Pass returns nil and records nothing.
local pending = Frame("PendingWindow")
local function Blocked(label, set, reset)
    set()
    assert(scan:CanScan() == false and scan:Pass() == nil and not Log().PendingWindow, label)
    reset()
end
Blocked("not Forever", function() addon.isForever = false end, function() addon.isForever = true end)
Blocked("disabled", function() addon.db.enabled = false end, function() addon.db.enabled = true end)
Blocked("scan off", function() addon.db.seamScan = false end, function() addon.db.seamScan = nil end)
Blocked("not spanned", function() metrics.isSpanned = false end, function() metrics.isSpanned = true end)
Blocked("combat", function() combat = true end, function() combat = false end)
Blocked("geometry transition", function() addon._displayGeometryTransitionActive = true end,
    function() addon._displayGeometryTransitionActive = nil end)
Retire(pending)

-- 14. Keep on game display clamps to the nearest position inside the game rectangle.
assert(scan:KeepOnMainhand("SeamWindow") == true, "a learnable visible frame can be kept on the game display")
local point = seam.points[1]
assert(#seam.points == 1 and point[1] == "TOPLEFT" and point[2] == parent and point[3] == "BOTTOMLEFT"
    and point[4] == 500 and point[5] == 500, "the frame moves only as far as it takes to lie inside")
local record = addon.db.learnedAddonWindows.SeamWindow
assert(record.region == "MAINHAND" and record.x == 0 and windows:GetRecordRegion("SeamWindow") == "MAINHAND")
assert(Entry("SeamWindow").state == "learned", "a kept frame reads learned")
seam.shown = false
windows:Refresh()
seam.left, seam.top, seam.points = 400, 500, {{"TOPLEFT", parent, "BOTTOMLEFT", 400, 500}}
seam.shown = true
windows:Refresh()
assert(seam.left == 500 and seam.top == 500, "a reopened frame its addon re-anchored is put back")
local huge = Frame("HugeWindow", {height = 650})
scan:Pass()
assert(Entry("HugeWindow").state == "learnable" and scan:KeepOnMainhand("HugeWindow") == false
    and addon.db.learnedAddonWindows.HugeWindow == nil, "a frame larger than the game rectangle fails")
assert(scan:KeepOnMainhand("NoSuchKey") == false)
Retire(huge)

-- 5 (learned). The record decides learned; forgetting reads learnable while visible, else closed.
assert(scan:Forget("SeamWindow") == true and not windows:GetRecordRegion("SeamWindow"))
assert(Entry("SeamWindow").state == "learnable", "a visible describable frame reads learnable after Forget")
assert(scan:KeepOnMainhand("SeamWindow") == true)
seam.shown = false
windows:Refresh()
windows:ForgetName("SeamWindow")
assert(Entry("SeamWindow").state == "manual" and Entry("SeamWindow").reason == "closed")
seam.shown = true

-- 13. Exact diagnostics and Describe for a known log.
assert(loadfile("Core/SeamScan.lua"))("Offhand", addon)
scan = addon.SeamScan
local savedLog = addon.db.seamScanLog
addon.db.seamScanLog = {
    KnownSeam = {owner = "ExampleAddon", file = "a.lua", name = "KnownSeam", class = "seam", anchor = "screen",
        state = "manual", reason = "fixed", bridge = "ExampleAddon", sessions = 3, first = 1, last = 2},
    ["OtherAddon/b.lua:42"] = {owner = "OtherAddon", file = "b.lua", class = "away", anchor = "frame",
        state = "bridged", sessions = 1, first = 1, last = 2},
    Broken = {owner = "ExampleAddon"},
}
assert(scan:GetDiagnostics() == "state=on | passes=0 | children=0 | faults=0 | seen=2 | seam=1 | away=1"
    .. " | bridged=1 | owned=0 | learned=0 | learnable=0 | manual=1 | bridgeGaps=1", scan:GetDiagnostics())
local entries = scan:GetEntries()
assert(scan:Describe(entries[1]) == "ExampleAddon: KnownSeam | seam | anchor=screen | manual:fixed | bridge=ExampleAddon | sessions=3",
    scan:Describe(entries[1]))
assert(scan:Describe(entries[2]) == "OtherAddon: b.lua:42 | away | anchor=frame | bridged | sessions=1",
    scan:Describe(entries[2]))
addon.db.seamScan = false
assert(scan:GetDiagnostics():sub(1, 10) == "state=off ")
addon.db.seamScan = nil
metrics.isSpanned = false
assert(scan:GetDiagnostics():sub(1, 11) == "state=idle ")
metrics.isSpanned = true
scan:Pass()
assert(addon.db.seamScanLog.Broken == nil, "a malformed entry is dropped on the first pass of a session")
addon.db.seamScanLog = savedLog
addon.db.seamScanLog.Broken = {owner = 7}

-- 8. sessions rises once per session, not once per pass.
assert(loadfile("Core/SeamScan.lua"))("Offhand", addon)
scan = addon.SeamScan
local sessions = Log().AwayWindow.sessions
scan:Pass()
assert(Log().AwayWindow.sessions == sessions + 1, "the first sighting of a new session counts it")
scan:Pass()
assert(Log().AwayWindow.sessions == sessions + 1, "later passes of the same session do not")
assert(Log().Broken == nil, "the replaced log is validated too")
assert(loadfile("Core/SeamScan.lua"))("Offhand", addon)
scan = addon.SeamScan
scan:Pass()
assert(Log().AwayWindow.sessions == sessions + 2, "a reload is a new session")

-- 17. The notice prints once per session, only for a new learnable or manual entry.
printed = {}
assert(loadfile("Core/SeamScan.lua"))("Offhand", addon)
scan = addon.SeamScan
scan:Pass()
assert(#printed == 0, "refreshing known entries prints nothing")
local bridgedLater = Frame("BridgedPin9", {source = bridgedSource})
scan:Pass()
assert(#printed == 0, "a new handled entry prints nothing")
local manualLater = Frame("ManualLaterWindow", {movable = false})
scan:Pass()
local summaryNow = scan:GetSummary()
assert(#printed == 1 and printed[1] == string.format(L.SEAM_SCAN_NOTICE, summaryNow.learnable + summaryNow.manual),
    "a new manual entry prints the notice with the count of entries that need attention")
local learnableLater = Frame("LearnableLaterWindow")
scan:Pass()
assert(#printed == 1, "the notice prints once per session")
Retire(bridgedLater, manualLater, learnableLater)

-- 9. The 200 entry cap: the oldest entry not seen this session goes; when every entry was seen, a
-- new key is not recorded.
assert(loadfile("Core/SeamScan.lua"))("Offhand", addon)
scan = addon.SeamScan
scan:Clear()
for _, frame in ipairs(roots) do frame.shown = false end
local synthetic = {}
for index = 1, 200 do
    synthetic["Synthetic" .. index] = {owner = "ExampleAddon", file = "s.lua", name = "Synthetic" .. index,
        class = "away", anchor = "screen", state = "manual", reason = "fixed", sessions = 1, first = 1, last = index}
end
addon.db.seamScanLog = synthetic
seam.shown = true
scan:Pass()
assert(Count() == 200 and Log().SeamWindow and Log().Synthetic1 == nil and Log().Synthetic2,
    "a new key replaces the entry with the smallest last not seen this session")
scan:Clear()
seam.shown = false
local cap = {}
for index = 1, 200 do cap[index] = Frame("CapWindow" .. index) end
assert(scan:Pass() == 200 and Count() == 200)
local extra = Frame("CapExtraWindow")
assert(scan:Pass() == 200 and not Log().CapExtraWindow and Count() == 200,
    "with every entry seen this session the new key is not recorded")

-- 18. Scan:Run.
printed = {}
scan:Run("")
summary = scan:GetSummary()
assert(printed[1] == string.format(L.SEAM_SCAN_SUMMARY, summary.seen, summary.learnable + summary.manual,
    summary.bridged + summary.owned + summary.learned), "the list starts with the summary")
assert(#printed == 22 and printed[2] == scan:Describe(scan:GetEntries()[1])
    and printed[22] == string.format(L.SEAM_SCAN_MORE, 180), "twenty lines, then the rest counted")
printed = {}
scan:Run("list")
assert(#printed == 22, "list is the default")
printed = {}
metrics.isSpanned = false
scan:Run("now")
assert(printed[1] == L.SEAM_SCAN_UNAVAILABLE and #printed == 23, "now explains when the scan cannot run, then lists")
metrics.isSpanned = true
printed = {}
scan:Run("off")
assert(addon.db.seamScan == false and printed[1] == L.SEAM_SCAN_OFF)
scan:Run("on")
assert(addon.db.seamScan == nil and printed[2] == L.SEAM_SCAN_ON)
scan:Run("bogus")
assert(printed[3] == L.SEAM_SCAN_HELP)
scan:Run("clear")
assert(printed[4] == L.SEAM_SCAN_CLEARED and Count() == 0)
scan:Run("")
assert(printed[5] == L.SEAM_SCAN_EMPTY, "an empty log says so")
for _, frame in ipairs(cap) do frame.shown = false end
extra.shown = false

-- The ticker starts once at PLAYER_LOGIN and runs a pass through the maintenance probe.
local ran
addon.PerformanceMaintenanceProbe = {Run = function(_, label, fn, receiver)
    ran = label
    return fn(receiver)
end}
local loginFrame = LoginFrame()
loginFrame.scripts.OnEvent(loginFrame, "PLAYER_LOGIN")
assert(not loginFrame.events.PLAYER_LOGIN, "the login event is handled once")
local ticker = assert(tickers[#tickers], "PLAYER_LOGIN starts the ticker")
assert(ticker.interval == 5)
seam.shown = true
ticker.fn()
assert(ran == "seam-scan" and Log().SeamWindow, "the tick runs a pass through the maintenance probe")
addon.PerformanceMaintenanceProbe = nil

-- 19. The review window lists the entries and its Keep button calls through.
scan:Run("review")
assert(review:IsOpen(), "review opens the window")
local keep
for _, control in ipairs(controls) do
    if control.shown and control.action == "keep" and control.entry and control.entry.key == "SeamWindow" then
        keep = control
    end
end
assert(keep and keep.label == L.SEAM_SCAN_BTN_KEEP, "a learnable visible row offers Keep on game display")
keep.scripts.OnClick(keep)
assert(windows:GetRecordRegion("SeamWindow") == "MAINHAND" and Entry("SeamWindow").state == "learned")
assert(keep.action == "forget" and keep.label == L.LEARN_WINDOW_BTN_FORGET and keep.shown,
    "the row then reads learned and offers Forget")
scan:Run("review")
assert(not review:IsOpen(), "review toggles the window closed")

-- The Addon windows card shows the scan summary and a review button below the learn button.
local cardTexts, cardButtons = {}, {}
local function MockWidget(_, _, _, template)
    local widget = {}
    function widget:CreateFontString()
        local font = {}
        function font:SetText(value) self.text = value; cardTexts[#cardTexts + 1] = value end
        return setmetatable(font, {__index = function() return Noop end})
    end
    function widget:CreateTexture() return setmetatable({}, {__index = function() return Noop end}) end
    function widget:GetFontString() return self:CreateFontString() end
    function widget:SetText(value) self.label = value end
    function widget:SetScript(key, handler) self[key] = handler end
    function widget:SetHeight(value) self.height = value end
    if template == "UIPanelButtonTemplate" then cardButtons[#cardButtons + 1] = widget end
    return setmetatable(widget, {__index = function() return Noop end})
end
local function BuildCard(withScan)
    local workspace = {isForever = true, db = addon.db, L = L, LearnedAddonWindows = windows,
        AddonWindowSelection = {Toggle = Noop}, SeamScan = withScan and scan or nil,
        SeamScanReview = withScan and review or nil,
        WorkspaceProfiles = {List = function() return {{id = "default", name = "Default"}}, "default" end},
        WorkspaceRouting = {GetGroups = function() return {} end},
        UIControls = {CreateFrame = MockWidget, FitCompactParagraph = function() return 28 end}}
    assert(loadfile("UI/WorkspaceOptions.lua"))("Offhand", workspace)
    local card = workspace.WorkspaceOptions.Build({panels = MockWidget(), appearance = MockWidget(),
        profiles = MockWidget()}, function() return MockWidget() end, {}).learning
    for _, refresh in ipairs(workspace.WorkspaceOptions.refreshers or {}) do pcall(refresh) end
    return assert(card, "the Addon windows card is built")
end
local plainHeight = BuildCard(false).height
cardTexts, cardButtons = {}, {}
local card = BuildCard(true)
summary = scan:GetSummary()
local cardSummary = string.format(L.SEAM_SCAN_SUMMARY, summary.seen, summary.learnable + summary.manual,
    summary.bridged + summary.owned + summary.learned)
local sawSummary = false
for _, text in ipairs(cardTexts) do
    if text == cardSummary then sawSummary = true end
end
assert(sawSummary and type(plainHeight) == "number" and card.height > plainHeight,
    "the card refresher shows the scan summary and grows the card")
local reviewButton
for _, button in ipairs(cardButtons) do
    if button.label == L.SEAM_SCAN_BTN_REVIEW then reviewButton = button end
end
assert(reviewButton, "the card offers Review seen windows")
reviewButton.OnClick(reviewButton)
assert(review:IsOpen(), "the card button opens the review window")
review:Close()

-- 15. Remember without a target is unchanged: tests/learned-addon-windows.lua covers it untouched.
print("PASS: seam scan records, classifies, bounds its log, never writes to scanned frames and keeps windows on the game display")
