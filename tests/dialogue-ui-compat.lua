-- Dialogue UI confinement must translate only its UIParent-relative anchors.
-- The handling is the built-in bridge Bridges/DialogueUI/Bridge.lua, loaded
-- through the real Core/MainhandGeometry.lua and Core/Bridges.lua.
local function NewFrame(name)
    local frame = {name = name, points = {}, children = {}, scale = 1, width = 100, height = 100, scripts = {}}
    function frame:GetName() return self.name end
    function frame:GetNumPoints() return #self.points end
    function frame:GetPoint(index) return unpack(self.points[index]) end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = {...} end
    function frame:GetChildren() return unpack(self.children) end
    function frame:GetScale() return self.scale end
    function frame:SetScale(value) self.scale = value end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:SetHeight(value) self.height = value end
    function frame:SetWidth(value) self.width = value end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:HookScript(script, callback) self.scripts[script] = callback end
    function frame:IsForbidden() return self.forbidden == true end
    function frame:IsProtected() return self.protected == true end
    function frame:IsVisible() return self.visible == true end
    return frame
end

local function ReadSource(path)
    local handle = assert(io.open(path, "rb"), "missing " .. path)
    local text = handle:read("*a")
    handle:close()
    return text
end

UIParent = NewFrame("UIParent")
UIParent.width = 1366
UIParent.height = 768
WorldFrame = NewFrame("WorldFrame")
WorldFrame.height = 432
DialogueUI_DB = {FrameSize = 3}
local metrics = {isSpanned = true, physicalHeight = 2560, gamePixelHeight = 1440,
    gameLeft = 0, gameBottom = 0, gameRight = 1366, gameTop = 432}
local addon = {
    db = {enabled = true},
    Viewport = {GetMetrics = function() return metrics end},
    PopupBounds = {Queue = function(self, frame)
        self.queued = frame
        self.queueCount = (self.queueCount or 0) + 1
    end},
}

local loader
local createdFrames = 0
CreateFrame = function(_, name)
    createdFrames = createdFrames + 1
    if name == "OffhandMainhandFrame" then
        local anchor = NewFrame(name)
        function anchor:SetFrameStrata() end
        function anchor:SetFrameLevel() end
        function anchor:SetAllPoints() end
        return anchor
    end
    loader = {
        RegisterEvent = function() end,
        SetScript = function(self, _, callback) self.callback = callback end,
    }
    return loader
end
local loaded = false
C_AddOns = {IsAddOnLoaded = function(name) return loaded and name == "DialogueUI" end}

local hookCount = 0
hooksecurefunc = function(target, method, callback)
    hookCount = hookCount + 1
    local original = target[method]
    target[method] = function(self, ...)
        local results = {original(self, ...)}
        callback(self, ...)
        return unpack(results)
    end
end

assert(loadfile("Core/MainhandGeometry.lua"))("Offhand", addon)
assert(loadfile("Core/Bridges.lua"))("Offhand", addon)

-- Without the bridge contract the file does nothing.
assert(loadfile("Bridges/DialogueUI/Bridge.lua"))("Offhand", {})

-- Dialogue UI absent at load: the bridge registers and only waits for it, as
-- the core module did (its loader always existed, so a vendor that loads
-- after Offhand is still attached). It hooks nothing until then.
do
    local early = {}
    assert(loadfile("Core/Bridges.lua"))("Offhand", early)
    early.API.GetMainhandFrame = function() end
    assert(loadfile("Bridges/DialogueUI/Bridge.lua"))("Offhand", early)
    assert(early.Bridges:Get("DialogueUI") ~= nil and createdFrames == 1 and loader ~= nil and hookCount == 0,
        "without Dialogue UI the bridge must only register and wait for it to load")
    assert(early.Bridges:GetDiagnostics() == nil, "a waiting bridge adds nothing to compact diagnostics")
    loader = nil
end

loaded = true
DUIQuestFrame = NewFrame("DUIQuestFrame")
DUIQuestFrame.visible = true
DUIQuestFrame.frameWidth = 504
DUIQuestFrame.frameHeight = 593
DUIQuestFrame:SetSize(504, 593)
function DUIQuestFrame:UpdateFrameSize()
    self.updateFrameSizeCalls = (self.updateFrameSizeCalls or 0) + 1
    self.frameWidth = 257
    self.frameHeight = 303
    self.halfFrameWidth = 100
    self.quarterFrameWidth = 50
    self:SetSize(self.frameWidth, self.frameHeight)
