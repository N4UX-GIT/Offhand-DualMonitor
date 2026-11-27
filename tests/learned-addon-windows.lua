local addon = {isForever = true, db = {enabled = true}}
local combat, gamepad, message
local roots, controls = {}, {}
local parent = {GetEffectiveScale = function() return 1 end,
    GetNumChildren = function() return #roots end, GetChildren = function() return unpack(roots) end}
UIParent = parent
UIPanelWindows = {}
ADD, DONE, NONE = "Add", "Done", "None"
local loaded = {ExampleAddon = true, Platynator = true, ForeverDungeonJournal = true,
    DaylightUI = true, DaylightUI_InfoPanel = true, DaylightUI_UnitFrames = true, EllesmereUIChat = true}
C_AddOns = {IsAddOnLoaded = function(name) return loaded[name] == true end}
InCombatLockdown = function() return combat end
CreateFrame = function(kind, _, owner)
    local function Noop() end
    local control = {kind = kind, owner = owner, scripts = {}, SetFrameStrata = Noop,
        SetFrameLevel = Noop, SetBackdrop = Noop, SetBackdropColor = Noop, SetBackdropBorderColor = Noop,
        SetPoint = Noop, ClearAllPoints = Noop, SetSize = Noop, SetWidth = Noop,
        RegisterForClicks = Noop, RegisterEvent = Noop, SetEnabled = Noop}
    function control:EnableMouse(flag) self.mouseEnabled = flag end
    function control:CreateFontString()
        return {SetPoint = Noop, SetJustifyH = Noop, SetWidth = Noop,
            SetText = function(font, value) font.text = value end}
    end
    function control:SetScript(key, handler) self.scripts[key] = handler end
    function control:SetText(label) self.label = label end
    function control:Show() self.shown = true end
    function control:Hide()
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    controls[#controls + 1] = control
    return control
end

local metrics = {
    isSpanned = true, gameLeft = 500, gameBottom = 0, gameRight = 1000, gameTop = 600,
    workspaceLeft = 0, workspaceBottom = 0, workspaceWidth = 500, workspaceHeight = 600,
}
addon.Viewport = {GetMetrics = function() return metrics end}
addon.UIControls = {StyleSurface = function() end}
function addon:IsGamepadUIEnabled() return gamepad end
function addon:Print(text, ...) message = string.format(text, ...) end
for _, file in ipairs({"Locales/enUS.lua", "Core/WorkspaceRegions.lua", "Core/HUDCompatibility.lua",
    "Core/CanvasCompatibility.lua", "Core/AddonWindowCatalog.lua", "Core/Bridges.lua",
    "Core/CanvasAddonEscape.lua", "Core/LearnedAddonWindows.lua", "Bridges/EllesmereUI/Bridge.lua",
    "Bridges/ForeverDungeonJournal/Bridge.lua", "Bridges/Platynator/Bridge.lua",
    "UI/AddonWindowSelection.lua"}) do
    assert(loadfile(file))("Offhand", addon)
end
addon.API.RegisterGeometryCallback = function() end
_G.Offhand = addon
_G.DaylightUI = {Movers = {unlocked = false}}
_G.SlashCmdList = {}
assert(loadfile("Bridges/DaylightUI/Core.lua"))("Offhand", addon)
assert(loadfile("Bridges/DaylightUI/Init.lua"))("Offhand", addon)
local windows, selection = addon.LearnedAddonWindows, addon.AddonWindowSelection

local function Frame(name, frameParent)
    local frame = {shown = true, parent = frameParent or parent, children = {}, writes = 0,
        source = "Interface\\AddOns\\ExampleAddon\\Settings.lua:12", width = 300, height = 400,
        scale = 0.5, points = {{"TOPLEFT", parent, "BOTTOMLEFT", 1200, 1000}}}
    function frame:GetName() return name end
    function frame:GetParent() return self.parent end
    function frame:GetObjectType() return "Frame" end
    function frame:IsMovable() return true end
    function frame:GetSourceLocation() return self.source end
    function frame:IsProtected() return self.protected == true end
    function frame:IsForbidden() return false end
    function frame:IsVisible() return self.shown end
    function frame:IsShown() return self.shown end
    function frame:GetEffectiveAlpha() return 1 end
    function frame:GetFrameStrata() return "MEDIUM" end
    function frame:GetHighestFrameLevel(allChildren) assert(allChildren); return 12 end
    function frame:IsUserPlaced() return true end
    function frame:GetChildren() return unpack(self.children) end
    function frame:GetNumChildren() return #self.children end
    function frame:GetNumPoints() return #self.points end
    function frame:GetPoint(i) return unpack(self.points[i]) end
    function frame:GetLeft() return self.points[1][4] end
    function frame:GetTop() return self.points[1][5] end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:GetEffectiveScale() return self.scale end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...)
        self.writes = self.writes + 1
        if self.failNextWrite then self.failNextWrite = nil; error("rejected anchor") end
        self.points = {{...}}
    end
    if name then _G[name] = frame end
    if not frameParent then roots[#roots + 1] = frame end
    return frame
end

local frame = Frame("ExampleConfigFrame")
local child = Frame(nil, frame)
frame.children = {child}
Frame(nil)
local function FindButton(name)
    for _, control in ipairs(controls) do
        if control.shown and control.window and control.window.name == name then return control end
    end
end
local function FindToolbar()
    for _, control in ipairs(controls) do
        if control.shown and control.hint then return control end
    end
end
local target
local function Pick()
    selection:Stop()
    windows:Run("")
    target = assert(FindButton("ExampleConfigFrame"), "the ordinary movable root should be highlighted")
end
local function Accept()
    target.scripts.OnClick(target)
end
local function Reject()
    selection:Stop()
    windows:Run("")
    assert(not FindButton("ExampleConfigFrame"))
    selection:Stop()
end

Pick()
windows:Run("")
assert(not target.shown and not FindToolbar(), "toggling off must remove the toolbar and selection hitboxes")
Accept()
assert(frame.writes == 0 and addon.db.learnedAddonWindows == nil, "leaving mode without clicking must not move a window")
Pick()
frame.points[1][4] = 1220
Accept()
assert(frame.writes == 0 and addon.db.learnedAddonWindows == nil, "a moved window must be highlighted again before saving")
frame.points[1][4] = 1200
Pick()
frame.failNextWrite = true
Accept()
assert(frame:GetLeft() == 1200 and addon.db.learnedAddonWindows == nil, "rejected writes must roll back")
Pick()
Accept()
local saved = addon.db.learnedAddonWindows.ExampleConfigFrame
assert(saved and saved.owner == "ExampleAddon" and saved.file == "settings.lua"
    and saved.x == 0.35 and saved.y == 2/3)
assert(frame:GetLeft() == 350 and frame:GetTop() == 800, "placement uses the frame's effective scale")
assert(not FindButton("ExampleConfigFrame") and FindToolbar(), "adding a window keeps selection mode open")
assert(addon.HUDCompatibility.ShouldPreservePopupPosition(frame, "ExampleConfigFrame"),
    "automatic popup recovery must yield to the active placement")

local second = Frame("AnotherConfigFrame")
assert(not FindButton("AnotherConfigFrame"))
local toolbar = FindToolbar()
toolbar.scripts.OnUpdate(toolbar, 0.25)
local secondButton = assert(FindButton("AnotherConfigFrame"), "a window opened in selection mode must be offered")
assert(toolbar.focusText.text:find("AnotherConfigFrame", 1, true), "the toolbar names the current window")
windows:Run("add")
assert(frame:GetLeft() == 350 and second:GetLeft() == 350 and not secondButton.shown,
    "a second click can save another window in the same session")
for _, control in ipairs(controls) do
    if control.label == DONE then control.scripts.OnClick(control) end
end
assert(not FindToolbar(), "Done exits the selection mode")
windows:Run("forget AnotherConfigFrame")
second.shown = false

-- Initial catalog roles use their reviewed root, source and shape.
local journal = Frame("ForeverDungeonJournalFrame")
journal.source = "Interface/AddOns/ForeverDungeonJournal/Core/Journal.lua:8997"
local platynator = Frame("PlatynatorCustomiseDialogblizzard")
platynator.source = "Interface/AddOns/Platynator/CustomiseDialog/Main.lua:575"
platynator.Tabs, platynator.CloseButton = {}, {}
local import = Frame("PlatynatorCustomiseDialogImportDialog")
import.source = "Interface/AddOns/Platynator/CustomiseDialog/ImportDialog.lua:9"
import.Tabs, import.CloseButton = {}, {}
frame.shown = false
windows:Run("")
toolbar = FindToolbar()
assert(FindButton("ForeverDungeonJournalFrame") and FindButton("PlatynatorCustomiseDialogblizzard"))
assert(not FindButton("PlatynatorCustomiseDialogImportDialog"), "the catalog must leave the import modal alone")
assert(toolbar.focusText.text:find("ForeverDungeonJournalFrame", 1, true))
windows:Run("next")
assert(toolbar.focusText.text:find("PlatynatorCustomiseDialogblizzard", 1, true))
selection:Refresh()
assert(toolbar.focusText.text:find("PlatynatorCustomiseDialogblizzard", 1, true), "refresh must preserve keyboard focus")
windows:Run("add")
assert(platynator:GetLeft() == 350 and journal.writes == 0 and import.writes == 0)
windows:Run("done")
assert(not FindToolbar())
windows:Run("forget PlatynatorCustomiseDialogblizzard")
frame.shown = true
journal.shown, platynator.shown, import.shown = false, false, false

local function Reopen(x)
    frame.shown = false
    windows:Refresh()
    frame.points[1][4], frame.shown = x, true
    windows:Refresh()
end
Reopen(1300)
assert(frame:GetLeft() == 350, "reopening must restore saved placement")
frame.points[1][4] = 1400
windows:Refresh()
assert(frame:GetLeft() == 1400, "an open window must keep changes made by its owner")
windows:Run("list")
assert(message:find("ExampleConfigFrame", 1, true))
windows:Run("forget ExampleConfigFrame")
assert(not addon.db.learnedAddonWindows.ExampleConfigFrame and frame:GetLeft() == 1400,
    "forget must preserve a position already changed by the owner")

Pick()
Accept()
local records = addon.db.learnedAddonWindows
addon.db = {enabled = true}
windows:Refresh()
assert(frame:GetLeft() == 1400, "profile switch must release Offhand's anchor")
addon.db.learnedAddonWindows = records
frame.shown = false
selection:Stop()
assert(loadfile("Core/LearnedAddonWindows.lua"))("Offhand", addon)
windows = addon.LearnedAddonWindows
assert(loadfile("UI/AddonWindowSelection.lua"))("Offhand", addon)
selection = addon.AddonWindowSelection
windows:Refresh()
assert(frame:GetLeft() == 1400, "reload must not open a closed window")
frame.shown = true
windows:Refresh()
assert(frame:GetLeft() == 350, "a saved profile must restore on first native open")
metrics.isSpanned = false
combat = true
windows:Refresh()
assert(frame:GetLeft() == 350, "release must wait for combat to end")
combat = false
windows:Refresh()
assert(frame:GetLeft() == 1400, "unspan must restore the original anchor if still owned")
metrics.isSpanned = true

-- Same global name with an unrelated or changed source cannot claim the record.
local replacement = Frame("ExampleConfigFrame")
replacement.source = "Interface/AddOns/ExampleAddon/Different.lua:13"
windows:Refresh()
assert(replacement.writes == 0)
replacement.source = frame.source:gsub(":12", ":67")
replacement.children = {Frame(nil, replacement)}
replacement.children[1].protected = true
windows:Refresh()
assert(replacement.writes == 0, "protected descendants must block restoration")
replacement.children[1].protected = false
replacement.shown = false
windows:Refresh()
replacement.shown = true
windows:Refresh()
assert(replacement:GetLeft() == 350, "new instances may match the same stable identity")

windows:Run("forget ExampleConfigFrame")
assert(replacement:GetLeft() == 1200)
gamepad = true
Reject()
gamepad = false
UIPanelWindows.ExampleConfigFrame = {}
Reject()
UIPanelWindows.ExampleConfigFrame = nil
replacement.children[1].protected = true
Reject()
replacement.children[1].protected = false
replacement.source = "Interface/AddOns/ExampleAddon/Libs/Widget.lua:7"
Reject()

replacement.source = frame.source
replacement.points[1][4], replacement.points[1][5] = 2200, 840
metrics.workspaceRegions = {
    {id = "Left", x = 0, y = 0, width = 500, height = 600},
    {id = "Right", x = 1000, y = 0, width = 500, height = 600},
}
metrics.primaryWorkspaceRegion = "Left"
Pick()
combat = true
toolbar = FindToolbar()
toolbar.scripts.OnEvent(toolbar, "PLAYER_REGEN_DISABLED")
assert(not target.shown and not FindToolbar(), "entering combat must remove selection overlays")
combat = false
Pick()
Accept()
assert(records.ExampleConfigFrame.region == "Right" and replacement:GetLeft() == 2200,
    "learning a manually placed window must remember its specific workspace")
replacement.shown = false
windows:Refresh()
replacement.points[1][4], replacement.shown = 1200, true
metrics.workspaceRegions[2] = nil
windows:Refresh()
assert(replacement:GetLeft() == 1200, "do not redirect into a different workspace if the saved display is absent")
frame.shown = false
replacement.shown = false
windows:Refresh()
replacement.points[1][4], replacement.points[1][5] = 1200, 1000
windows:Run("forget ExampleConfigFrame")
selection:Stop()
windows:Run("")
toolbar = FindToolbar()
assert(toolbar and toolbar.hint.text == addon.L.LEARN_WINDOW_NO_TARGET
    and toolbar.focusText.text == addon.L.LEARN_WINDOW_FOCUS_NONE,
    "empty selection mode must explain eligibility and show zero eligible windows")
replacement.shown = true
selection:Refresh()
assert(toolbar.hint.text == addon.L.LEARN_WINDOW_MODE_HELP
    and toolbar.focusText.text:find("ExampleAddon", 1, true)
    and toolbar.focusText.text:find("ExampleConfigFrame", 1, true),
    "eligible selection mode must show instructions and the focused addon/frame")
local pill = assert(FindButton("ExampleConfigFrame"))
assert(pill.mouseEnabled == true and pill.outline and pill.outline.mouseEnabled == false,
    "window outline must be click-through so dragging the window never triggers an accidental click")
assert(pill.labelText.text == addon.L.LEARN_WINDOW_PILL_ADD,
    "unlearned window pill must invite adding to Offhand")
Accept()
selection:Stop()
-- Re-entering selection mode clearly labels an already-remembered window and enables Forget
windows:Run("")
pill = assert(FindButton("ExampleConfigFrame"))
assert(pill.window.remembered == true and pill.labelText.text == addon.L.LEARN_WINDOW_PILL_UPDATE,
    "already-remembered windows must be visibly labeled as saved/updatable")
selection:ForgetFocused()
assert(addon.db.learnedAddonWindows.ExampleConfigFrame == nil,
    "toolbar Forget button must forget the focused remembered window")
selection:Stop()
assert(#windows:ListNames() == 0, "ListNames must return empty when no windows are remembered")

-- DaylightUI HUD/Mover widgets and UI suites must stay excluded while DaylightUIOptions is learnable
local dlInfo = Frame("DaylightUIInfoPanel")
dlInfo.source = "Interface/AddOns/DaylightUI_InfoPanel/Panel.lua:181"
local dlMover = Frame("DaylightUIMoverBar")
dlMover.source = "Interface/AddOns/DaylightUI/Movers.lua:1555"
local euiChat = Frame("EllesmereUIChatHolder")
euiChat.source = "Interface/AddOns/EllesmereUIChat/Chat.lua:42"
local dlOpts = Frame("DaylightUIOptions")
dlOpts.source = "Interface/AddOns/DaylightUI/Options/Panel.lua:386"
replacement.shown = false
windows:Run("")
assert(not FindButton("DaylightUIInfoPanel") and not FindButton("DaylightUIMoverBar")
    and not FindButton("EllesmereUIChatHolder"),
    "suite HUD and mover widgets must never be offered by the generic addon window picker")
assert(FindButton("DaylightUIOptions"),
    "reviewed DaylightUIOptions settings window should remain selectable")
-- DaylightUI unlock/edit mode pauses selection cleanly
_G.DaylightUI = {Movers = {unlocked = true}}
selection:Refresh()
assert(not FindToolbar(), "DaylightUI unlock mode must pause addon window selection")
_G.DaylightUI.Movers.unlocked = false
-- Stale catalog-excluded records saved before suite exclusion are hidden and retired on Refresh
addon.db.learnedAddonWindows = {
    DaylightUIInfoPanel = {owner = "DaylightUI_InfoPanel", file = "panel.lua", x = 0.2, y = 0.8},
    DaylightUIMoverBar = {owner = "DaylightUI", file = "movers.lua", x = 0.2, y = 0.8},
}
assert(#windows:ListNames() == 0, "catalog-excluded stale records must not appear in ListNames")
windows:Refresh()
assert(addon.db.learnedAddonWindows.DaylightUIInfoPanel == nil
    and addon.db.learnedAddonWindows.DaylightUIMoverBar == nil,
    "Refresh must retire stale catalog-excluded suite records without moving them")
assert(dlInfo.writes == 0 and dlMover.writes == 0, "retired suite HUD frames must never be moved")
dlInfo.shown, dlMover.shown, euiChat.shown, dlOpts.shown = false, false, false, false

-- Verify Panel layout > Addon windows card description and multi-paragraph ? help
local cardCalls, createdTexts = {}, {}
local function MockWidget()
    local w = {}
    local function Noop() end
    function w:CreateFontString()
        local fs = {SetPoint = Noop, SetJustifyH = Noop, SetWidth = Noop, SetHeight = Noop,
            SetWordWrap = Noop, SetTextColor = Noop, ClearAllPoints = Noop, SetJustifyV = Noop}
        function fs:SetText(v) self.text = v; createdTexts[#createdTexts + 1] = v end
        return setmetatable(fs, {__index = function() return Noop end})
    end
    function w:CreateTexture() return setmetatable({}, {__index = function() return Noop end}) end
    function w:GetFontString() return self:CreateFontString() end
    return setmetatable(w, {__index = function() return Noop end})
end
local mockWorkspace = {
    isForever = true,
    db = addon.db,
    L = addon.L,
    LearnedAddonWindows = windows,
    AddonWindowSelection = selection,
    WorkspaceProfiles = {List = function() return {{id = "default", name = "Default"}}, "default" end},
    WorkspaceRouting = {GetGroups = function() return {} end},
    WorkspaceScaleControls = nil,
    UIControls = {
        CreateFrame = MockWidget,
        FitCompactParagraph = function() return 28 end,
    },
}
assert(loadfile("UI/WorkspaceOptions.lua"))("Offhand", mockWorkspace)
local function MockCard(_, title, _, ...)
    cardCalls[title] = {...}
    return MockWidget()
end
local built = mockWorkspace.WorkspaceOptions.Build({panels = MockWidget(), appearance = MockWidget(), profiles = MockWidget()}, MockCard, {})
assert(built.learning ~= nil, "Forever WorkspaceOptions must build the Addon windows card")
local helpParas = cardCalls[addon.L.LEARN_WINDOW_MODE_TITLE]
assert(helpParas and #helpParas == 3
    and helpParas[1] == addon.L.LEARN_WINDOW_HELP_OVERVIEW
    and helpParas[2] == addon.L.LEARN_WINDOW_HELP_STEPS
    and helpParas[3] == addon.L.LEARN_WINDOW_HELP_ELIGIBLE,
    "Addon windows ? help must provide overview, selection steps, and eligibility rules")
local sawDesc = false
for _, t in ipairs(createdTexts) do
    if t == addon.L.LEARN_WINDOW_CARD_DESC then sawDesc = true end
end
assert(sawDesc, "Addon windows card must render an inline description")

-- Done re-opens Offhand Settings only when launched from Settings (and never on auto-exit/combat)
local optionsOpened, optionsClosed = 0, 0
addon.Options = {
    Open = function() optionsOpened = optionsOpened + 1 end,
    Close = function() optionsClosed = optionsClosed + 1 end,
}
selection:Stop()
-- Launched via slash/keybind -> Done must NOT reopen Settings
windows:Run("")
toolbar = FindToolbar()
toolbar.done.scripts.OnClick(toolbar.done)
assert(optionsOpened == 0, "Done must not open Settings when selection mode was not launched from Settings")
-- Launched from Settings -> Done reopens Settings
selection:Toggle(true)
assert(optionsClosed >= 1)
toolbar = FindToolbar()
toolbar.done.scripts.OnClick(toolbar.done)
assert(optionsOpened == 1, "Done must reopen Settings when selection mode was launched from Settings")
-- Launched from Settings + combat auto-exit -> must NOT reopen Settings
selection:Toggle(true)
toolbar = FindToolbar()
combat = true
toolbar.scripts.OnEvent(toolbar, "PLAYER_REGEN_DISABLED")
combat = false
assert(optionsOpened == 1, "combat auto-exit must never reopen Settings")
addon.Options = nil

print("PASS: learned windows confirm identity, restore only placement, yield, and release safely")
