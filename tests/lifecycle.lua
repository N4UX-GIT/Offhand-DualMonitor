StaticPopupDialogs = {}
-- Run from the project root with Lua 5.1.
local addon = {}
local events = {}
local registeredEvents = {}
local combat = false
GetBuildInfo = function() return "", "", "", 11509 end
CreateFrame = function(_, frameName)
    return { RegisterEvent = function(_, event) registeredEvents[event] = true end,
        SetScript = function(_, name, fn)
            if frameName == "OffhandEventFrame" then events[name] = fn end
        end }
end
InCombatLockdown = function() return combat end
SlashCmdList = {}
assert(loadfile("Core/Init.lua"))("Offhand", addon)
assert(loadfile("Core/ClientRuntime.lua"))("Offhand", addon)

do
    local oldUI, oldReload = C_UI, ReloadUI
    local legacy, modern = function() end, function() end
    C_UI, ReloadUI = { Reload = modern }, legacy
    assert(addon:GetReloadUIFunction() == modern, "prefer the current reload API when both exist")
    local previousForever = addon.isForever
    addon.isForever = true
    assert(addon:GetReloadUIFunction() == modern,
        "Forever keyboard clicks retain the native reload API")
    local previousStyle = addon.IsGamepadUIEnabled
    addon.IsGamepadUIEnabled = function() return true end
    assert(addon:GetReloadUIFunction() == nil, "unverified Forever controller reload remains manual")
    addon.IsGamepadUIEnabled = previousStyle
    addon.isForever = previousForever
    ReloadUI = nil
    assert(addon:GetReloadUIFunction() == modern, "reload must work without the legacy global")
    C_UI, ReloadUI = {}, legacy
    assert(addon:GetReloadUIFunction() == legacy, "retain original-client reload compatibility")
    ReloadUI = nil
    assert(addon:GetReloadUIFunction() == nil, "missing capabilities must not pretend to reload")
    C_UI, ReloadUI = oldUI, oldReload
end

-- The live interface-style API is authoritative when available, with
-- InputUtil retained only for builds/load orders that do not expose it yet.
Enum = { InputDeviceInterfaceType = { Mkb = 1, Gamepad = 2 } }
C_InputInterfaceStyle = { GetCurrentStyle = function() return 2 end }
InputUtil = { IsGamepadUIEnabled = function() return false end }
assert(addon:IsGamepadUIEnabled(),
    "native Gamepad UI detection must prefer the live interface style")
C_InputInterfaceStyle.GetCurrentStyle = function() return 1 end
InputUtil.IsGamepadUIEnabled = function() return true end
assert(not addon:IsGamepadUIEnabled(),
    "a live keyboard/mouse style must not be overridden by a stale utility result")
C_InputInterfaceStyle = nil
assert(addon:IsGamepadUIEnabled(),
    "Gamepad UI detection must fall back to InputUtil when the style API is unavailable")