end
function DUIQuestFrame:OnSettingsChanged()
    self.settingsChangedCalls = (self.settingsChangedCalls or 0) + 1
end
local banner = NewFrame()
local internal = NewFrame()
local protected = NewFrame()
protected.protected = true
DUIQuestFrame.children = {banner, internal, protected}
DUIQuestFrame:SetPoint("CENTER", UIParent, "CENTER", 192, 0)
banner:SetPoint("TOP", UIParent, "TOP", 0, -76)
internal:SetPoint("TOPLEFT", DUIQuestFrame, "TOPLEFT", 12, -12)
protected:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

DUIBookFrame = NewFrame("DUIBookFrame")
DUIBookFrame:SetPoint("LEFT", UIParent, "CENTER", -336, 0)
DUIDialogSettings = NewFrame("DUIDialogSettings")
DUIDialogSettings:SetPoint("CENTER", UIParent, "CENTER", -240, 0)

local dialogueTooltip = NewFrame()
dialogueTooltip.ProcessInfo = function() end
dialogueTooltip.ProcessItemExternal = function() end
dialogueTooltip.ToggleAlternateInfo = function() end
dialogueTooltip.ReprocessInfo = function() end
dialogueTooltip.Layout = function() end
UIParent.children = {dialogueTooltip}

assert(loadfile("Bridges/DialogueUI/Bridge.lua"))("Offhand", addon)
local ids = addon.Bridges:List()
assert(#ids == 1 and ids[1] == "DialogueUI" and addon.Bridges:Get("DialogueUI") ~= nil,
    "the bridge must register as DialogueUI")
assert(addon.Bridges:GetDiagnostics() == nil,
    "the bridge must not add to the compact diagnostics line")
local compat = addon.API.GetBridgeNamespace("DialogueUI").Compat
local mainhand = addon.API.GetMainhandFrame()
assert(compat and mainhand, "the bridge must expose its handler and use the Mainhand frame")
assert(DUIQuestFrame:GetPoint(1) == "CENTER"
        and select(2, DUIQuestFrame:GetPoint(1)) == mainhand,
    "Dialogue root was not translated to Mainhand")
assert(select(2, banner:GetPoint(1)) == mainhand,
    "Dialogue banner was not translated to Mainhand")
local _, _, _, questX = DUIQuestFrame:GetPoint(1)
local _, _, _, _, bannerY = banner:GetPoint(1)
assert(questX == 192 and bannerY == -76,
    "Dialogue native offsets changed during Mainhand confinement")
assert(select(2, internal:GetPoint(1)) == DUIQuestFrame,
    "ordinary Dialogue child anchor was changed")
assert(select(2, protected:GetPoint(1)) == UIParent,
    "protected Dialogue child must remain untouched")
assert(select(2, DUIBookFrame:GetPoint(1)) == mainhand
        and select(2, DUIDialogSettings:GetPoint(1)) == mainhand,
    "Dialogue book or settings root was not translated")
assert(math.abs(DUIQuestFrame:GetScale() - 0.5625) < 0.001
        and math.abs(DUIBookFrame:GetScale() - 0.5625) < 0.001
        and math.abs(DUIDialogSettings:GetScale() - 0.5625) < 0.001,
    "Dialogue presentation roots were not scaled to Mainhand's pixel height")
assert(banner:GetScale() == 1,
    "Dialogue child received a second local scale compensation")
assert(addon.PopupBounds.queued == dialogueTooltip and dialogueTooltip.scripts.OnShow,
    "Dialogue UI's anonymous custom tooltip was not discovered")
local queuedBefore = addon.PopupBounds.queueCount
dialogueTooltip:SetPoint("BOTTOMLEFT", banner, "TOPRIGHT", 0, 2)
dialogueTooltip:Layout()
assert(addon.PopupBounds.queueCount >= queuedBefore + 2,
    "Dialogue tooltip anchor and layout did not queue physical confinement")

