-- Run the production logout handler with a temporary spanned UI scale.
local logout
StaticPopupDialogs, SlashCmdList = {}, {}
CreateFrame = function()
    local events = {}
    return {
        RegisterEvent = function(_, event) events[event] = true end,
        SetScript = function(_, script, callback)
            if script == "OnEvent" and events.PLAYER_LOGOUT and not events.PLAYER_LOGIN then
                logout = callback
            end
        end,
    }
end
GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
local combat, scale, writes = false, 0.8, 0
InCombatLockdown = function() return combat end
UIParent = {
    GetScale = function() return scale end,
    SetScale = function(_, value) scale, writes = value, writes + 1 end,
}
WorldFrame = {ClearAllPoints = function() end, SetAllPoints = function() end}
local cvarWrites = 0
GetCVar = function() return nil end
SetCVar = function() cvarWrites = cvarWrites + 1 end
local addon = {}
assert(loadfile("Core/Init.lua"))("Offhand", addon)
assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
assert(logout, "production PLAYER_LOGOUT cleanup was not captured")
local viewport = addon.Viewport
viewport.GetMetrics = function() return {isSpanned = true,
    gamePixelHeight = 1080, gamePixelWidth = 1920, physicalHeight = 2160} end
local function apply()
    addon.db = {enabled = true, hudScale = 0.7}
    viewport:ApplyGlobalScale()
    assert(math.abs(scale - 0.35) < 0.00001, "fixture did not apply spanned UI scale")
end
apply()
logout()
assert(scale == 0.8, "logout left Offhand's temporary scale on UIParent")
assert(addon.db.enabled, "logout changed the saved enabled preference")
assert(cvarWrites == 0, "runtime-scale cleanup changed saved UI/font preferences")
local restoredWrites = writes
-- Simulate a synchronous display callback or late layout event during teardown.
viewport:ApplyGlobalScale()
logout()
assert(scale == 0.8 and writes == restoredWrites, "teardown reapplied or repeatedly restored scale")

-- Another scale owner wins if it changed the root after Offhand's last write.
assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
viewport = addon.Viewport
viewport.GetMetrics = function() return {isSpanned = true,
    gamePixelHeight = 1080, gamePixelWidth = 1920, physicalHeight = 2160} end
apply()
scale = 0.9
logout()
assert(scale == 0.9, "logout overwrote another owner's UI scale")

-- A synchronous native/other-addon hook can change the root before our setter
-- returns. Track our requested value, never claim that hook's replacement.
assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
viewport = addon.Viewport
viewport.GetMetrics = function() return {isSpanned = true,
    gamePixelHeight = 1080, gamePixelWidth = 1920, physicalHeight = 2160} end
local setScale = UIParent.SetScale
UIParent.SetScale = function(self, value)
    setScale(self, value)
    scale = 0.95
end
addon.db = {enabled = true, hudScale = 0.7}
viewport:ApplyGlobalScale()
UIParent.SetScale = setScale
logout()
assert(scale == 0.95, "logout claimed another owner's synchronous scale replacement")

-- A reload requested in combat must not write the protected root or queue
-- a restore into a session which is already being torn down.
assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
viewport = addon.Viewport
viewport.GetMetrics = function() return {isSpanned = true,
    gamePixelHeight = 1080, gamePixelWidth = 1920, physicalHeight = 2160} end
apply()
combat = true
addon.RunOrQueueCombat = function() end
local combatWrites = writes
logout()
assert(writes == combatWrites, "logout changed UIParent scale during combat")
combat = false
viewport:ApplyGlobalScale()
assert(writes == combatWrites, "a late callback reapplied scale after combat logout")
print("PASS: logout restores owned UI scale, preserves preferences/external ownership, and guards combat/late callbacks")

-- Explicit disable must release ownership as carefully as logout does.
assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
viewport=addon.Viewport
viewport.GetMetrics=function()return{isSpanned=true,gamePixelHeight=1080,gamePixelWidth=1920,physicalHeight=2160}end
apply();scale=.9;addon.db.enabled=false;viewport:ApplyGlobalScale()
assert(scale==.9,'disable overwrote a later external UI scale')
assert(viewport.originalScale==nil and viewport.appliedScale==nil,'disable retained stale ownership')
apply();scale=.95;viewport:ApplyGlobalScale();addon.db.enabled=false;viewport:ApplyGlobalScale()
assert(scale==.95,'reclaiming the root forgot the latest external baseline')
print('PASS: disable yields external scale and restores the latest baseline after an explicit reclaim')
