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
local initOnEvent = events.OnEvent
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
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
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
addon.db.enabled = true
addon.Viewport.Apply = function() cinematicApplies = cinematicApplies + 1 end
addon.ApplyFullLayout = function() error("cinematic recovery rebuilt the full layout") end
initOnEvent(nil, "CINEMATIC_START")
local startTimers = cinematicTimers
cinematicTimers = {}
initOnEvent(nil, "CINEMATIC_STOP")
local stopTimers = cinematicTimers
for _, timer in ipairs(startTimers) do timer.fn() end
assert(cinematicApplies == 0, "stale cinematic-start timers were not superseded")
assert(#stopTimers == 3 and stopTimers[1].delay == 0
        and stopTimers[2].delay == 0.1 and stopTimers[3].delay == 0.5,
    "cinematic recovery did not schedule the expected settling passes")
for _, timer in ipairs(stopTimers) do timer.fn() end
assert(cinematicApplies == 3, "cinematic stop did not reassert the viewport")

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