-- Dialogue UI's intro animation repeatedly resets the root against UIParent.
-- The SetPoint observer must translate each new native point without changing
-- its own offset or accumulating Mainhand displacement.
DUIQuestFrame:ClearAllPoints()
DUIQuestFrame:SetPoint("CENTER", UIParent, "CENTER", 155, 0)
local point, relativeTo, relativePoint, x, y = DUIQuestFrame:GetPoint(1)
assert(point == "CENTER" and relativeTo == mainhand and relativePoint == "CENTER"
        and x == 155 and y == 0,
    "animated Dialogue anchor was not translated idempotently")

-- A frame-size change can leave the Unfold animation's half-height behind.
-- The completed native transaction must finish at Dialogue UI's own target.
DialogueUI_DB.FrameSize = 2
DUIQuestFrame:UpdateFrameSize()
assert(DUIQuestFrame.updateFrameSizeCalls == 1
        and DUIQuestFrame:GetHeight() == DUIQuestFrame.frameHeight
        and DUIQuestFrame:GetWidth() == 444
        and DUIQuestFrame:GetHeight() == 522
        and DUIQuestFrame.halfFrameWidth == 194
        and DUIQuestFrame.quarterFrameWidth == 97
        and math.abs(DUIQuestFrame:GetScale() - 0.5625) < 0.001,
    "Dialogue quest size refresh was not normalized from the constrained WorldFrame")

addon.db.enabled = false
compat:Refresh()
assert(select(2, DUIQuestFrame:GetPoint(1)) == UIParent
        and select(2, banner:GetPoint(1)) == UIParent
        and select(2, DUIBookFrame:GetPoint(1)) == UIParent,
    "disabling Offhand did not restore Dialogue UI's native anchor owner")
local _, _, _, restoredX = DUIQuestFrame:GetPoint(1)
assert(math.abs(restoredX - 155) < 0.001,
    "disabling Offhand did not restore Dialogue UI's native offset")
assert(DUIQuestFrame:GetScale() == 1 and DUIBookFrame:GetScale() == 1
        and DUIDialogSettings:GetScale() == 1,
    "disabling Offhand did not restore Dialogue UI's native scale")

addon.db.enabled = true
metrics.isSpanned = false
DUIQuestFrame:ClearAllPoints()
DUIQuestFrame:SetPoint("CENTER", UIParent, "CENTER", 100, 0)
assert(select(2, DUIQuestFrame:GetPoint(1)) == UIParent,
    "single-screen Dialogue UI was unnecessarily changed")

local diagnostics = compat:GetDiagnostics()
assert(diagnostics:find("DialogueUI=loaded", 1, true)
        and diagnostics:find("MainhandConfinement=inactive", 1, true),
    "Dialogue UI compatibility state was not diagnosable")

-- The bridge reaches Offhand through Offhand.API only.
local source = ReadSource("Bridges/DialogueUI/Bridge.lua")
for _, needle in ipairs({"Offhand.db", "Offhand.Viewport", "Offhand.Canvas", "Offhand.isForever",
    "Offhand.Mainhand", "Offhand.PopupBounds", "Offhand.DialogueUICompat"}) do
    assert(not source:find(needle, 1, true), "the DialogueUI bridge must not reach " .. needle)
end

-- The core stays free of Dialogue UI specifics. Core/Init.lua keeps a guarded
-- debug print of the retired module, which is now inert. Every Core file is
-- listed in at least one manifest.
assert(io.open("Core/DialogueUICompat.lua", "rb") == nil,
    "Core/DialogueUICompat.lua must remain retired into Bridges/DialogueUI/Bridge.lua")
local coreFiles = {}
for _, manifest in ipairs({"Offhand.toc", "Offhand_Classic.toc", "Offhand_Forever.toc",
    "Offhand_Mainline.toc", "Offhand_Vanilla.toc", "Offhand_Wrath335a.toc"}) do
    for line in ReadSource(manifest):gmatch("[^\r\n]+") do
        local file = line:match("^Core\\([^\\]+%.lua)$")
        if file then coreFiles["Core/" .. file] = true end
    end
end
assert(coreFiles["Core/Bridges.lua"] and coreFiles["Core/Init.lua"], "manifest Core files were not read")
for file in pairs(coreFiles) do
    if file ~= "Core/Init.lua" then
        assert(not ReadSource(file):find("DialogueUI", 1, true), "core module must not name DialogueUI: " .. file)
    end
end

print("PASS: Dialogue UI Mainhand confinement, animation repair, restore, and safety boundary")