-- Native Gamepad UI must not use a Blizzard StaticPopup for Edit Mode recovery.
-- Closing that popup asks FrameControlsManager to restore its previous focus,
-- which can be a stale LootFrame control. The addon-owned card keeps the same
-- hardware-click boundary without entering Blizzard's popup focus stack.
local originalCreateFrame = CreateFrame
local originalUIParent = UIParent
local originalStaticPopupShow = StaticPopup_Show
local originalStaticPopupHide = StaticPopup_Hide
local createdFrames = {}
local function makePromptFrame(name)
    local frame = { name = name, shown = false, scripts = {}, points = {} }
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetHeight(value) self.height = value end
    function frame:SetWidth(value) self.width = value end
    function frame:SetFrameStrata(value) self.strata = value end
    function frame:SetClampedToScreen(value) self.clamped = value end
    function frame:EnableMouse(value) self.mouse = value end
    function frame:SetBackdrop(value) self.backdrop = value end
    function frame:SetBackdropColor(...) self.backdropColor = {...} end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:SetText(value) self.text = value end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:Show()
        if self.name == "OffhandGamepadSafePopup" then
            assert(not self.shown and #self.points == 1 and self.points[1][1] == "CENTER",
                "owned confirmations must be hidden and positioned before becoming visible")
        end
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function frame:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function frame:SetAutoFocus(value) self.autoFocus = value end
    function frame:SetCursorPosition(value) self.cursorPosition = value end
    function frame:ClearFocus() self.focused = false end
    function frame:CreateFontString()
        local text = { points = {} }
        function text:SetPoint(...) self.points[#self.points + 1] = { ... } end
        function text:SetWidth(value) self.width = value end
        function text:SetHeight(value) self.height = value end
        function text:SetJustifyH(value) self.justifyH = value end
        function text:SetJustifyV(value) self.justifyV = value end
        function text:SetWordWrap(value) self.wordWrap = value end
        function text:SetText(value) self.text = value end
        function text:GetText() return self.text end
        return text
    end
    createdFrames[#createdFrames + 1] = frame
    return frame
end
CreateFrame = function(_, name) return makePromptFrame(name) end
UIParent = {
    GetEffectiveScale = function() return 1 end,
}
local mainhand = makePromptFrame("Mainhand")
addon.API = { GetMainhandFrame = function() return mainhand end }
local accepted, declined = 0, 0
addon.HUD = {
    BringForeverEditModeControlsToMainhand = function() accepted = accepted + 1 end,
    DismissForeverEditModeControlsPrompt = function() declined = declined + 1 end,
}
local staticShows, staticHides = 0, 0
StaticPopup_Show = function() staticShows = staticShows + 1 end
StaticPopup_Hide = function() staticHides = staticHides + 1 end
addon:ShowForeverEditModeControlsPrompt()
local gamepadPrompt = addon._foreverGamepadEditModeControlsPrompt
assert(gamepadPrompt and gamepadPrompt.shown and staticShows == 0,
    "native Gamepad Edit Mode recovery must bypass Blizzard StaticPopup focus")
assert(gamepadPrompt.points[1] and gamepadPrompt.points[1][1] == "CENTER"
        and gamepadPrompt.points[1][2] == mainhand
        and gamepadPrompt.points[1][3] == "CENTER",
    "native Gamepad Edit Mode recovery card must be centered on Mainhand")
gamepadPrompt.accept.scripts.OnClick()
assert(accepted == 1 and not gamepadPrompt.shown and staticHides == 0,
    "Gamepad recovery click must move controls without closing a Blizzard popup")
addon:ShowForeverEditModeControlsPrompt()
gamepadPrompt.cancel.scripts.OnClick()
assert(declined == 1 and not gamepadPrompt.shown and staticHides == 0,
    "Gamepad recovery dismissal must remain outside Blizzard's popup stack")

local safeAccepted, safeCancelled, safeHidden = 0, 0, 0
StaticPopupDialogs.OFFHAND_GAMEPAD_SAFE_TEST = {
    text = "Safe %s",
    button1 = "Accept",
    button2 = "Cancel",
    gamepadEditBoxText = function() return "https://example.invalid" end,
    OnAccept = function(_, callback) safeAccepted = safeAccepted + 1; callback() end,
    OnCancel = function() safeCancelled = safeCancelled + 1 end,
    OnHide = function() safeHidden = safeHidden + 1 end,
}
local dataCalled = 0
local safePrompt = addon:ShowPopup("OFFHAND_GAMEPAD_SAFE_TEST", "Gamepad", nil,
    function() dataCalled = dataCalled + 1 end)
assert(safePrompt and safePrompt.shown and staticShows == 0
        and safePrompt.text.text == "Safe Gamepad"
        and safePrompt.EditBox.text == "https://example.invalid"
        and safePrompt.points[1][1] == "CENTER"
        and safePrompt.points[1][2] == mainhand,
    "native Gamepad dialogs must render through the addon-owned popup card")
assert(safePrompt.backdrop.bgFile == "Interface\\Buttons\\WHITE8X8"
        and safePrompt.backdropColor[4] == 1,
    "owned popup background must be opaque over underlying wizard text")
safePrompt.accept.scripts.OnClick()
assert(safeAccepted == 1 and dataCalled == 1 and safeHidden == 1
        and not safePrompt.shown and staticHides == 0,
    "accepting a Gamepad-safe dialog must preserve callback data without Blizzard popup calls")
addon:ShowPopup("OFFHAND_GAMEPAD_SAFE_TEST", "Gamepad")
safePrompt.cancel.scripts.OnClick()
assert(safeCancelled == 1 and safeHidden == 2 and staticHides == 0,
    "cancelling a Gamepad-safe dialog must remain outside Blizzard's focus stack")
StaticPopupDialogs.OFFHAND_GAMEPAD_SAFE_TEST = nil

-- Keyboard setup confirmations must sit above the fullscreen wizard, inside
-- Mainhand, without changing any native popup's strata or point handlers.
InputUtil.IsGamepadUIEnabled = function() return false end
addon.Viewport = { GetMetrics = function() return {
    isSpanned = true, gameWidth = 1950, gameLeft = 1097, gameRight = 3047,
    gameBottom = 4, gameTop = 1101,
} end }
assert(loadfile("UI/Controls.lua"))("Offhand", addon)
addon.UIControls.FitDialog = function() return 0.8 end
StaticPopupDialogs.OFFHAND_WIZARD_SKIP_MAINHAND_LAYOUT = {
    text = 'Confirm', button1 = 'Finish', button2 = 'Back',
    OnAccept = function(_, callback) callback() end,
}
local confirmed = 0
local prompt = addon:ShowPopup('OFFHAND_WIZARD_SKIP_MAINHAND_LAYOUT', nil, nil,
    function() confirmed = confirmed + 1 end)
assert(prompt.strata == 'TOOLTIP' and staticShows == 0 and prompt.width == 440
        and prompt.height == prompt.text.height + 70 and prompt.height < 120,
    "short confirmations should size to their text and action row")
assert(prompt.points[1][2] == UIParent and prompt.points[1][4] == 2072 / 0.8,
    'setup confirmation must use Mainhand geometry, not a stale anchor')
prompt.accept.scripts.OnClick()
assert(confirmed == 1 and not prompt.shown, 'owned setup confirmation must preserve callback data')
-- Guide placement and the HUD completion/reload prompts must never enter the
-- native stack, even in keyboard UI. Reuse must not inherit the previous card's
-- anchor or accidentally invoke its callback when a new prompt replaces it.
local setupKeys = {
    "OFFHAND_WEBSITE_LINK", "OFFHAND_DISCORD_LINK",
    "OFFHAND_CONFIRM_WINDOWED_MODE", "OFFHAND_CONFIRM_PLACEMENT",
    "OFFHAND_CONFIRM_MANUAL_LAYOUT", "OFFHAND_CONFIRM_MANUAL_LAYOUT_FOREVER",
    "OFFHAND_MAINHAND_LAYOUT_RELOAD", "OFFHAND_MAINHAND_LAYOUT_SELECT",
}
for _, key in ipairs(setupKeys) do
    local previous = StaticPopupDialogs[key]
    local accepts, cancels = 0, 0
    StaticPopupDialogs[key] = {
        text = "Review %s", button1 = "Continue", button2 = "Back",
        OnAccept = function(_, data) accepts = accepts + data end,
        OnCancel = function() cancels = cancels + 1 end,
    }
    local card = addon:ShowPopup(key, "placement", nil, 2)
    assert(card == prompt and staticShows == 0 and card.strata == "TOOLTIP"
            and card.text.text == "Review placement"
            and card.points[1][2] == UIParent and card.points[1][3] == "BOTTOMLEFT"
            and card.points[1][4] == 2072 / 0.8 and card.points[1][5] == 552.5 / 0.8,
        key .. " must open centered inside Mainhand without a native TOP/seam anchor")
    addon:ShowPopup(key, "placement", nil, 2)
    assert(accepts == 0 and cancels == 0, "replacing a prompt must not accept or cancel it")
    card.cancel.scripts.OnClick()
    assert(cancels == 1 and accepts == 0 and not card.shown)
    addon:ShowPopup(key, "placement", nil, 2).accept.scripts.OnClick()
    assert(accepts == 2 and not card.shown, "owned dialogs must retain callback data")
    addon:ShowPopup(key, "placement", nil, 2)
    assert(addon:HidePopup(key) and not card.shown and staticHides == 0,
        "hiding an owned setup prompt must leave the native stack untouched")
    StaticPopupDialogs[key] = previous
end
-- Reload callbacks must run while the clicked parent is visible. Ordinary
-- callbacks retain hide-first semantics, and reopened cards survive cleanup.
do
    local key = "OFFHAND_MAINHAND_LAYOUT_RELOAD"
    local accepts, hides = 0, 0
    local definition = {
        text = "Reload", button1 = "Reload", button2 = "Later",
        offhandAcceptBeforeHide = true,
        OnHide = function() hides = hides + 1 end,
        OnAccept = function(card, data)
            assert(card.shown and hides == 0 and data == 42,
                "reload must retain the visible hardware-click target until its callback")
            accepts = accepts + 1
        end,
    }
    StaticPopupDialogs[key] = definition
    addon:ShowPopup(key,nil,nil,42).accept.scripts.OnClick()
    assert(accepts == 1 and hides == 1 and not prompt.shown)
    definition.OnAccept = function()
        addon:ShowPopup(key,nil,nil,99)
    end
    addon:ShowPopup(key).accept.scripts.OnClick()
    assert(prompt.shown and prompt.data == 99,
        "a callback reopening the same definition must keep its replacement card")
    addon:HidePopup(key)
    definition.offhandAcceptBeforeHide = nil
    definition.OnAccept = function(card) assert(not card.shown, "ordinary callbacks remain hide-first") end
    addon:ShowPopup(key).accept.scripts.OnClick()
    definition.offhandAcceptBeforeHide = true
    definition.OnAccept = function() error("cancel must not invoke accept") end
    addon:ShowPopup(key).cancel.scripts.OnClick()
    assert(not prompt.shown)
    StaticPopupDialogs[key] = nil
end
addon:ShowManualReloadPrompt()
assert(prompt.popupKey == "OFFHAND_SETUP_MANUAL_RELOAD" and prompt.strata == "TOOLTIP"
        and not prompt.definition.OnAccept and not prompt.cancel.shown and staticShows == 0,
    "manual reload must only show the owned instruction card, with no reload callback")
prompt.accept.scripts.OnClick()
assert(not prompt.shown, "closing instructions must not request a native reload")
addon:ShowPopup("OFFHAND_NATIVE_KEYBOARD_PROBE")
assert(staticShows == 1, "unrelated keyboard popups must retain their existing native route")
staticShows = 0
local reminderCharacter = OffhandCharDB
local reminderEditMode = addon.HasBlizzardEditMode
OffhandCharDB = {mainhandLayoutDeferred = true}
addon.HasBlizzardEditMode = function() return true end
assert(addon:RefreshMainhandLayoutAttention() and prompt.popupKey == "OFFHAND_HUD_SETUP_REMINDER",
    "previously skipped HUD setup must offer recovery at the next entry check")
assert(not addon:RefreshMainhandLayoutAttention(), "HUD reminders must not repeat in one UI session")
prompt.cancel.scripts.OnClick()
assert(OffhandCharDB.hudSetupReminderDeclined, "explicit decline must persist per character")
addon._hudSetupReminderShown = nil
assert(not addon:RefreshMainhandLayoutAttention(), "declined reminders must stay suppressed across sessions")
OffhandCharDB.hudSetupReminderDeclined = nil
local resumed = 0
addon.Wizard = {OpenHUDSetup = function() resumed = resumed + 1 end}
assert(addon:RefreshMainhandLayoutAttention())
prompt.accept.scripts.OnClick()
assert(resumed == 1 and OffhandCharDB.mainhandLayoutDeferred,
    "resuming must open HUD setup without claiming the layout is repaired")
addon.Wizard, addon.HasBlizzardEditMode, addon._hudSetupReminderShown = nil, reminderEditMode, nil
local priorMainhand, priorCharacterSetup = addon.Mainhand, addon.CharacterSetup
addon.Mainhand = {GetGeometrySignature = function() return "character-test" end}
OffhandCharDB = {}
addon.Wizard = {OpenHUDSetup = function() resumed = resumed + 1 end}
assert(loadfile("Core/CharacterSetup.lua"))("Offhand", addon)
assert(addon.CharacterSetup:Show("CHARACTER_SETUP_WAITING_FOR_SPAN"))
assert(prompt.shown and prompt.strata == "TOOLTIP" and not prompt.alternate.shown
        and prompt.accept.text == addon.L.POPUP_BTN_GOT_IT
        and prompt.cancel.shown and prompt.cancel.text == addon.L.CHARACTER_SETUP_HIDE_SPAN_NOTICE,
    "the span notice must offer both temporary and persistent dismissal")
addon.CharacterSetup:Hide()
assert(not OffhandCharDB.hudSpanNoticeDismissed, "hiding the notice must not persist dismissal")
assert(addon.CharacterSetup:Show("CHARACTER_SETUP_WAITING_FOR_SPAN"))
prompt.accept.scripts.OnClick()
assert(not prompt.shown and addon.CharacterSetup.spanNoticeDismissed
        and not OffhandCharDB.hudSpanNoticeDismissed and not OffhandCharDB.characterSetup,
    "Got it must only acknowledge the notice for this UI session")
assert(addon.CharacterSetup:Show("CHARACTER_SETUP_WAITING_FOR_SPAN"))
prompt.cancel.scripts.OnClick()
assert(not prompt.shown and OffhandCharDB.hudSpanNoticeDismissed and not OffhandCharDB.characterSetup,
    "the persistent dismissal button must save only the notice preference")
local characterMessage = rawget(addon.L, "CHARACTER_SETUP_TEXT")
addon.L.CHARACTER_SETUP_TEXT = "Set up this character's HUD\n\nChoose how to set up your HUD.\n\n%s"
assert(addon.CharacterSetup:Show("CHARACTER_SETUP_READY"))
assert(prompt.popupKey == "OFFHAND_CHARACTER_SETUP" and prompt.strata == "TOOLTIP"
        and prompt.alternate.shown and prompt.alternate.text == addon.L.CHARACTER_SETUP_CUSTOMIZE,
    "the three-choice character check must use the owned Mainhand popup in keyboard UI")
assert(prompt.width == 520 and prompt.height > 120 and not prompt.EditBox.shown
        and prompt.accept.points[1][4] + prompt.accept.width / 2
            < prompt.alternate.points[1][4] - prompt.alternate.width / 2
        and prompt.alternate.points[1][4] + prompt.alternate.width / 2
            < prompt.cancel.points[1][4] - prompt.cancel.width / 2,
    "a reused character card must expand for its paragraphs and keep three distinct actions")
addon.L.CHARACTER_SETUP_TEXT = characterMessage
prompt.alternate.scripts.OnClick()
assert(resumed == 2 and OffhandCharDB.characterSetup.choice == "customize"
        and not OffhandCharDB.characterSetup.complete,
    "the owned third button must preserve the character's Customize choice")
addon.Mainhand, addon.CharacterSetup, addon.Wizard = priorMainhand, priorCharacterSetup, nil
OffhandCharDB = reminderCharacter
StaticPopupDialogs.OFFHAND_WIZARD_SKIP_MAINHAND_LAYOUT = nil
addon.Viewport, addon.UIControls = nil, nil

CreateFrame = originalCreateFrame
UIParent = originalUIParent
StaticPopup_Show = originalStaticPopupShow
StaticPopup_Hide = originalStaticPopupHide
addon._foreverGamepadEditModeControlsPrompt = nil
addon._gamepadSafePopup = nil
addon.API = nil
addon.HUD = nil
InputUtil, Enum = nil, nil

local initSource = assert(io.open("Core/Init.lua", "rb")):read("*a")
for _, obsolete in ipairs({
    "Performance diagnostics:", "AA diagnostics:", "Scaling diagnostics:",
    "Nameplate frame diagnostics:", "Nameplate visibility diagnostics:",
    "Addon bag diagnostics:",
    "Forever native bag diagnostics:", "Panel reload diagnostics:",
    "Panel motion diagnostics:", "Group-frame diagnostics:",
    "Protected-HUD diagnostics:",
}) do
    assert(not initSource:find(obsolete, 1, true),
        "resolved test probe remains in /offhand diag: " .. obsolete)
end
for _, current in ipairs({
    "Topology diagnostics:", "Combat text diagnostics:",
    "Speech bubble diagnostics:", "Group loot diagnostics:", "Pet battle diagnostics:",
    "Edit Mode layout diagnostics:",
}) do
    assert(initSource:find(current, 1, true),
        "current support diagnostic is missing: " .. current)
end
local printedDiagnostic
DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, message) printedDiagnostic = message end,
}
addon:Print("Optional diagnostic=%s", nil)
assert(printedDiagnostic and string.find(printedDiagnostic,
        "Optional diagnostic=unavailable", 1, true),
    "a missing optional diagnostic value aborted formatted chat output")
