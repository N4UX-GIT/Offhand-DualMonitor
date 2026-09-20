StaticPopupDialogs = {}
-- Run from the project root with Lua 5.1.
local addon = {}
local events = {}
local combat = false
GetBuildInfo = function() return "", "", "", 11509 end
CreateFrame = function(_, frameName)
    return { RegisterEvent = function() end,
        SetScript = function(_, name, fn)
            if frameName == "OffhandEventFrame" then events[name] = fn end
        end }
end
InCombatLockdown = function() return combat end
SlashCmdList = {}
assert(loadfile("Core/Init.lua"))("Offhand", addon)
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
    events.OnEvent(nil, "ADDON_LOADED", "Offhand")
end)
assert(initOk, "ADDON_LOADED failed with error: " .. tostring(initErr))
assert(type(addon.InitializeCanvas) == "function", "InitializeCanvas missing")
assert(type(addon.InitializeSeamRedirect) == "function", "InitializeSeamRedirect missing")

-- Disabled profiles must not mutate Blizzard frame placement or user CVars at login.
local loginMutations = 0
addon.db.enabled = false
addon.ApplyFullLayout = function() end
ChatFrame1 = { SetClampedToScreen = function() loginMutations = loginMutations + 1 end }
ContainerFrame1 = { SetUserPlaced = function() loginMutations = loginMutations + 1 end }
PlayerFrame = { SetUserPlaced = function() loginMutations = loginMutations + 1 end }
SetCVar = function() loginMutations = loginMutations + 1 end
events.OnEvent(nil, "PLAYER_LOGIN")
assert(loginMutations == 0, "disabled Offhand profile mutated Blizzard frames or CVars at login")

print("PASS: config preservation, defaults, combat coalescing, error recovery, reentrancy, ADDON_LOADED stack safety, disabled login isolation")

