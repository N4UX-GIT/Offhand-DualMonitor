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
    function frame:SetFrameStrata(value) self.strata = value end
    function frame:SetClampedToScreen(value) self.clamped = value end
    function frame:EnableMouse(value) self.mouse = value end
    function frame:SetBackdrop(value) self.backdrop = value end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:SetText(value) self.text = value end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:Show()
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
        function text:SetHeight(value) self.height = value end
        function text:SetJustifyH(value) self.justifyH = value end
        function text:SetJustifyV(value) self.justifyV = value end
        function text:SetWordWrap(value) self.wordWrap = value end
        function text:SetText(value) self.text = value end
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
safePrompt.accept.scripts.OnClick()
assert(safeAccepted == 1 and dataCalled == 1 and safeHidden == 1
        and not safePrompt.shown and staticHides == 0,
    "accepting a Gamepad-safe dialog must preserve callback data without Blizzard popup calls")
addon:ShowPopup("OFFHAND_GAMEPAD_SAFE_TEST", "Gamepad")
safePrompt.cancel.scripts.OnClick()
assert(safeCancelled == 1 and safeHidden == 2 and staticHides == 0,
    "cancelling a Gamepad-safe dialog must remain outside Blizzard's focus stack")
StaticPopupDialogs.OFFHAND_GAMEPAD_SAFE_TEST = nil

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
    "Addon bag diagnostics:", "Cinematic skip-dialog diagnostics:",
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
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", addon)
assert(loadfile("Core/HUDTransientPolicy.lua"))("Offhand", addon)
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
finalTimer.fn()
assert(displayApplies == 1 and displayRestores == 1,
    "settled display geometry did not apply and restore exactly once")
assert(addon._displayGeometryTransitionActive == false,
    "display transition remained active after settled layout restore")

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

print("PASS: config preservation, defaults, combat coalescing, cinematic recovery, error recovery, reentrancy, ADDON_LOADED stack safety, disabled login isolation")