local initOnEvent = events.OnEvent
local attentionPopup
StaticPopup_Show = function(name) attentionPopup = name end
addon.isForever = false
addon.Mainhand = { NeedsEditModeLayoutAttention = function() return true, "missing" end }
assert(addon:RefreshMainhandLayoutAttention()
        and attentionPopup == "OFFHAND_MAINHAND_LAYOUT_ATTENTION",
    "an existing setup missing its generated HUD layout must receive a repair action")
StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_ATTENTION.OnCancel()
attentionPopup = nil
assert(not addon:RefreshMainhandLayoutAttention() and attentionPopup == nil,
    "declining Mainhand HUD repair must suppress repeats for the current UI session")
addon._mainhandLayoutAttentionDismissed = nil
local repairPrint, reloadPrompted
addon.Mainhand = {
    NeedsEditModeLayoutAttention = function() return true, "missing" end,
    CreateOrUpdateEditModeLayout = function()
        return true, "Offhand - Mainhand - Tester", 12
    end,
    PromptReload = function() reloadPrompted = true end,
}
addon.Print = function(_, key, name, moved)
    repairPrint = { key, name, moved }
end
StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_ATTENTION.OnAccept()
assert(repairPrint and repairPrint[2] == "Offhand - Mainhand - Tester"
        and repairPrint[3] == 12 and reloadPrompted,
    "the migration repair action must preserve the layout name and moved-system count")
