-- Run the production logout and display handlers with a temporary spanned UI scale.
StaticPopupDialogs, SlashCmdList = {}, {}
GetBuildInfo = function() return "1.60.1", "70938", "", 16001 end
local combat = false
InCombatLockdown = function() return combat end
local scale, scaleWrites, cvarWrites, worldResets, worldAnchors = 0.8, 0, 0, 0, 0
local onScaleWrite, onWorldReset
UIParent = {
    GetScale = function() return scale end,
    GetEffectiveScale = function() return scale end,
    SetScale = function(_, value)
        scale, scaleWrites = value, scaleWrites + 1
        if onScaleWrite then onScaleWrite() end
    end,
}
WorldFrame = {
    GetEffectiveScale = function() return 1 end,
    SetPoint = function() worldAnchors = worldAnchors + 1 end,
    ClearAllPoints = function() end,
    SetAllPoints = function()
        worldResets = worldResets + 1
        if onWorldReset then onWorldReset() end
    end,
}
GetCVar = function() return nil end
SetCVar = function() cvarWrites = cvarWrites + 1 end

local function setup()
    local mainEvent, logout
    CreateFrame = function(_, name)
        local events = {}
        return {
            RegisterEvent = function(_, event) events[event] = true end,
            SetScript = function(_, script, callback)
                if script ~= "OnEvent" then return end
                if name == "OffhandEventFrame" then
                    mainEvent = callback
                elseif events.PLAYER_LOGOUT and not events.PLAYER_LOGIN then
                    logout = callback
                end
            end,
        }
    end
    local addon = {}
    assert(loadfile("Core/Init.lua"))("Offhand", addon)
    assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
    assert(mainEvent and logout, "production event handlers were not captured")
    local metrics = {
        isSpanned = true, gamePixelHeight = 1080, gamePixelWidth = 1920, physicalHeight = 2160,
        gameLeft = 0, gameBottom = 0, gameRight = 960, gameTop = 540,
    }
    addon.Viewport.GetMetrics = function() return metrics end
    addon.db = {enabled = true, hudScale = 0.7, restoreWorkspaceOnReload = true,
        savedWorkspacePositions = {}}
    addon.IsGamepadUIEnabled = function() return false end
    scale = 0.8
    addon.Viewport:ApplyGlobalScale()
    assert(math.abs(scale - 0.35) < 0.00001, "fixture did not apply spanned UI scale")
    return addon, mainEvent, logout, metrics
end

local timers = {}
C_Timer = {
    NewTimer = function(_, callback)
        local timer = { callback = callback }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end,
}

-- Simulate a native notification and direct layout retry during teardown.
local addon, mainEvent, logout = setup()
local spannedScale, beforeScaleWrites, beforeResets = scale, scaleWrites, worldResets
local layoutWrites, rawRestores, rawUpdates, rawRefreshes, panelRestores = 0, 0, 0, 0, 0
addon.UpdateCanvas = function() layoutWrites = layoutWrites + 1 end
addon.RawMouse = {
    Restore = function() rawRestores = rawRestores + 1 end,
    Update = function() rawUpdates = rawUpdates + 1 end,
    Refresh = function() rawRefreshes = rawRefreshes + 1 end,
}
addon.Canvas = {
    RestorePersistentFrames = function() panelRestores = panelRestores + 1 end,
}
local function retryLayout()
    mainEvent(nil, "UI_SCALE_CHANGED")
    addon:ApplyFullLayout()
    addon.Viewport:Apply()
end
onScaleWrite, onWorldReset = retryLayout, retryLayout
mainEvent(nil, "DISPLAY_SIZE_CHANGED")
local pendingTimer = timers[1]
logout()
onScaleWrite, onWorldReset = nil, nil
assert(scale == spannedScale and scaleWrites == beforeScaleWrites,
    "PLAYER_LOGOUT wrote the native UI root scale during teardown")
assert(pendingTimer.cancelled and #timers == 1,
    "PLAYER_LOGOUT did not cancel existing display work or accepted a new notification")
assert(rawRestores == 1 and worldResets == beforeResets + 1, "legacy logout cleanup did not run")
mainEvent(nil, "DISPLAY_SIZE_CHANGED")
pendingTimer.callback() -- A timer already dispatched before cancellation must be harmless.
addon.Viewport:ApplyGlobalScale()
assert(#timers == 1 and layoutWrites == 0 and rawUpdates == 0
    and rawRefreshes == 0 and panelRestores == 0 and worldAnchors == 0,
    "display layout resumed after shutdown began")
assert(addon.db.enabled and cvarWrites == 0, "logout changed saved UI/font preferences")

-- A display pass that already transferred into the combat queue must also stop,
-- even if the main event frame gets PLAYER_LOGOUT before the cleanup frame.
addon, mainEvent, logout = setup()
combat = true
local queued
local queue = addon.RunOrQueueCombat
addon.RunOrQueueCombat = function(_, callback) queued = callback end
mainEvent(nil, "DISPLAY_SIZE_CHANGED")
timers[#timers].callback()
assert(queued, "fixture did not queue display work for combat")
local captured = false
addon.ForeverPersistence = {
    SaveOpenPanels = function() end,
    SaveProfileSnapshot = function() captured = true end,
}
addon.RawMouse = { Refresh = function() rawRefreshes = rawRefreshes + 1 end }
addon.RunOrQueueCombat = queue
local combatWrites = scaleWrites
mainEvent(nil, "PLAYER_LOGOUT")
local timerCount = #timers
mainEvent(nil, "DISPLAY_SIZE_CHANGED")
logout()
combat = false
queued()
assert(captured, "PLAYER_LOGOUT skipped saved workspace state")
assert(#timers == timerCount and rawRefreshes == 0 and scaleWrites == combatWrites,
    "logout accepted display work or a queued refresh rewrote runtime scale")

-- Explicit disable or an unspanned window releases the runtime scale while the
-- UI is still active, preserving any later scale owner.
local viewport, metrics
addon, mainEvent, logout, metrics = setup()
viewport = addon.Viewport
metrics.isSpanned = false
viewport:ApplyGlobalScale()
assert(scale == 0.8 and addon.db.enabled, "unspan did not restore the native baseline")
assert(viewport.originalScale == nil and viewport.appliedScale == nil,
    "unspan retained stale scale ownership")

addon = setup()
viewport = addon.Viewport
addon.db.enabled = false
viewport:ApplyGlobalScale()
assert(scale == 0.8, "disable did not restore the native baseline")

for _, externalScale in ipairs({0.9, 0.95}) do
    addon = setup()
    viewport = addon.Viewport
    scale = externalScale
    if externalScale == 0.95 then
        -- A new explicit reapplication captures the newer owner as its baseline.
        viewport:ApplyGlobalScale()
    end
    addon.db.enabled = false
    viewport:ApplyGlobalScale()
    assert(scale == externalScale, "disable overwrote another owner's baseline")
    assert(viewport.originalScale == nil and viewport.appliedScale == nil,
        "disable retained stale scale ownership")
end

addon = setup()
viewport = addon.Viewport
local setScale = UIParent.SetScale
UIParent.SetScale = function(self, value)
    setScale(self, value)
    scale = 0.93
end
scale = 0.91
viewport:ApplyGlobalScale()
UIParent.SetScale = setScale
addon.db.enabled = false
viewport:ApplyGlobalScale()
assert(scale == 0.93, "disable claimed another owner's synchronous scale replacement")
print("PASS: logout blocks new and queued layout work without changing root scale or saved preferences")
print("PASS: disable and unspan restore owned scale and preserve external ownership")