addon.Mainhand = nil
assert(not addon:HasBlizzardEditMode(),
    "a Classic-family client without an Edit Mode module must retain legacy ownership")
C_AddOns = {
    DoesAddOnExist = function(name) return name == "Blizzard_EditMode" end,
}
assert(addon:HasBlizzardEditMode(),
    "Classic and Anniversary clients must detect load-on-demand Blizzard Edit Mode")
C_AddOns = nil
GetAddOnInfo = function(name)
    return name == "Blizzard_EditMode" and name or nil
end
assert(addon:HasBlizzardEditMode(),
    "legacy addon discovery must detect Blizzard Edit Mode before its API is loaded")
GetAddOnInfo = nil
assert(loadfile("Core/Config.lua"))("Offhand", addon)
local messages = {}
addon.Print = function(_, message) messages[#messages + 1] = message end

OffhandDB = { deckWidthRatio = 0.55, hudScale = 0.85 }
addon:InitializeConfig()
assert(addon.db.deckWidthRatio == 0.55, "migration changed seam")
assert(addon.db.hudScale == 0.85, "migration changed HUD scale")
OffhandDB = "invalid"
addon:InitializeConfig()
local defaultSeam = addon.db.deckWidthRatio
local defaultHeight = addon.db.gameHeightRatio
addon:ResetConfig()
assert(addon.db.deckWidthRatio == defaultSeam)
assert(addon.db.gameHeightRatio == defaultHeight)
assert(registeredEvents.CINEMATIC_START and registeredEvents.CINEMATIC_STOP,
    "cinematic viewport recovery events were not registered")
assert(registeredEvents.PLAYER_CONTROL_LOST and registeredEvents.PLAYER_CONTROL_GAINED,
    "Blizzard input-ownership events were not registered")

local calls = 0
addon.UpdateViewport = function() calls = calls + 1 end
addon.UpdateCanvas = function() assert(not combat) end
combat = true
for i = 1, 20 do addon:ApplyFullLayout() end
assert(calls == 0, "layout ran during combat")
combat = false
events.OnEvent(nil, "PLAYER_REGEN_ENABLED")
assert(calls == 1, "combat requests were not coalesced")
addon.UpdateCanvas = function() error("injected layout failure") end
addon:ApplyFullLayout()
assert(messages[#messages] == "MSG_LAYOUT_ERROR", "failure was hidden")
addon.UpdateCanvas = function() addon:ApplyFullLayout() end
addon:ApplyFullLayout()
assert(calls == 3, "layout guard did not recover or prevent recursion")

local menuRefreshes = 0
local previousViewport, previousMenus = addon.Viewport, addon.MenuPlacement
addon.Viewport = {GetMetrics=function() return {isSpanned=false} end}
addon.MenuPlacement = {Refresh=function() menuRefreshes=menuRefreshes+1 end}
addon.UpdateCanvas = function() end
addon:ApplyFullLayout()
assert(menuRefreshes==1,"single-window fallback must refresh owned open menus, not only spanned HUD")
addon.Viewport,addon.MenuPlacement=previousViewport,previousMenus

do
    local oldViewport=addon.Viewport
    local rootWrites=0
    addon.Viewport={GetMetrics=function()return{isSpanned=true}end,
        ApplyGlobalScale=function()rootWrites=rootWrites+1 end}
    local before=calls
    addon:ApplyFullLayout(true)
    assert(calls==before+1 and rootWrites==0,'external scale refresh must run geometry without replacing root scale')
    addon:ApplyFullLayout()
    assert(rootWrites==1,'ordinary layout lost its scale ownership')
    addon.Viewport=oldViewport
end

-- Verify ADDON_LOADED initializes Canvas and SeamRedirect without recursion / stack overflow
UIParent = {
    GetEffectiveScale = function() return 1 end,
    GetWidth = function() return 4000 end,
    GetHeight = function() return 2560 end,
    GetLeft = function() return 0 end,
    GetRight = function() return 4000 end,
    GetTop = function() return 2560 end,
    GetBottom = function() return 0 end,
    GetScale = function() return 1 end,
    SetScale = function() end,
}
WorldFrame = { ClearAllPoints = function() end, SetAllPoints = function() end, SetPoint = function() end }
hooksecurefunc = function() end
UISpecialFrames = {}
addon.Viewport = {
    GetMetrics = function()
        return { isSpanned = true, gameWidth = 2560, gameHeight = 1440, deckWidth = 1440, bezel = 0, gameLeft = 1440, gameRight = 4000, gameBottom = 0, gameTop = 1440 }
    end,
    Apply = function() end,
}
local function makeMockFrame()
    local f = {}
    f.RegisterEvent = function() end
    f.SetScript = function(_, name, fn) events[name] = fn end
    f.SetFrameStrata = function() end
    f.SetFrameLevel = function() end
    f.CreateTexture = function() return { SetAllPoints = function() end } end
    f.SetAllPoints = function() end
    f.ClearAllPoints = function() end
    f.SetPoint = function() end
    f.Hide = function() end
    f.Show = function() end
    f.HookScript = function() end
    return f
end
CreateFrame = function() return makeMockFrame() end
assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasFrameState.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelRegistry.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPersistence.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasBackpackState.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasForeverBags.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasForeverMap.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasChat.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasProfessions.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelMotion.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasMapPresentation.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelLifecycle.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelPlacement.lua"))("Offhand", addon)
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", addon)
assert(loadfile("Core/HUDTransientPolicy.lua"))("Offhand", addon)
assert(loadfile("Core/HUDRecovery.lua"))("Offhand", addon)
assert(loadfile("Core/HUDTransientFrames.lua"))("Offhand", addon)
assert(loadfile("Core/SeamRedirect.lua"))("Offhand", addon)
C_Timer = {After=function() end}
local initOk, initErr = pcall(function()
    initOnEvent(nil, "ADDON_LOADED", "Offhand")
end)
assert(initOk, "ADDON_LOADED failed with error: " .. tostring(initErr))
assert(type(addon.InitializeCanvas) == "function", "InitializeCanvas missing")
assert(type(addon.InitializeSeamRedirect) == "function", "InitializeSeamRedirect missing")

-- Display changes are a burst during Companion spanning. The prior timer must
-- be cancelled, persistence capture suspended, and layout restored only after
-- the final geometry settles.
local displayTimers = {}
C_Timer.NewTimer = function(delay, fn)
    local timer = { delay = delay, fn = fn, cancelled = false }
    function timer:Cancel() self.cancelled = true end
    displayTimers[#displayTimers + 1] = timer
    return timer
end
local displayApplies, displayRestores = 0, 0
local displayGuideRefreshes, previousDisplayGuide = 0, addon.Onboarding
addon.Onboarding = {RefreshDisplayState = function()
    assert(addon._displayGeometryTransitionActive == false,
        "guide readiness must refresh after the transition flag is cleared")
    displayGuideRefreshes = displayGuideRefreshes + 1
end}
addon.ApplyFullLayout = function() displayApplies = displayApplies + 1 end
addon.Canvas.RestorePersistentFrames = function() displayRestores = displayRestores + 1 end
initOnEvent(nil, "DISPLAY_SIZE_CHANGED")
local superseded = displayTimers[#displayTimers]
initOnEvent(nil, "UI_SCALE_CHANGED")
local finalTimer = displayTimers[#displayTimers]
assert(superseded.cancelled == true, "display debounce did not cancel the superseded geometry pass")
assert(addon._displayGeometryTransitionActive == true, "display transition did not suspend persistence capture")
superseded.fn()
assert(displayApplies == 0, "superseded display geometry pass applied a layout")
assert(displayGuideRefreshes == 0, "superseded display generation refreshed the guide")
finalTimer.fn()
assert(displayApplies == 1 and displayRestores == 1,
    "settled display geometry did not apply and restore exactly once")
assert(addon._displayGeometryTransitionActive == false,
    "display transition remained active after settled layout restore")
assert(displayGuideRefreshes == 1, "settled display geometry must refresh the guide exactly once")

-- A graphics reset can settle while combat still blocks layout writes. A later
-- reset must invalidate work already queued by the older debounce callback.
local originalRunOrQueueCombat = addon.RunOrQueueCombat
local queuedDisplayWork = {}
addon.RunOrQueueCombat = function(_, callback) queuedDisplayWork[#queuedDisplayWork + 1] = callback end
local appliesBeforeQueue, restoresBeforeQueue = displayApplies, displayRestores
initOnEvent(nil, "DISPLAY_SIZE_CHANGED")
displayTimers[#displayTimers].fn()
initOnEvent(nil, "DISPLAY_SIZE_CHANGED")
displayTimers[#displayTimers].fn()
assert(#queuedDisplayWork == 2)
queuedDisplayWork[1]()
assert(displayApplies == appliesBeforeQueue and displayRestores == restoresBeforeQueue
        and addon._displayGeometryTransitionActive,
    "a superseded combat-queued resize must not restore layout or end the newer transition")
assert(displayGuideRefreshes == 1, "stale queued geometry must not refresh guide readiness")
queuedDisplayWork[2]()
assert(displayApplies == appliesBeforeQueue + 1 and displayRestores == restoresBeforeQueue + 1
        and not addon._displayGeometryTransitionActive,
    "only the latest combat-queued display reset may restore the settled layout")
assert(displayGuideRefreshes == 2, "only the latest queued transition may refresh guide readiness")
addon.RunOrQueueCombat = originalRunOrQueueCombat
addon.Onboarding = previousDisplayGuide

-- In-engine cinematics can restore WorldFrame across the entire spanned
-- window. Start/stop transitions must reassert only the viewport after
-- Blizzard settles, cancel stale transition timers, and coalesce combat work.
local cinematicTimers = {}
C_Timer.After = function(delay, fn)
    cinematicTimers[#cinematicTimers + 1] = { delay = delay, fn = fn }
end
local cinematicApplies = 0
local rawMouseRefreshes = 0
local onboardingCloses, cinematicPopupShows = 0, 0
local skipDialogHook
local skipDialog = {
    shown = false,
    points = {},
    IsShown = function(self) return self.shown end,
    IsForbidden = function() return false end,
    IsProtected = function() return false end,
    GetEffectiveScale = function() return 1 end,
    ClearAllPoints = function(self) self.points = {} end,
    SetPoint = function(self, ...) self.points[#self.points + 1] = {...} end,
    HookScript = function(_, event, fn) if event == "OnShow" then skipDialogHook = fn end end,
}
CinematicFrame = { closeDialog = skipDialog, IsShown = function() return true end }
GetScreenWidth = function() return UIParent:GetWidth() end
addon.db.enabled = true
addon.isForever = true
addon.Viewport.Apply = function() cinematicApplies = cinematicApplies + 1 end
addon.RawMouse = {Refresh = function() rawMouseRefreshes = rawMouseRefreshes + 1 end}
addon.Onboarding = {Close = function() onboardingCloses = onboardingCloses + 1 end}
StaticPopup_Show = function() cinematicPopupShows = cinematicPopupShows + 1 end
addon.ApplyFullLayout = function() error("cinematic recovery rebuilt the full layout") end
initOnEvent(nil, "CINEMATIC_START")
assert(type(skipDialogHook) == "function",
    "Forever cinematic start must observe the native skip dialog without replacing key handling")
skipDialog.shown = true
skipDialogHook(skipDialog)
local skipPoint = skipDialog.points[#skipDialog.points]
assert(skipPoint and skipPoint[1] == "CENTER" and skipPoint[2] == UIParent
        and skipPoint[3] == "BOTTOMLEFT",
    "shown cinematic skip dialog must be centered in the visible Mainhand rectangle")
addon.isForever = false
addon:ShowCompanionNotice("HANDOFF", { topologyStatus = "ABSENT" })
assert(addon:IsCinematicOrMovieActive() and onboardingCloses == 1
        and cinematicPopupShows == 0,
    "intro cinematics must hide first-launch UI and suppress automatic popups so Escape reaches Blizzard")
local startTimers = cinematicTimers
cinematicTimers = {}
CinematicFrame.IsShown = function() return false end
skipDialog.shown = false
initOnEvent(nil, "CINEMATIC_STOP")
local stopTimers = cinematicTimers
for _, timer in ipairs(startTimers) do timer.fn() end
assert(cinematicApplies == 0, "stale cinematic-start timers were not superseded")
assert(#stopTimers == 5 and stopTimers[1].delay == 0
        and stopTimers[2].delay == 0.1 and stopTimers[3].delay == 0.5
        and stopTimers[4].delay == 0.5 and stopTimers[5].delay == 0.75,
    "cinematic recovery did not schedule the expected settling passes")
for _, timer in ipairs(stopTimers) do timer.fn() end
assert(cinematicApplies == 3, "cinematic stop did not reassert the viewport")
assert(rawMouseRefreshes == 1,
    "cinematic stop did not refresh native raw-mouse registration")
assert(not addon:IsCinematicOrMovieActive(),
    "cinematic stop must release automatic UI deferral")
MovieFrame = { IsShown = function() return true end }
local popupsBeforeMovie = cinematicPopupShows
addon:ShowForeverLayoutRecoveryPrompt("fallback", "Offhand")
assert(cinematicPopupShows == popupsBeforeMovie and addon._automaticUIPendingAfterCinematic,
    "movie playback must suppress recovery popups without relying on cinematic events")
MovieFrame = nil
addon._automaticUIPendingAfterCinematic = nil

-- Some first-character intros reserve player input without a cinematic frame.
-- Automatic UI and inherited workspace restoration must remain deferred until
-- Blizzard returns control.
local inputRestoreCalls = 0
addon.Canvas.RestorePersistentFrames = function() inputRestoreCalls = inputRestoreCalls + 1 end
initOnEvent(nil, "PLAYER_CONTROL_LOST")
addon:ShowCompanionNotice("HANDOFF", { topologyStatus = "ABSENT" })
assert(addon:IsBlizzardInputReserved() and cinematicPopupShows == popupsBeforeMovie,
    "PLAYER_CONTROL_LOST must suppress automatic UI even without a cinematic frame")
cinematicTimers = {}
addon.Canvas.persistentRestorePendingForInput = true
initOnEvent(nil, "PLAYER_CONTROL_GAINED")
assert(not addon:IsBlizzardInputReserved() and inputRestoreCalls == 1,
    "PLAYER_CONTROL_GAINED must release and resume inherited workspace restoration")
for _, timer in ipairs(cinematicTimers) do timer.fn() end

cinematicTimers = {}
combat = true
initOnEvent(nil, "CINEMATIC_STOP")
for _, timer in ipairs(cinematicTimers) do timer.fn() end
assert(cinematicApplies == 3, "cinematic viewport changed during combat")
combat = false
initOnEvent(nil, "PLAYER_REGEN_ENABLED")
assert(cinematicApplies == 4, "combat cinematic recovery was not coalesced")

-- Disabled profiles must not mutate Blizzard frame placement or user CVars at login.
local loginMutations = 0
addon.db.enabled = false
addon.ApplyFullLayout = function() end
ChatFrame1 = { SetClampedToScreen = function() loginMutations = loginMutations + 1 end }
ContainerFrame1 = { SetUserPlaced = function() loginMutations = loginMutations + 1 end }
PlayerFrame = { SetUserPlaced = function() loginMutations = loginMutations + 1 end }
SetCVar = function() loginMutations = loginMutations + 1 end
initOnEvent(nil, "PLAYER_LOGIN")
assert(loginMutations == 0, "disabled Offhand profile mutated Blizzard frames or CVars at login")

-- Forever owns protected HUD placement through Blizzard Edit Mode. Login may
-- normalize bag placement, but must not mark PlayerFrame, TargetFrame or the
-- minimap as user-placed; even that seemingly harmless write can taint secret
-- status-bar values when CharacterFrame later closes.
local foreverBagMutations, foreverHudMutations = 0, 0
addon.db.enabled = true
addon.isForever = true
ChatFrame1 = { SetClampedToScreen = function() end }
ContainerFrame1 = { SetUserPlaced = function() foreverBagMutations = foreverBagMutations + 1 end }
PlayerFrame = { SetUserPlaced = function() foreverHudMutations = foreverHudMutations + 1 end }
TargetFrame = { SetUserPlaced = function() foreverHudMutations = foreverHudMutations + 1 end }
MinimapCluster = { SetUserPlaced = function() foreverHudMutations = foreverHudMutations + 1 end }
initOnEvent(nil, "PLAYER_LOGIN")
assert(foreverBagMutations == 1,
    "Forever login regression did not exercise the enabled placement path")
assert(foreverHudMutations == 0,
    "Forever login must not mutate protected PlayerFrame, TargetFrame or minimap placement")

-- Forever /reload may emit PLAYER_LOGOUT without PLAYER_LEAVING_WORLD. Capture
-- visibility there, and do not let a later teardown event overwrite it.
local capturedOpenPanels
local capturedProfileOpenPanels
addon.db.enabled = true
addon.db.restoreWorkspaceOnReload = true
addon.db.savedWorkspacePositions = { TestWorkspaceFrame = { x = 10, y = 20 } }
TestWorkspaceFrame = { IsVisible = function() return true end }
addon.ForeverPersistence = {
    SaveOpenPanels = function(_, panels)
        capturedOpenPanels = {}
        for name, value in pairs(panels) do capturedOpenPanels[name] = value end
    end,
    SaveProfileSnapshot = function()
        capturedProfileOpenPanels = {}
        for name, value in pairs(addon.db.openWorkspacePanels or {}) do
            capturedProfileOpenPanels[name] = value
        end
    end,
}
initOnEvent(nil, "PLAYER_LOGOUT")
assert(capturedOpenPanels and capturedOpenPanels.TestWorkspaceFrame == true,
    "PLAYER_LOGOUT must capture open workspace panels for /reload")
assert(capturedProfileOpenPanels and capturedProfileOpenPanels.TestWorkspaceFrame == true,
    "the complete Forever snapshot must be written after open-panel capture")
TestWorkspaceFrame.IsVisible = function() return false end
initOnEvent(nil, "PLAYER_LEAVING_WORLD")
assert(capturedOpenPanels.TestWorkspaceFrame == true,
    "a later teardown event must not overwrite the captured visibility snapshot")

-- Forever may hide panels before the first teardown event is delivered. The
-- continuously tracked state must survive that already-hidden first snapshot.
addon._openPanelsCapturedForTransition = false
addon.db.openWorkspacePanels = { TestWorkspaceFrame = true }
capturedOpenPanels = nil
TestWorkspaceFrame.IsVisible = function() return false end
initOnEvent(nil, "PLAYER_LOGOUT")
assert(capturedOpenPanels and capturedOpenPanels.TestWorkspaceFrame == true,
    "PLAYER_LOGOUT must preserve the last explicit open state after Blizzard teardown hiding")

-- Restore Window can leave Forever without any loaded exact topology. Do not
-- replace the last spanned-session visibility snapshot with the temporary
-- single-screen state during logout or /reload.
addon._openPanelsCapturedForTransition = false
addon.db.openWorkspacePanels = { TestWorkspaceFrame = true }
capturedOpenPanels = nil
addon.Viewport.GetMetrics = function()
    return { isSpanned = false, topologyStatus = "ABSENT" }
end
addon.Viewport.IsSingleScreenRecovery = function(_, metrics)
    return metrics and not metrics.isSpanned
        and (metrics.topologyStatus == "MISMATCH" or metrics.topologyStatus == "ABSENT")
end
initOnEvent(nil, "PLAYER_LOGOUT")
assert(capturedOpenPanels == nil and addon.db.openWorkspacePanels.TestWorkspaceFrame == true,
    "Forever absent-topology recovery must preserve the last workspace visibility snapshot")

-- A welcome acknowledgement is not calibration completion. Entry notices must
-- resume enabled incomplete setups, but leave completed/disabled users alone.
do
    local queue, opened = {}, 0
    C_Timer.After = function(_, callback) queue[#queue + 1] = callback end
    addon.IsBlizzardInputReserved = function() return false end
    addon.HideCompanionNotices = function() end
    addon.HideResolvedSpanPrompts = function() end
    addon.RefreshCompanionNoticeState = function() return false end
    addon.RefreshMainhandLayoutAttention = function() end
    addon.ApplyFullLayout = function() end
    addon.RawMouse = nil
    addon.Canvas = {}
    addon.Viewport.GetMetrics = function() return {isSpanned = false} end
    addon.Onboarding = {Open = function() opened = opened + 1 end}
    addon.IsWelcomeDismissed = function() return true end
    addon.GetOnboardingResumeStep = function() return nil end
    local complete = false
    addon.IsSetupComplete = function() return complete end
    addon.db.firstRunComplete = false
    addon.db.enabled = true
    addon._displayGeometryTransitionActive = false
    local function Enter(first)
        if first then addon._hasEnteredWorld = nil end
        initOnEvent(nil, "PLAYER_ENTERING_WORLD")
        local count = 0
        while #queue > 0 do
            count = count + 1
            assert(count < 10, "entry notices must not poll indefinitely")
            table.remove(queue, 1)()
        end
    end
    Enter(true)
    assert(opened == 1, "login must resume a dismissed welcome whose calibration is incomplete")
    Enter(false)
    assert(opened == 1, "zone transitions must not repeatedly reopen onboarding")
    complete = true
    Enter(true)
    assert(opened == 1, "completed users must not be forced through setup again")
    complete, addon.db.enabled = false, false
    addon.db.automaticSetupSuppressed = true
    addon.GetOnboardingResumeStep = function() return 6 end
    Enter(true)
    assert(opened == 1, "a deliberately disabled profile must not receive incomplete-setup prompts")
end
print("PASS: lifecycle, entry notice resumption, disabled isolation and completed-setup preservation")

